<% if is_new_method %>

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
<% end %>
<% if use_conditional_test_key? %>
#ifdef DEBUG
    [Branch setUseTestBranchKey:YES];
#endif // DEBUG
<% end %>
    [[Branch getInstance] initSessionWithLaunchOptions:launchOptions
        andRegisterDeepLinkHandlerUsingBranchUniversalObject:^(BranchUniversalObject *universalObject, BranchLinkProperties *linkProperties, NSError *error){
        // TODO: Route Branch links
    }];
<% if is_new_method %>
    return YES;
}
<% end %>
