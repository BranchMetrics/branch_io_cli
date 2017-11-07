    // TODO: Adjust your method as you see fit.
    if ([[Branch getInstance] application:application openURL:url sourceApplication:sourceApplication annotation:annotation]) {
        return YES;
    }
