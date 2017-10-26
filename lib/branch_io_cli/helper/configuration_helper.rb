require "json"
require "net/http"
require "pathname"
require "xcodeproj"
require "zip"

module BranchIOCLI
  module Helper
    # rubocop: disable Metrics/ClassLength
    class ConfigurationHelper
      class << self
        APP_LINK_REGEXP = /\.app\.link$|\.test-app\.link$/

        attr_accessor :xcodeproj_path
        attr_accessor :xcodeproj
        attr_accessor :keys
        attr_accessor :all_domains
        attr_accessor :podfile_path
        attr_accessor :cartfile_path
        attr_accessor :target
        attr_accessor :uri_scheme

        def validate_setup_options(options)
          print_identification "setup"

          say "--force is ignored when --no_validate is used." if options.no_validate && options.force

          validate_xcodeproj_path options
          validate_target options
          validate_keys_from_setup_options options
          validate_all_domains options, !@target.extension_target_type?
          validate_uri_scheme options
          validate_buildfile_path options, "Podfile"
          validate_buildfile_path options, "Cartfile"

          print_setup_configuration

          validate_sdk_addition options
        end

        def validate_validation_options(options)
          print_identification "validate"

          validate_xcodeproj_path options
          validate_target options, false

          print_validation_configuration
        end

        def print_identification(command)
          say <<EOF

<%= color("branch_io #{command} v. #{VERSION}", BOLD) %>

EOF
        end

        def print_setup_configuration
          say <<EOF
<%= color('Configuration:', BOLD) %>

<%= color('Xcode project:', BOLD) %> #{@xcodeproj_path}
<%= color('Target:', BOLD) %> #{@target.name}
<%= color('Live key:', BOLD) %> #{@keys[:live] || '(none)'}
<%= color('Test key:', BOLD) %> #{@keys[:test] || '(none)'}
<%= color('Domains:', BOLD) %> #{@all_domains}
<%= color('URI scheme:', BOLD) %> #{@uri_scheme || '(none)'}
<%= color('Podfile:', BOLD) %> #{@podfile_path || '(none)'}
<%= color('Cartfile:', BOLD) %> #{@cartfile_path || '(none)'}

EOF
        end

        def print_validation_configuration
          say <<EOF
<%= color('Configuration:', BOLD) %>

<%= color('Xcode project:', BOLD) %> #{@xcodeproj_path}
<%= color('Target:', BOLD) %> #{@target.name}
<%= color('Domains:', BOLD) %> #{@all_domains || '(none)'}
EOF
        end

        def validate_keys_from_setup_options(options)
          live_key = options.live_key
          test_key = options.test_key
          @keys = {}
          @keys[:live] = live_key unless live_key.nil?
          @keys[:test] = test_key unless test_key.nil?

          while @keys.empty?
            say "A live key, a test key or both is required."
            live_key = ask "Please enter your live Branch key or use --live_key [enter for none]: "
            test_key = ask "Please enter your test Branch key or use --test_key [enter for none]: "

            @keys[:live] = live_key unless live_key == ""
            @keys[:test] = test_key unless test_key == ""
          end
        end

        def validate_all_domains(options, required = true)
          app_link_roots = app_link_roots_from_domains options.domains

          unless options.app_link_subdomain.nil? || app_link_roots.include?(options.app_link_subdomain)
            app_link_roots << options.app_link_subdomain
          end

          # app_link_roots now contains options.app_link_subdomain, if supplied, and the roots of any
          # .app.link or .test-app.link domains provided via options.domains.

          app_link_subdomains = app_link_subdomains_from_roots app_link_roots

          custom_domains = custom_domains_from_domains options.domains

          @all_domains = (app_link_subdomains + custom_domains).uniq

          while required && @all_domains.empty?
            domains = ask "Please enter domains as a comma-separated list: ", ->(str) { str.split "," }

            @all_domains = all_domains_from_domains domains
          end
        end

        def validate_uri_scheme(options)
          # No validation at the moment. Just strips off any trailing ://
          @uri_scheme = uri_scheme_without_suffix options.uri_scheme
        end

        # 1. Look for options.xcodeproj.
        # 2. If not specified, look for projects under . (excluding anything in Pods or Carthage folder).
        # 3. If none or more than one found, prompt the user.
        def validate_xcodeproj_path(options)
          if options.xcodeproj
            path = options.xcodeproj
          else
            all_xcodeproj_paths = Dir[File.expand_path(File.join(".", "**/*.xcodeproj"))]
            # find an xcodeproj (ignoring the Pods and Carthage folders)
            # TODO: Improve this filter
            xcodeproj_paths = all_xcodeproj_paths.select do |p|
              valid = true
              Pathname.new(p).each_filename do |f|
                valid = false && break if f == "Carthage" || f == "Pods"
              end
              valid
            end

            path = xcodeproj_paths.first if xcodeproj_paths.count == 1
          end

          loop do
            path = ask "Please enter the path to your Xcode project or use --xcodeproj: " if path.nil?
            # TODO: Allow the user to choose if xcodeproj_paths.count > 0
            begin
              @xcodeproj = Xcodeproj::Project.open path
              @xcodeproj_path = path
              return
            rescue StandardError => e
              say e.message
              path = nil
            end
          end
        end

        def validate_target(options, allow_extensions = true)
          non_test_targets = @xcodeproj.targets.reject(&:test_target_type?)
          raise "No non-test target found in project" if non_test_targets.empty?

          valid_targets = non_test_targets.reject { |t| !allow_extensions && t.extension_target_type? }

          begin
            target = BranchHelper.target_from_project @xcodeproj, options.target

            # If a test target was explicitly specified.
            raise "Cannot use test targets" if target.test_target_type?

            # If an extension target was explicitly specified for validation.
            raise "Extension targets not allowed for this command" if !allow_extensions && target.extension_target_type?

            @target = target
          rescue StandardError => e
            say e.message

            choice = choose do |menu|
              valid_targets.each { |t| menu.choice t.name }
              menu.prompt = "Which target do you wish to use? "
            end

            @target = @xcodeproj.targets.find { |t| t.name = choice }
          end
        end

        def app_link_roots_from_domains(domains)
          return [] if domains.nil?

          domains.select { |d| d =~ APP_LINK_REGEXP }
                 .map { |d| d.sub(APP_LINK_REGEXP, '').sub(/-alternate$/, '') }
                 .uniq
        end

        def custom_domains_from_domains(domains)
          return [] if domains.nil?
          domains.reject { |d| d =~ APP_LINK_REGEXP }.uniq
        end

        def app_link_subdomains(root)
          app_link_subdomain = root
          return [] if app_link_subdomain.nil?

          live_key = @keys[:live]
          test_key = @keys[:test]

          domains = []
          unless live_key.nil?
            domains += [
              "#{app_link_subdomain}.app.link",
              "#{app_link_subdomain}-alternate.app.link"
            ]
          end
          unless test_key.nil?
            domains += [
              "#{app_link_subdomain}.test-app.link",
              "#{app_link_subdomain}-alternate.test-app.link"
            ]
          end
          domains
        end

        def app_link_subdomains_from_roots(roots)
          roots.inject([]) { |domains, root| domains + app_link_subdomains(root) }
        end

        def all_domains_from_domains(domains)
          app_link_roots = app_link_roots_from_domains domains
          app_link_subdomains = app_link_subdomains_from_roots app_link_roots
          custom_domains = custom_domains_from_domains domains
          custom_domains + app_link_subdomains
        end

        # Removes any trailing :// from the argument and returns a copy
        def uri_scheme_without_suffix(scheme)
          return nil if scheme.nil?
          scheme.sub %r{://$}, ""
        end

        def validate_buildfile_path(options, filename)
          # Disable Podfile/Cartfile update if --no_add_sdk is present
          return if options.no_add_sdk

          buildfile_path = filename == "Podfile" ? options.podfile : options.cartfile

          # Was --podfile/--cartfile used?
          if buildfile_path
            # Yes: Validate. Prompt if not valid.
            loop do
              valid = buildfile_path =~ %r{/?#{filename}$}
              say "#{filename} path must end in /#{filename}." unless valid

              if valid
                valid = File.exist? buildfile_path
                say "#{buildfile_path} not found." unless valid
              end

              if valid
                if filename == "Podfile"
                  @podfile_path = buildfile_path
                else
                  @cartfile_path = buildfile_path
                end
                return
              end

              buildfile_path = ask "Please enter the path to your #{filename}: "
            end
          end

          # No: Check for Podfile/Cartfile next to @xcodeproj_path
          buildfile_path = File.expand_path "../#{filename}", @xcodeproj_path
          return unless File.exist? buildfile_path

          # Exists: Use it (valid if found)
          if filename == "Podfile"
            @podfile_path = buildfile_path
          else
            @cartfile_path = buildfile_path
          end
        end

        def validate_sdk_addition(options)
          return if options.no_add_sdk || @podfile_path || @cartfile_path

          # If no CocoaPods or Carthage, check to see if the framework is linked.
          target = BranchHelper.target_from_project @xcodeproj, options.target
          return if target.frameworks_build_phase.files.map(&:file_ref).map(&:path).any? { |p| p =~ %r{/Branch.framework$} }

          # --podfile, --cartfile not specified. No Podfile found. No Cartfile found. No Branch.framework in project.
          # Prompt the user:
          selected = choose do |menu|
            menu.header = "No Podfile or Cartfile specified or found. Here are your options"

            SDK_OPTIONS.each_key { |k| menu.choice k }

            menu.prompt = "What would you like to do?"
          end

          option = SDK_OPTIONS[selected]

          case option
          when :skip
            return
          else
            send "add_#{option}", options
          end
        end

        def add_cocoapods(options)
          @podfile_path = File.expand_path "../Podfile", @xcodeproj_path
          target = BranchHelper.target_from_project @xcodeproj, options.target

          install_command = "pod install"
          install_command += " --repo-update" unless options.no_pod_repo_update
          Dir.chdir(File.dirname(@podfile_path)) do
            system "pod init"
            BranchHelper.apply_patch(
              files: @podfile_path,
              regexp: /^(\s*)# Pods for #{target.name}$/,
              mode: :append,
              text: "\n\\1pod \"Branch\"",
              global: false
            )
            system install_command
          end

          BranchHelper.add_change @podfile_path
          BranchHelper.add_change "#{@podfile_path}.lock"

          # For now, add Pods folder to SCM.
          pods_folder_path = Pathname.new(File.expand_path("../Pods", podfile_path)).relative_path_from Pathname.pwd
          workspace_path = Pathname.new(File.expand_path(@xcodeproj_path.sub(/.xcodeproj$/, ".xcworkspace"))).relative_path_from Pathname.pwd
          podfile_pathname = Pathname.new(@podfile_path).relative_path_from Pathname.pwd
          BranchHelper.add_change pods_folder_path
          BranchHelper.add_change workspace_path
          `git add #{podfile_pathname} #{podfile_pathname}.lock #{pods_folder_path} #{workspace_path}` if options.commit
        end

        def add_carthage(options)
          # TODO: Collapse this and Command::update_cartfile

          # 1. Generate Cartfile
          @cartfile_path = File.expand_path "../Cartfile", @xcodeproj_path
          File.open(@cartfile_path, "w") do |file|
            file.write <<EOF
github "BranchMetrics/ios-branch-deep-linking"
EOF
          end

          # 2. carthage update
          Dir.chdir(File.dirname(@cartfile_path)) do
            system "carthage update --platform ios"
          end

          # 3. Add Cartfile and Cartfile.resolved to commit (in case :commit param specified)
          BranchHelper.add_change cartfile_path
          BranchHelper.add_change "#{cartfile_path}.resolved"

          # 4. Add to target dependencies
          frameworks_group = @xcodeproj.frameworks_group
          branch_framework = frameworks_group.new_file "Carthage/Build/iOS/Branch.framework"
          target = BranchHelper.target_from_project @xcodeproj, options.target
          target.frameworks_build_phase.add_file_reference branch_framework

          # 5. Create a copy-frameworks build phase
          carthage_build_phase = target.new_shell_script_build_phase "carthage copy-frameworks"
          carthage_build_phase.shell_script = "/usr/local/bin/carthage copy-frameworks"

          carthage_build_phase.input_paths << "$(SRCROOT)/Carthage/Build/iOS/Branch.framework"
          carthage_build_phase.output_paths << "$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/Branch.framework"

          @xcodeproj.save

          # For now, add Carthage folder to SCM

          # 6. Add the Carthage folder to the commit (in case :commit param specified)
          carthage_folder_path = Pathname.new(File.expand_path("../Carthage", cartfile_path)).relative_path_from(Pathname.pwd)
          cartfile_pathname = Pathname.new(@cartfile_path).relative_path_from Pathname.pwd
          BranchHelper.add_change carthage_folder_path
          `git add #{cartfile_pathname} #{cartfile_pathname}.resolved #{carthage_folder_path}` if options.commit
        end

        def add_direct(options)
          # TODO: Put these intermediates in a temp directory until Branch.framework is unzipped
          # (and validated?). For now dumped in the project folder and the destination path.
          project_folder = File.dirname @xcodeproj_path
          zip_path = File.join project_folder, "Branch.framework.zip"

          # Put the framework in the path for any existing Frameworks group in the project.
          frameworks_group = @xcodeproj.frameworks_group
          framework_path = File.join frameworks_group.real_path, "Branch.framework"

          File.unlink zip_path if File.exist? zip_path
          remove_directory framework_path

          say "Finding current framework release"

          # Find the latest release from GitHub.
          releases = JSON.parse fetch "https://api.github.com/repos/BranchMetrics/ios-branch-deep-linking/releases"
          current_release = releases.first
          # Get the download URL for the framework.
          framework_asset = current_release["assets"][0]
          framework_url = framework_asset["browser_download_url"]

          say "Downloading Branch.framework v. #{current_release['tag_name']} (#{framework_asset['size']} bytes zipped)"

          # Download the framework zip
          download framework_url, zip_path

          say "Unzipping Branch.framework"

          # Unzip
          Zip::File.open zip_path do |zip_file|
            # Start with just the framework and add dSYM, etc., later
            zip_file.glob "Carthage/Build/iOS/Branch.framework/**/*" do |entry|
              filename = entry.name.sub %r{^Carthage/Build/iOS}, frameworks_group.real_path.to_s
              ensure_directory File.dirname filename
              entry.extract filename
            end
          end

          # Remove intermediate zip file
          File.unlink zip_path

          # Now the current framework is in framework_path

          say "Adding to #{@xcodeproj_path}"

          # Add as a dependency in the Frameworks group
          framework = frameworks_group.new_file "Branch.framework" # relative to frameworks_group.real_path
          target = BranchHelper.target_from_project @xcodeproj, options.target
          target.frameworks_build_phase.add_file_reference framework, true

          # Make sure this is in the FRAMEWORK_SEARCH_PATHS if frameworks_group.path is nil,
          # which means it points to $(SRCROOT).
          if frameworks_group.path.nil?
            @xcodeproj.build_configurations.each do |config|
              setting = config.build_settings["FRAMEWORK_SEARCH_PATHS"] || []
              setting = [setting] if setting.kind_of? String
              next if setting.any? { |p| p == "$(SRCROOT)" || p == "$(SRCROOT)/**" }
              setting << "$(SRCROOT)"
              config.build_settings["FRAMEWORK_SEARCH_PATHS"] = setting
            end
          end

          # If frameworks_group.path is non-nil, we did not just add it. If it
          # already existed, it's likely it's already in FRAMEWORK_SEARCH_PATHS.
          # TODO: Verify and add if needed.

          @xcodeproj.save

          BranchHelper.add_change framework_path
          `git add #{framework_path}` if options.commit

          say "Done. ✅"
        end

        def fetch(url)
          response = Net::HTTP.get_response URI(url)

          case response
          when Net::HTTPSuccess
            response.body
          when Net::HTTPRedirection
            fetch response['location']
          else
            raise "Error fetching #{url}: #{response.code} #{response.message}"
          end
        end

        def download(url, dest)
          uri = URI(url)

          Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
            request = Net::HTTP::Get.new uri

            http.request request do |response|
              case response
              when Net::HTTPSuccess
                bytes_downloaded = 0
                dots_reported = 0
                # report a dot every 100 kB
                per_dot = 102_400

                File.open dest, 'w' do |io|
                  response.read_body do |chunk|
                    io.write chunk

                    # print progress
                    bytes_downloaded += chunk.length
                    while (bytes_downloaded - per_dot * dots_reported) >= per_dot
                      print "."
                      dots_reported += 1
                    end
                    STDOUT.flush
                  end
                end
                say "\n"
              when Net::HTTPRedirection
                download response['location'], dest
              else
                raise "Error downloading #{url}: #{response.code} #{response.message}"
              end
            end
          end
        end

        def ensure_directory(path)
          return if path == "/" || path == "."
          parent = File.dirname path
          ensure_directory parent
          return if Dir.exist? path
          Dir.mkdir path
        end

        def remove_directory(path)
          return unless File.exist? path

          Dir["#{path}/*"].each do |file|
            remove_directory(file) and next if File.directory?(file)
            File.unlink file
          end

          Dir.rmdir path
        end

        SDK_OPTIONS =
          {
            "Set this project up to use CocoaPods and add the Branch SDK." => :cocoapods,
            "Set this project up to use Carthage and add the Branch SDK." => :carthage,
            "Add Branch.framework directly to the project's dependencies." => :direct,
            "Skip adding the framework to the project." => :skip
          }
      end
    end
  end
  # rubocop enable: Metrics/ClassLength
end
