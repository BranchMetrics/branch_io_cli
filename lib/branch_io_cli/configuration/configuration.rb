require "pathname"
require "xcodeproj"

module BranchIOCLI
  module Configuration
    class Configuration
      attr_reader :options

      def initialize(options)
        @options = options
      end

      def log
        # implemented in subclasses
      end

      def print_identification(command)
        say <<EOF

<%= color("branch_io #{command} v. #{VERSION}", BOLD) %>

EOF
      end

      def helper
        Helper::BranchHelper
      end

      # 1. Look for options.xcodeproj.
      # 2. If not specified, look for projects under . (excluding anything in Pods or Carthage folder).
      # 3. If none or more than one found, prompt the user.
      def validate_xcodeproj_path
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

      def validate_target(allow_extensions = true)
        non_test_targets = @xcodeproj.targets.reject(&:test_target_type?)
        raise "No non-test target found in project" if non_test_targets.empty?

        valid_targets = non_test_targets.reject { |t| !allow_extensions && t.extension_target_type? }

        begin
          target = helper.target_from_project @xcodeproj, options.target

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
    end
  end
end
