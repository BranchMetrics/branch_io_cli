require "branch_io_cli/configuration"
require "branch_io_cli/helper/methods"

module BranchIOCLI
  module Command
    class SetupCommand < Command
      attr_reader :config

      def initialize(options)
        super
        @config = Configuration::SetupConfiguration.new options
        @keys = config.keys
        @domains = config.all_domains
      end

      # rubocop: disable Metrics/PerceivedComplexity
      def run!
        # Make sure the user stashes or commits before continuing.
        check_repo_status

        xcodeproj = config.xcodeproj

        case config.sdk_integration_mode
        when :cocoapods
          if File.exist? config.podfile_path
            helper.update_podfile options
          else
            helper.add_cocoapods options
          end
        when :carthage
          if File.exist? config.cartfile_path
            helper.update_cartfile options, xcodeproj
          else
            helper.add_carthage options
          end
        when :direct
          helper.add_direct options
        end

        is_app_target = !config.target.extension_target_type?

        if is_app_target && options.validate &&
           !helper.validate_team_and_bundle_ids_from_aasa_files(@domains)
          say "Universal Link configuration failed validation."
          helper.errors.each { |error| say " #{error}" }
          return unless options.force
        elsif is_app_target && options.validate
          say "Universal Link configuration passed validation. ✅"
        end

        # the following calls can all raise IOError
        helper.add_keys_to_info_plist @keys
        helper.add_branch_universal_link_domains_to_info_plist @domains if is_app_target
        helper.ensure_uri_scheme_in_info_plist if is_app_target # does nothing if already present

        new_path = helper.add_universal_links_to_project @domains, false if is_app_target
        sh "git add #{new_path}" if options.commit && new_path

        config_helper.target.add_system_frameworks options.frameworks unless options.frameworks.nil? || options.frameworks.empty?

        xcodeproj.save

        helper.patch_source xcodeproj if options.patch_source

        return unless options.commit

        changes = helper.changes.to_a.map { |c| Pathname.new(File.expand_path(c)).relative_path_from(Pathname.pwd).to_s }

        sh "git commit -qm '[branch_io_cli] Branch SDK integration' #{changes.join(' ')}"
      end
      # rubocop: enable Metrics/PerceivedComplexity

      def check_repo_status
        # If the git command is not installed, there's not much we can do.
        # Don't want to use verify_git here, which will insist on installing
        # the command. The logic of that method could change.
        return if `which git`.empty?

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
          menu.choice "Commit (you will be prompted for a commit message)"
          menu.choice "Quit"
          menu.prompt = "Please enter one of the options above: "
        end

        case choice
        when /^Stash/
          sh "git stash -q"
        when /^Commit/
          message = ask "Please enter a commit message: "
          sh "git commit -aqm'#{message}'"
        else
          say "Please stash or commit your changes before continuing."
          exit(-1)
        end
      end
    end
  end
end
