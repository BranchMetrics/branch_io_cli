<% if is_new_method %>

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
<% end %>
<% if use_conditional_test_key? %>
        #if DEBUG
            Branch.setUseTestBranchKey(true)
        #endif
<% end %>
        Branch.getInstance().initSession(launchOptions: launchOptions) {
            universalObject, linkProperties, error in

            // TODO: Route Branch links
        }
<% if is_new_method %>
        return true
    }
<% end %>
