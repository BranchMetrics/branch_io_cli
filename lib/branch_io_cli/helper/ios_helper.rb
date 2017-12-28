require "active_support/core_ext/object"
require "json"
require "openssl"
require "plist"

require "branch_io_cli/configuration"
require "branch_io_cli/helper/methods"

module BranchIOCLI
  module Helper
    module IOSHelper
      include Methods

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
          files + [config.target.expanded_build_setting("INFOPLIST_FILE", c.name)]
        end.uniq.count > 1
      end

      def uses_test_key?(build_configuration)
        return build_configuration.debug? unless config.setting && config.test_configurations
        config.test_configurations.include? build_configuration.name
      end

      def add_custom_build_setting
        return unless config.setting

        config.target.build_configurations.each do |c|
          key = uses_test_key?(c) ? config.keys[:test] : config.keys[:live]
          # Reuse the same key if both not present
          key ||= uses_test_key?(c) ? config.keys[:live] : config.keys[:test]
          c.build_settings[config.setting] = key
        end
      end

      def add_keys_to_info_plist(keys)
        if has_multiple_info_plists?
          config.xcodeproj.build_configurations.each do |c|
            update_info_plist_setting c.name do |info_plist|
              if keys.count > 1 && !config.setting
                # Use test key in debug configs and live key in release configs
                info_plist["branch_key"] = c.debug? ? keys[:test] : keys[:live]
              elsif config.setting
                info_plist["branch_key"] = "$(#{config.setting})"
              else
                info_plist["branch_key"] = keys[:live] ? keys[:live] : keys[:test]
              end
            end
          end
        else
          update_info_plist_setting RELEASE_CONFIGURATION do |info_plist|
            # add/overwrite Branch key(s)
            if keys.count > 1 && !config.setting
              info_plist["branch_key"] = keys
            elsif config.setting
              info_plist["branch_key"] = "$(#{config.setting})"
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

      def info_plist_path(configuration)
        # find the Info.plist paths for this configuration
        info_plist_path = config.target.expanded_build_setting "INFOPLIST_FILE", configuration

        raise "Info.plist not found for configuration #{configuration}" if info_plist_path.nil?

        project_parent = File.dirname config.xcodeproj_path

        File.expand_path info_plist_path, project_parent
      end

      def info_plist(path)
        # try to open and parse the Info.plist (raises)
        info_plist = File.open(path) { |f| Plist.parse_xml f }
        raise "Failed to parse #{path}" if info_plist.nil?
        info_plist
      end

      def update_info_plist_setting(configuration = RELEASE_CONFIGURATION, &b)
        info_plist_path = info_plist_path(configuration)
        info_plist = info_plist(info_plist_path)
        yield info_plist

        Plist::Emit.save_plist info_plist, info_plist_path
        add_change info_plist_path
      end

      def add_universal_links_to_project(domains, remove_existing, configuration = RELEASE_CONFIGURATION)
        project = config.xcodeproj
        target = config.target

        relative_entitlements_path = target.expanded_build_setting CODE_SIGN_ENTITLEMENTS, configuration
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
        matches = /^(.*?)\.(.*)$/.match identifier
        matches[1, 2]
      end

      def reportable_app_id(identifier)
        team, bundle = team_and_bundle_from_app_id identifier
        "Signing team: #{team.inspect}, Bundle identifier: #{bundle.inspect}"
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

        product_bundle_identifier = target.expanded_build_setting PRODUCT_BUNDLE_IDENTIFIER, configuration
        development_team = target.expanded_build_setting DEVELOPMENT_TEAM, configuration

        identifiers = app_ids_from_aasa_file domain
        return false if identifiers.nil?

        app_id = "#{development_team}.#{product_bundle_identifier}"
        match_found = identifiers.include? app_id

        unless match_found
          report_app_id_mismatch domain, app_id, identifiers
        end

        match_found
      end

      def report_app_id_mismatch(domain, app_id, identifiers)
        error_string = "[#{domain}] appID mismatch. Project #{reportable_app_id app_id}\n"
        if identifiers.count <= 20
          error_string << " Apps from AASA:\n"
          identifiers.each do |identifier|
            reportable = reportable_app_id identifier
            error_string << "  #{reportable}\n"
          end
        else
          error_string << " Please check your settings in the Branch Dashboard (https://dashboard.branch.io)"
        end

        @errors << error_string
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
        elsif config.respond_to?(:scheme) && project.targets.map(&:name).include?(config.scheme)
          # Return a target with the same name as the scheme, if there is one.
          target = project.targets.find { |t| t.name == config.scheme }
        else
          # find the first application target
          target = project.targets.find { |t| t.name == File.basename(project.path, '.xcodeproj') } ||
                   project.targets.select { |t| !t.extension_target_type? && !t.test_target_type? }.first
        end
        target
      end

      def domains_from_project(configuration = RELEASE_CONFIGURATION)
        project = config.xcodeproj
        target = config.target

        relative_entitlements_path = target.expanded_build_setting CODE_SIGN_ENTITLEMENTS, configuration
        return [] if relative_entitlements_path.nil?

        project_parent = File.dirname project.path
        entitlements_path = File.expand_path relative_entitlements_path, project_parent

        # Raises
        entitlements = File.open(entitlements_path) { |f| Plist.parse_xml f }
        raise "Failed to parse entitlements file #{entitlements_path}" if entitlements.nil?

        associated_domains = entitlements[ASSOCIATED_DOMAINS]
        return [] if associated_domains.nil?

        associated_domains.select { |d| d =~ /^applinks:/ }.map { |d| d.sub(/^applinks:/, "") }
      end

      # Validates Branch-related settings in a project (keys, domains, URI schemes)
      def project_valid?(configuration)
        @errors = []

        info_plist_path = info_plist_path(configuration)
        info_plist = info_plist(info_plist_path).symbolize_keys
        branch_key = config.target.expand_build_settings info_plist[:branch_key], configuration

        if branch_key.blank?
          @errors << "branch_key not found in Info.plist"
          return false
        end

        if branch_key.kind_of?(Hash)
          branch_keys = branch_key.map { |k, v| v }
        else
          branch_keys = [branch_key]
        end

        valid = true

        # Retrieve app data from Branch API for all keys in the Info.plist
        apps = branch_keys.map do |key|
          begin
            BranchApp[key]
          rescue StandardError => e
            # Failed to retrieve a key in the Info.plist from the API.
            @errors << "[#{key}] #{e.message}"
            valid = false
            nil
          end
        end.compact.uniq

        # Get domains and URI schemes loaded from API
        domains_from_api = domains apps

        # Make sure all domains and URI schemes are present in the project.
        domains = domains_from_project(configuration)
        missing_domains = domains_from_api - domains
        unless missing_domains.empty?
          valid = false
          missing_domains.each do |domain|
            @errors << "[#{domain}] Missing from #{configuration} configuration."
          end
        end

        valid
      end

      def branch_keys_from_project(configurations)
        configurations.map do |c|
          path = info_plist_path(c)
          info_plist = info_plist(path).symbolize_keys
          branch_key = config.target.expand_build_settings(info_plist[:branch_key], c)
          if branch_key.kind_of?(Hash)
            branch_key.values
          else
            branch_key
          end
        end.compact.flatten.uniq
      end
    end
  end
end
