#!/bin/zsh

_branch_io_complete() {
  local word opts
  word="$1"
  opts="-h --help -t --trace -v --version"
  opts="$opts -L --live-key -T --test-key -D --domains --app-link-subdomain -U --uri-scheme"
  opts="$opts --xcodeproj --target --frameworks --podfile --cartfile --carthage-command --setting -s"
  opts="$opts --test-configurations --no-test-configurations --no-confirm"
  # Don't autocomplete the default values here, e.g. --no-force, --pod-repo-update.
  opts="$opts --no-add-sdk --no-validate --force --no-pod-repo-update --commit --no-patch-source"

  reply=( "${(ps: :)opts}" )
}

compctl -K _branch_io_complete branch_io
