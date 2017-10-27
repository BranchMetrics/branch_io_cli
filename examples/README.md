# Example projects

There are several example application projects in this folder. Each is an empty
app that just displays a blank screen. These projects may or may not already
have other dependencies via CocoaPods, Carthage or direct integration. The
CLI may be used to integrate the Branch SDK with each project. These projects
will not pass validation without first being set up.

## [BranchPluginExample](./BranchPluginExample)

This project uses Swift and CocoaPods.

## [BranchPluginExampleCarthage](./BranchPluginExampleCarthage)

This project uses Swift and Carthage.

## [BranchPluginExampleObjc](./BranchPluginExampleObjc)

This project uses Objective-C and CocoaPods.

---

Each project will pass validation if `k272.app.link` is used for the domain. If
you wish to try them with your own Branch parameters, you must first manually
change the bundle identifier and signing team in the project. To test basic
integration without modification (using a dummy key), change to each subdirectory:

```bash
branch_io setup -D k272.app.link -L key_live_xxxx
```

Validation will fail before setup and pass afterward.

```bash
branch_io validate -D k272.app.link,k272-alternate.app.link
```

To use the command from this repo rather than your PATH, first 'bundle install'
and then:

```bash
bundle exec branch_io setup # or validate
```
