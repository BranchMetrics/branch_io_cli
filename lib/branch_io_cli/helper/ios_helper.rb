require "json"
require "net/http"
require "openssl"
require "pathname"
require "plist"
require "tmpdir"
require "zip"

require "branch_io_cli/configuration"
require "branch_io_cli/helper/methods"

module BranchIOCLI
  module Helper
    module IOSHelper
      APPLINKS = "applinks"
      ASSOCIATED_DOMAINS = "com.apple.developer.associated-domains"
      CODE_SIGN_ENTITLEMENTS = "CODE_SIGN_ENTITLEMENTS"
      DEVELOPMENT_TEAM = "DEVELOPMENT_TEAM"
      PRODUCT_BUNDLE_IDENTIFIER = "PRODUCT_BUNDLE_IDENTIFIER"
      RELEASE_CONFIGURATION = "Release"

      def config
        Configuration::Configuration.current
      end

      def has_multiple_info_plists?
        config.xcodeproj.build_configurations.inject([]) do |files, c|
          files + [expanded_build_setting(config.target, "INFOPLIST_FILE", c.name)]
        end.uniq.count > 1
      end

      def add_keys_to_info_plist(keys)
        if has_multiple_info_plists?
          config.xcodeproj.build_configurations.each do |c|
            update_info_plist_setting c.name do |info_plist|
              if keys.count > 1
                # Use test key in debug configs and live key in release configs
                info_plist["branch_key"] = c.debug? ? keys[:test] : keys[:live]
              else
                info_plist["branch_key"] = keys[:live] ? keys[:live] : keys[:test]
              end
            end
          end
        else
          update_info_plist_setting RELEASE_CONFIGURATION do |info_plist|
            # add/overwrite Branch key(s)
            if keys.count > 1
              info_plist["branch_key"] = keys
            elsif keys[:live]
              info_plist["branch_key"] = keys[:live]
            else
              info_plist["branch_key"] = keys[:test]
            end
          end
        end
      end

      def add_branch_universal_link_domains_to_info_plist(domains)
        # Add all supplied domains unless all are app.link domains.
        return if domains.all? { |d| d =~ /app\.link$/ }

        config.xcodeproj.build_configurations.each do |c|
          update_info_plist_setting c.name do |info_plist|
            info_plist["branch_universal_link_domains"] = domains
          end
        end
      end

      def ensure_uri_scheme_in_info_plist
        uri_scheme = config.uri_scheme

        # No URI scheme specified. Do nothing.
        return if uri_scheme.nil?

        config.xcodeproj.build_configurations.each do |c|
          update_info_plist_setting c.name do |info_plist|
            url_types = info_plist["CFBundleURLTypes"] || []
            uri_schemes = url_types.inject([]) { |schemes, t| schemes + t["CFBundleURLSchemes"] }

            # Already present. Don't mess with the identifier.
            next if uri_schemes.include? uri_scheme

            # Not found. Add. Don't worry about the CFBundleURLName (reverse-DNS identifier)
            # TODO: Should we prompt here to add or let them change the Dashboard? If there's already
            # a URI scheme in the app, seems likely they'd want to use it. They may have just made
            # a typo at the CLI or in the Dashboard.
            url_types << {
              "CFBundleURLSchemes" => [uri_scheme]
            }
            info_plist["CFBundleURLTypes"] = url_types
          end
        end
      end

      def update_info_plist_setting(configuration = RELEASE_CONFIGURATION, &b)
        # find the Info.plist paths for this configuration
        info_plist_path = expanded_build_setting config.target, "INFOPLIST_FILE", configuration

        raise "Info.plist not found for configuration #{configuration}" if info_plist_path.nil?

        project_parent = File.dirname config.xcodeproj_path

        info_plist_path = File.expand_path info_plist_path, project_parent

        # try to open and parse the Info.plist (raises)
        info_plist = File.open(info_plist_path) { |f| Plist.parse_xml f }
        raise "Failed to parse #{info_plist_path}" if info_plist.nil?

        yield info_plist

        Plist::Emit.save_plist info_plist, info_plist_path
        add_change info_plist_path
      end

      def add_universal_links_to_project(domains, remove_existing, configuration = RELEASE_CONFIGURATION)
        project = config.xcodeproj
        target = config.target

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

      def update_team_and_bundle_ids_from_aasa_file(domain)
        # raises
        identifiers = app_ids_from_aasa_file domain
        raise "Multiple appIDs found in AASA file" if identifiers.count > 1

        identifier = identifiers[0]
        team, bundle = team_and_bundle_from_app_id identifier

        update_team_and_bundle_ids team, bundle
        add_change config.xcodeproj_path
      end

      def validate_team_and_bundle_ids_from_aasa_files(domains = [], remove_existing = false, configuration = RELEASE_CONFIGURATION)
        @errors = []
        valid = true

        # Include any domains already in the project.
        # Raises. Returns a non-nil array of strings.
        if remove_existing
          # Don't validate domains to be removed (#16)
          all_domains = domains
        else
          all_domains = (domains + domains_from_project(configuration)).uniq
        end

        if all_domains.empty?
          # Cannot get here from SetupBranchAction, since the domains passed in will never be empty.
          # If called from ValidateUniversalLinksAction, this is a failure, possibly caused by
          # failure to add applinks:.
          @errors << "No Universal Link domains in project. Be sure each Universal Link domain is prefixed with applinks:."
          return false
        end

        all_domains.each do |domain|
          domain_valid = validate_team_and_bundle_ids domain, configuration
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

      def validate_team_and_bundle_ids(domain, configuration)
        target = config.target

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

      def validate_project_domains(expected, configuration = RELEASE_CONFIGURATION)
        @errors = []
        project_domains = domains_from_project configuration
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

      def update_team_and_bundle_ids(team, bundle)
        target = config.target

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
          targets = project.targets.select { |t| !t.extension_target_type? && !t.test_target_type? }
          target = targets.find { |t| t.name == File.basename(project.path).sub(/\.xcodeproj$/, "") } || targets.first
          raise "No application target found" if target.nil?
        end
        target
      end

      def domains_from_project(configuration = RELEASE_CONFIGURATION)
        project = config.xcodeproj
        target = config.target

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

      def patch_app_delegate_swift(project)
        app_delegate_swift = project.files.find { |f| f.path =~ /AppDelegate.swift$/ }
        return false if app_delegate_swift.nil?

        app_delegate_swift_path = app_delegate_swift.real_path.to_s

        app_delegate = File.read app_delegate_swift_path
        return false if app_delegate =~ /import\s+Branch/

        say "Patching #{app_delegate_swift_path}"

        apply_patch(
          files: app_delegate_swift_path,
          regexp: /^\s*import .*$/,
          text: "\nimport Branch",
          mode: :prepend
        )

        patch_did_finish_launching_method_swift app_delegate_swift_path
        patch_continue_user_activity_method_swift app_delegate_swift_path
        patch_open_url_method_swift app_delegate_swift_path

        add_change app_delegate_swift_path
        true
      end

      def patch_app_delegate_objc(project)
        app_delegate_objc = project.files.find { |f| f.path =~ /AppDelegate.m$/ }
        return false if app_delegate_objc.nil?

        app_delegate_objc_path = app_delegate_objc.real_path.to_s

        app_delegate = File.read app_delegate_objc_path
        return false if app_delegate =~ %r{^\s+#import\s+<Branch/Branch.h>|^\s+@import\s+Branch;}

        say "Patching #{app_delegate_objc_path}"

        apply_patch(
          files: app_delegate_objc_path,
          regexp: /^\s+@import|^\s+#import.*$/,
          text: "\n#import <Branch/Branch.h>",
          mode: :prepend
        )

        patch_did_finish_launching_method_objc app_delegate_objc_path
        patch_continue_user_activity_method_objc app_delegate_objc_path
        patch_open_url_method_objc app_delegate_objc_path

        add_change app_delegate_objc_path
        true
      end

      def patch_did_finish_launching_method_swift(app_delegate_swift_path)
        app_delegate_swift = File.read app_delegate_swift_path

        if app_delegate_swift =~ /didFinishLaunching[^\n]+?\{/m
          # method already present
          init_session_text = config.keys.count <= 1 || has_multiple_info_plists? ? "" : <<EOF
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
        else
          # method not present. add entire method

          method_text = <<EOF

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
EOF

          if config.keys.count > 1 && !has_multiple_info_plists?
            method_text += <<EOF
        #if DEBUG
          Branch.setUseTestBranchKey(true)
        #endif

EOF
          end

          method_text += <<-EOF
        Branch.getInstance().initSession(launchOptions: launchOptions) {
            universalObject, linkProperties, error in

            // TODO: Route Branch links
        }
        return true
    }
        EOF

          apply_patch(
            files: app_delegate_swift_path,
            regexp: /var\s+window\s?:\s?UIWindow\?.*?\n/m,
            text: method_text,
            mode: :append
          )
        end
      end

      def patch_did_finish_launching_method_objc(app_delegate_objc_path)
        app_delegate_objc = File.read app_delegate_objc_path

        if app_delegate_objc =~ /didFinishLaunchingWithOptions/m
          # method exists. patch it.
          init_session_text = config.keys.count <= 1 || has_multiple_info_plists? ? "" : <<EOF
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
        else
          # method does not exist. add it.
          method_text = <<EOF

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
EOF

          if config.keys.count > 1 && !has_multiple_info_plists?
            method_text += <<EOF
#ifdef DEBUG
    [Branch setUseTestBranchKey:YES];
#endif // DEBUG

EOF
          end

          method_text += <<-EOF
    [[Branch getInstance] initSessionWithLaunchOptions:launchOptions
        andRegisterDeepLinkHandlerUsingBranchUniversalObject:^(BranchUniversalObject *universalObject, BranchLinkProperties *linkProperties, NSError *error){
        // TODO: Route Branch links
    }];
    return YES;
}
          EOF

          apply_patch(
            files: app_delegate_objc_path,
            regexp: /^@implementation.*?\n/m,
            text: method_text,
            mode: :append
          )
        end
      end

      def patch_open_url_method_swift(app_delegate_swift_path)
        app_delegate_swift = File.read app_delegate_swift_path
        if app_delegate_swift =~ /application.*open\s+url.*options/
          # Has application:openURL:options:
          open_url_text = <<-EOF
        // TODO: Adjust your method as you see fit.
        if Branch.getInstance().application(app, open: url, options: options) {
            return true
        }

          EOF

          apply_patch(
            files: app_delegate_swift_path,
            regexp: /application.*open\s+url.*options:.*?\{.*?\n/m,
            text: open_url_text,
            mode: :append
          )
        elsif app_delegate_swift =~ /application.*open\s+url.*sourceApplication/
          # Has application:openURL:sourceApplication:annotation:
          # TODO: This method is deprecated.
          open_url_text = <<-EOF
        // TODO: Adjust your method as you see fit.
        if Branch.getInstance().application(application, open: url, sourceApplication: sourceApplication, annotation: annotation) {
            return true
        }

          EOF

          apply_patch(
            files: app_delegate_swift_path,
            regexp: /application.*open\s+url.*sourceApplication:.*?\{.*?\n/m,
            text: open_url_text,
            mode: :append
          )
        else
          # Has neither
          open_url_text = <<EOF


    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        return Branch.getInstance().application(app, open: url, options: options)
    }
EOF

          apply_patch(
            files: app_delegate_swift_path,
            regexp: /\n\s*\}[^{}]*\Z/m,
            text: open_url_text,
            mode: :prepend
          )
        end
      end

      def patch_continue_user_activity_method_swift(app_delegate_swift_path)
        app_delegate = File.read app_delegate_swift_path
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
      end

      def patch_open_url_method_objc(app_delegate_objc_path)
        app_delegate_objc = File.read app_delegate_objc_path
        if app_delegate_objc =~ /application:.*openURL:.*options/
          # Has application:openURL:options:
          open_url_text = <<-EOF
    // TODO: Adjust your method as you see fit.
    if ([[Branch getInstance] application:app openURL:url options:options]) {
        return YES;
    }

EOF

          apply_patch(
            files: app_delegate_objc_path,
            regexp: /application:.*openURL:.*options:.*?\{.*?\n/m,
            text: open_url_text,
            mode: :append
          )
        elsif app_delegate_objc =~ /application:.*openURL:.*sourceApplication/
          # Has application:openURL:sourceApplication:annotation:
          open_url_text = <<-EOF
    // TODO: Adjust your method as you see fit.
    if ([[Branch getInstance] application:application openURL:url sourceApplication:sourceApplication annotation:annotation]) {
        return YES;
    }

EOF

          apply_patch(
            files: app_delegate_objc_path,
            regexp: /application:.*openURL:.*sourceApplication:.*?\{.*?\n/m,
            text: open_url_text,
            mode: :append
          )
        else
          # Has neither
          open_url_text = <<-EOF


- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    return [[Branch getInstance] application:app openURL:url options:options];
}
          EOF

          apply_patch(
            files: app_delegate_objc_path,
            regexp: /\n\s*@end[^@]*\Z/m,
            text: open_url_text,
            mode: :prepend
          )
        end
      end

      def patch_continue_user_activity_method_objc(app_delegate_objc_path)
        app_delegate = File.read app_delegate_objc_path
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
      end

      def patch_podfile(podfile_path)
        podfile = File.read podfile_path

        # Podfile already contains the Branch pod
        # TODO: Allow for adding to multiple targets in the Podfile
        return false if podfile =~ /pod\s+('Branch'|"Branch")/

        say "Adding pod \"Branch\" to #{podfile_path}"

        if podfile =~ /target\s+(["'])#{config.target.name}\1\s+do.*?\n/m
          # if there is a target block for this target:
          apply_patch(
            files: podfile_path,
            regexp: /\n(\s*)target\s+(["'])#{config.target.name}\2\s+do.*?\n/m,
            text: "\\1  pod \"Branch\"\n",
            mode: :append
          )
        else
          # add to the abstract_target for this target
          apply_patch(
            files: podfile_path,
            regexp: /^(\s*)target\s+["']#{config.target.name}/,
            text: "\\1pod \"Branch\"\n",
            mode: :prepend
          )
        end

        true
      end

      def patch_cartfile(cartfile_path)
        cartfile = File.read cartfile_path

        # Cartfile already contains the Branch framework
        return false if cartfile =~ /git.+Branch/

        say "Adding \"Branch\" to #{cartfile_path}"

        apply_patch(
          files: cartfile_path,
          regexp: /\z/,
          text: "github \"BranchMetrics/ios-branch-deep-linking\"\n",
          mode: :append
        )

        true
      end

      def add_cocoapods(options)
        verify_cocoapods

        podfile_path = config.podfile_path

        install_command = "pod install"
        install_command += " --repo-update" if options.pod_repo_update
        Dir.chdir(File.dirname(podfile_path)) do
          sh "pod init"
          apply_patch(
            files: podfile_path,
            regexp: /^(\s*)# Pods for #{config.target.name}$/,
            mode: :append,
            text: "\n\\1pod \"Branch\"",
            global: false
          )
          sh install_command
        end

        add_change podfile_path
        add_change "#{podfile_path}.lock"

        # For now, add Pods folder to SCM.
        pods_folder_path = Pathname.new(File.expand_path("../Pods", podfile_path)).relative_path_from Pathname.pwd
        workspace_path = Pathname.new(File.expand_path(config.xcodeproj_path.sub(/.xcodeproj$/, ".xcworkspace"))).relative_path_from Pathname.pwd
        podfile_pathname = Pathname.new(podfile_path).relative_path_from Pathname.pwd
        add_change pods_folder_path
        add_change workspace_path
        sh "git add #{podfile_pathname} #{podfile_pathname}.lock #{pods_folder_path} #{workspace_path}" if options.commit
      end

      def add_carthage(options)
        # TODO: Collapse this and Command::update_cartfile
        verify_carthage

        # 1. Generate Cartfile
        cartfile_path = config.cartfile_path
        File.open(cartfile_path, "w") do |file|
          file.write <<EOF
github "BranchMetrics/ios-branch-deep-linking"
EOF
        end

        # 2. carthage update
        Dir.chdir(File.dirname(cartfile_path)) do
          sh "carthage #{config.carthage_command}"
        end

        # 3. Add Cartfile and Cartfile.resolved to commit (in case :commit param specified)
        add_change cartfile_path
        add_change "#{cartfile_path}.resolved"
        add_change config.xcodeproj_path

        # 4. Add to target dependencies
        frameworks_group = config.xcodeproj.frameworks_group
        branch_framework = frameworks_group.new_file "Carthage/Build/iOS/Branch.framework"
        target = config.target
        target.frameworks_build_phase.add_file_reference branch_framework

        # 5. Create a copy-frameworks build phase
        carthage_build_phase = target.new_shell_script_build_phase "carthage copy-frameworks"
        carthage_build_phase.shell_script = "/usr/local/bin/carthage copy-frameworks"

        carthage_build_phase.input_paths << "$(SRCROOT)/Carthage/Build/iOS/Branch.framework"
        carthage_build_phase.output_paths << "$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/Branch.framework"

        config.xcodeproj.save

        # For now, add Carthage folder to SCM

        # 6. Add the Carthage folder to the commit (in case :commit param specified)
        carthage_folder_path = Pathname.new(File.expand_path("../Carthage", cartfile_path)).relative_path_from(Pathname.pwd)
        cartfile_pathname = Pathname.new(cartfile_path).relative_path_from Pathname.pwd
        add_change carthage_folder_path
        sh "git add #{cartfile_pathname} #{cartfile_pathname}.resolved #{carthage_folder_path}" if options.commit
      end

      def add_direct(options)
        # Put the framework in the path for any existing Frameworks group in the project.
        frameworks_group = config.xcodeproj.frameworks_group
        framework_path = File.join frameworks_group.real_path, "Branch.framework"
        raise "#{framework_path} exists." if File.exist? framework_path

        say "Finding current framework release"

        # Find the latest release from GitHub.
        releases = JSON.parse fetch "https://api.github.com/repos/BranchMetrics/ios-branch-deep-linking/releases"
        current_release = releases.first
        # Get the download URL for the framework.
        framework_asset = current_release["assets"][0]
        framework_url = framework_asset["browser_download_url"]

        say "Downloading Branch.framework v. #{current_release['tag_name']} (#{framework_asset['size']} bytes zipped)"

        Dir.mktmpdir do |download_folder|
          zip_path = File.join download_folder, "Branch.framework.zip"

          File.unlink zip_path if File.exist? zip_path

          # Download the framework zip
          download framework_url, zip_path

          say "Unzipping Branch.framework"

          # Unzip
          Zip::File.open zip_path do |zip_file|
            # Start with just the framework and add dSYM, etc., later
            zip_file.glob "Carthage/Build/iOS/Branch.framework/**/*" do |entry|
              filename = entry.name.sub %r{^Carthage/Build/iOS}, frameworks_group.real_path.to_s
              ensure_directory File.dirname filename
              entry.extract filename
            end
          end
        end

        # Now the current framework is in framework_path

        say "Adding to #{config.xcodeproj_path}"

        # Add as a dependency in the Frameworks group
        framework = frameworks_group.new_file "Branch.framework" # relative to frameworks_group.real_path
        config.target.frameworks_build_phase.add_file_reference framework, true

        # Make sure this is in the FRAMEWORK_SEARCH_PATHS if we just added it.
        if frameworks_group.files.count == 1
          config.target.build_configurations.each do |config|
            paths = config.build_settings["FRAMEWORK_SEARCH_PATHS"] || []
            next if paths.any? { |p| p == '$(SRCROOT)' || p == '$(SRCROOT)/**' }
            paths << '$(SRCROOT)'
            config.build_settings["FRAMEWORK_SEARCH_PATHS"] = paths
          end
        end
        # If it already existed, it's almost certainly already in FRAMEWORK_SEARCH_PATHS.

        config.xcodeproj.save

        add_change config.xcodeproj_path
        add_change framework_path
        sh "git add #{framework_path}" if options.commit

        say "Done. ✅"
      end

      def update_podfile(options)
        verify_cocoapods

        podfile_path = config.podfile_path
        return false if podfile_path.nil?

        # 1. Patch Podfile. Return if no change (Branch pod already present).
        return false unless patch_podfile podfile_path

        # 2. pod install
        # command = "PATH='#{ENV['PATH']}' pod install"
        command = 'pod install'
        command += ' --repo-update' if options.pod_repo_update

        Dir.chdir(File.dirname(podfile_path)) do
          sh command
        end

        # 3. Add Podfile and Podfile.lock to commit (in case :commit param specified)
        add_change podfile_path
        add_change "#{podfile_path}.lock"

        # 4. Check if Pods folder is under SCM
        pods_folder_path = Pathname.new(File.expand_path("../Pods", podfile_path)).relative_path_from Pathname.pwd
        `git ls-files #{pods_folder_path} --error-unmatch > /dev/null 2>&1`
        return true unless $?.exitstatus == 0

        # 5. If so, add the Pods folder to the commit (in case :commit param specified)
        add_change pods_folder_path
        sh "git add #{pods_folder_path}" if options.commit

        true
      end

      def update_cartfile(options, project)
        verify_carthage

        cartfile_path = config.cartfile_path
        return false if cartfile_path.nil?

        # 1. Patch Cartfile. Return if no change (Branch already present).
        return false unless patch_cartfile cartfile_path

        # 2. carthage update
        Dir.chdir(File.dirname(cartfile_path)) do
          sh "carthage #{config.carthage_command}"
        end

        # 3. Add Cartfile and Cartfile.resolved to commit (in case :commit param specified)
        add_change cartfile_path
        add_change "#{cartfile_path}.resolved"
        add_change config.xcodeproj_path

        # 4. Add to target dependencies
        frameworks_group = project.frameworks_group
        branch_framework = frameworks_group.new_file "Carthage/Build/iOS/Branch.framework"
        target = config.target
        target.frameworks_build_phase.add_file_reference branch_framework

        # 5. Add to copy-frameworks build phase
        carthage_build_phase = target.build_phases.find do |phase|
          phase.respond_to?(:shell_script) && phase.shell_script =~ /carthage\s+copy-frameworks/
        end

        if carthage_build_phase
          carthage_build_phase.input_paths << "$(SRCROOT)/Carthage/Build/iOS/Branch.framework"
          carthage_build_phase.output_paths << "$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/Branch.framework"
        end

        # 6. Check if Carthage folder is under SCM
        carthage_folder_path = Pathname.new(File.expand_path("../Carthage", cartfile_path)).relative_path_from Pathname.pwd
        `git ls-files #{carthage_folder_path} --error-unmatch > /dev/null 2>&1`
        return true unless $?.exitstatus == 0

        # 7. If so, add the Carthage folder to the commit (in case :commit param specified)
        add_change carthage_folder_path
        sh "git add #{carthage_folder_path}" if options.commit

        true
      end

      def patch_source(xcodeproj)
        patch_app_delegate_swift(xcodeproj) || patch_app_delegate_objc(xcodeproj)
      end

      def verify_cocoapods
        pod_cmd = `which pod`
        return unless pod_cmd.empty?

        gem_cmd = `which gem`
        if gem_cmd.empty?
          say "'pod' command not available in PATH and 'gem' command not available in PATH to install cocoapods."
          exit(-1)
        end

        install = ask "'pod' command not available in PATH. Install cocoapods (may require a sudo password) (Y/n)? "
        if install.downcase =~ /^n/
          say "Please install cocoapods or use --no-add-sdk to continue."
          exit(-1)
        end

        gem_home = ENV["GEM_HOME"]
        if gem_home && File.writable?(gem_home)
          sh "gem install cocoapods"
        else
          sh "sudo gem install cocoapods"
        end

        # Ensure master podspec repo is set up (will update if it exists).
        sh "pod setup"
      end

      def verify_carthage
        carthage_cmd = `which carthage`
        return unless carthage_cmd.empty?

        brew_cmd = `which brew`
        if brew_cmd.empty?
          say "'carthage' command not available in PATH and 'brew' command not available in PATH to install 'carthage'."
          exit(-1)
        end

        install = ask "'carthage' command not available in PATH. Use Homebrew to install carthage (Y/n)? "
        if install.downcase =~ /^n/
          say "Please install carthage or use --no-add-sdk to continue."
          exit(-1)
        end

        sh "brew install carthage"
      end

      def verify_git
        return unless config.commit

        git_cmd = `which git`
        return unless git_cmd.empty?

        xcode_select_path = `which xcode-select`
        if xcode_select_path.empty?
          say "'git' command not available in PATH and 'xcode-select' command not available in PATH to install 'git'."
          exit(-1)
        end

        install = ask "'git' command not available in PATH. Install Xcode command-line tools (requires password) (Y/n)? "
        if install.downcase =~ /^n/
          say "Please install Xcode command tools or leave out the --commit option to continue."
          exit(-1)
        end

        sh "xcode-select --install"
      end
    end
  end
end
