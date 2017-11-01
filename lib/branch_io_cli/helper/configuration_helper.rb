require "pathname"
require "xcodeproj"

module BranchIOCLI
  module Helper
    # Processes CLI options.
    # Validates options.
    # Prompts for input in a number of cases.
    # rubocop: disable Metrics/ClassLength
    class ConfigurationHelper
      APP_LINK_REGEXP = /\.app\.link$|\.test-app\.link$/
      SDK_OPTIONS =
        {
          "Set this project up to use CocoaPods and add the Branch SDK." => :cocoapods,
          "Set this project up to use Carthage and add the Branch SDK." => :carthage,
          "Add Branch.framework directly to the project's dependencies." => :direct,
          "Skip adding the framework to the project." => :skip
        }

      class << self
        attr_reader :xcodeproj_path
        attr_reader :xcodeproj
        attr_reader :workspace_path
        attr_reader :workspace
        attr_reader :keys
        attr_reader :all_domains
        attr_reader :podfile_path
        attr_reader :cartfile_path
        attr_reader :carthage_command
        attr_reader :target
        attr_reader :uri_scheme
        attr_reader :pod_repo_update
        attr_reader :validate
        attr_reader :add_sdk
        attr_reader :force
        attr_reader :patch_source
        attr_reader :commit
        attr_reader :sdk_integration_mode
        attr_reader :clean
        attr_reader :header_only
        attr_reader :scheme
        attr_reader :configuration
        attr_reader :report_path

        def validate_setup_options(options)
          print_identification "setup"

          @pod_repo_update = options.pod_repo_update
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

          validate_xcodeproj_path options
          validate_target options
          validate_keys_from_setup_options options
          validate_all_domains options, !@target.extension_target_type?
          validate_uri_scheme options

          # If neither --podfile nor --cartfile is present, arbitrarily look for a Podfile
          # first.

          # If --cartfile is present, don't look for a Podfile. Just validate that
          # Cartfile.
          validate_buildfile_path options.podfile, "Podfile" if options.cartfile.nil? && options.add_sdk

          # If --podfile is present or a Podfile was found, don't look for a Cartfile.
          validate_buildfile_path options.cartfile, "Cartfile" if @sdk_integration_mode.nil? && options.add_sdk
          @carthage_command = options.carthage_command if @sdk_integration_mode == :carthage

          validate_sdk_addition options

          print_setup_configuration
        end

        def validate_validation_options(options)
          print_identification "validate"

          validate_xcodeproj_path options
          validate_target options, false

          print_validation_configuration
        end

        def validate_report_options(options)
          print_identification "report"

          @clean = options.clean
          @header_only = options.header_only
          @scheme = options.scheme
          @target = options.target
          @configuration = options.configuration
          @report_path = options.out || "./report.txt"

          validate_xcodeproj_and_workspace options
          validate_scheme options

          # If neither --podfile nor --cartfile is present, arbitrarily look for a Podfile
          # first.

          # If --cartfile is present, don't look for a Podfile. Just validate that
          # Cartfile.
          validate_buildfile_path(options.podfile, "Podfile") if options.cartfile.nil?

          # If --podfile is present or a Podfile was found, don't look for a Cartfile.
          validate_buildfile_path(options.cartfile, "Cartfile") if @sdk_integration_mode.nil?

          print_report_configuration
        end

        def print_identification(command)
          say <<EOF

<%= color("branch_io #{command} v. #{VERSION}", BOLD) %>

EOF
        end

        def print_setup_configuration
          say <<EOF
<%= color('Configuration:', BOLD) %>

<%= color('Xcode project:', BOLD) %> #{@xcodeproj_path}
<%= color('Target:', BOLD) %> #{@target.name}
<%= color('Live key:', BOLD) %> #{@keys[:live] || '(none)'}
<%= color('Test key:', BOLD) %> #{@keys[:test] || '(none)'}
<%= color('Domains:', BOLD) %> #{@all_domains}
<%= color('URI scheme:', BOLD) %> #{@uri_scheme || '(none)'}
<%= color('Podfile:', BOLD) %> #{@podfile_path || '(none)'}
<%= color('Cartfile:', BOLD) %> #{@cartfile_path || '(none)'}
<%= color('Carthage command:', BOLD) %> #{@carthage_command || '(none)'}
<%= color('Pod repo update:', BOLD) %> #{@pod_repo_update.inspect}
<%= color('Validate:', BOLD) %> #{@validate.inspect}
<%= color('Force:', BOLD) %> #{@force.inspect}
<%= color('Add SDK:', BOLD) %> #{@add_sdk.inspect}
<%= color('Patch source:', BOLD) %> #{@patch_source.inspect}
<%= color('Commit:', BOLD) %> #{@commit.inspect}
<%= color('SDK integration mode:', BOLD) %> #{@sdk_integration_mode || '(none)'}

EOF
        end

        def print_validation_configuration
          say <<EOF
<%= color('Configuration:', BOLD) %>

<%= color('Xcode project:', BOLD) %> #{@xcodeproj_path}
<%= color('Target:', BOLD) %> #{@target.name}
<%= color('Domains:', BOLD) %> #{@all_domains || '(none)'}
EOF
        end

        def print_report_configuration
          say <<EOF
<%= color('Configuration:', BOLD) %>

<%= color('Xcode workspace:', BOLD) %> #{@workspace_path || '(none)'}
<%= color('Xcode project:', BOLD) %> #{@xcodeproj_path || '(none)'}
<%= color('Scheme:', BOLD) %> #{@scheme || '(none)'}
<%= color('Target:', BOLD) %> #{@target || '(none)'}
<%= color('Configuration:', BOLD) %> #{@configuration || '(none)'}
<%= color('Podfile:', BOLD) %> #{@podfile_path || '(none)'}
<%= color('Cartfile:', BOLD) %> #{@cartfile_path || '(none)'}
<%= color('Clean:', BOLD) %> #{@clean.inspect}
<%= color('Report path:', BOLD) %> #{@report_path}
EOF
        end

        def validate_keys_from_setup_options(options)
          live_key = options.live_key
          test_key = options.test_key
          @keys = {}
          @keys[:live] = live_key unless live_key.nil?
          @keys[:test] = test_key unless test_key.nil?

          while @keys.empty?
            say "A live key, a test key or both is required."
            live_key = ask "Please enter your live Branch key or use --live_key [enter for none]: "
            test_key = ask "Please enter your test Branch key or use --test_key [enter for none]: "

            @keys[:live] = live_key unless live_key == ""
            @keys[:test] = test_key unless test_key == ""
          end
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

        # 1. Look for options.xcodeproj.
        # 2. If not specified, look for projects under . (excluding anything in Pods or Carthage folder).
        # 3. If none or more than one found, prompt the user.
        def validate_xcodeproj_path(options)
          if options.xcodeproj
            path = options.xcodeproj
          else
            all_xcodeproj_paths = Dir[File.expand_path(File.join(".", "**/*.xcodeproj"))]
            # find an xcodeproj (ignoring the Pods and Carthage folders)
            # TODO: Improve this filter
            xcodeproj_paths = all_xcodeproj_paths.select do |p|
              valid = true
              Pathname.new(p).each_filename do |f|
                valid = false && break if f == "Carthage" || f == "Pods"
              end
              valid
            end

            path = xcodeproj_paths.first if xcodeproj_paths.count == 1
          end

          loop do
            path = ask "Please enter the path to your Xcode project or use --xcodeproj: " if path.nil?
            # TODO: Allow the user to choose if xcodeproj_paths.count > 0
            begin
              @xcodeproj = Xcodeproj::Project.open path
              @xcodeproj_path = path
              return
            rescue StandardError => e
              say e.message
              path = nil
            end
          end
        end

        # rubocop: disable Metrics/PerceivedComplexity
        def validate_xcodeproj_and_workspace(options)
          # 1. What was passed in?
          begin
            if options.workspace
              path = options.workspace
              @workspace = Xcodeproj::Workspace.new_from_xcworkspace options.workspace
              @workspace_path = options.workspace
            end
            if options.xcodeproj
              path = options.xcodeproj
              @xcodeproj = Xcodeproj::Project.open options.xcodeproj
              @xcodeproj_path = options.xcodeproj
            else
              # Pass --workspace and --xcodeproj to override this inference.
              if @workspace && @workspace.file_references.count > 0 && @workspace.file_references.first.path =~ /\.xcodeproj$/
                @xcodeproj_path = File.expand_path "../#{@workspace.file_references.first.path}", @workspace_path
                @xcodeproj = Xcodeproj::Project.open @xcodeproj_path
              end
            end
            return if @workspace || @xcodeproj
          rescue StandardError => e
            say e.message
          end

          # Try to find first a workspace, then a project
          all_workspace_paths = Dir[File.expand_path(File.join(".", "**/*.xcworkspace"))]
                                .reject { |w| w =~ %r{/project.xcworkspace$} }
                                .select do |p|
            valid = true
            Pathname.new(p).each_filename do |f|
              valid = false && break if f == "Carthage" || f == "Pods"
            end
            valid
          end

          if all_workspace_paths.count == 1
            path = all_workspace_paths.first
          elsif all_workspace_paths.count == 0
            all_xcodeproj_paths = Dir[File.expand_path(File.join(".", "**/*.xcodeproj"))]
            xcodeproj_paths = all_xcodeproj_paths.select do |p|
              valid = true
              Pathname.new(p).each_filename do |f|
                valid = false && break if f == "Carthage" || f == "Pods"
              end
              valid
            end

            path = xcodeproj_paths.first if xcodeproj_paths.count == 1
          end
          # If more than one workspace. Don't try to find a project. Just prompt.

          loop do
            path = ask "Please enter a path to your Xcode project or workspace: " if path.nil?
            begin
              if path =~ /\.xcworkspace$/
                @workspace = Xcodeproj::Workspace.new_from_xcworkspace path
                @workspace_path = path

                # Pass --workspace and --xcodeproj to override this inference.
                if @workspace.file_references.count > 0 && @workspace.file_references.first.path =~ /\.xcodeproj$/
                  @xcodeproj_path = File.expand_path "../#{@workspace.file_references.first.path}", @workspace_path
                  @xcodeproj = Xcodeproj::Project.open @xcodeproj_path
                end

                return
              elsif path =~ /\.xcodeproj$/
                @xcodeproj = Xcodeproj::Project.open path
                @xcodeproj_path = path
                return
              else
                say "Path must end with .xcworkspace or .xcodeproj"
              end
            rescue StandardError => e
              say e.message
            end
          end
        end
        # rubocop: enable Metrics/PerceivedComplexity

        def validate_scheme(options)
          schemes = all_schemes
          if options.scheme && schemes.include?(options.scheme)
            @scheme = options.scheme
          elsif schemes.count == 1
            @scheme = schemes.first
          elsif !schemes.empty?
            say "Please specify one of the following for the --scheme argument:"
            schemes.each do |scheme|
              say " #{scheme}"
            end
            exit 1
          else
            say "No scheme defined in project."
            exit(-1)
          end
        end

        def all_schemes
          if @workspace_path
            @workspace.schemes.keys.reject { |scheme| scheme == "Pods" }
          else
            Xcodeproj::Project.schemes @xcodeproj_path
          end
        end

        def validate_target(options, allow_extensions = true)
          non_test_targets = @xcodeproj.targets.reject(&:test_target_type?)
          raise "No non-test target found in project" if non_test_targets.empty?

          valid_targets = non_test_targets.reject { |t| !allow_extensions && t.extension_target_type? }

          begin
            target = BranchHelper.target_from_project @xcodeproj, options.target

            # If a test target was explicitly specified.
            raise "Cannot use test targets" if target.test_target_type?

            # If an extension target was explicitly specified for validation.
            raise "Extension targets not allowed for this command" if !allow_extensions && target.extension_target_type?

            @target = target
          rescue StandardError => e
            say e.message

            choice = choose do |menu|
              valid_targets.each { |t| menu.choice t.name }
              menu.prompt = "Which target do you wish to use? "
            end

            @target = @xcodeproj.targets.find { |t| t.name = choice }
          end
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

          live_key = @keys[:live]
          test_key = @keys[:test]

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

        def validate_buildfile_path(buildfile_path, filename)
          # Disable Podfile/Cartfile update if --no-add-sdk is present
          return unless @sdk_integration_mode.nil?

          # Was --podfile/--cartfile used?
          if buildfile_path
            # Yes: Validate. Prompt if not valid.
            loop do
              valid = buildfile_path =~ %r{/?#{filename}$}
              say "#{filename} path must end in /#{filename}." unless valid

              if valid
                valid = File.exist? buildfile_path
                say "#{buildfile_path} not found." unless valid
              end

              if valid
                if filename == "Podfile"
                  @podfile_path = buildfile_path
                else
                  @cartfile_path = buildfile_path
                end
                return
              end

              buildfile_path = ask "Please enter the path to your #{filename}: "
            end
          end

          # No: Check for Podfile/Cartfile next to workspace or project
          buildfile_path = File.expand_path "../#{filename}", (@workspace_path || @xcodeproj_path)
          return unless File.exist? buildfile_path

          # Exists: Use it (valid if found)
          if filename == "Podfile"
            @podfile_path = buildfile_path
          else
            @cartfile_path = buildfile_path
          end

          @sdk_integration_mode = filename == "Podfile" ? :cocoapods : :carthage
        end

        def validate_sdk_addition(options)
          return if !options.add_sdk || @sdk_integration_mode

          # If no CocoaPods or Carthage, check to see if the framework is linked.
          target = BranchHelper.target_from_project @xcodeproj, options.target
          return if target.frameworks_build_phase.files.map(&:file_ref).map(&:path).any? { |p| p =~ /Branch.framework$/ }

          # --podfile, --cartfile not specified. No Podfile found. No Cartfile found. No Branch.framework in project.
          # Prompt the user:
          selected = choose do |menu|
            menu.header = "No Podfile or Cartfile specified or found. Here are your options"

            SDK_OPTIONS.each_key { |k| menu.choice k }

            menu.prompt = "What would you like to do?"
          end

          @sdk_integration_mode = SDK_OPTIONS[selected]

          case @sdk_integration_mode
          when :cocoapods
            @podfile_path = File.expand_path "../Podfile", @xcodeproj_path
          when :carthage
            @cartfile_path = File.expand_path "../Cartfile", @xcodeproj_path
            @carthage_command = options.carthage_command
          end
        end
      end
    end
    # rubocop: enable Metrics/ClassLength
  end
end
