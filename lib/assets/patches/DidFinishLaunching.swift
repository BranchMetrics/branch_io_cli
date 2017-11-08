<% if use_conditional_test_key? %>
        #if DEBUG
            Branch.setUseTestBranchKey(true)
        #endif
<% end %>
        Branch.getInstance().initSession(launchOptions: launchOptions) {
            universalObject, linkProperties, error in

            // TODO: Route Branch links
        }
