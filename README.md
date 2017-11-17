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
branch_io report -h
```

### Shell completion

_Work in progress_

You can enable completion of all options in `bash` or `zsh`. The following
additions should follow initialization of RVM, rbenv or chruby or setting
any Ruby-related environment variables if using the system Ruby.

#### Bash

Add to `~/.bash_profile` or `~/.bashrc`:

```bash
. `gem which branch_io_cli | sed 's+branch_io_cli.rb$+assets/completions/completion.bash+'`
```

#### Zsh

Add to `~/.zshrc`:

```zsh
. `gem which branch_io_cli | sed 's+branch_io_cli.rb$+assets/completions/completion.zsh+'`
```

Currently command-line completion for bash is much more extensive than for zsh.

## Commands

<!-- The following is generated. Do not edit by hand. Run rake readme to -->
<!-- regenerate this section. -->
<!-- BEGIN COMMAND REFERENCE -->
### Setup command

```bash
branch_io setup [OPTIONS]
```

Integrates the Branch SDK into a native app project. This currently supports iOS only.
It will infer the project location if there is exactly one .xcodeproj anywhere under
the current directory, excluding any in a Pods or Carthage folder. Otherwise, specify
the project location using the `--xcodeproj` option, or the CLI will prompt you for the
location.

If a Podfile or Cartfile is detected, the Branch SDK will be added to the relevant
configuration file and the dependencies updated to include the Branch framework.
This behavior may be suppressed using `--no-add-sdk`. If no Podfile or Cartfile
is found, and Branch.framework is not already among the project's dependencies,
you will be prompted for a number of choices, including setting up CocoaPods or
Carthage for the project or directly installing the Branch.framework.

By default, all supplied Universal Link domains are validated. If validation passes,
the setup continues. If validation fails, no further action is taken. Suppress
validation using `--no-validate` or force changes when validation fails using
`--force`.

By default, this command will look for the first app target in the project. Test
targets are not supported. To set up an extension target, supply the `--target` option.

All relevant target settings are modified. The Branch keys are added to the Info.plist,
along with the `branch_universal_link_domains` key for custom domains (when `--domains`
is used). For app targets, all domains are added to the project's Associated Domains
entitlement. An entitlements file is also added for app targets if none is found.
Optionally, if `--frameworks` is specified, this command can add a list of system
frameworks to the target's dependencies (e.g., AdSupport, CoreSpotlight, SafariServices).

A language-specific patch is applied to the AppDelegate (Swift or Objective-C).
This can be suppressed using `--no-patch-source`.

#### Prerequisites

Before using this command, make sure to set up your app in the Branch Dashboard
(https://dashboard.branch.io). See https://docs.branch.io/pages/dashboard/integrate/
for details. To use the `setup` command, you need:

- Branch key(s), either live, test or both
- Domain name(s) used for Branch links
- Location of your Xcode project (may be inferred in simple projects)

If using the `--commit` option, `git` is required. If not using `--no-add-sdk`,
the `pod` or `carthage` command may be required. If not found, the CLI will
offer to install and set up these command-line tools for you. Alternately, you can arrange
that the relevant commands are available in your `PATH`.

All parameters are optional. A live key or test key, or both is required, as well
as at least one domain. Specify `--live-key`, `--test-key` or both and `--app-link-subdomain`,
`--domains` or both. If these are not specified, this command will prompt you
for this information.

See https://github.com/BranchMetrics/branch_io_cli#setup-command for more information.


#### Options

|Option|Description|
|------|-----------|
|-h, --help|Prints a list of commands or help for each command|
|-v, --version|Prints the current version of the CLI|
|-t, --trace|Prints a stack trace when exceptions are raised|
|-L, --live-key key_live_xxxx|Branch live key|
|-T, --test-key key_test_yyyy|Branch test key|
|-D, --domains example.com,www.example.com|Comma-separated list of custom domain(s) or non-Branch domain(s)|
|--app-link-subdomain myapp|Branch app.link subdomain, e.g. myapp for myapp.app.link|
|-U, --uri-scheme myurischeme[://]|Custom URI scheme used in the Branch Dashboard for this app|
|-s, --setting [BRANCH_KEY_SETTING]|Use a custom build setting for the Branch key (default: Use Info.plist)|
|--test-configurations config1,config2|List of configurations that use the test key with a custom build setting (default: Debug configurations)|
|--xcodeproj MyProject.xcodeproj|Path to an Xcode project to update|
|--target MyAppTarget|Name of a target to modify in the Xcode project|
|--podfile /path/to/Podfile|Path to the Podfile for the project|
|--cartfile /path/to/Cartfile|Path to the Cartfile for the project|
|--carthage-command <command>|Command to run when installing from Carthage (default: update --platform ios)|
|--frameworks AdSupport,CoreSpotlight,SafariServices|Comma-separated list of system frameworks to add to the project|
|--[no-]pod-repo-update|Update the local podspec repo before installing (default: yes)|
|--[no-]validate|Validate Universal Link configuration (default: yes)|
|--[no-]force|Update project even if Universal Link validation fails (default: no)|
|--[no-]add-sdk|Add the Branch framework to the project (default: yes)|
|--[no-]patch-source|Add Branch SDK calls to the AppDelegate (default: yes)|
|--[no-]commit|Commit the results to Git (default: no)|
|--[no-]check-repo-changes|Check for uncommitted changes to a git repo (default: yes)|


#### Examples


##### Test without validation (can use dummy keys and domains)

```bash
branch_io setup -L key_live_xxxx -D myapp.app.link --no-validate
```


##### Use both live and test keys

```bash
branch_io setup -L key_live_xxxx -T key_test_yyyy -D myapp.app.link
```


##### Use custom or non-Branch domains

```bash
branch_io setup -D myapp.app.link,example.com,www.example.com
```


##### Avoid pod repo update

```bash
branch_io setup --no-pod-repo-update
```


##### Install using carthage bootstrap

```bash
branch_io --carthage-command "bootstrap --no-use-binaries"
```




### Validate command

```bash
branch_io validate [OPTIONS]
```

This command validates all Universal Link domains configured in a project without making any
modification. It validates both Branch and non-Branch domains. Unlike web-based Universal
Link validators, this command operates directly on the project. It finds the bundle and
signing team identifiers in the project as well as the app's Associated Domains. It requests
the apple-app-site-association file for each domain and validates the file against the
project's settings.

Only app targets are supported for this command. By default, it will validate the first.
If your project has multiple app targets, specify the `--target` option to validate other
targets.

All parameters are optional. If `--domains` is specified, the list of Universal Link domains in
the Associated Domains entitlement must exactly match this list, without regard to order. If
no `--domains` are provided, validation passes if at least one Universal Link domain is
configured and passes validation, and no Universal Link domain is present that does not pass
validation.

See https://github.com/BranchMetrics/branch_io_cli#validate-command for more information.


#### Options

|Option|Description|
|------|-----------|
|-h, --help|Prints a list of commands or help for each command|
|-v, --version|Prints the current version of the CLI|
|-t, --trace|Prints a stack trace when exceptions are raised|
|-D, --domains example.com,www.example.com|Comma-separated list of domains to validate (Branch domains or non-Branch domains) (default: [])|
|--xcodeproj MyProject.xcodeproj|Path to an Xcode project to update|
|--target MyAppTarget|Name of a target to validate in the Xcode project|





### Report command

```bash
branch_io report [OPTIONS]
```

_Work in progress_

This command optionally cleans and then builds a workspace or project, generating a verbose
report with additional diagnostic information suitable for opening a support ticket.


#### Options

|Option|Description|
|------|-----------|
|-h, --help|Prints a list of commands or help for each command|
|-v, --version|Prints the current version of the CLI|
|-t, --trace|Prints a stack trace when exceptions are raised|
|--workspace MyProject.xcworkspace|Path to an Xcode workspace|
|--xcodeproj MyProject.xcodeproj|Path to an Xcode project|
|--scheme MyProjectScheme|A scheme from the project or workspace to build|
|--target MyProjectTarget|A target to build|
|--configuration Debug/Release/CustomConfigName|The build configuration to use (default: Scheme-dependent)|
|--sdk iphoneos|Passed as -sdk to xcodebuild (default: iphonesimulator)|
|--podfile /path/to/Podfile|Path to the Podfile for the project|
|--cartfile /path/to/Cartfile|Path to the Cartfile for the project|
|--[no-]clean|Clean before attempting to build (default: yes)|
|-H, --[no-]header-only|Write a report header to standard output and exit (default: no)|
|--[no-]pod-repo-update|Update the local podspec repo before installing (default: yes)|
|-o, --out ./report.txt|Report output path (default: ./report.txt)|





<!-- END COMMAND REFERENCE -->

## Examples

See the [examples](./examples) folder for several example projects that can be
used to exercise the CLI.

## Rake task

You can use these commands easily with Rake:

```Ruby
require 'branch_io_cli/rake_task'
BranchIOCLI::RakeTask.new
```

This defines the tasks `branch:report`, `branch:setup` and `branch:validate`.
Each takes a path or an array of paths for a project directory as the first
argument, followed by an options Hash with keys derived from the command-line
arguments. For example:

```Ruby
Rake::Task["branch:validate"].invoke ".", domains: %w(example.com www.example.com)
```
