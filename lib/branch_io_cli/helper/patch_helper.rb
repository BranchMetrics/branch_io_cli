require "pattern_patch"

module BranchIOCLI
  module Helper
    class PatchHelper
      class << self
        def patch_app_delegate_swift(project)
          app_delegate_swift = project.files.find { |f| f.path =~ /AppDelegate.swift$/ }
          return false if app_delegate_swift.nil?

          app_delegate_swift_path = app_delegate_swift.real_path.to_s

          app_delegate = File.read app_delegate_swift_path
          return false if app_delegate =~ /import\s+Branch/

          say "Patching #{app_delegate_swift_path}"

          PatternPatch::Patch.new(
            regexp: /^\s*import .*$/,
            text: "\nimport Branch",
            mode: :prepend
          ).apply app_delegate_swift_path

          patch_did_finish_launching_method_swift app_delegate_swift_path
          patch_continue_user_activity_method_swift app_delegate_swift_path
          patch_open_url_method_swift app_delegate_swift_path

          add_change app_delegate_swift_path
          true
        end

        def patch_app_delegate_objc(project)
          app_delegate_objc = project.files.find { |f| f.path =~ /AppDelegate.m$/ }
          return false if app_delegate_objc.nil?

          app_delegate_objc_path = app_delegate_objc.real_path.to_s

          app_delegate = File.read app_delegate_objc_path
          return false if app_delegate =~ %r{^\s+#import\s+<Branch/Branch.h>|^\s+@import\s+Branch;}

          say "Patching #{app_delegate_objc_path}"

          PatternPatch::Patch.new(
            regexp: /^\s+@import|^\s+#import.*$/,
            text: "\n#import <Branch/Branch.h>",
            mode: :prepend
          ).apply app_delegate_objc_path

          patch_did_finish_launching_method_objc app_delegate_objc_path
          patch_continue_user_activity_method_objc app_delegate_objc_path
          patch_open_url_method_objc app_delegate_objc_path

          add_change app_delegate_objc_path
          true
        end

        def patch_did_finish_launching_method_swift(app_delegate_swift_path)
          app_delegate_swift = File.read app_delegate_swift_path

          if app_delegate_swift =~ /didFinishLaunching[^\n]+?\{/m
            # method already present
            init_session_text = config.keys.count <= 1 || has_multiple_info_plists? ? "" : <<EOF
      #if DEBUG
          Branch.setUseTestBranchKey(true)
      #endif

EOF

            init_session_text += <<-EOF
        Branch.getInstance().initSession(launchOptions: launchOptions) {
            universalObject, linkProperties, error in

            // TODO: Route Branch links
        }
            EOF

            PatternPatch::Patch.new(
              regexp: /didFinishLaunchingWithOptions.*?\{[^\n]*\n/m,
              text: init_session_text,
              mode: :append
            ).apply app_delegate_swift_path
          else
            # method not present. add entire method

            method_text = <<EOF

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
EOF

            if config.keys.count > 1 && !has_multiple_info_plists?
              method_text += <<EOF
        #if DEBUG
            Branch.setUseTestBranchKey(true)
        #endif

EOF
            end

            method_text += <<-EOF
        Branch.getInstance().initSession(launchOptions: launchOptions) {
            universalObject, linkProperties, error in

            // TODO: Route Branch links
        }
        return true
    }
            EOF

            PatternPatch::Patch.new(
              regexp: /var\s+window\s?:\s?UIWindow\?.*?\n/m,
              text: method_text,
              mode: :append
            ).apply app_delegate_swift_path
          end
        end

        def patch_did_finish_launching_method_objc(app_delegate_objc_path)
          app_delegate_objc = File.read app_delegate_objc_path

          if app_delegate_objc =~ /didFinishLaunchingWithOptions/m
            # method exists. patch it.
            init_session_text = config.keys.count <= 1 || has_multiple_info_plists? ? "" : <<EOF
  #ifdef DEBUG
      [Branch setUseTestBranchKey:YES];
  #endif // DEBUG

EOF

            init_session_text += <<-EOF
    [[Branch getInstance] initSessionWithLaunchOptions:launchOptions
        andRegisterDeepLinkHandlerUsingBranchUniversalObject:^(BranchUniversalObject *universalObject, BranchLinkProperties *linkProperties, NSError *error){
        // TODO: Route Branch links
    }];
            EOF

            PatternPatch::Patch.new(
              regexp: /didFinishLaunchingWithOptions.*?\{[^\n]*\n/m,
              text: init_session_text,
              mode: :append
            ).apply app_delegate_objc_path
          else
            # method does not exist. add it.
            method_text = <<EOF

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
EOF

            if config.keys.count > 1 && !has_multiple_info_plists?
              method_text += <<EOF
  #ifdef DEBUG
      [Branch setUseTestBranchKey:YES];
  #endif // DEBUG

EOF
            end

            method_text += <<-EOF
    [[Branch getInstance] initSessionWithLaunchOptions:launchOptions
        andRegisterDeepLinkHandlerUsingBranchUniversalObject:^(BranchUniversalObject *universalObject, BranchLinkProperties *linkProperties, NSError *error){
        // TODO: Route Branch links
    }];
    return YES;
}
            EOF

            PatternPatch::Patch.new(
              regexp: /^@implementation.*?\n/m,
              text: method_text,
              mode: :append
            ).apply app_delegate_objc_path
          end
        end

        def patch_open_url_method_swift(app_delegate_swift_path)
          app_delegate_swift = File.read app_delegate_swift_path
          if app_delegate_swift =~ /application.*open\s+url.*options/
            # Has application:openURL:options:
            open_url_text = <<-EOF
        // TODO: Adjust your method as you see fit.
        if Branch.getInstance().application(app, open: url, options: options) {
            return true
        }

            EOF

            PatternPatch::Patch.new(
              regexp: /application.*open\s+url.*options:.*?\{.*?\n/m,
              text: open_url_text,
              mode: :append
            ).apply app_delegate_swift_path
          elsif app_delegate_swift =~ /application.*open\s+url.*sourceApplication/
            # Has application:openURL:sourceApplication:annotation:
            # TODO: This method is deprecated.
            open_url_text = <<-EOF
              // TODO: Adjust your method as you see fit.
              if Branch.getInstance().application(application, open: url, sourceApplication: sourceApplication, annotation: annotation) {
                  return true
              }

            EOF

            PatternPatch::Patch.new(
              regexp: /application.*open\s+url.*sourceApplication:.*?\{.*?\n/m,
              text: open_url_text,
              mode: :append
            ).apply app_delegate_swift_path
          else
            # Has neither
            open_url_text = <<EOF


        func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
            return Branch.getInstance().application(app, open: url, options: options)
        }
EOF

            PatternPatch::Patch.new(
              regexp: /\n\s*\}[^{}]*\Z/m,
              text: open_url_text,
              mode: :prepend
            )
          end
        end

        def patch_continue_user_activity_method_swift(app_delegate_swift_path)
          app_delegate = File.read app_delegate_swift_path
          if app_delegate =~ /application:.*continue userActivity:.*restorationHandler:/
            # Add something to the top of the method
            continue_user_activity_text = <<-EOF
        // TODO: Adjust your method as you see fit.
        if Branch.getInstance.continue(userActivity) {
            return true
        }

            EOF

            PatternPatch::Patch.new(
              regexp: /application:.*continue userActivity:.*restorationHandler:.*?\{.*?\n/m,
              text: continue_user_activity_text,
              mode: :append
            ).apply app_delegate_swift_path
          else
            # Add the application:continueUserActivity:restorationHandler method if it does not exist
            continue_user_activity_text = <<-EOF


    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        return Branch.getInstance().continue(userActivity)
    }
            EOF

            PatternPatch::Patch.new(
              regexp: /\n\s*\}[^{}]*\Z/m,
              text: continue_user_activity_text,
              mode: :prepend
            ).apply app_delegate_swift_path
          end
        end

        def patch_open_url_method_objc(app_delegate_objc_path)
          app_delegate_objc = File.read app_delegate_objc_path
          if app_delegate_objc =~ /application:.*openURL:.*options/
            # Has application:openURL:options:
            open_url_text = <<-EOF
    // TODO: Adjust your method as you see fit.
    if ([[Branch getInstance] application:app openURL:url options:options]) {
        return YES;
    }

            EOF

            PatternPatch::Patch.new(
              regexp: /application:.*openURL:.*options:.*?\{.*?\n/m,
              text: open_url_text,
              mode: :append
            ).apply app_delegate_objc_path
          elsif app_delegate_objc =~ /application:.*openURL:.*sourceApplication/
            # Has application:openURL:sourceApplication:annotation:
            open_url_text = <<-EOF
    // TODO: Adjust your method as you see fit.
    if ([[Branch getInstance] application:application openURL:url sourceApplication:sourceApplication annotation:annotation]) {
        return YES;
    }

            EOF

            PatternPatch::Patch.new(
              regexp: /application:.*openURL:.*sourceApplication:.*?\{.*?\n/m,
              text: open_url_text,
              mode: :append
            ).apply app_delegate_objc_path
          else
            # Has neither
            open_url_text = <<-EOF


- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    return [[Branch getInstance] application:app openURL:url options:options];
}
            EOF

            PatternPatch::Patch.new(
              regexp: /\n\s*@end[^@]*\Z/m,
              text: open_url_text,
              mode: :prepend
            ).apply app_delegate_objc_path
          end
        end

        def patch_continue_user_activity_method_objc(app_delegate_objc_path)
          app_delegate = File.read app_delegate_objc_path
          if app_delegate =~ /application:.*continueUserActivity:.*restorationHandler:/
            continue_user_activity_text = <<-EOF
    // TODO: Adjust your method as you see fit.
    if ([[Branch getInstance] continueUserActivity:userActivity]) {
        return YES;
    }

            EOF

            PatternPatch::Patch.new(
              regexp: /application:.*continueUserActivity:.*restorationHandler:.*?\{.*?\n/m,
              text: continue_user_activity_text,
              mode: :append
            ).apply app_delegate_objc_path
          else
            # Add the application:continueUserActivity:restorationHandler method if it does not exist
            continue_user_activity_text = <<-EOF


- (BOOL)application:(UIApplication *)app continueUserActivity:(nonnull NSUserActivity *)userActivity restorationHandler:(nonnull void (^)(NSArray * _Nullable))restorationHandler
{
    return [[Branch getInstance] continueUserActivity:userActivity];
}
            EOF

            PatternPatch::Patch.new(
              regexp: /\n\s*@end[^@]*\Z/m,
              text: continue_user_activity_text,
              mode: :prepend
            ).apply app_delegate_objc_path
          end
        end

        def patch_podfile(podfile_path)
          podfile = File.read podfile_path

          # Podfile already contains the Branch pod
          # TODO: Allow for adding to multiple targets in the Podfile
          return false if podfile =~ /pod\s+('Branch'|"Branch")/

          say "Adding pod \"Branch\" to #{podfile_path}"

          if podfile =~ /target\s+(["'])#{config.target.name}\1\s+do.*?\n/m
            # if there is a target block for this target:
            patch = PatternPatch::Patch.new(
              regexp: /\n(\s*)target\s+(["'])#{config.target.name}\2\s+do.*?\n/m,
              text: "\\1  pod \"Branch\"\n",
              mode: :append
            )
          else
            # add to the abstract_target for this target
            patch = PatternPatch::Patch.new(
              regexp: /^(\s*)target\s+["']#{config.target.name}/,
              text: "\\1pod \"Branch\"\n",
              mode: :prepend
            )
          end
          patch.apply podfile_path

          true
        end

        def patch_cartfile(cartfile_path)
          cartfile = File.read cartfile_path

          # Cartfile already contains the Branch framework
          return false if cartfile =~ /git.+Branch/

          say "Adding \"Branch\" to #{cartfile_path}"

          PatternPatch::Patch.new(
            regexp: /\z/,
            text: "github \"BranchMetrics/ios-branch-deep-linking\"\n",
            mode: :append
          ).apply cartfile_path

          true
        end

        def patch_source(xcodeproj)
          patch_app_delegate_swift(xcodeproj) || patch_app_delegate_objc(xcodeproj)
        end
      end
    end
  end
end
