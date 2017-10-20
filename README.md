# branch_io_cli gem

This is a command-line tool to integrate the Branch SDK into mobile app projects. (Currently iOS only.)

[![Gem](https://img.shields.io/gem/v/branch_io_cli.svg?style=flat)](https://rubygems.org/gems/branch_io_cli)
[![Downloads](https://img.shields.io/gem/dt/branch_io_cli.svg?style=flat)](https://rubygems.org/gems/branch_io_cli)
[![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://github.com/BranchMetrics/branch_io_cli/blob/master/LICENSE)
[![CircleCI](https://img.shields.io/circleci/project/github/BranchMetrics/branch_io_cli.svg)](https://circleci.com/gh/BranchMetrics/branch_io_cli)

## Preliminary release

This is a preliminary release of this gem. Please report any problems by opening issues in this repo.

### Using Fastlane?

See also the [Branch Fastlane plugin](https://github.com/BranchMetrics/fastlane-plugin-branch), which offers
the same support via Fastlane.

## Getting started

```bash
gem install branch_io_cli
```

Note that this command may require `sudo` access if you are using the system Ruby, i.e. `sudo gem install branch_io_cli`.

```bash
branch_io -h
branch_io setup -h
branch_io validate -h
```

## Commands

### Setup command

```bash
branch_io setup
```

Integrates the Branch SDK into a native app project. This currently supports iOS only.
It will infer the project location if there is exactly one .xcodeproj anywhere under
the current directory, excluding any in a Pods or Carthage folder. Otherwise, specify
the project location using the `--xcodeproj` option.

If a Podfile or Cartfile is detected, the Branch SDK will be added to the relevant
configuration file and the dependencies updated to include the Branch framework.
This behavior may be suppressed using `--no_add_sdk`. If no Podfile or Cartfile
is found, and Branch.framework is not already among the project's dependencies,
you will be prompted for a number of choices.

By default, all supplied Universal Link domains are validated. If validation passes,
the setup continues. If validation fails, no further action is taken. Suppress
validation using `--no_validate` or force changes when validation fails using
`--force`.

All relevant project settings are modified. The Branch keys are added to the Info.plist,
along with the `branch_universal_link_domains` key for custom domains (when `--domains`
is used). All domains are added to the project's Associated Domains entitlements.
An entitlements file is added if none is found. Optionally, if `--frameworks` is
specified, this command can add a list of system frameworks to the project (e.g.,
AdSupport, CoreSpotlight, SafariServices).

A language-specific patch is applied to the AppDelegate (Swift or Objective-C).
This can be suppressed using `--no_patch_source`.

#### Prerequisites

Before using this command, make sure to set up your app in the [Branch Dashboard](https://dashboard.branch.io). See https://docs.branch.io/pages/dashboard/integrate/ for details. To use the `setup` command, you need:

- Branch key(s), either live, test or both
- Domain name(s) used for Branch links
- Location of your Xcode project (may be inferred in simple projects)

To use the `--commit` option, you must have the `git` command available in your path.

To add the SDK with CocoaPods or Carthage, you must have the `pod` or `carthage`
command, respectively, available in your path.

#### Options

|Option|Description|
|------|-----------|
|--live_key key_live_xxxx|Branch live key|
|--test_key key_test_yyyy|Branch test key|
|--app_link_subdomain myapp|Branch app.link subdomain, e.g. myapp for myapp.app.link|
|--domains example.com,www.example.com|Comma-separated list of custom domain(s) or non-Branch domain(s)|
|--xcodeproj MyProject.xcodeproj|Path to an Xcode project to update|
|--target MyAppTarget|Name of a target to modify in the Xcode project|
|--podfile /path/to/Podfile|Path to the Podfile for the project|
|--cartfile /path/to/Cartfile|Path to the Cartfile for the project|
|--frameworks AdSupport,CoreSpotlight,SafariServices|Comma-separated list of system frameworks to add to the project|
|--no_pod_repo_update|Skip update of the local podspec repo before installing|
|--no_validate|Skip validation of Universal Link configuration|
|--force|Update project even if Universal Link validation fails|
|--no_add_sdk|Don't add the Branch framework to the project|
|--no_patch_source|Don't add Branch SDK calls to the AppDelegate|
|--commit|Commit the results to Git|

All parameters are optional. A live key or test key, or both is required, as well as at least one domain.
Specify --live_key, --test_key or both and --app_link_subdomain, --domains or both. If these are not
specified, this command will prompt you for this information.

### Validate command

```bash
branch_io validate
```

This command validates all Universal Link domains configured in a project without making any modification.
It validates both Branch and non-Branch domains. Unlike web-based Universal Link validators,
this command operates directly on the project. It finds the bundle and
signing team identifiers in the project as well as the app's Associated Domains.
It requests the apple-app-site-association file for each domain and validates
the file against the project's settings.

#### Options

|Option|Description|
|------|-----------|
|--domains example.com,www.example.com|Comma-separated list of domains. May include app.link subdomains.|
|--xcodeproj MyProject.xcodeproj|Path to an Xcode project to update|
|--target MyAppTarget|Name of a target to modify in the Xcode project|

All parameters are optional. If `--domains` is specified, the list of Universal Link domains in the
Associated Domains entitlement must exactly match this list, without regard to order. If no `--domains`
are provided, validation passes if at least one Universal Link domain is configured and passes validation,
and no Universal Link domain is present that does not pass validation.

#### Return value

If validation passes, this command returns 0. If validation fails, it returns 1.

## Examples

See the [examples](./examples) folder for several example projects that can be
used to exercise the CLI.
