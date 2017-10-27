module BranchIOCLI
  module Commands
    class SetupCommand < Command
      def initialize(options)
        super
        config_helper.validate_setup_options options
        @keys = config_helper.keys
        @domains = config_helper.all_domains
      end

      # rubocop: disable Metrics/PerceivedComplexity
      def run!
        xcodeproj = config_helper.xcodeproj

        case config_helper.sdk_integration_mode
        when :cocoapods
          if File.exist? config_helper.podfile_path
            helper.update_podfile options
          else
            helper.add_cocoapods options
          end
        when :carthage
          if File.exist? config_helper.cartfile_path
            helper.update_cartfile options, xcodeproj
          else
            helper.add_carthage options
          end
        when :direct
          helper.add_direct options
        end

        target_name = options.target # may be nil
        is_app_target = !config_helper.target.extension_target_type?

        if is_app_target && options.validate &&
           !helper.validate_team_and_bundle_ids_from_aasa_files(xcodeproj, target_name, @domains)
          say "Universal Link configuration failed validation."
          helper.errors.each { |error| say " #{error}" }
          return unless options.force
        elsif is_app_target && options.validate
          say "Universal Link configuration passed validation. ✅"
        end

        # the following calls can all raise IOError
        helper.add_keys_to_info_plist xcodeproj, target_name, @keys
        helper.add_branch_universal_link_domains_to_info_plist xcodeproj, target_name, @domains if is_app_target
        helper.ensure_uri_scheme_in_info_plist if is_app_target # does nothing if already present

        new_path = helper.add_universal_links_to_project xcodeproj, target_name, @domains, false if is_app_target
        `git add #{new_path}` if options.commit && new_path

        helper.add_system_frameworks xcodeproj, target_name, options.frameworks unless options.frameworks.nil? || options.frameworks.empty?

        xcodeproj.save

        helper.patch_source xcodeproj if options.patch_source

        return unless options.commit

        changes = helper.changes.to_a.map { |c| Pathname.new(File.expand_path(c)).relative_path_from(Pathname.pwd).to_s }

        `git commit #{changes.join(" ")} -m '[branch_io_cli] Branch SDK integration'`
      end
      # rubocop: enable Metrics/PerceivedComplexity
    end
  end
end
