require "rubygems"
require "commander"

module BranchIOCLI
  class CLI
    include Commander::Methods

    def run
      program :name, "Branch.io command-line interface"
      program :version, VERSION
      program :description, "More to come"

      command :setup do |c|
        c.syntax = "branch_io setup"
        c.description = "Set up an iOS project to use the Branch SDK."

        # Required Branch params
        c.option "--live_key key_live_xxxx", String, "Branch live key"
        c.option "--test_key key_test_yyyy", String, "Branch test key"
        c.option "--app_link_subdomain myapp", String, "Branch app.link subdomain, e.g. myapp.app.link"
        c.option "--domains example.com,www.example.com", Array, "Comma-separated list of custom domain(s) or non-Branch domain(s)"

        c.option "--xcodeproj MyProject.xcodeproj", String, "Path to an Xcode project to update"
        c.option "--target MyAppTarget", String, "Name of a target to modify in the Xcode project"
        c.option "--podfile /path/to/Podfile", String, "Path to the Podfile for the project"
        c.option "--cartfile /path/to/Cartfile", String, "Path to the Cartfile for the project"
        c.option "--frameworks AdSupport,CoreSpotlight,SafariServices", Array, "Comma-separated list of system frameworks to add to the project"

        c.option "--no_pod_repo_update", TrueClass, "Skip update of the local podspec repo before installing"
        c.option "--no_validate", TrueClass, "Skip validation of Universal Link configuration"
        c.option "--force", TrueClass, "Update project even if Universal Link validation fails"
        c.option "--no_add_sdk", TrueClass, "Don't add the Branch framework to the project"
        c.option "--no_patch_source", TrueClass, "Don't add Branch SDK calls to the AppDelegate"
        c.option "--commit", TrueClass, "Commit the results to Git"

        c.action do |args, options|
          Command.setup options
        end
      end

      command :validate do |c|
        c.syntax = "branch_io validate"
        c.description = "Validate the Universal Link configuration for an Xcode project"

        c.option "--xcodeproj MyProject.xcodeproj", String, "Path to an Xcode project to update"
        c.option "--target MyAppTarget", String, "Name of a target to modify in the Xcode project"
        c.option "--domains example.com,www.example.com", Array, "Comma-separated list of domains to validate (Branch domains or non-Branch domains)"

        c.action do |args, options|
          Command.validate options
        end
      end

      run!
    end
  end
end
