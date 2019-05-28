#!/usr/bin/env bash

# Usage:
#
#   ./build.bash variables-vagrant.json archlinux-vagrant.json
#

# Exit immediately if a "simple" command, a "compound" command, a list, or the last
# command in a pipeline exits with a non-zero exit status.
set -e

# Treat unset variables as errors, exiting when detected.
set -u

# Fail if any command in a pipeline chain returns with a non-zero exit status.
set -o pipefail

# Get the path of the directory that this script is in.
path="$(cd "${BASH_SOURCE[0]%/*}" && pwd)"

# Create the logs directory if it doesn't exist.
log_dir="${path}/logs/packer"
[[ -d "$log_dir" ]] || install --directory --mode=0700 "$log_dir"

# Create a timestamped log file.
log="${log_dir}/packer-$(date --iso-8601=seconds).log"
[[ -f "$log" ]] || touch "$log"

# Append both stdout and stderr to the log file and the terminal.
exec > >(tee --append "$log") 2>&1

# The name of this script.
script="${BASH_SOURCE[0]##*/}"

error()
{
    local status=$1
    local line=$2
    local message="${3:-}"

    printf "%s" "${script}: Terminating... error on or near line ${line}. " >&2

    if [[ -n "${message}" ]]; then
        printf "%s\\n" "${message}; exiting with status: ${status}." >&2
    else
        printf "%s\\n" "Exiting with status: ${status}." >&2
    fi

    exit $status
}

# Trap any errors, calling error() when they're caught.
trap 'error $? $LINENO' ERR

# This function logs user interruptions.
interrupt()
{
    local status=$?
    trap '' EXIT
    printf "%s\\n" "${script}: received interrupt signal. The last command finished with exit status ${status}."
    exit $status
}

# Trap any user interruptions, such as Ctrl+c, calling interrupt() when they're caught.
trap interrupt INT
trap interrupt QUIT
trap interrupt TERM

# Used for the logs.
arguments="$@"

# All of the variables that contain the arguments accepted by `packer validate` and
# `packer build`.
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
        '-color=false' ) color="$1" ;;
        '-debug' ) debug='-debug' ;;
        '-except='* ) except="$1" ;;
        '-only='* ) only="$1" ;;
        '-force' ) force='-force' ;;
        '-machine-readable' ) machine='-machine-readable' ;;
        '-on-error='* ) on_error="$1" ;;
        '-parallel='* ) parallel="$1" ;;
        '-timestamp-ui' ) timestampui='-timestamp-ui' ;;
        '-var' ) var+="-var ${2}" shift 1 ;;
        '-var-file='* ) varfile="$1" ;;
        * ) if [[ $1 =~ .*\.json ]]; then template="$1"; else error 3 "$LINENO" "\"${1}\" is not a valid template"; fi ;;
    esac
    shift 1
done

printf "%s%s%s%s%s\\n" "${script}: packer validate ${except:+${except} }" \
                                                  "${only:+${only} }" \
                                                  "${var:+${var} }" \
                                                  "${varfile:+${varfile} }" \
                                                  "${template:+${template} }"
packer validate $except $only $var $varfile $template

printf "%s\\n" "packer build ${arguments}"
PACKER_CACHE_DIR="${path}/packer_cache" \
PACKER_LOG=1 \
    packer build $color $debug $except $only $force $machine $on_error $parallel $timestampui $var $varfile $template
