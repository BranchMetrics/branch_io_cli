require "cocoapods-core"
require "pathname"
require "xcodeproj"

module BranchIOCLI
  module Configuration
    class Configuration
      class << self
        attr_accessor :current
      end

      attr_reader :options
      attr_reader :xcodeproj
      attr_reader :xcodeproj_path
      attr_reader :target
      attr_reader :podfile
      attr_reader :podfile_path
      attr_reader :cartfile_path
      attr_reader :sdk_integration_mode
      attr_reader :workspace
      attr_reader :workspace_path
      attr_reader :pod_repo_update

      def initialize(options)
        @options = options
        @pod_repo_update = options.pod_repo_update
        Configuration.current = self

        print_identification self.class.name.sub(/^.*::(.*?)Configuration$/, '\1').downcase
        validate_options
        log
      end

      def validate_options
        # implemented in subclasses
      end

      def log
        say <<EOF
<%= color('Configuration:', [CYAN, BOLD, UNDERLINE]) %>

EOF
        # subclass implementation follows
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
        non_test_targets = xcodeproj.targets.reject(&:test_target_type?)
        raise "No non-test target found in project" if non_test_targets.empty?

        valid_targets = non_test_targets.reject { |t| !allow_extensions && t.extension_target_type? }

        begin
          target = helper.target_from_project xcodeproj, options.target

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

          @target = xcodeproj.targets.find { |t| t.name = choice }
        end
      end

      def validate_buildfile_path(buildfile_path, filename)
        # Disable Podfile/Cartfile update if --no-add-sdk is present
        return unless sdk_integration_mode.nil?

        # No --podfile or --cartfile option
        if buildfile_path.nil?
          # Check for Podfile/Cartfile next to workspace or project
          buildfile_path = File.expand_path "../#{filename}", (workspace_path || xcodeproj_path)
          buildfile_path = nil unless File.exist? buildfile_path
        end

        # Validate. Prompt if not valid.
        while !buildfile_path || !validate_buildfile_at_path(buildfile_path, filename)
          buildfile_path = ask "Please enter the path to your #{filename}: "
        end

        @sdk_integration_mode = filename == "Podfile" ? :cocoapods : :carthage
      end

      def open_podfile(path)
        @podfile = Pod::Podfile.from_file path
        @podfile_path = path
        true
      rescue RuntimeError => e
        say e.message
        false
      end

      def validate_buildfile_at_path(buildfile_path, filename)
        valid = buildfile_path =~ %r{/?#{filename}$}
        say "#{filename} path must end in /#{filename}." unless valid

        if valid
          valid = File.exist? buildfile_path
          say "#{buildfile_path} not found." unless valid
        end

        if filename == "Podfile" && open_podfile(buildfile_path)
          true
        elsif filename == "Cartfile"
          @cartfile_path = buildfile_path
          true
        end
        false
      end
    end
  end
end
