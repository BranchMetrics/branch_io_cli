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
        # List of build settings with values not present in the configuration.
        #
        # @return [Hash] A hash of fixed build settings
        def fixed_build_settings
          {
            "SRCROOT" => ".",
            "TARGET_NAME" => name
          }
        end

        # Layer on top of #resolved_build_setting to recursively expand all
        # build settings as they would be resolved in Xcode. Calls
        # #expand_build_settings on the value returned by
        # #resolved_build_setting, with the exception of anything defined
        # in #fixed_build_settings. Those settings are returned directly.
        #
        # @param setting_name [String] Name of any valid build setting for this target
        # @param configuration [String] Name of any valid configuration for this target
        # @return [String, nil] The build setting value with all embedded settings expanded or nil if not found
        def expanded_build_setting(setting_name, configuration)
          fixed_setting = fixed_build_settings[setting_name]
          return fixed_setting.clone if fixed_setting

          # second arg true means if there is an xcconfig, also consult that
          begin
            setting_value = resolved_build_setting(setting_name, true)[configuration]
          rescue Errno::ENOENT
            # If not found, look up without it. Unresolved settings will be passed
            # unmodified, e.g. $(UNRESOLVED_SETTING_NAME).
            setting_value = resolved_build_setting(setting_name, false)[configuration]
          end

          # TODO: What is the correct resolution order here? Which overrides which in
          # Xcode? Or does it matter here?
          if setting_value.nil? && defined?(BranchIOCLI::Configuration::XcodeSettings)
            setting_value = BranchIOCLI::Configuration::XcodeSettings[configuration][setting_name]
          end

          return nil if setting_value.nil?

          expand_build_settings setting_value, configuration
        end

        # Recursively resolves build settings in any string for the given
        # configuration. This includes xcconfig expansion and handling for the
        # :rfc1034identifier. Unresolved settings are passed unchanged, e.g.
        # $(UNRESOLVED_SETTING_NAME).
        #
        # @param string [String] Any string that may include build settings to be resolved
        # @param configuration [String] Name of any valid configuration for this target
        # @return [String] A copy of the original string with all embedded build settings expanded
        def expand_build_settings(string, configuration)
          search_position = 0
          string = string.clone

          while (matches = /\$\(([^(){}]*)\)|\$\{([^(){}]*)\}/.match(string, search_position))
            original_macro = matches[1] || matches[2]
            delimiter_length = 3 # $() or ${}
            delimiter_offset = 2 # $( or ${
            search_position = string.index(original_macro) - delimiter_offset

            if (m = /^(.+):(.+)$/.match original_macro)
              macro_name = m[1]
              modifier = m[2]
            else
              macro_name = original_macro
            end

            expanded_macro = expanded_build_setting macro_name, configuration

            search_position += original_macro.length + delimiter_length and next if expanded_macro.nil?

            # From the Apple dev portal when creating a new app ID:
            # You cannot use special characters such as @, &, *, ', "
            # From trial and error with Xcode, it appears that only letters, digits and hyphens are allowed.
            # Everything else becomes a hyphen, including underscores.
            expanded_macro.gsub!(/[^A-Za-z0-9-]/, '-') if modifier == "rfc1034identifier"

            string.gsub!(/\$\(#{original_macro}\)|\$\{#{original_macro}\}/, expanded_macro)
            search_position += expanded_macro.length
          end

          # HACK: When matching against an xcconfig, as here, sometimes the macro is just returned
          # without delimiters as the entire string or as a path component, e.g. TARGET_NAME or
          # PROJECT_DIR/PROJECT_NAME/BridgingHeader.h.
          string = string.split("/").map do |component|
            next component unless component =~ /^[A-Z0-9_]+$/
            expanded_build_setting(component, configuration) || component
          end.join("/")

          string
        end
      end
    end
  end
end
