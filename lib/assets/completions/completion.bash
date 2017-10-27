#!/bin/bash

_branch_io()
{
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    commands="setup validate"
    global_opts="-h --help -t --trace -v --version"

    setup_opts="$global_opts -L --live-key -T --test-key -D --domains --app-link-subdomain -U --uri-scheme"
    setup_opts="$setup_opts --xcodeproj --target --frameworks --podfile --cartfile"
    # Don't autocomplete the default values here, e.g. --no-force, --pod-repo-update.
    setup_opts="$setup_opts --no-add-sdk --no-validate --force --no-pod-repo-update --commit --no-patch-source"

    validate_opts="$global_opts -D --domains --xcodeproj --target"

    if [[ ${cur} == -* ]] ; then
      if [[ ${prev} == setup ]] ; then
        opts=$setup_opts
      elif [[ ${prev} == validate ]] ; then
        opts=$validate_opts
      else
        opts=$global_opts
      fi
    else
      opts=`for c in $commands; do echo $c; done | grep "^$cur"`
      opts="$opts $global_opts"
    fi

    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    return 0
}
complete -F _branch_io branch_io
