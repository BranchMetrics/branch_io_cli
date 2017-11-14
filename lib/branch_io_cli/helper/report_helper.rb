require "plist"
require "shellwords"
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
            cmd = "#{cmd} -workspace #{Shellwords.escape config.workspace_path}"
          else
            cmd = "#{cmd} -project #{Shellwords.escape config.xcodeproj_path}"
          end
          cmd
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

          cartfile_requirement = config.requirement_from_cartfile
          header += "\nFrom Cartfile:\n#{cartfile_requirement}\n" if cartfile_requirement

          version = config.branch_version
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
          report = "Branch configuration:\n"

          config.configurations_from_scheme.each do |configuration|
            report += " #{configuration}:\n"
            infoplist_path = helper.expanded_build_setting config.target, "INFOPLIST_FILE", configuration
            infoplist_path = File.expand_path infoplist_path, File.dirname(config.xcodeproj_path)

            begin
              info_plist = File.open(infoplist_path) { |f| Plist.parse_xml f }
              branch_key = info_plist["branch_key"]
              if config.branch_key_setting_from_info_plist(configuration)
                annotation = " [Info.plist:$(#{config.branch_key_setting_from_info_plist})]"
              else
                annotation = " (Info.plist)"
              end

              report += "  Branch key(s) #{annotation}:\n"
              if branch_key.kind_of? Hash
                branch_key.each_key do |key|
                  resolved_key = helper.expand_build_settings branch_key[key], config.target, configuration
                  report += "   #{key.capitalize}: #{resolved_key}\n"
                end
              elsif branch_key
                resolved_key = helper.expand_build_settings branch_key, config.target, configuration
                report += "   #{resolved_key}\n"
              else
                report += "   (none found)\n"
              end

              branch_universal_link_domains = info_plist["branch_universal_link_domains"]
              if branch_universal_link_domains
                if branch_universal_link_domains.kind_of? Array
                  report += "  branch_universal_link_domains (Info.plist):\n"
                  branch_universal_link_domains.each do |domain|
                    report += "   #{domain}\n"
                  end
                else
                  report += "  branch_universal_link_domains (Info.plist): #{branch_universal_link_domains}\n"
                end
              end
            rescue StandardError => e
              report += "  (Failed to open Info.plist: #{e.message})\n"
            end
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

        def pod_install_if_required(report)
          return unless config.pod_install_required?
          # Only if a Podfile is detected/supplied at the command line.
          say "pod install required in order to build."
          install = ask %{Run "pod install" now (Y/n)? }
          if install.downcase =~ /^n/
            say %{Please run "pod install" or "pod update" first in order to continue.}
            exit(-1)
          end

          helper.verify_cocoapods

          install_command = "pod install"

          if config.pod_repo_update
            install_command += " --repo-update"
          else
            say <<-EOF
You have disabled "pod repo update". This can cause "pod install" to fail in
some cases. If that happens, please rerun without --no-pod-repo-update or run
"pod install --repo-update" manually.
        EOF
          end

          say "Running #{install_command.inspect}"
          if report.log_command(install_command).success?
            say "Done ✅"
          else
            say "pod install failed. See report for details."
            exit(-1)
          end
        end
      end
    end
  end
end
