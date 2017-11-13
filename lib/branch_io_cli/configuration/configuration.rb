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
      attr_accessor :podfile
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

      def relative_path(path)
        return nil if path.nil?

        path = Pathname.new(path) unless path.kind_of? Pathname
        return path.to_s unless path.absolute?

        unless @root
          if workspace
            @root = Pathname.new(workspace_path).dirname
          else
            @root = Pathname.new(xcodeproj_path).dirname
          end
        end

        path.relative_path_from(@root).to_s
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
            @xcodeproj_path = File.expand_path path
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
          return unless File.exist? buildfile_path
        end

        # Validate. Prompt if not valid.
        while !buildfile_path || !validate_buildfile_at_path(buildfile_path, filename)
          buildfile_path = ask "Please enter the path to your #{filename}: "
        end

        @sdk_integration_mode = filename == "Podfile" ? :cocoapods : :carthage
      end

      def open_podfile(path = @podfile_path)
        @podfile = Pod::Podfile.from_file path
        @podfile_path = path
        @sdk_integration_mode = :cocoapods
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
          say "#{buildfile_path} not found." and return false unless valid
        end

        if filename == "Podfile" && open_podfile(buildfile_path)
          true
        elsif filename == "Cartfile"
          @cartfile_path = buildfile_path
          @sdk_integration_mode = :carthage
          true
        else
          false
        end
      end

      def uses_frameworks?
        return nil unless podfile
        target_definition = podfile.target_definition_list.find { |t| t.name == target.name }
        return nil unless target_definition
        target_definition.uses_frameworks?
      end

      def bridging_header_required?
        return false unless swift_version
        # If there is a Podfile and use_frameworks! is not present for this
        # target, we need a bridging header.
        podfile && !uses_frameworks?
      end

      def app_delegate_swift_path
        return nil unless swift_version && swift_version.to_f >= 3.0

        app_delegate = target.source_build_phase.files.find { |f| f.file_ref.path =~ /AppDelegate\.swift$/ }
        return nil if app_delegate.nil?

        app_delegate.file_ref.real_path.to_s
      end

      def app_delegate_objc_path
        app_delegate = target.source_build_phase.files.find { |f| f.file_ref.path =~ /AppDelegate\.m$/ }
        return nil if app_delegate.nil?

        app_delegate.file_ref.real_path.to_s
      end

      # TODO: How many of these can vary by configuration?

      def modules_enabled?
        return nil unless target
        setting = target.resolved_build_setting("CLANG_ENABLE_MODULES")["Release"]
        return nil unless setting
        setting == "YES"
      end

      def bridging_header_path
        return @bridging_header_path if @bridging_header_path

        return nil unless target
        path = helper.expanded_build_setting target, "SWIFT_OBJC_BRIDGING_HEADER", "Release"
        return nil unless path

        @bridging_header_path = File.expand_path path, File.dirname(xcodeproj_path)
        @bridging_header_path
      end

      def swift_version
        return @swift_version if @swift_version

        return nil unless target
        @swift_version = target.resolved_build_setting("SWIFT_VERSION")["Release"]
        @swift_version
      end
    end
  end
end
