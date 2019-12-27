#!/usr/bin/env bash

# Usage:
#
#   ./build.bash variables-vagrant.json archlinux-vagrant.json

set -e # Exit immediately when there is an error.
set -u # Treat unset variables as errors, exiting when detected.
set -o pipefail # Fail if any command in a pipeline chain returns an error.

error()
{
    local status=$1
    local line=$2
    local message="${3:-}"

    printf "%s" "${script_name}: terminating... error on or near line ${line}. " >&2

    if [[ -n "${message}" ]]; then
        printf "%s\\n" "${message}; exiting with status: ${status}." >&2
    else
        printf "%s\\n" "Exiting with status: ${status}." >&2
    fi

    exit $status
}

# This function logs user interruptions.
interrupt()
{
    local status=$?
    trap '' EXIT
    printf "%s\\n" "${script_name}: received interrupt signal. The last command finished with exit status ${status}."
    exit $status
}

# Create the logs directory if it doesn't exist.
start_log() {
    log_dir="${path}/logs/packer"
    [[ -d "$log_dir" ]] || install --directory --mode=0700 "$log_dir"

    # Create a timestamped log file.
    log="${log_dir}/packer-$(date --iso-8601=seconds).log"
    [[ -f "$log" ]] || touch "$log"

    # Append both stdout and stderr to the log file and the terminal.
    exec > >(tee --append "$log") 2>&1
}

validate() {
    echo "packer validate ${validate_args[@]}"
    packer validate ${validate_args[@]}
}

build() {
    echo "packer build ${args}"
    PACKER_CACHE_DIR="${path}/packer_cache" PACKER_LOG=1 packer build $args
}

main() {
    path="$(cd "${BASH_SOURCE[0]%/*}" && pwd)"
    start_log

    script_name="${BASH_SOURCE[0]##*/}"
    # Trap any errors, calling error() when they're caught.
    trap 'error $? $LINENO' ERR
    # Trap any user interruptions, such as Ctrl+c, calling interrupt() when they're caught.
    trap interrupt INT
    trap interrupt QUIT
    trap interrupt TERM

    args="$@"
    validate_args=()
    color=""
    debug=""
    except=""
    only=""
    force=""
    machine=""
    on_error=""
    parallel=""
    timestampui=""
    var=""
    varfile=""
    template=""

    while (( $# )); do
        case $1 in
            '-color=false'|'-debug'|'-force'|'-machine-readable'|'-on-error='*|'-parallel='*|'-timestamp-ui') ;;
            '-except='*|'-only='*|'-var-file='*|*'.json') validate_args+=("$1") ;;
            '-var') validate_args+=("-var ${2}") shift 1 ;;
            *) error 3 "$LINENO" "\"${1}\" is not a valid argument" ;;
        esac
        shift 1
    done

    validate
    build
}

main $@
