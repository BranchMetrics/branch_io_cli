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
          options
        end

        def validate_validation_options(options)
          options.xcodeproj = xcodeproj_path options
          options
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
      end
    end
  end
end
