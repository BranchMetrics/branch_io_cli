        #if DEBUG
            Branch.setUseTestBranchKey(true)
        #endif

        Branch.getInstance().initSession(launchOptions: launchOptions) {
            universalObject, linkProperties, error in

            // TODO: Route Branch links
        }
