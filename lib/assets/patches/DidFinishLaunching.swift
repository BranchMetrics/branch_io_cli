<% unless config.keys.count <= 1 || has_multiple_info_plists? >
        #if DEBUG
            Branch.setUseTestBranchKey(true)
        #endif

<% end %>
        Branch.getInstance().initSession(launchOptions: launchOptions) {
            universalObject, linkProperties, error in

            // TODO: Route Branch links
        }
