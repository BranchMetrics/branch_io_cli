require "json"
require "net/http"
require "pathname"
require "xcodeproj"
require "zip"

module BranchIOCLI
  module Helper
    class ConfigurationHelper
      class << self
        attr_accessor :xcodeproj_path
        attr_accessor :xcodeproj
        attr_accessor :keys
        attr_accessor :all_domains
        attr_accessor :podfile_path
        attr_accessor :cartfile_path

        def validate_setup_options(options)
          say "--force is ignored when --no_validate is used." if options.no_validate && options.force

          validate_xcodeproj_path options
          validate_keys_from_setup_options options
          validate_all_domains options
          validate_buildfile_path options, "Podfile"
          validate_buildfile_path options, "Cartfile"
          validate_sdk_addition options
        end

        def validate_validation_options(options)
          validate_xcodeproj_path options
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

        def validate_all_domains(options)
          app_link_subdomains = app_link_subdomains options
          custom_domains = options.domains || []
          @all_domains = (app_link_subdomains + custom_domains).uniq

          while @all_domains.empty?
            @all_domains = ask "Please enter domains as a comma-separated list: ", ->(str) { str.split "," }
          end
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

        def app_link_subdomains(options)
          app_link_subdomain = options.app_link_subdomain
          live_key = options.live_key
          test_key = options.test_key
          return [] if live_key.nil? and test_key.nil?
          return [] if app_link_subdomain.nil?

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
          current_pathname = Pathname.new File.expand_path "."
          pods_folder_path = Pathname.new(File.expand_path("../Pods", podfile_path)).relative_path_from current_pathname
          workspace_path = Pathname.new(File.expand_path(@xcodeproj_path.sub(/.xcodeproj$/, ".xcworkspace"))).relative_path_from current_pathname
          podfile_pathname = Pathname.new(@podfile_path).relative_path_from current_pathname
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

          # 4. Add to target depependencies
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
          current_pathname = Pathname.new File.expand_path "."
          carthage_folder_path = Pathname.new(File.expand_path("../Carthage", cartfile_path)).relative_path_from(current_pathname)
          cartfile_pathname = Pathname.new(@cartfile_path).relative_path_from current_pathname
          BranchHelper.add_change carthage_folder_path
          `git add #{cartfile_pathname} #{cartfile_pathname}.resolved #{carthage_folder_path}` if options.commit
        end

        def add_direct(options)
          # TODO: Put these intermediates in a temp directory until Branch.framework is unzipped
          # (and validated?). For now dumped in the current directory.
          File.unlink "Branch.framework.zip" if File.exist? "Branch.framework.zip"
          remove_directory "Branch.framework"

          say "Finding current framework release..."

          # Find the latest release from GitHub.
          releases = JSON.parse fetch "https://api.github.com/repos/BranchMetrics/ios-branch-deep-linking/releases"
          current_release = releases.first
          # Get the download URL for the framework.
          framework_asset = current_release["assets"][0]
          framework_url = framework_asset["browser_download_url"]

          say "Downloading Branch.framework v. #{current_release['tag_name']} (#{framework_asset['size']} bytes zipped)..."

          # Download the framework zip
          File.open("Branch.framework.zip", "w") do |file|
            file.write fetch framework_url
          end

          say "Unzipping Branch.framework..."

          # Unzip
          Zip::File.open "Branch.framework.zip" do |zip_file|
            # Start with just the framework and add dSYM, etc., later
            zip_file.glob "Carthage/Build/iOS/Branch.framework/**/*" do |entry|
              filename = entry.name.sub %r{^Carthage/Build/iOS/}, ""
              ensure_directory File.dirname filename
              entry.extract filename
            end
          end

          # Remove intermediate zip file
          File.unlink "Branch.framework.zip"

          # Now the current framework is in ./Branch.framework

          say "Adding to #{@xcodeproj_path}..."

          # Add as a dependency in the Frameworks group
          frameworks_group = @xcodeproj.frameworks_group
          framework = frameworks_group.new_file "Branch.framework"
          target = BranchHelper.target_from_project @xcodeproj, options.target
          target.frameworks_build_phase.add_file_reference framework, true
          @xcodeproj.save

          BranchHelper.add_change File.expand_path "Branch.framework"
          `git add Branch.framework` if options.commit

          say "Done. ✅"
        end

        def fetch(url)
          response = Net::HTTP.get_response URI(url)

          case response
          when Net::HTTPRedirection
            fetch response['location']
          else
            response.body
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
end
