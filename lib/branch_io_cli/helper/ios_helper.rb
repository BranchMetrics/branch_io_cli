require "json"
require "net/http"
require "openssl"
require "plist"

module BranchIOCLI
  module Helper
    module IOSHelper
      APPLINKS = "applinks"
      ASSOCIATED_DOMAINS = "com.apple.developer.associated-domains"
      CODE_SIGN_ENTITLEMENTS = "CODE_SIGN_ENTITLEMENTS"
      DEVELOPMENT_TEAM = "DEVELOPMENT_TEAM"
      PRODUCT_BUNDLE_IDENTIFIER = "PRODUCT_BUNDLE_IDENTIFIER"
      RELEASE_CONFIGURATION = "Release"

      def add_keys_to_info_plist(project, target_name, keys, configuration = RELEASE_CONFIGURATION)
        update_info_plist_setting project, target_name, configuration do |info_plist|
          # add/overwrite Branch key(s)
          if keys.count > 1
            info_plist["branch_key"] = keys
          elsif keys[:live]
            info_plist["branch_key"] = keys[:live]
          else # no need to validate here, which was done by the action
            info_plist["branch_key"] = keys[:test]
          end
        end
      end

      def add_branch_universal_link_domains_to_info_plist(project, target_name, domains, configuration = RELEASE_CONFIGURATION)
        # Add all supplied domains unless all are app.link domains.
        return if domains.all? { |d| d =~ /app\.link$/ }

        update_info_plist_setting project, target_name, configuration do |info_plist|
          info_plist["branch_universal_link_domains"] = domains
        end
      end

      def ensure_uri_scheme_in_info_plist
        uri_scheme = ConfigurationHelper.uri_scheme

        # No URI scheme specified. Do nothing.
        return if uri_scheme.nil?

        update_info_plist_setting ConfigurationHelper.xcodeproj,
                                  ConfigurationHelper.target.name,
                                  RELEASE_CONFIGURATION do |info_plist|
          url_types = info_plist["CFBundleURLTypes"] || []
          uri_schemes = url_types.inject([]) { |schemes, t| schemes + t["CFBundleURLSchemes"] }

          if uri_schemes.empty?
            say "No URI scheme currently defined in project."
          else
            say "Existing URI schemes found in project:"
            uri_schemes.each do |scheme|
              say " #{scheme}"
            end
          end

          # Already present. Don't mess with the identifier.
          return if uri_schemes.include? uri_scheme

          # Not found. Add. Don't worry about the CFBundleURLName (reverse-DNS identifier)
          url_types << {
            "CFBundleURLSchemes" => [uri_scheme]
          }
          info_plist["CFBundleURLTypes"] = url_types

          say "Added URI scheme #{uri_scheme} to project."
        end
      end

      def update_info_plist_setting(project, target_name, configuration = RELEASE_CONFIGURATION, &b)
        # raises
        target = target_from_project project, target_name

        # find the Info.plist paths for this configuration
        info_plist_path = expanded_build_setting target, "INFOPLIST_FILE", configuration

        raise "Info.plist not found for configuration #{configuration}" if info_plist_path.nil?

        project_parent = File.dirname project.path

        info_plist_path = File.expand_path info_plist_path, project_parent

        # try to open and parse the Info.plist (raises)
        info_plist = File.open(info_plist_path) { |f| Plist.parse_xml f }
        raise "Failed to parse #{info_plist_path}" if info_plist.nil?

        yield info_plist

        Plist::Emit.save_plist info_plist, info_plist_path
        add_change info_plist_path
      end

      def add_universal_links_to_project(project, target_name, domains, remove_existing, configuration = RELEASE_CONFIGURATION)
        # raises
        target = target_from_project project, target_name

        relative_entitlements_path = expanded_build_setting target, CODE_SIGN_ENTITLEMENTS, configuration
        project_parent = File.dirname project.path

        if relative_entitlements_path.nil?
          relative_entitlements_path = File.join target.name, "#{target.name}.entitlements"
          entitlements_path = File.expand_path relative_entitlements_path, project_parent

          # Add CODE_SIGN_ENTITLEMENTS setting to each configuration
          target.build_configuration_list.set_setting CODE_SIGN_ENTITLEMENTS, relative_entitlements_path

          # Add the file to the project
          project.new_file relative_entitlements_path

          entitlements = {}
          current_domains = []

          add_change project.path
          new_path = entitlements_path
        else
          entitlements_path = File.expand_path relative_entitlements_path, project_parent
          # Raises
          entitlements = File.open(entitlements_path) { |f| Plist.parse_xml f }
          raise "Failed to parse entitlements file #{entitlements_path}" if entitlements.nil?

          if remove_existing
            current_domains = []
          else
            current_domains = entitlements[ASSOCIATED_DOMAINS]
          end
        end

        current_domains += domains.map { |d| "#{APPLINKS}:#{d}" }
        all_domains = current_domains.uniq

        entitlements[ASSOCIATED_DOMAINS] = all_domains

        Plist::Emit.save_plist entitlements, entitlements_path
        add_change entitlements_path

        new_path
      end

      def team_and_bundle_from_app_id(identifier)
        team = identifier.sub(/\..+$/, "")
        bundle = identifier.sub(/^[^.]+\./, "")
        [team, bundle]
      end

      def update_team_and_bundle_ids_from_aasa_file(project, target_name, domain)
        # raises
        identifiers = app_ids_from_aasa_file domain
        raise "Multiple appIDs found in AASA file" if identifiers.count > 1

        identifier = identifiers[0]
        team, bundle = team_and_bundle_from_app_id identifier

        update_team_and_bundle_ids project, target_name, team, bundle
        add_change project.path.expand_path
      end

      def validate_team_and_bundle_ids_from_aasa_files(project, target_name, domains = [], remove_existing = false, configuration = RELEASE_CONFIGURATION)
        @errors = []
        valid = true

        # Include any domains already in the project.
        # Raises. Returns a non-nil array of strings.
        if remove_existing
          # Don't validate domains to be removed (#16)
          all_domains = domains
        else
          all_domains = (domains + domains_from_project(project, target_name, configuration)).uniq
        end

        if all_domains.empty?
          # Cannot get here from SetupBranchAction, since the domains passed in will never be empty.
          # If called from ValidateUniversalLinksAction, this is a failure, possibly caused by
          # failure to add applinks:.
          @errors << "No Universal Link domains in project. Be sure each Universal Link domain is prefixed with applinks:."
          return false
        end

        all_domains.each do |domain|
          domain_valid = validate_team_and_bundle_ids project, target_name, domain, configuration
          valid &&= domain_valid
          say "Valid Universal Link configuration for #{domain} ✅" if domain_valid
        end
        valid
      end

      def app_ids_from_aasa_file(domain)
        data = contents_of_aasa_file domain
        # errors reported in the method above
        return nil if data.nil?

        # raises
        file = JSON.parse data

        applinks = file[APPLINKS]
        @errors << "[#{domain}] No #{APPLINKS} found in AASA file" and return if applinks.nil?

        details = applinks["details"]
        @errors << "[#{domain}] No details found for #{APPLINKS} in AASA file" and return if details.nil?

        identifiers = details.map { |d| d["appID"] }.uniq
        @errors << "[#{domain}] No appID found in AASA file" and return if identifiers.count <= 0
        identifiers
      rescue JSON::ParserError => e
        @errors << "[#{domain}] Failed to parse AASA file: #{e.message}"
        nil
      end

      def contents_of_aasa_file(domain)
        uris = [
          URI("https://#{domain}/.well-known/apple-app-site-association"),
          URI("https://#{domain}/apple-app-site-association")
          # URI("http://#{domain}/.well-known/apple-app-site-association"),
          # URI("http://#{domain}/apple-app-site-association")
        ]

        data = nil

        uris.each do |uri|
          break unless data.nil?

          Net::HTTP.start uri.host, uri.port, use_ssl: uri.scheme == "https" do |http|
            request = Net::HTTP::Get.new uri
            response = http.request request

            # Better to use Net::HTTPRedirection and Net::HTTPSuccess here, but
            # having difficulty with the unit tests.
            if (300..399).cover?(response.code.to_i)
              say "#{uri} cannot result in a redirect. Ignoring."
              next
            elsif response.code.to_i != 200
              # Try the next URI.
              say "Could not retrieve #{uri}: #{response.code} #{response.message}. Ignoring."
              next
            end

            content_type = response["Content-type"]
            @errors << "[#{domain}] AASA Response does not contain a Content-type header" and next if content_type.nil?

            case content_type
            when %r{application/pkcs7-mime}
              # Verify/decrypt PKCS7 (non-Branch domains)
              cert_store = OpenSSL::X509::Store.new
              signature = OpenSSL::PKCS7.new response.body
              # raises
              signature.verify nil, cert_store, nil, OpenSSL::PKCS7::NOVERIFY
              data = signature.data
            else
              @error << "[#{domain}] Unsigned AASA files must be served via HTTPS" and next if uri.scheme == "http"
              data = response.body
            end

            say "GET #{uri}: #{response.code} #{response.message} (Content-type:#{content_type}) ✅"
          end
        end

        @errors << "[#{domain}] Failed to retrieve AASA file" and return nil if data.nil?

        data
      rescue IOError, SocketError => e
        @errors << "[#{domain}] Socket error: #{e.message}"
        nil
      rescue OpenSSL::PKCS7::PKCS7Error => e
        @errors << "[#{domain}] Failed to verify signed AASA file: #{e.message}"
        nil
      end

      def validate_team_and_bundle_ids(project, target_name, domain, configuration)
        # raises
        target = target_from_project project, target_name

        product_bundle_identifier = expanded_build_setting target, PRODUCT_BUNDLE_IDENTIFIER, configuration
        development_team = expanded_build_setting target, DEVELOPMENT_TEAM, configuration

        identifiers = app_ids_from_aasa_file domain
        return false if identifiers.nil?

        app_id = "#{development_team}.#{product_bundle_identifier}"
        match_found = identifiers.include? app_id

        unless match_found
          @errors << "[#{domain}] appID mismatch. Project: #{app_id}. AASA: #{identifiers}"
        end

        match_found
      end

      def validate_project_domains(expected, project, target, configuration = RELEASE_CONFIGURATION)
        @errors = []
        project_domains = domains_from_project project, target, configuration
        valid = expected.count == project_domains.count
        if valid
          sorted = expected.sort
          project_domains.sort.each_with_index do |domain, index|
            valid = false and break unless sorted[index] == domain
          end
        end

        unless valid
          @errors << "Project domains do not match :domains parameter"
          @errors << "Project domains: #{project_domains}"
          @errors << ":domains parameter: #{expected}"
        end

        valid
      end

      def update_team_and_bundle_ids(project, target_name, team, bundle)
        # raises
        target = target_from_project project, target_name

        target.build_configuration_list.set_setting PRODUCT_BUNDLE_IDENTIFIER, bundle
        target.build_configuration_list.set_setting DEVELOPMENT_TEAM, team

        # also update the team in the first test target
        target = project.targets.find(&:test_target_type?)
        return if target.nil?

        target.build_configuration_list.set_setting DEVELOPMENT_TEAM, team
      end

      def target_from_project(project, target_name)
        if target_name
          target = project.targets.find { |t| t.name == target_name }
          raise "Target #{target} not found" if target.nil?
        else
          # find the first application target
          target = project.targets.find { |t| !t.extension_target_type? && !t.test_target_type? }
          raise "No application target found" if target.nil?
        end
        target
      end

      def domains_from_project(project, target_name, configuration = RELEASE_CONFIGURATION)
        # Raises. Does not return nil.
        target = target_from_project project, target_name

        relative_entitlements_path = expanded_build_setting target, CODE_SIGN_ENTITLEMENTS, configuration
        return [] if relative_entitlements_path.nil?

        project_parent = File.dirname project.path
        entitlements_path = File.expand_path relative_entitlements_path, project_parent

        # Raises
        entitlements = File.open(entitlements_path) { |f| Plist.parse_xml f }
        raise "Failed to parse entitlements file #{entitlements_path}" if entitlements.nil?

        entitlements[ASSOCIATED_DOMAINS].select { |d| d =~ /^applinks:/ }.map { |d| d.sub(/^applinks:/, "") }
      end

      def expanded_build_setting(target, setting_name, configuration)
        setting_value = target.resolved_build_setting(setting_name)[configuration]
        return if setting_value.nil?

        search_position = 0
        while (matches = /\$\(([^(){}]*)\)|\$\{([^(){}]*)\}/.match(setting_value, search_position))
          macro_name = matches[1] || matches[2]
          search_position = setting_value.index(macro_name) - 2

          expanded_macro = macro_name == "SRCROOT" ? "." : expanded_build_setting(target, macro_name, configuration)
          search_position += macro_name.length + 3 and next if expanded_macro.nil?

          setting_value.gsub!(/\$\(#{macro_name}\)|\$\{#{macro_name}\}/, expanded_macro)
          search_position += expanded_macro.length
        end
        setting_value
      end

      def add_system_frameworks(project, target_name, frameworks)
        target = target_from_project project, target_name

        target.add_system_framework frameworks
      end

      def patch_app_delegate_swift(project)
        app_delegate_swift = project.files.find { |f| f.path =~ /AppDelegate.swift$/ }
        return false if app_delegate_swift.nil?

        app_delegate_swift_path = app_delegate_swift.real_path.to_s

        app_delegate = File.open(app_delegate_swift_path, &:read)
        return false if app_delegate =~ /import\s+Branch/

        say "Patching #{app_delegate_swift_path}"

        apply_patch(
          files: app_delegate_swift_path,
          regexp: /^\s*import .*$/,
          text: "\nimport Branch",
          mode: :prepend
        )

        init_session_text = ConfigurationHelper.keys.count <= 1 ? "" : <<EOF
        #if DEBUG
            Branch.setUseTestBranchKey(true)
        #endif

EOF

        init_session_text += <<-EOF
        Branch.getInstance().initSession(launchOptions: launchOptions) {
            universalObject, linkProperties, error in

            // TODO: Route Branch links
        }
        EOF

        apply_patch(
          files: app_delegate_swift_path,
          regexp: /didFinishLaunchingWithOptions.*?\{[^\n]*\n/m,
          text: init_session_text,
          mode: :append
        )

        if app_delegate =~ /application:.*continue userActivity:.*restorationHandler:/
          # Add something to the top of the method
          continue_user_activity_text = <<-EOF
        // TODO: Adjust your method as you see fit.
        if Branch.getInstance.continue(userActivity) {
            return true
        }

          EOF

          apply_patch(
            files: app_delegate_swift_path,
            regexp: /application:.*continue userActivity:.*restorationHandler:.*?\{.*?\n/m,
            text: continue_user_activity_text,
            mode: :append
          )
        else
          # Add the application:continueUserActivity:restorationHandler method if it does not exist
          continue_user_activity_text = <<-EOF


    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        return Branch.getInstance().continue(userActivity)
    }
          EOF

          apply_patch(
            files: app_delegate_swift_path,
            regexp: /\n\s*\}[^{}]*\Z/m,
            text: continue_user_activity_text,
            mode: :prepend
          )
        end

        add_change app_delegate_swift_path
        true
      end

      def patch_app_delegate_objc(project)
        app_delegate_objc = project.files.find { |f| f.path =~ /AppDelegate.m$/ }
        return false if app_delegate_objc.nil?

        app_delegate_objc_path = app_delegate_objc.real_path.to_s

        app_delegate = File.open(app_delegate_objc_path, &:read)
        return false if app_delegate =~ %r{^\s+#import\s+<Branch/Branch.h>|^\s+@import\s+Branch;}

        say "Patching #{app_delegate_objc_path}"

        apply_patch(
          files: app_delegate_objc_path,
          regexp: /^\s+@import|^\s+#import.*$/,
          text: "\n#import <Branch/Branch.h>",
          mode: :prepend
        )

        init_session_text = ConfigurationHelper.keys.count <= 1 ? "" : <<EOF
#ifdef DEBUG
    [Branch setUseTestBranchKey:YES];
#endif // DEBUG

EOF

        init_session_text += <<-EOF
    [[Branch getInstance] initSessionWithLaunchOptions:launchOptions
        andRegisterDeepLinkHandlerUsingBranchUniversalObject:^(BranchUniversalObject *universalObject, BranchLinkProperties *linkProperties, NSError *error){
        // TODO: Route Branch links
    }];
        EOF

        apply_patch(
          files: app_delegate_objc_path,
          regexp: /didFinishLaunchingWithOptions.*?\{[^\n]*\n/m,
          text: init_session_text,
          mode: :append
        )

        if app_delegate =~ /application:.*continueUserActivity:.*restorationHandler:/
          continue_user_activity_text = <<-EOF
    // TODO: Adjust your method as you see fit.
    if ([[Branch getInstance] continueUserActivity:userActivity]) {
        return YES;
    }

EOF

          apply_patch(
            files: app_delegate_objc_path,
            regexp: /application:.*continueUserActivity:.*restorationHandler:.*?\{.*?\n/m,
            text: continue_user_activity_text,
            mode: :append
          )
        else
          # Add the application:continueUserActivity:restorationHandler method if it does not exist
          continue_user_activity_text = <<-EOF


- (BOOL)application:(UIApplication *)app continueUserActivity:(nonnull NSUserActivity *)userActivity restorationHandler:(nonnull void (^)(NSArray * _Nullable))restorationHandler
{
    return [[Branch getInstance] continueUserActivity:userActivity];
}
          EOF

          apply_patch(
            files: app_delegate_objc_path,
            regexp: /\n\s*@end[^@]*\Z/m,
            text: continue_user_activity_text,
            mode: :prepend
          )
        end

        add_change app_delegate_objc_path
        true
      end

      def patch_podfile(podfile_path)
        podfile = File.open(podfile_path, &:read)

        # Podfile already contains the Branch pod
        return false if podfile =~ /pod\s+('Branch'|"Branch")/

        say "Adding pod \"Branch\" to #{podfile_path}"

        # TODO: Improve this patch. Should work in the majority of cases for now.
        apply_patch(
          files: podfile_path,
          regexp: /^(\s*)pod\s*/,
          text: "\n\\1pod \"Branch\"\n",
          mode: :prepend
        )

        true
      end

      def patch_cartfile(cartfile_path)
        cartfile = File.open(cartfile_path, &:read)

        # Cartfile already contains the Branch framework
        return false if cartfile =~ /git.+Branch/

        say "Adding \"Branch\" to #{cartfile_path}"

        apply_patch(
          files: cartfile_path,
          regexp: /\z/,
          text: "git \"https://github.com/BranchMetrics/ios-branch-deep-linking\"\n",
          mode: :append
        )

        true
      end
    end
  end
end
