#!/bin/bash
# This file is generated. Run rake readme to regenerate it.

_branch_io_complete()
{
    local cur prev opts global_opts setup_opts validate_opts commands cmd
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    cmd="${COMP_WORDS[1]}"

    commands="setup report validate"
    global_opts="-h --help -t --trace -v --version"


    setup_opts="-L --live-key -T --test-key -D --domains --app-link-subdomain -U --uri-scheme -s --setting --test-configurations --xcodeproj --target --podfile --cartfile --carthage-command --frameworks --no-pod-repo-update --no-validate --force --no-add-sdk --no-patch-source --commit --no-confirm"

    report_opts="--workspace --xcodeproj --scheme --target --configuration --sdk --podfile --cartfile --no-clean -H --header-only --no-pod-repo-update -o --out"

    validate_opts="-D --domains --xcodeproj --target --configurations"


    if [[ ${cur} == -* ]] ; then
      case "${cmd}" in
        report)
          opts=$report_opts
          ;;
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
