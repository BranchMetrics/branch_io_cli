require "xcodeproj"

module BranchIOCLI
  module Helper
    class ConfigurationHelper
      class << self
        attr_accessor :xcodeproj_path
        attr_accessor :xcodeproj
        attr_accessor :keys
        attr_accessor :all_domains
        attr_accessor :podfile_path
        attr_accessor :cartfile_path

        def validate_setup_options(options)
          say "--force is ignored when --no_validate is used." if options.no_validate && options.force

          validate_xcodeproj_path options
          validate_keys_from_setup_options options
          validate_all_domains options
          validate_buildfile_path options, "Podfile"
          validate_buildfile_path options, "Cartfile"
          validate_sdk_addition options
        end

        def validate_validation_options(options)
          validate_xcodeproj_path options
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

        def validate_all_domains(options)
          app_link_subdomains = app_link_subdomains options
          custom_domains = options.domains || []
          @all_domains = (app_link_subdomains + custom_domains).uniq

          while @all_domains.empty?
            @all_domains = ask "Please enter domains as a comma-separated list: ", ->(str) { str.split "," }
          end
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
            xcodeproj_paths = all_xcodeproj_paths.reject { |p| p =~ /Pods|Carthage/ }

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
            end
          end
        end

        def app_link_subdomains(options)
          app_link_subdomain = options.app_link_subdomain
          live_key = options.live_key
          test_key = options.test_key
          return [] if live_key.nil? and test_key.nil?
          return [] if app_link_subdomain.nil?

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

        def validate_buildfile_path(options, filename)
          # Disable Podfile/Cartfile update if --no_add_sdk is present
          return if options.no_add_sdk

          buildfile_path = filename == "Podfile" ? options.podfile : options.cartfile

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

          # No: Check for Podfile/Cartfile next to @xcodeproj_path
          buildfile_path = File.expand_path "../#{filename}", @xcodeproj_path
          return unless File.exist? buildfile_path

          # Exists: Use it (valid if found)
          if filename == "Podfile"
            @podfile_path = buildfile_path
          else
            @cartfile_path = buildfile_path
          end
        end

        def validate_sdk_addition(options)
          return if options.no_add_sdk || @podfile_path || @cartfile_path

          # --podfile, --cartfile not specified. No Podfile found. No Cartfile found.
          # Prompt the user:
          selected = choose do |menu|
            menu.header = "No Podfile or Cartfile specified or found. Here are your options"

            SDK_OPTIONS.each_key { |k| menu.choice k }

            menu.prompt = "What would you like to do?"
          end

          option = SDK_OPTIONS[selected]

          case option
          when :skip
            return
          else
            send "set_up_#{option}"
          end
        end

        def set_up_cocoapods
          say "Setting up CocoaPods"
        end

        def set_up_carthage
          say "Setting up Carthage"
        end

        def set_up_manual
          say "Setting up manual installation"
        end

        SDK_OPTIONS =
          {
            "Set this project up to use CocoaPods and add the Branch SDK." => :cocoapods,
            "Set this project up to use Carthage and add the Branch SDK." => :carthage,
            "Add Branch.framework directly to the project's dependencies." => :manual,
            "Skip adding the framework to the project." => :skip
          }
      end
    end
  end
end
