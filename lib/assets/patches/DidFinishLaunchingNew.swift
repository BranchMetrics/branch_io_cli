
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        <% unless config.keys.count <= 1 || has_multiple_info_plists? %>
        #ifdef DEBUG
            [Branch setUseTestBranchKey:YES];
        #endif // DEBUG
          
        <% end %>
        Branch.getInstance().initSession(launchOptions: launchOptions) {
            universalObject, linkProperties, error in

            // TODO: Route Branch links
        }
        return true
    }
