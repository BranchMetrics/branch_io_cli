module BranchIOCLI
  module Helper
    class ConfigurationHelper
      class << self
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
          return options.xcodeproj if options.xcodeproj

          all_xcodeproj_paths = Dir[File.expand_path(File.join(".", "**/*.xcodeproj"))]
          # find an xcodeproj (ignoring the Pods and Carthage folders)
          # TODO: Improve this filter
          xcodeproj_paths = all_xcodeproj_paths.reject { |p| p =~ /Pods|Carthage/ }

          return xcodeproj_paths.first if xcodeproj_paths.count == 1

          loop do
            path = ask "Please enter the path to your Xcode project or use --xcodeproj: "
            full_path = File.expand_path path, "."
            return path if File.exist?(full_path) && File.directory?(full_path) && File.exist?(File.join(full_path, "project.pbxproj"))
          end
        end
      end
    end
  end
end
