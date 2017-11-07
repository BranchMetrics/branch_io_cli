    // TODO: Adjust your method as you see fit.
    if ([[Branch getInstance] application:app openURL:url options:options]) {
        return YES;
    }
