require_relative "../helper"

module BranchIOCLI
  module Command
    class SetupCommand < Command
      include Helper::Methods

      def initialize(options)
        super
        @keys = config.keys
        @domains = config.all_domains
      end

      def run!
        # Make sure the user stashes or commits before continuing.
        return 1 unless check_repo_status

        # Validate Universal Link configuration in an application target.
        if config.validate && config.target.symbol_type == :application
          valid = validate_universal_links
          return 1 unless valid || config.force
        end

        return false unless tool_helper.pod_install_if_required

        # Set up Universal Links and Branch key(s)
        update_project_settings

        # Add SDK via CocoaPods, Carthage or direct download (no-op if disabled).
        add_sdk

        # Patch source code if so instructed.
        patch_helper.patch_source config.xcodeproj if config.patch_source

        # Commit changes if so instructed.
        commit_changes if config.commit

        say "\nDone ✅"

        # Return success.
        0
      end

      def validate_universal_links
        say "Validating new Universal Link configuration before making any changes."
        valid = true
        config.xcodeproj.build_configurations.each do |c|
          message = "Validating #{c.name} configuration"
          say "\n<%= color('#{message}', [BOLD, CYAN]) %>\n\n"

          configuration_valid = helper.validate_team_and_bundle_ids_from_aasa_files @domains, false, c.name

          if configuration_valid
            say "Universal Link configuration passed validation for #{c.name} configuration. ✅\n\n"
          else
            say "Universal Link configuration failed validation for #{c.name} configuration.\n\n"
            helper.errors.each { |error| say " #{error}" }
          end

          valid &&= configuration_valid
        end
        valid
      end

      def add_sdk
        say "\nMaking sure Branch dependency is available.\n\n"
        case config.sdk_integration_mode
        when :cocoapods
          if File.exist? config.podfile_path
            tool_helper.update_podfile config
          else
            tool_helper.add_cocoapods config
          end
        when :carthage
          if File.exist? config.cartfile_path
            tool_helper.update_cartfile config, config.xcodeproj
          else
            tool_helper.add_carthage config
          end
        when :direct
          tool_helper.add_direct config
        end
      end

      def update_project_settings
        say "Updating project settings.\n\n"
        helper.add_custom_build_setting if config.setting
        helper.add_keys_to_info_plist @keys
        config.target.add_system_frameworks config.frameworks unless config.frameworks.blank?

        return unless config.target.symbol_type == :application

        helper.add_branch_universal_link_domains_to_info_plist @domains
        helper.ensure_uri_scheme_in_info_plist
        config.xcodeproj.build_configurations.each do |c|
          new_path = helper.add_universal_links_to_project @domains, false, c.name
          sh "git", "add", new_path if config.commit && new_path
        end
      ensure
        config.xcodeproj.save
      end

      def commit_changes
        changes = helper.changes.to_a.map { |c| Pathname.new(File.expand_path(c)).relative_path_from(Pathname.pwd).to_s }

        commit_message = config.commit if config.commit.kind_of?(String)
        commit_message ||= "[branch_io_cli] Branch SDK integration #{config.relative_path(config.xcodeproj_path)} (#{config.target.name})"

        sh "git", "commit", "-qm", commit_message, *changes
      end

      def check_repo_status
        # If the git command is not installed, there's not much we can do.
        # Don't want to use verify_git here, which will insist on installing
        # the command. The logic of that method could change.
        return true if `which git`.empty? || !config.confirm

        unless Dir.exist? ".git"
          `git rev-parse --git-dir > /dev/null 2>&1`
          # Not a git repo
          return true unless $?.success?
        end

        `git diff-index --quiet HEAD --`
        return true if $?.success?

        # Show the user
        sh "git status"

        choice = choose do |menu|
          menu.header = "There are uncommitted changes in this repo. It's best to stash or commit them before continuing."
          menu.readline = true
          menu.choice "Stash"
          menu.choice "Commit (You will be prompted for a commit message.)"
          menu.choice "Quit"
          menu.choice "Ignore and continue"
          menu.prompt = "Please enter one of the options above: "
        end

        case choice
        when /^Stash/
          sh %w(git stash -q)
        when /^Commit/
          message = ask "Please enter a commit message: "
          sh "git", "commit", "-aqm", message
        when /^Quit/
          say "Please stash or commit your changes before continuing."
          return false
        end

        true
      end
    end
  end
end
