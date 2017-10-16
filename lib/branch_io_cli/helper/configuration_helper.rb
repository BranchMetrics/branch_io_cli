require "xcodeproj"

module BranchIOCLI
  module Helper
    class ConfigurationHelper
      class << self
        attr_accessor :xcodeproj
        attr_accessor :keys
        attr_accessor :all_domains

        def validate_setup_options(options)
          options.xcodeproj = xcodeproj_path options
          validate_keys_from_setup_options options
          validate_all_domains options
          options
        end

        def validate_validation_options(options)
          options.xcodeproj = xcodeproj_path options
          options
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
        def xcodeproj_path(options)
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
              return path
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
      end
    end
  end
end
