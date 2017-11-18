module BranchIOCLI
  module Configuration
    # rubocop: disable Metrics/ClassLength
    class SetupConfiguration < Configuration
      class << self
        def summary
          "Integrates the Branch SDK into a native app project"
        end

        def examples
          {
            "Test without validation (can use dummy keys and domains)" => "branch_io setup -L key_live_xxxx -D myapp.app.link --no-validate",
            "Use both live and test keys" => "branch_io setup -L key_live_xxxx -T key_test_yyyy -D myapp.app.link",
            "Use custom or non-Branch domains" => "branch_io setup -D myapp.app.link,example.com,www.example.com",
            "Avoid pod repo update" => "branch_io setup --no-pod-repo-update",
            "Install using carthage bootstrap" => "branch_io --carthage-command \"bootstrap --no-use-binaries\""
          }
        end

        def available_options
          [
            Option.new(
              name: :live_key,
              description: "Branch live key",
              example: "key_live_xxxx",
              type: String,
              aliases: "-L"
            ),
            Option.new(
              name: :test_key,
              description: "Branch test key",
              example: "key_test_yyyy",
              type: String,
              aliases: "-T"
            ),
            Option.new(
              name: :domains,
              description: "Comma-separated list of custom domain(s) or non-Branch domain(s)",
              example: "example.com,www.example.com",
              type: Array,
              aliases: "-D",
              confirm_symbol: :all_domains
            ),
            Option.new(
              name: :app_link_subdomain,
              description: "Branch app.link subdomain, e.g. myapp for myapp.app.link",
              example: "myapp",
              type: String,
              label: "app.link subdomain",
              skip_confirmation: true
            ),
            Option.new(
              name: :uri_scheme,
              description: "Custom URI scheme used in the Branch Dashboard for this app",
              example: "myurischeme[://]",
              type: String,
              aliases: "-U",
              label: "URI scheme"
            ),
            Option.new(
              name: :setting,
              description: "Use a custom build setting for the Branch key (default: Use Info.plist)",
              example: "BRANCH_KEY_SETTING",
              type: String,
              argument_optional: true,
              aliases: "-s",
              label: "User-defined setting for Branch key"
            ),
            Option.new(
              name: :test_configurations,
              description: "List of configurations that use the test key with a user-defined setting (default: Debug configurations)",
              example: "config1,config2",
              type: Array,
              negatable: true,
              valid_values_proc: ->() { Configuration.current.xcodeproj.build_configurations.map(&:name) }
            ),
            Option.new(
              name: :xcodeproj,
              description: "Path to an Xcode project to update",
              example: "MyProject.xcodeproj",
              type: String,
              confirm_symbol: :xcodeproj_path,
              validate_proc: ->(path) { Configuration.open_xcodeproj path }
            ),
            Option.new(
              name: :target,
              description: "Name of a target to modify in the Xcode project",
              example: "MyAppTarget",
              type: String,
              confirm_symbol: :target_name,
              valid_values_proc: ->() { Configuration.current.xcodeproj.targets.map(&:name) }
            ),
            Option.new(
              name: :podfile,
              description: "Path to the Podfile for the project",
              example: "/path/to/Podfile",
              type: String,
              confirm_symbol: :podfile_path,
              validate_proc: ->(path) { Configuration.open_podfile path }
            ),
            Option.new(
              name: :cartfile,
              description: "Path to the Cartfile for the project",
              example: "/path/to/Cartfile",
              type: String,
              confirm_symbol: :cartfile_path,
              validate_proc: ->(path) { !path.nil? && File.exist?(path.to_s) },
              convert_proc: ->(path) { Configuration.absolute_path(path.to_s) unless path.nil? }
            ),
            Option.new(
              name: :carthage_command,
              description: "Command to run when installing from Carthage",
              example: "<command>",
              type: String,
              default_value: "update --platform ios"
            ),
            Option.new(
              name: :frameworks,
              description: "Comma-separated list of system frameworks to add to the project",
              example: "AdSupport,CoreSpotlight,SafariServices",
              type: Array
            ),
            Option.new(
              name: :pod_repo_update,
              description: "Update the local podspec repo before installing",
              default_value: true
            ),
            Option.new(
              name: :validate,
              description: "Validate Universal Link configuration",
              default_value: true
            ),
            Option.new(
              name: :force,
              description: "Update project even if Universal Link validation fails",
              default_value: false
            ),
            Option.new(
              name: :add_sdk,
              description: "Add the Branch framework to the project",
              default_value: true
            ),
            Option.new(
              name: :patch_source,
              description: "Add Branch SDK calls to the AppDelegate",
              default_value: true
            ),
            Option.new(
              name: :commit,
              description: "Commit the results to Git if non-blank",
              type: String,
              example: "message",
              argument_optional: true,
              label: "Commit message"
            ),
            Option.new(
              name: :confirm,
              description: "Confirm configuration before proceeding",
              default_value: true,
              skip_confirmation: true
            )
          ]
        end
      end

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

      def initialize(options)
        super
        # Configuration has been validated and logged to the screen.
        confirm_with_user if options.confirm
      end

      def validate_options
        @validate = options.validate
        @patch_source = options.patch_source
        @add_sdk = options.add_sdk
        @force = options.force
        @commit = options.commit
        @check_repo_changes = options.check_repo_changes

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
        validate_test_configurations options

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
          if test_configurations
            message += <<-EOF
<%= color('Test configurations:', BOLD) %> #{test_configurations}
            EOF
          end
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
        instance_variable_set "@#{type}_key", key
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
          setting = ask "Invalid build setting. Please enter an all-caps identifier (may include digits and underscores): "
        end
      end

      def validate_test_configurations(options)
        return if options.test_configurations.nil?
        unless options.setting
          say "--test-configurations ignored without --setting"
          return
        end

        all_configurations = target.build_configurations.map(&:name)
        test_configs = options.test_configurations == false ? [] : options.test_configurations
        loop do
          invalid_configurations = test_configs.reject { |c| all_configurations.include? c }
          @test_configurations = test_configs and return if invalid_configurations.empty?

          say "The following test configurations are invalid: #{invalid_configurations}."
          say "Available configurations: #{all_configurations}"
          test_configs = ask "Please enter a comma-separated list of configurations to use the Branch test key: ", Array
        end
      end
    end
    # rubocop: enable Metrics/ClassLength
  end
end
