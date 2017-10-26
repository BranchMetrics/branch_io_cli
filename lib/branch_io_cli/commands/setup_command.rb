module BranchIOCLI
  module Commands
    class SetupCommand < Command
      def run(options)
        config_helper.validate_setup_options options

        @keys = config_helper.keys
        @domains = config_helper.all_domains
        @xcodeproj_path = config_helper.xcodeproj_path
        xcodeproj = config_helper.xcodeproj

        update_podfile(options) || update_cartfile(options, xcodeproj)

        target_name = options.target # may be nil
        is_app_target = !Helper::ConfigurationHelper.target.extension_target_type?

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

        patch_source xcodeproj if options.patch_source

        return unless options.commit

        changes = helper.changes.to_a.map { |c| Pathname.new(File.expand_path(c)).relative_path_from(Pathname.pwd).to_s }

        `git commit #{changes.join(" ")} -m '[branch_io_cli] Branch SDK integration'`
      end
    end
  end
end
