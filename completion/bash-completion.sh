#!/bin/bash

_branch_io()
{
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="-h --help -t --trace -v --version"
    opts="$opts -L --live-key -T --test-key -D --domains --app-link-subdomain -U --uri-scheme"
    opts="$opts --xcodeproj --target --frameworks --podfile --cartfile"
    # Don't autocomplete the default values here, e.g. --no-force, --pod-repo-update.
    opts="$opts --no-add-sdk --no-validate --force --no-pod-repo-update --commit --no-patch-source"

    if [[ ${cur} == -* ]] ; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi
}
complete -F _branch_io branch_io
