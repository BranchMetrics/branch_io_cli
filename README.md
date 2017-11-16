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
<!-- END COMMAND REFERENCE -->

## Examples

See the [examples](./examples) folder for several example projects that can be
used to exercise the CLI.
