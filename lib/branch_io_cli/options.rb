require "optparse"

module BranchIOCLI
  class Options
    class << self
      def parse(args)
        options = Options.new
        option_parser = OptionParser.new do |opts|
          opts.banner = "Usage: branch_io [options]"

          opts.on("-xXCODEPROJ", "--xcodeproj=XCODEPROJ", "Path to an Xcode project to update") do |path|
            options.xcodeproj = path
          end

          opts.on("-lLIVE_KEY", "--live_key=LIVE_KEY", "Branch live key") do |key|
            options.live_key = key
          end

          opts.on("-tTEST_KEY", "--test_key=TEST_KEY", "Branch test key") do |key|
            options.test_key = key
          end

          opts.on("-TTARGET", "--target=TARGET", "Target to modify in the Xcode project") do |target|
            options.target = target
          end

          opts.on("-aAPP_LINK_SUBDOMAIN", "--app_link_subdomain=APP_LINK_SUBDOMAIN", "An app.link subdomain for Branch links") do |subdomain|
            options.app_link_subdomain = subdomain
          end

          opts.on("-dDOMAINS", "--domains=DOMAINS", Array, "Comma-separated list of custom or non-Branch domains to use") do |domains|
            options.domains = domains
          end

          opts.on("-FFRAMEWORKS", "--frameworks=FRAMEWORKS", Array, "Comma-separated list of system frameworks to add to the Xcode target") do |frameworks|
            options.frameworks = frameworks
          end

          opts.on("-s", "--no_add_sdk", "Don't add the Branch framework to the Xcode project") do
            options.add_sdk = false
          end

          opts.on("-P", "--no_patch_source", "Don't add source code patches to the Xcode project") do
            options.patch_source = false
          end

          opts.on("-p", "--podfile=PODFILE", "Path to the project's Podfile") do |path|
            options.podfile = path
          end

          opts.on("-C", "--cartfile=CARTFILE", "Path to the project's Cartfile") do |path|
            options.cartfile = path
          end

          opts.on("-V", "--no_validate", "Don't validate the AASA files for the project's Universal Link domains") do
            options.validate = false
          end

          opts.on("-f", "--force", "Set up project even if Universal Link validation fails") do
            options.force = true
          end

          opts.on("-c", "--commit", "Commit the results to Git") do
            options.commit = true
          end

          opts.on("-u", "--no_pod_repo_update", "Don't update the local podspec repo before adding the Branch pod") do
            options.pod_repo_update = false
          end

          opts.on("-h", "--help", "Display help") do
            puts opts
            exit
          end
        end

        option_parser.parse! args
        options
      end
    end

    attr_accessor :xcodeproj
    attr_accessor :live_key
    attr_accessor :test_key
    attr_accessor :target
    attr_accessor :app_link_subdomain
    attr_accessor :domains
    attr_accessor :frameworks
    attr_accessor :add_sdk
    attr_accessor :podfile
    attr_accessor :cartfile
    attr_accessor :patch_source
    attr_accessor :validate
    attr_accessor :force
    attr_accessor :commit
    attr_accessor :pod_repo_update

    def initialize
      # Set default values
      @validate = true
      @force = false
      @commit = false
      @frameworks = %w{AdSupport CoreSpotlight SafariServices}
      @add_sdk = true
      @patch_source = true
      @pod_repo_update = true
    end

    def to_s
      <<-EOF
Options:
  xcodeproj: #{xcodeproj.inspect}
  live_key: #{live_key.inspect}
  test_key: #{test_key.inspect}
  target: #{target.inspect}
  app_link_subdomain: #{app_link_subdomain.inspect}
  domains: #{domains.inspect}
  frameworks: #{frameworks.inspect}
  add_sdk: #{add_sdk.inspect}
  patch_source: #{patch_source.inspect}
  podfile: #{podfile.inspect}
  cartfile: #{cartfile.inspect}
  validate: #{validate.inspect}
  force: #{force.inspect}
  commit: #{commit.inspect}
  pod_repo_update: #{pod_repo_update.inspect}
      EOF
    end

    def keys
      return { live: live_key, test: test_key } if live_key && test_key
      return { live: live_key } if live_key
      return { test: test_key } if test_key
      return {}
    end

    def all_domains
      # TODO: Merge app_link_subdomain and domains params
    end

    def validate!
      valid = true
      valid &&= !keys.empty?

      raise "Invalid parameters" unless valid
    end
  end
end
