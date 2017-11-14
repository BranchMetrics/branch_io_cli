<% if is_new_method %>
    override func didBecomeActive(with conversation: MSConversation) {
<% end %>
<% if use_conditional_test_key? %>
        #if DEBUG
            Branch.setUseTestBranchKey(true)
        #endif
<% end %>
        Branch.getInstance().initSession(launchOptions: [:]) {
            universalObject, linkProperties, error in

            // TODO: Route Branch links
        }
<% if is_new_method %>
    }
<% end %>
