module BranchIOCLI
  module Configuration
    class SetupConfiguration < Configuration
      APP_LINK_REGEXP = /\.app\.link$|\.test-app\.link$/
      SDK_OPTIONS =
        {
          "Specify the location of a Podfile or Cartfile" => :specify,
          "Set this project up to use CocoaPods and add the Branch SDK." => :cocoapods,
          "Set this project up to use Carthage and add the Branch SDK." => :carthage,
          "Add Branch.framework directly to the project's dependencies." => :direct,
          "Skip adding the framework to the project." => :skip
        }

      attr_reader :keys
      attr_reader :all_domains
      attr_reader :carthage_command
      attr_reader :uri_scheme
      attr_reader :validate
      attr_reader :add_sdk
      attr_reader :force
      attr_reader :patch_source
      attr_reader :commit
      attr_reader :setting

      def validate_options
        @validate = options.validate
        @patch_source = options.patch_source
        @add_sdk = options.add_sdk
        @force = options.force
        @commit = options.commit

        say "--force is ignored when --no-validate is used." if !options.validate && options.force
        if options.cartfile && options.podfile
          say "--cartfile and --podfile are mutually exclusive. Please specify the file to patch."
          exit 1
        end

        validate_xcodeproj_path
        validate_target
        validate_keys_from_setup_options options
        validate_all_domains options, !target.extension_target_type?
        validate_uri_scheme options
        validate_setting options

        # If neither --podfile nor --cartfile is present, arbitrarily look for a Podfile
        # first.

        # If --cartfile is present, don't look for a Podfile. Just validate that
        # Cartfile.
        validate_buildfile_path options.podfile, "Podfile" if options.cartfile.nil? && options.add_sdk

        # If --podfile is present or a Podfile was found, don't look for a Cartfile.
        validate_buildfile_path options.cartfile, "Cartfile" if sdk_integration_mode.nil? && options.add_sdk
        @carthage_command = options.carthage_command if sdk_integration_mode == :carthage

        validate_sdk_addition options
      end

      def log
        super
        message = <<-EOF
<%= color('Xcode project:', BOLD) %> #{xcodeproj_path}
<%= color('Target:', BOLD) %> #{target.name}
<%= color('Live key:', BOLD) %> #{keys[:live] || '(none)'}
<%= color('Test key:', BOLD) %> #{keys[:test] || '(none)'}
<%= color('Domains:', BOLD) %> #{all_domains}
<%= color('URI scheme:', BOLD) %> #{uri_scheme || '(none)'}
        EOF

        if setting
          message += <<-EOF
<%= color('Branch key setting:', BOLD) %> #{setting}
          EOF
        end

        message += <<-EOF
<%= color('Podfile:', BOLD) %> #{relative_path(podfile_path) || '(none)'}
<%= color('Cartfile:', BOLD) %> #{relative_path(cartfile_path) || '(none)'}
<%= color('Carthage command:', BOLD) %> #{carthage_command || '(none)'}
<%= color('Pod repo update:', BOLD) %> #{pod_repo_update.inspect}
<%= color('Validate:', BOLD) %> #{validate.inspect}
<%= color('Force:', BOLD) %> #{force.inspect}
<%= color('Add SDK:', BOLD) %> #{add_sdk.inspect}
<%= color('Patch source:', BOLD) %> #{patch_source.inspect}
<%= color('Commit:', BOLD) %> #{commit.inspect}
<%= color('SDK integration mode:', BOLD) %> #{sdk_integration_mode || '(none)'}
        EOF

        if swift_version
          message += <<-EOF
<%= color('Swift version:', BOLD) %> #{swift_version}
          EOF
        end

        message += "\n"

        say message
      end

      def validate_keys_from_setup_options(options)
        @keys = {}

        # 1. Check the options passed in. If nothing (nil) passed, continue.
        validate_key options.live_key, :live, accept_nil: true
        validate_key options.test_key, :test, accept_nil: true

        # 2. Did we find a valid key above?
        while @keys.empty?
          # 3. If not, prompt.
          say "A live key, a test key or both is required."
          validate_key nil, :live
          validate_key nil, :test
        end

        # 4. We have at least one valid key now.
      end

      def key_valid?(key, type)
        return false if key.nil?
        key.empty? || key =~ /^key_#{type}_/
      end

      def validate_key(key, type, options = {})
        return if options[:accept_nil] && key.nil?
        until key_valid? key, type
          say "#{key.inspect} is not a valid #{type} Branch key. It must begin with key_#{type}_." if key
          key = ask "Please enter your #{type} Branch key or use --#{type}-key [enter for none]: "
        end
        @keys[type] = key unless key.empty?
      end

      def validate_all_domains(options, required = true)
        app_link_roots = app_link_roots_from_domains options.domains

        unless options.app_link_subdomain.nil? || app_link_roots.include?(options.app_link_subdomain)
          app_link_roots << options.app_link_subdomain
        end

        # app_link_roots now contains options.app_link_subdomain, if supplied, and the roots of any
        # .app.link or .test-app.link domains provided via options.domains.

        app_link_subdomains = app_link_subdomains_from_roots app_link_roots

        custom_domains = custom_domains_from_domains options.domains

        @all_domains = (app_link_subdomains + custom_domains).uniq

        while required && @all_domains.empty?
          domains = ask "Please enter domains as a comma-separated list: ", ->(str) { str.split "," }

          @all_domains = all_domains_from_domains domains
        end
      end

      def validate_uri_scheme(options)
        # No validation at the moment. Just strips off any trailing ://
        @uri_scheme = uri_scheme_without_suffix options.uri_scheme
      end

      def app_link_roots_from_domains(domains)
        return [] if domains.nil?

        domains.select { |d| d =~ APP_LINK_REGEXP }
               .map { |d| d.sub(APP_LINK_REGEXP, '').sub(/-alternate$/, '') }
               .uniq
      end

      def custom_domains_from_domains(domains)
        return [] if domains.nil?
        domains.reject { |d| d =~ APP_LINK_REGEXP }.uniq
      end

      def app_link_subdomains(root)
        app_link_subdomain = root
        return [] if app_link_subdomain.nil?

        live_key = keys[:live]
        test_key = keys[:test]

        domains = []
        unless live_key.nil?
          domains += [
            "#{app_link_subdomain}.app.link",
            "#{app_link_subdomain}-alternate.app.link"
          ]
        end
        unless test_key.nil?
          domains += [
            "#{app_link_subdomain}.test-app.link",
            "#{app_link_subdomain}-alternate.test-app.link"
          ]
        end
        domains
      end

      def app_link_subdomains_from_roots(roots)
        roots.inject([]) { |domains, root| domains + app_link_subdomains(root) }
      end

      def all_domains_from_domains(domains)
        app_link_roots = app_link_roots_from_domains domains
        app_link_subdomains = app_link_subdomains_from_roots app_link_roots
        custom_domains = custom_domains_from_domains domains
        custom_domains + app_link_subdomains
      end

      # Removes any trailing :// from the argument and returns a copy
      def uri_scheme_without_suffix(scheme)
        return nil if scheme.nil?
        scheme.sub %r{://$}, ""
      end

      def prompt_for_podfile_or_cartfile
        loop do
          path = ask("Please enter the location of your Podfile or Cartfile: ").trim
          case path
          when %r{/?Podfile$}
            return if validate_buildfile_at_path path, "Podfile"
          when %r{/?Cartfile$}
            return if validate_buildfile_at_path path, "Cartfile"
          else
            say "Path must end in Podfile or Cartfile."
          end
        end
      end

      def validate_sdk_addition(options)
        return if !options.add_sdk || sdk_integration_mode

        # If no CocoaPods or Carthage, check to see if the framework is linked.
        return if target.frameworks_build_phase.files.map(&:file_ref).map(&:path).any? { |p| p =~ /Branch.framework$/ }

        # --podfile, --cartfile not specified. No Podfile found. No Cartfile found. No Branch.framework in project.
        # Prompt the user:
        selected = choose do |menu|
          menu.header = "No Podfile or Cartfile specified or found. Here are your options"

          SDK_OPTIONS.each_key { |k| menu.choice k }

          menu.prompt = "What would you like to do?"
        end

        @sdk_integration_mode = SDK_OPTIONS[selected]

        case sdk_integration_mode
        when :specify
          prompt_for_podfile_or_cartfile
        when :cocoapods
          @podfile_path = File.expand_path "../Podfile", xcodeproj_path
        when :carthage
          @cartfile_path = File.expand_path "../Cartfile", xcodeproj_path
          @carthage_command = options.carthage_command
        end
      end

      def validate_setting(options)
        setting = options.setting
        return if setting.nil?

        @setting = "BRANCH_KEY" and return if setting == true

        loop do
          if setting =~ /^[A-Z0-9_]+$/
            @setting = setting
            return
          end
          setting = "Invalid build setting. Please enter an all-caps identifier (may include digits and underscores): "
        end
      end
    end
  end
end
