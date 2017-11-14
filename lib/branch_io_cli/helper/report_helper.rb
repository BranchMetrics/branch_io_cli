require "branch_io_cli/configuration/configuration"

module BranchIOCLI
  module Helper
    class ReportHelper
      class << self
        def report_imports
          report = "Branch imports:\n"
          config.branch_imports.each_key do |path|
            report += " #{config.relative_path path}:\n"
            report += "  #{config.branch_imports[path].join("\n  ")}"
            report += "\n"
          end
          report
        end

        def config
          Configuration::Configuration.current
        end

        def helper
          Helper::BranchHelper
        end

        def xcode_settings
          Configuration::XcodeSettings.settings
        end

        def base_xcodebuild_cmd
          cmd = "xcodebuild"
          if config.workspace_path
            cmd = "#{cmd} -workspace #{config.workspace_path}"
          else
            cmd = "#{cmd} -project #{config.xcodeproj_path}"
          end
          cmd
        end

        def branch_version
          version_from_podfile_lock ||
            version_from_cartfile_resolved ||
            version_from_branch_framework ||
            version_from_bnc_config_m
        end

        def requirement_from_podfile
          return nil unless config.podfile_path
          podfile = File.read config.podfile_path
          matches = /\n?\s*pod\s+("Branch"|'Branch').*?\n/m.match podfile
          matches ? matches[0].strip : nil
        end

        def requirement_from_cartfile
          return nil unless config.cartfile_path
          cartfile = File.read config.cartfile_path
          matches = %r{^git(hub\s+"|\s+"https://github.com/)BranchMetrics/(ios-branch-deep-linking|iOS-Deferred-Deep-Linking-SDK.*?).*?\n}m.match cartfile
          matches ? matches[0].strip : nil
        end

        def version_from_podfile_lock
          return nil unless config.podfile_path && File.exist?("#{config.podfile_path}.lock")
          podfile_lock = Pod::Lockfile.from_file Pathname.new "#{config.podfile_path}.lock"
          version = podfile_lock.version("Branch") || podfile_lock.version("Branch-SDK")

          version ? "#{version} [Podfile.lock]" : nil
        end

        def version_from_cartfile_resolved
          return nil unless config.cartfile_path && File.exist?("#{config.cartfile_path}.resolved")
          cartfile_resolved = File.read "#{config.cartfile_path}.resolved"

          # Matches:
          # git "https://github.com/BranchMetrics/ios-branch-deep-linking"
          # git "https://github.com/BranchMetrics/ios-branch-deep-linking/"
          # git "https://github.com/BranchMetrics/iOS-Deferred-Deep-Linking-SDK"
          # git "https://github.com/BranchMetrics/iOS-Deferred-Deep-Linking-SDK/"
          # github "BranchMetrics/ios-branch-deep-linking"
          # github "BranchMetrics/ios-branch-deep-linking/"
          # github "BranchMetrics/iOS-Deferred-Deep-Linking-SDK"
          # github "BranchMetrics/iOS-Deferred-Deep-Linking-SDK/"
          matches = %r{(ios-branch-deep-linking|iOS-Deferred-Deep-Linking-SDK)/?" "(\d+\.\d+\.\d+)"}m.match cartfile_resolved
          return nil unless matches
          version = matches[2]
          "#{version} [Cartfile.resolved]"
        end

        def version_from_branch_framework
          framework = config.target.frameworks_build_phase.files.find { |f| f.file_ref.path =~ /Branch.framework$/ }
          return nil unless framework

          if framework.file_ref.isa == "PBXFileReference"
            project_path = config.relative_path(config.xcodeproj_path)
            framework_path = framework.file_ref.real_path
          elsif framework.file_ref.isa == "PBXReferenceProxy" && xcode_settings
            project_path = config.relative_path framework.file_ref.remote_ref.proxied_object.project.path
            framework_path = File.expand_path framework.file_ref.path, xcode_settings[framework.file_ref.source_tree]
          end
          info_plist_path = File.join framework_path.to_s, "Info.plist"
          return nil unless File.exist? info_plist_path

          require "cfpropertylist"

          raw_info_plist = CFPropertyList::List.new file: info_plist_path
          info_plist = CFPropertyList.native_types raw_info_plist.value
          version = info_plist["CFBundleVersion"]
          return nil unless version
          "#{version} [Branch.framework/Info.plist:#{project_path}]"
        end

        def version_from_bnc_config_m(project = config.xcodeproj)
          # Look for BNCConfig.m in embedded source
          bnc_config_m_ref = project.files.find { |f| f.path =~ /BNCConfig\.m$/ }
          unless bnc_config_m_ref
            subprojects = project.files.select { |f| f.path =~ /\.xcodeproj$/ }
            subprojects.each do |subproject|
              p = Xcodeproj::Project.open subproject.real_path
              version = version_from_bnc_config_m p
              return version if version
            end
          end

          return nil unless bnc_config_m_ref
          bnc_config_m = File.read bnc_config_m_ref.real_path
          matches = /BNC_SDK_VERSION\s+=\s+@"(\d+\.\d+\.\d+)"/m.match bnc_config_m
          return nil unless matches
          version = matches[1]
          "#{version} [BNCConfig.m:#{config.relative_path project.path}]"
        end

        def report_configuration
          <<EOF
Configuration:

Xcode workspace: #{config.workspace_path || '(none)'}
Xcode project: #{config.xcodeproj_path || '(none)'}
Scheme: #{config.scheme || '(none)'}
Target: #{config.target || '(none)'}
Configuration: #{config.configuration || '(none)'}
SDK: #{config.sdk}
Podfile: #{config.relative_path(config.podfile_path) || '(none)'}
Cartfile: #{config.relative_path(config.cartfile_path) || '(none)'}
Pod repo update: #{config.pod_repo_update.inspect}
Clean: #{config.clean.inspect}
EOF
        end

        # rubocop: disable Metrics/PerceivedComplexity
        def report_header
          header = "cocoapods-core: #{Pod::CORE_VERSION}\n"

          header += `xcodebuild -version`
          header += "SDK: #{xcode_settings['SDK_NAME']}\n" if xcode_settings

          bundle_identifier = helper.expanded_build_setting config.target, "PRODUCT_BUNDLE_IDENTIFIER", config.configuration
          dev_team = helper.expanded_build_setting config.target, "DEVELOPMENT_TEAM", config.configuration
          infoplist_path = helper.expanded_build_setting config.target, "INFOPLIST_FILE", config.configuration
          entitlements_path = helper.expanded_build_setting config.target, "CODE_SIGN_ENTITLEMENTS", config.configuration

          header += "\nTarget #{config.target.name}:\n"
          header += " Bundle identifier: #{bundle_identifier || '(none)'}\n"
          header += " Development team: #{dev_team || '(none)'}\n"
          header += " Deployment target: #{config.target.deployment_target}\n"
          header += " Modules #{config.modules_enabled? ? '' : 'not '}enabled\n"
          header += " Swift #{config.swift_version}\n" if config.swift_version
          header += " Bridging header: #{config.relative_path(config.bridging_header_path)}\n" if config.bridging_header_path
          header += " Info.plist: #{config.relative_path(infoplist_path) || '(none)'}\n"
          header += " Entitlements file: #{config.relative_path(entitlements_path) || '(none)'}\n"

          if config.podfile_path
            begin
              cocoapods_version = `pod --version`.chomp
            rescue Errno::ENOENT
              header += "\n(pod command not found)\n"
            end

            if File.exist?("#{config.podfile_path}.lock")
              podfile_lock = Pod::Lockfile.from_file Pathname.new "#{config.podfile_path}.lock"
            end

            if cocoapods_version || podfile_lock
              header += "\nUsing CocoaPods v. "
              if cocoapods_version
                header += "#{cocoapods_version} (CLI) "
              end
              if podfile_lock
                header += "#{podfile_lock.cocoapods_version} (Podfile.lock)"
              end
              header += "\n"
            end

            target_definition = config.podfile.target_definitions[config.target.name]
            if target_definition
              branch_deps = target_definition.dependencies.select { |p| p.name =~ %r{^(Branch|Branch-SDK)(/.*)?$} }
              header += "Podfile target #{target_definition.name}:"
              header += "\n use_frameworks!" if target_definition.uses_frameworks?
              header += "\n platform: #{target_definition.platform}"
              header += "\n build configurations: #{target_definition.build_configurations}"
              header += "\n inheritance: #{target_definition.inheritance}"
              branch_deps.each do |dep|
                header += "\n pod '#{dep.name}', '#{dep.requirement}'"
                header += ", #{dep.external_source}" if dep.external_source
                header += "\n"
              end
            else
              header += "Target #{config.target.name.inspect} not found in Podfile.\n"
            end

            header += "\npod install #{config.pod_install_required? ? '' : 'not '}required.\n"
          end

          if config.cartfile_path
            begin
              carthage_version = `carthage version`.chomp
              header += "\nUsing Carthage v. #{carthage_version}\n"
            rescue Errno::ENOENT
              header += "\n(carthage command not found)\n"
            end
          end

          cartfile_requirement = requirement_from_cartfile
          header += "\nFrom Cartfile:\n#{cartfile_requirement}\n" if cartfile_requirement

          version = branch_version
          if version
            header += "\nBranch SDK v. #{version}\n"
          else
            header += "\nBranch SDK not found.\n"
          end

          header += "\n#{branch_report}"

          header
        end
        # rubocop: enable Metrics/PerceivedComplexity

        # String containing information relevant to Branch setup
        def branch_report
          infoplist_path = helper.expanded_build_setting config.target, "INFOPLIST_FILE", config.configuration
          infoplist_path = File.expand_path infoplist_path, File.dirname(config.xcodeproj_path)

          report = "Branch configuration:\n"

          begin
            info_plist = File.open(infoplist_path) { |f| Plist.parse_xml f }
            branch_key = info_plist["branch_key"]
            report += " Branch key(s) (Info.plist):\n"
            if branch_key.kind_of? Hash
              branch_key.each_key do |key|
                resolved_key = helper.expand_build_settings branch_key[key], config.target, config.configuration
                report += "  #{key.capitalize}: #{resolved_key}\n"
              end
            elsif branch_key
              resolved_key = helper.expand_build_settings branch_key, config.target, config.configuration
              report += "  #{resolved_key}\n"
            else
              report += "  (none found)\n"
            end

            branch_universal_link_domains = info_plist["branch_universal_link_domains"]
            if branch_universal_link_domains
              if branch_universal_link_domains.kind_of? Array
                report += " branch_universal_link_domains (Info.plist):\n"
                branch_universal_link_domains.each do |domain|
                  report += "  #{domain}\n"
                end
              else
                report += " branch_universal_link_domains (Info.plist): #{branch_universal_link_domains}\n"
              end
            end
          rescue StandardError => e
            report += " (Failed to open Info.plist: #{e.message})\n"
          end

          unless config.target.extension_target_type?
            begin
              domains = helper.domains_from_project config.configuration
              report += " Universal Link domains (entitlements):\n"
              domains.each do |domain|
                report += "  #{domain}\n"
              end
            rescue StandardError => e
              report += " (Failed to get Universal Link domains from entitlements file: #{e.message})\n"
            end
          end

          report += report_imports

          report
        end
      end
    end
  end
end
