#!/bin/bash
# This file is generated. Run rake readme to regenerate it.

_branch_io_complete()
{
    local cur prev opts global_opts setup_opts validate_opts commands cmd
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    cmd="${COMP_WORDS[1]}"

    commands="env setup report validate"
    global_opts="-h --help -t --trace -v --version"


    env_opts="-c --completion-script -s --shell -V --verbose"

    setup_opts="-L --live-key -T --test-key -D --domains --app-link-subdomain -U --uri-scheme -s --setting --test-configurations --xcodeproj --target --podfile --cartfile --carthage-command --frameworks --no-pod-repo-update --no-validate --force --no-add-sdk --no-patch-source --commit --no-confirm"

    report_opts="--workspace --xcodeproj --scheme --target --configuration --sdk --podfile --cartfile --no-clean -H --header-only --no-pod-repo-update -o --out --no-confirm"

    validate_opts="-L --live-key -T --test-key -D --domains --xcodeproj --target --configurations --universal-links-only --no-confirm"


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
        env)
          opts=$env_opts
          ;;
        *)
          opts=$global_opts
          ;;
      esac
      COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    elif [[ ${prev} == branch_io || ${prev} == br ]] ; then
      COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )
    else
      COMPREPLY=( $(compgen -o default ${cur}) )
    fi
    return 0
}
complete -F _branch_io_complete branch_io
complete -F _branch_io_complete br
