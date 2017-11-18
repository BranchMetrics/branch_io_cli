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

    module Object
      class PBXNativeTarget
        def expanded_build_setting(setting_name, configuration)
          # second arg true means if there is an xcconfig, also consult that
          begin
            setting_value = resolved_build_setting(setting_name, true)[configuration]
          rescue Errno::ENOENT
            # If not found, look up without it
            setting_value = resolved_build_setting(setting_name, false)[configuration]
          end

          return if setting_value.nil?

          expand_build_settings setting_value, configuration
        end

        def expand_build_settings(string, configuration)
          search_position = 0
          # It's safest to make a copy of this string, though we probably get a
          # copy from PBXNativeTarget#resolve_build_setting anyway. Copying here
          # avoids a copy on every match.
          string = string.clone

          # HACK: When matching against an xcconfig, as here, sometimes the macro is just returned
          # without delimiters, e.g. TARGET_NAME or BUILT_PRODUCTS_DIR/Branch.framework. We allow
          # these two patterns for now.
          while (matches = %r{\$\(([^(){}]*)\)|\$\{([^(){}]*)\}|^([A-Z_]+)(/.*)?$}.match(string, search_position))
            original_macro = matches[1] || matches[2] || matches[3]
            delimiter_length = matches[3] ? 0 : 3 # $() or ${}
            delimiter_offset = matches[3] ? 0 : 2 # $( or ${
            search_position = string.index(original_macro) - delimiter_offset

            modifier_regexp = /^(.+):(.+)$/
            if (matches = modifier_regexp.match original_macro)
              macro_name = matches[1]
              modifier = matches[2]
            else
              macro_name = original_macro
            end

            case macro_name
            when "SRCROOT"
              expanded_macro = "."
            when "TARGET_NAME"
              # Clone in case of modifier processing
              expanded_macro = name.clone
            else
              expanded_macro = expanded_build_setting(macro_name, configuration)
            end

            search_position += original_macro.length + delimiter_length and next if expanded_macro.nil?

            if modifier == "rfc1034identifier"
              # From the Apple dev portal when creating a new app ID:
              # You cannot use special characters such as @, &, *, ', "
              # From trial and error with Xcode, it appears that only letters, digits and hyphens are allowed.
              # Everything else becomes a hyphen, including underscores.
              special_chars = /[^A-Za-z0-9-]/
              expanded_macro.gsub!(special_chars, '-')
            end

            string.gsub!(/\$\(#{original_macro}\)|\$\{#{original_macro}\}|^#{original_macro}/, expanded_macro)
            search_position += expanded_macro.length
          end
          string
        end
      end
    end
  end
end
