    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        #if DEBUG
            Branch.setUseTestBranchKey(true)
        #endif

        Branch.getInstance().initSession(launchOptions: launchOptions) {
            universalObject, linkProperties, error in

            // TODO: Route Branch links
        }
        return true
    }
