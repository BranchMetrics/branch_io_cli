require "branch_io_cli/helper/methods"

module BranchIOCLI
  module Command
    class SetupCommand < Command
      class << self
        def available_options
          [
            Configuration::Option.new(
              name: :live_key,
              description: "Branch live key",
              example: "key_live_xxxx",
              type: String,
              aliases: "-L"
            ),
            Configuration::Option.new(
              name: :test_key,
              description: "Branch test key",
              example: "key_test_yyyy",
              type: String,
              aliases: "-T"
            ),
            Configuration::Option.new(
              name: :domains,
              description: "Comma-separated list of custom domain(s) or non-Branch domain(s)",
              example: "example.com,www.example.com",
              type: Array,
              aliases: "-D"
            ),
            Configuration::Option.new(
              name: :app_link_subdomain,
              description: "Branch app.link subdomain, e.g. myapp for myapp.app.link",
              example: "myapp",
              type: String
            ),
            Configuration::Option.new(
              name: :uri_scheme,
              description: "Custom URI scheme used in the Branch Dashboard for this app",
              example: "myurischeme[://]",
              type: String,
              aliases: "-U"
            ),
            Configuration::Option.new(
              name: :setting,
              description: "Use a custom build setting for the Branch key (default: Use Info.plist)",
              example: "BRANCH_KEY_SETTING",
              type: String,
              argument_optional: true,
              aliases: "-s"
            ),
            Configuration::Option.new(
              name: :test_configurations,
              description: "List of configurations that use the test key with a custom build setting (default: Debug configurations)",
              example: "config1,config2",
              type: Array,
              negatable: true
            ),
            Configuration::Option.new(
              name: :xcodeproj,
              description: "Path to an Xcode project to update",
              example: "MyProject.xcodeproj",
              type: String
            ),
            Configuration::Option.new(
              name: :target,
              description: "Name of a target to modify in the Xcode project",
              example: "MyAppTarget",
              type: String
            ),
            Configuration::Option.new(
              name: :podfile,
              description: "Path to the Podfile for the project",
              example: "/path/to/Podfile",
              type: String
            ),
            Configuration::Option.new(
              name: :cartfile,
              description: "Path to the Cartfile for the project",
              example: "/path/to/Cartfile",
              type: String
            ),
            Configuration::Option.new(
              name: :carthage_command,
              description: "Command to run when installing from Carthage",
              example: "<command>",
              type: String,
              default_value: "update --platform ios"
            ),
            Configuration::Option.new(
              name: :frameworks,
              description: "Comma-separated list of system frameworks to add to the project",
              example: "AdSupport,CoreSpotlight,SafariServices",
              type: Array
            ),
            Configuration::Option.new(
              name: :pod_repo_update,
              description: "Update the local podspec repo before installing",
              default_value: true
            ),
            Configuration::Option.new(
              name: :validate,
              description: "Validate Universal Link configuration",
              default_value: true
            ),
            Configuration::Option.new(
              name: :force,
              description: "Update project even if Universal Link validation fails",
              default_value: false
            ),
            Configuration::Option.new(
              name: :add_sdk,
              description: "Add the Branch framework to the project",
              default_value: true
            ),
            Configuration::Option.new(
              name: :patch_source,
              description: "Add Branch SDK calls to the AppDelegate",
              default_value: true
            ),
            Configuration::Option.new(
              name: :commit,
              description: "Commit the results to Git",
              default_value: false
            )
          ]
        end
      end

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

        if is_app_target && options.validate &&
           !helper.validate_team_and_bundle_ids_from_aasa_files(@domains)
          say "Universal Link configuration failed validation."
          helper.errors.each { |error| say " #{error}" }
          return unless options.force
        elsif is_app_target && options.validate
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

        new_path = helper.add_universal_links_to_project @domains, false if is_app_target
        sh ["git", "add", new_path] if options.commit && new_path

        config_helper.target.add_system_frameworks options.frameworks unless options.frameworks.nil? || options.frameworks.empty?

        xcodeproj.save

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

        patch_helper.patch_source xcodeproj if options.patch_source

        return unless options.commit

        changes = helper.changes.to_a.map { |c| Pathname.new(File.expand_path(c)).relative_path_from(Pathname.pwd).to_s }

        commit_message = options.commit if options.commit.kind_of?(String)
        commit_message ||= "[branch_io_cli] Branch SDK integration #{config.relative_path(config.xcodeproj_path)} (#{config.target.name})"

        sh ["git", "commit", "-qm", commit_message, *changes]
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
