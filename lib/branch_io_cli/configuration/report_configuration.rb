require "plist"
require "xcodeproj"

module Xcodeproj
  class Project
    # Local override to allow for user schemes.
    #
    # Get list of shared and user schemes in project
    #
    # @param [String] path
    #         project path
    #
    # @return [Array]
    #
    def self.schemes(project_path)
      base_dirs = [File.join(project_path, 'xcshareddata', 'xcschemes'),
                   File.join(project_path, 'xcuserdata', "#{ENV['USER']}.xcuserdatad", 'xcschemes')]

      # Take any .xcscheme file from base_dirs
      schemes = base_dirs.inject([]) { |memo, dir| memo + Dir[File.join dir, '*.xcscheme'] }
                         .map { |f| File.basename(f, '.xcscheme') }

      # Include any scheme defined in the xcschememanagement.plist, if it exists.
      base_dirs.map { |d| File.join d, 'xcschememanagement.plist' }
               .select { |f| File.exist? f }.each do |plist_path|
        plist = File.open(plist_path) { |f| ::Plist.parse_xml f }
        scheme_user_state = plist["SchemeUserState"]
        schemes += scheme_user_state.keys.map { |k| File.basename k, '.xcscheme' }
      end

      schemes.uniq!
      if schemes.empty? && File.exist?(project_path)
        # Open the project, get all targets. Add one scheme per target.
        project = self.open project_path
        schemes += project.targets.reject(&:test_target_type?).map(&:name)
      elsif schemes.empty?
        schemes << File.basename(project_path, '.xcodeproj')
      end
      schemes
    end
  end
end

module BranchIOCLI
  module Configuration
    class ReportConfiguration < Configuration
      attr_reader :clean
      attr_reader :header_only
      attr_reader :scheme
      attr_reader :configuration
      attr_reader :report_path
      attr_reader :sdk

      def xcode_settings
        XcodeSettings.settings
      end

      def validate_options
        @clean = options.clean
        @header_only = options.header_only
        @scheme = options.scheme
        @target = options.target
        @report_path = options.out
        @sdk = options.sdk
        @pod_repo_update = options.pod_repo_update

        validate_xcodeproj_and_workspace options
        validate_scheme options
        validate_target options
        validate_configuration options

        # If neither --podfile nor --cartfile is present, arbitrarily look for a Podfile
        # first.

        # If --cartfile is present, don't look for a Podfile. Just validate that
        # Cartfile.
        validate_buildfile_path(options.podfile, "Podfile") if options.cartfile.nil?

        # If --podfile is present or a Podfile was found, don't look for a Cartfile.
        validate_buildfile_path(options.cartfile, "Cartfile") if sdk_integration_mode.nil?
      end

      # TODO: Collapse the following methods with support for formatting.
      def report_configuration
        <<EOF
Configuration:

Xcode workspace: #{workspace_path || '(none)'}
Xcode project: #{xcodeproj_path || '(none)'}
Scheme: #{scheme || '(none)'}
Target: #{target || '(none)'}
Configuration: #{configuration || '(none)'}
SDK: #{sdk}
Podfile: #{relative_path(podfile_path) || '(none)'}
Cartfile: #{relative_path(cartfile_path) || '(none)'}
Pod repo update: #{pod_repo_update.inspect}
Clean: #{clean.inspect}
EOF
      end

      def log
        super
        say <<EOF
<%= color('Xcode workspace:', BOLD) %> #{workspace_path || '(none)'}
<%= color('Xcode project:', BOLD) %> #{xcodeproj_path || '(none)'}
<%= color('Scheme:', BOLD) %> #{scheme || '(none)'}
<%= color('Target:', BOLD) %> #{target || '(none)'}
<%= color('Configuration:', BOLD) %> #{configuration || '(none)'}
<%= color('SDK:', BOLD) %> #{sdk}
<%= color('Podfile:', BOLD) %> #{relative_path(podfile_path) || '(none)'}
<%= color('Cartfile:', BOLD) %> #{relative_path(cartfile_path) || '(none)'}
<%= color('Pod repo update:', BOLD) %> #{pod_repo_update.inspect}
<%= color('Clean:', BOLD) %> #{clean.inspect}
<%= color('Report path:', BOLD) %> #{report_path}
EOF
      end

      # rubocop: disable Metrics/PerceivedComplexity
      def validate_xcodeproj_and_workspace(options)
        # 1. What was passed in?
        begin
          if options.workspace
            path = options.workspace
            @workspace = Xcodeproj::Workspace.new_from_xcworkspace options.workspace
            @workspace_path = File.expand_path options.workspace
          end
          if options.xcodeproj
            path = options.xcodeproj
            @xcodeproj = Xcodeproj::Project.open options.xcodeproj
            @xcodeproj_path = File.expand_path options.xcodeproj
          else
            # Pass --workspace and --xcodeproj to override this inference.
            if workspace && workspace.file_references.count > 0 && workspace.file_references.first.path =~ /\.xcodeproj$/
              @xcodeproj_path = File.expand_path "../#{@workspace.file_references.first.path}", workspace_path
              @xcodeproj = Xcodeproj::Project.open xcodeproj_path
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
              @workspace_path = File.expand_path path

              # Pass --workspace and --xcodeproj to override this inference.
              if workspace.file_references.count > 0 && workspace.file_references.first.path =~ /\.xcodeproj$/
                @xcodeproj_path = File.expand_path "../#{workspace.file_references.first.path}", workspace_path
                @xcodeproj = Xcodeproj::Project.open xcodeproj_path
              end

              return
            elsif path =~ /\.xcodeproj$/
              @xcodeproj = Xcodeproj::Project.open path
              @xcodeproj_path = File.expand_path path
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
          say "Scheme #{options.scheme} not found. Using #{@scheme}." if options.scheme
        elsif !schemes.empty?
          # By default, take a scheme with the same name as the project name.
          return if !options.scheme && (@scheme = schemes.find { |s| s == File.basename(xcodeproj_path, '.xcodeproj') })

          @scheme = choose do |menu|
            menu.header = "Schemes from project"
            schemes.each { |s| menu.choice s }
            menu.prompt = "Please choose one of the schemes above. "
          end
        else
          say "No scheme defined in project."
          exit(-1)
        end

        return if options.target || xcscheme.nil?

        # Find the target used when running the scheme if the user didn't specify one.
        # This will be picked up in #validate_target
        entry = xcscheme.build_action.entries.select(&:build_for_running?).first
        options.target = entry.buildable_references.first.target_name
      end

      def all_schemes
        if workspace_path
          workspace.schemes.keys.reject { |scheme| scheme == "Pods" }
        else
          Xcodeproj::Project.schemes xcodeproj_path
        end
      end

      def xcscheme
        return @xcscheme if @xcscheme_checked
        # This may not exist. If it comes back nil once, don't keep checking.
        @xcscheme_checked = true
        @xcscheme = scheme_with_name @scheme
        @xcscheme
      end

      def scheme_with_name(scheme_name)
        if workspace_path
          project_path = workspace.schemes[@scheme]
        else
          project_path = xcodeproj_path
        end

        # Look for a shared scheme.
        xcshareddata_path = File.join project_path, "xcshareddata", "xcschemes", "#{@scheme}.xcscheme"
        scheme_path = xcshareddata_path if File.exist?(xcshareddata_path)

        unless scheme_path
          # Look for a local scheme
          user = ENV["USER"]
          xcuserdata_path = File.join project_path, "xcuserdata", "#{user}.xcuserdatad", "xcschemes", "#{@scheme}.xcscheme"
          scheme_path = xcuserdata_path if File.exist?(xcuserdata_path)
        end

        return nil unless scheme_path

        Xcodeproj::XCScheme.new(scheme_path)
      end

      def validate_configuration(options)
        return unless options.configuration

        all_configs = xcodeproj.build_configurations.map(&:name)

        if all_configs.include?(options.configuration)
          @configuration = options.configuration
        else
          say "Configuration #{options.configuration} not found."
          @configuration = choose do |menu|
            menu.header = "Configurations from project"
            all_configs.each { |c| menu.choice c }
            menu.prompt = "Please choose one of the above. "
          end
        end
      end

      def configurations_from_scheme
        return ["Debug", "Release"] unless xcscheme
        %i[test launch profile archive analyze].map { |pfx| xcscheme.send("#{pfx}_action").build_configuration }.uniq
      end

      def branch_version
        version_from_podfile_lock ||
          version_from_cartfile_resolved ||
          version_from_branch_framework ||
          version_from_bnc_config_m
      end

      def requirement_from_podfile
        return nil unless podfile_path
        podfile = File.read podfile_path
        matches = /\n?\s*pod\s+("Branch"|'Branch').*?\n/m.match podfile
        matches ? matches[0].strip : nil
      end

      def requirement_from_cartfile
        return nil unless cartfile_path
        cartfile = File.read cartfile_path
        matches = %r{^git(hub\s+"|\s+"https://github.com/)BranchMetrics/(ios-branch-deep-linking|iOS-Deferred-Deep-Linking-SDK.*?).*?\n}m.match cartfile
        matches ? matches[0].strip : nil
      end

      def version_from_podfile_lock
        return nil unless podfile_path && File.exist?("#{podfile_path}.lock")
        podfile_lock = Pod::Lockfile.from_file Pathname.new "#{podfile_path}.lock"
        version = podfile_lock.version("Branch") || podfile_lock.version("Branch-SDK")

        version ? "#{version} [Podfile.lock]" : nil
      end

      def version_from_cartfile_resolved
        return nil unless cartfile_path && File.exist?("#{cartfile_path}.resolved")
        cartfile_resolved = File.read "#{cartfile_path}.resolved"

        # Matches:
        # git "https://github.com/BranchMetrics/ios-branch-deep-linking"
        # git "https://github.com/BranchMetrics/ios-branch-deep-linking/"
        # git "https://github.com/BranchMetrics/iOS-Deferred-Deep-Linking-SDK"
        # git "https://github.com/BranchMetrics/iOS-Deferred-Deep-Linking-SDK/"
        # github "BranchMetrics/ios-branch-deep-linking"
        # github "BranchMetrics/ios-branch-deep-linking/"
        # github "BranchMetrics/iOS-Deferred-Deep-Linking-SDK"
        # github "BranchMetrics/iOS-Deferred-Deep-Linking-SDK/"
        matches = %r{(ios-branch-deep-linking|iOS-Deferred-Deep-Linking-SDK)/?" "(\d+\.\d+\.\d+)"}m.match cartfile_resolved
        return nil unless matches
        version = matches[2]
        "#{version} [Cartfile.resolved]"
      end

      def version_from_branch_framework
        framework = target.frameworks_build_phase.files.find { |f| f.file_ref.path =~ /Branch.framework$/ }
        return nil unless framework

        if framework.file_ref.isa == "PBXFileReference"
          project_path = relative_path(config.xcodeproj_path)
          framework_path = framework.file_ref.real_path
        elsif framework.file_ref.isa == "PBXReferenceProxy" && xcode_settings
          project_path = relative_path framework.file_ref.remote_ref.proxied_object.project.path
          framework_path = File.expand_path framework.file_ref.path, xcode_settings[framework.file_ref.source_tree]
        end
        info_plist_path = File.join framework_path.to_s, "Info.plist"
        return nil unless File.exist? info_plist_path

        require "cfpropertylist"

        raw_info_plist = CFPropertyList::List.new file: info_plist_path
        info_plist = CFPropertyList.native_types raw_info_plist.value
        version = info_plist["CFBundleVersion"]
        return nil unless version
        "#{version} [Branch.framework/Info.plist:#{project_path}]"
      end

      def version_from_bnc_config_m(project = xcodeproj)
        # Look for BNCConfig.m in embedded source
        bnc_config_m_ref = project.files.find { |f| f.path =~ /BNCConfig\.m$/ }
        unless bnc_config_m_ref
          subprojects = project.files.select { |f| f.path =~ /\.xcodeproj$/ }
          subprojects.each do |subproject|
            p = Xcodeproj::Project.open subproject.real_path
            version = version_from_bnc_config_m p
            return version if version
          end
        end

        return nil unless bnc_config_m_ref
        bnc_config_m = File.read bnc_config_m_ref.real_path
        matches = /BNC_SDK_VERSION\s+=\s+@"(\d+\.\d+\.\d+)"/m.match bnc_config_m
        return nil unless matches
        version = matches[1]
        "#{version} [BNCConfig.m:#{relative_path project.path}]"
      end

      def branch_key_setting_from_info_plist(config = configuration || "Release")
        return @branch_key_setting_from_info_plist if @branch_key_setting_from_info_plist

        infoplist_path = helper.expanded_build_setting target, "INFOPLIST_FILE", config
        infoplist_path = File.expand_path infoplist_path, File.dirname(xcodeproj_path)
        info_plist = File.open(infoplist_path) { |f| Plist.parse_xml f }
        branch_key = info_plist["branch_key"]
        regexp = /^\$\((\w+)\)$|^\$\{(\w+)\}$/
        return nil unless branch_key.kind_of?(String) && (matches = regexp.match branch_key)
        @branch_key_setting_from_info_plist = matches[1] || matches[2]
        @branch_key_setting_from_info_plist
      end
    end
  end
end
