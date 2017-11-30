require "cocoapods-core"
require "pathname"
require "xcodeproj"

module BranchIOCLI
  module Configuration
    # rubocop: disable Metrics/ClassLength
    class Configuration
      class << self
        attr_accessor :current

        def wrapper(hash, add_defaults = true)
          OptionWrapper.new hash, available_options, add_defaults
        end

        def defaults
          available_options.inject({}) do |defs, o|
            default_value = o.env_value
            default_value = o.default_value if default_value.nil?

            next defs if default_value.nil?

            defs.merge(o.name => default_value)
          end
        end

        def available_options
          root = name.gsub(/^.*::(\w+)Configuration$/, '\1')
          BranchIOCLI::Configuration.const_get("#{root.capitalize}Options").available_options
        end

        def absolute_path(path)
          return path unless current
          current.absolute_path path
        end

        def relative_path(path)
          return path unless current
          current.relative_path path
        end

        def open_podfile(path)
          return false unless current
          current.open_podfile absolute_path path
        end

        def open_xcodeproj(path)
          return false unless current
          current.open_xcodeproj absolute_path path
        end

        def root
          return nil unless current
          current.root
        end
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
      attr_reader :sdk

      def initialize(options)
        @options = options
        @pod_repo_update = options.pod_repo_update if self.class.available_options.map(&:name).include?(:pod_repo_update)
        @sdk = "iphonesimulator" # to load Xcode build settings for commands without a --sdk option

        Configuration.current = self

        say "\n"
        print_identification
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

      def print_identification
        say <<EOF
<%= color("branch_io #{self.class.name.sub(/^.*::(.*?)Configuration$/, '\1').downcase} v. #{VERSION}", BOLD) %>

EOF
      end

      def helper
        Helper::BranchHelper
      end

      def target_name
        target.name.nil? ? nil : target.name
      end

      def root
        return @root if @root
        if workspace
          @root = Pathname.new(workspace_path).dirname
        else
          @root = Pathname.new(xcodeproj_path).dirname
        end
        @root
      end

      def absolute_path(path)
        return nil if path.nil?

        path = Pathname.new(path) unless path.kind_of? Pathname
        return path.to_s if path.absolute?

        (root + path).to_s
      end

      def relative_path(path)
        return nil if path.nil?

        path = Pathname.new(path) unless path.kind_of? Pathname
        return path.to_s unless path.absolute?

        path.relative_path_from(root).to_s
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
        return if @target

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

      def open_podfile(path = podfile_path)
        @podfile = Pod::Podfile.from_file path
        @podfile_path = path
        @sdk_integration_mode = :cocoapods
        true
      rescue Pod::PlainInformative => e
        say e.message
        false
      end

      def open_xcodeproj(path = xcodeproj_path)
        @xcodeproj = Xcodeproj::Project.open path
        @xcodeproj_path = path
        true
      rescue Xcodeproj::PlainInformative => e
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

      def pod_install_required?
        # If this is set, its existence has been verified.
        return false unless podfile_path

        lockfile_path = "#{podfile_path}.lock"
        manifest_path = File.expand_path "../Pods/Manifest.lock", podfile_path

        return true unless File.exist?(lockfile_path) && File.exist?(manifest_path)

        lockfile = Pod::Lockfile.from_file Pathname.new lockfile_path
        manifest = Pod::Lockfile.from_file Pathname.new manifest_path

        # diff the contents of Podfile.lock and Pods/Manifest.lock
        # This is just what is done in the "[CP] Check Pods Manifest.lock" script build phase
        # in a project using CocoaPods.
        return true unless lockfile == manifest

        # compare checksum of Podfile with checksum in Podfile.lock
        # This is a good sanity check, but perhaps unnecessary. It means pod install
        # has not been run since the Podfile was modified, which is probably an oversight.
        return true unless lockfile.to_hash["PODFILE CHECKSUM"] == podfile.checksum

        false
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

      def messages_view_controller_path
        return nil unless target.symbol_type == :messages_extension

        all_paths = target.source_build_phase.files.map { |f| f.file_ref.real_path.to_s }
        swift_paths = all_paths.grep(/\.swift$/)

        # We're looking for the @interface declaration for a class that inherits from
        # MSMessagesAppViewController. The target probably doesn't have a headers
        # build phase. Include all .ms from the source build phase and any .h
        # with the same root.
        objc_paths = all_paths.grep(/\.m$/)
        objc_paths += objc_paths.map { |p| p.sub(/\.m$/, '.h') }.select { |f| File.exist? f }

        path = swift_paths.find { |f| /class.*:\s+MSMessagesAppViewController\s*{\n/m.match_file? f } ||
               objc_paths.find { |f| /@interface.*:\s+MSMessagesAppViewController/.match_file? f }

        # If we found a .h, patch the corresponding .m.
        path && path.sub(/\.h$/, '.m')
      end

      # TODO: How many of these can vary by configuration?

      def modules_enabled?
        return nil unless target
        setting = target.resolved_build_setting("CLANG_ENABLE_MODULES")["Release"]
        return nil unless setting
        setting == "YES"
      end

      def bridging_header_path(configuration = "Release")
        return @bridging_header_path if @bridging_header_path

        return nil unless target
        path = target.expanded_build_setting "SWIFT_OBJC_BRIDGING_HEADER", configuration
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

      def branch_imports
        return @branch_imports if @branch_imports

        source_files = target.source_build_phase.files.map { |f| f.file_ref.real_path.to_s }
        source_files << bridging_header_path if bridging_header_path && File.exist?(bridging_header_path)
        @branch_imports = source_files.compact.map do |f|
          imports = branch_imports_from_file f
          next {} if imports.empty?
          { f => imports }
        end.inject({}, :merge)
        @branch_imports
      end

      # Detect anything that appears to be an attempt to import the Branch SDK,
      # even if it might be wrong.
      def branch_imports_from_file(path)
        imports = []
        File.readlines(path).each_with_index do |line, line_no|
          next unless line =~ /(include|import).*branch/i
          imports << "#{line_no}: #{line.chomp}"
        end
        imports
      rescue StandardError
        # Quietly ignore anything that can't be opened for now.
        # TODO: Get these errors into report output.
        []
      end

      def method_missing(method_sym, *arguments, &block)
        all_options = self.class.available_options.map(&:name)
        return super unless all_options.include?(method_sym)

        # Define an attr_reader for this method
        self.class.send :define_method, method_sym do
          instance_variable_get "@#{method_sym}"
        end

        send method_sym
      end

      # Prompt the user to confirm the configuration or edit.
      def confirm_with_user
        confirmed = Helper::Util.confirm "Is this OK? ", true
        return if confirmed

        loop do
          Helper::Util.clear

          print_identification

          say "<%= color('The following options may be adjusted before continuing.', BOLD) %>"
          choice = choose do |menu|
            self.class.available_options.reject(&:skip_confirmation).each do |option|
              value = send option.confirm_symbol
              menu.choice "#{option.label}: #{option.display_value(value)}"
            end

            menu.choice "Accept and continue"
            menu.choice "Quit"
            menu.readline = true
            menu.prompt = "What would you like to do?"
          end

          Helper::Util.clear

          print_identification

          if (option = self.class.available_options.find { |o| choice =~ /^#{Regexp.quote(o.label)}/ })
            loop do
              break if prompt_for_option(option)
              say "Invalid value for option.\n\n"
            end
          elsif choice =~ /^Accept/
            log
            return
          else
            exit(0)
          end
        end
      end

      def prompt_for_option(option)
        say "<%= color('#{option.label}', BOLD) %>\n\n"
        say "#{option.description}\n\n"
        value = send option.confirm_symbol
        say "<%= color('Type', BOLD) %>: #{option.ui_type}\n"
        say "<%= color('Current value', BOLD) %>: #{option.display_value(value)}"
        say "<%= color('Example', BOLD) %>: #{option.example}" if option.example
        say "\n"

        valid_values = option.valid_values

        if valid_values && !option.type.nil? && option.type != Array
          new_value = choose(*valid_values) do |menu|
            menu.readline = true
            menu.prompt = "Please choose from this list. "
          end

          # Valid because chosen from list
        elsif valid_values && option.type == Array
          # There seems to be a problem with using menu.gather, so we do this.
          valid_values.each do |v|
            say "#{v}\n"
          end

          new_value = ask "Please enter one or more of the above, separated by commas: " do |q|
            q.readline = true
            q.completion = valid_values
          end.split(",") # comma-split with Array not working
        elsif option.type.nil?
          new_value = Helper::Util.confirm "#{option.label}? ", value
        else
          new_value = ask "Please enter a new value for #{option.label}: ", option.type
        end

        new_value = option.convert new_value

        return false unless option.valid?(new_value)
        instance_variable_set "@#{option.confirm_symbol}", new_value
        true
      end
    end
    # rubocop: enable Metrics/ClassLength
  end
end
