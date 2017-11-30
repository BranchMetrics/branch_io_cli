require "branch_io_cli/helper"

module BranchIOCLI
  module Command
    class SetupCommand < Command
      include Helper::Methods

      def initialize(options)
        super
        @keys = config.keys
        @domains = config.all_domains
      end

      # rubocop: disable Metrics/PerceivedComplexity
      def run!
        # Make sure the user stashes or commits before continuing.
        check_repo_status

        xcodeproj = config.xcodeproj

        is_app_target = !config.target.extension_target_type?

        if is_app_target && config.validate &&
           !helper.validate_team_and_bundle_ids_from_aasa_files(@domains)
          say "Universal Link configuration failed validation."
          helper.errors.each { |error| say " #{error}" }
          return 1 unless config.force
        elsif is_app_target && config.validate
          say "Universal Link configuration passed validation. ✅"
        end

        if config.podfile_path && File.exist?(config.podfile_path) && config.pod_install_required?
          helper.verify_cocoapods
          say "Installing pods to resolve current build settings"
          Dir.chdir(File.dirname(config.podfile_path)) do
            # We haven't modified anything yet. Don't use --repo-update at this stage.
            # This is unlikely to fail.
            sh "pod install"
          end
        end

        helper.add_custom_build_setting if config.setting

        helper.add_keys_to_info_plist @keys
        helper.add_branch_universal_link_domains_to_info_plist @domains if is_app_target
        helper.ensure_uri_scheme_in_info_plist if is_app_target # does nothing if already present

        if is_app_target
          config.xcodeproj.build_configurations.each do |c|
            new_path = helper.add_universal_links_to_project @domains, false, c.name
            sh ["git", "add", new_path] if config.commit && new_path
          end
        end

        config_helper.target.add_system_frameworks config.frameworks unless config.frameworks.nil? || config.frameworks.empty?

        xcodeproj.save

        case config.sdk_integration_mode
        when :cocoapods
          if File.exist? config.podfile_path
            tool_helper.update_podfile config
          else
            tool_helper.add_cocoapods config
          end
        when :carthage
          if File.exist? config.cartfile_path
            tool_helper.update_cartfile config, xcodeproj
          else
            tool_helper.add_carthage config
          end
        when :direct
          tool_helper.add_direct config
        end

        patch_helper.patch_source xcodeproj if config.patch_source

        return 0 unless config.commit

        changes = helper.changes.to_a.map { |c| Pathname.new(File.expand_path(c)).relative_path_from(Pathname.pwd).to_s }

        commit_message = config.commit if config.commit.kind_of?(String)
        commit_message ||= "[branch_io_cli] Branch SDK integration #{config.relative_path(config.xcodeproj_path)} (#{config.target.name})"

        sh ["git", "commit", "-qm", commit_message, *changes]

        0
      end
      # rubocop: enable Metrics/PerceivedComplexity

      def check_repo_status
        # If the git command is not installed, there's not much we can do.
        # Don't want to use verify_git here, which will insist on installing
        # the command. The logic of that method could change.
        return if `which git`.empty? || !config.confirm

        unless Dir.exist? ".git"
          `git rev-parse --git-dir > /dev/null 2>&1`
          # Not a git repo
          return unless $?.success?
        end

        `git diff-index --quiet HEAD --`
        return if $?.success?

        # Show the user
        sh "git status"

        choice = choose do |menu|
          menu.header = "There are uncommitted changes in this repo. It's best to stash or commit them before continuing."
          menu.choice "Stash"
          menu.choice "Commit (You will be prompted for a commit message.)"
          menu.choice "Quit"
          menu.choice "Ignore and continue"
          menu.prompt = "Please enter one of the options above: "
        end

        case choice
        when /^Stash/
          sh "git stash -q"
        when /^Commit/
          message = ask "Please enter a commit message: "
          sh ["git", "commit", "-aqm", message]
        when /^Quit/
          say "Please stash or commit your changes before continuing."
          exit(-1)
        end
      end
    end
  end
end
