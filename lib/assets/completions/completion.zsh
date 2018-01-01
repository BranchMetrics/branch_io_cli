#!/bin/zsh
# This file is generated. Run rake readme to regenerate it.

_branch_io_complete() {
  local word opts
  word="$1"
  opts="-h --help -t --trace -v --version"
  opts="$opts -L --live-key -T --test-key -D --domains --app-link-subdomain -U --uri-scheme -s --setting --test-configurations --xcodeproj --target --podfile --cartfile --carthage-command --frameworks --no-pod-repo-update --no-validate --force --no-add-sdk --no-patch-source --commit --no-confirm"

  reply=( "${(ps: :)opts}" )
}

compctl -K _branch_io_complete branch_io
compctl -K _branch_io_complete br
