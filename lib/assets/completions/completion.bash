#!/bin/bash

_branch_io_complete()
{
    local cur prev opts global_opts setup_opts validate_opts commands cmd
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    cmd="${COMP_WORDS[1]}"

    commands="setup validate"
    global_opts="-h --help -t --trace -v --version"

    setup_opts="$global_opts -L --live-key -T --test-key -D --domains --app-link-subdomain -U --uri-scheme"
    setup_opts="$setup_opts --xcodeproj --target --frameworks --podfile --cartfile"
    # Don't autocomplete the default values here, e.g. --no-force, --pod-repo-update.
    setup_opts="$setup_opts --no-add-sdk --no-validate --force --no-pod-repo-update --commit --no-patch-source"

    validate_opts="$global_opts -D --domains --xcodeproj --target"

    if [[ ${cur} == -* ]] ; then
      case "${cmd}" in
        setup)
          opts=$setup_opts
          ;;
        validate)
          opts=$validate_opts
          ;;
        *)
          opts=$global_opts
          ;;
      esac
      COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    elif [[ ${prev} == branch_io ]] ; then
      COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )
    else
      COMPREPLY=( $(compgen -o default ${cur}) )
    fi
    return 0
}
complete -F _branch_io_complete branch_io
