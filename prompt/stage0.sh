#!/usr/bin/env bash

set -u

magic_exit_code=27
repo_path=
repo_name=
stage2_script=
root_path=
powershell_path=${POWERSHELL_PATH:-}

usage() {
    echo "Usage: $0 -repoPath PATH -repoName NAME [-stage2Script PATH] [-rootPath PATH] [-powerShellPath PATH]" >&2
}

while (($# > 0)); do
    if (($# < 2)); then
        usage
        exit 2
    fi

    case "$1" in
        -repoPath)
            repo_path=$2
            ;;
        -repoName)
            repo_name=$2
            ;;
        -stage2Script)
            stage2_script=$2
            ;;
        -rootPath)
            root_path=$2
            ;;
        -powerShellPath)
            powershell_path=$2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage
            exit 2
            ;;
    esac

    shift 2
done

if [[ -z $repo_path || -z $repo_name ]]; then
    usage
    exit 2
fi

if [[ ! -d $repo_path ]]; then
    echo "'$repo_path' does not exist" >&2
    exit 1
fi

if [[ -z $powershell_path ]]; then
    powershell_path=$(command -v pwsh-preview || true)
fi

if [[ -z $powershell_path ]]; then
    echo "Could not find pwsh-preview. Set POWERSHELL_PATH or pass -powerShellPath." >&2
    exit 1
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
script_args=(
    -NoExit
    -NoLogo
    -Interactive
    -File "$script_dir/stage1.ps1"
    -repoPath "$repo_path"
    -repoName "$repo_name"
    -relaunchMeExitCode "$magic_exit_code"
)

if [[ -n $stage2_script ]]; then
    script_args+=(-stage2Script "$stage2_script")
fi

if [[ -n $root_path ]]; then
    script_args+=(-rootPath "$root_path")
fi

# Bash resets caught signals to their defaults in child processes. This keeps
# Ctrl+C from terminating the supervisor without suppressing it in PowerShell.
trap ':' INT

while true; do
    "$powershell_path" "${script_args[@]}"
    exit_code=$?

    if ((exit_code != magic_exit_code)); then
        exit "$exit_code"
    fi
done
