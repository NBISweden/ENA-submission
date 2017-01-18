# Code and functions for portability and compatibility between systems.

# Make sure we have GNU Date.  Test it by calling it with '--version'
# (the output shold mention "coreutils").

date_cmd="$( command -v gdate || command -v date )"

if ! command "$date_cmd" --version 2>/dev/null | grep -q -F "coreutils"
then
    echo "This tool requires GNU Date" >&2
    exit 1
fi

function date
{
    # Calls (GNU) date.

    command "$date_cmd" "$@"
}

# Use either BSD 'md5' or Linux 'md5sum'.

checksum_cmd="$( command -v md5 || command -v md5sum )"

if [[ -z "$checksum_cmd" ]]; then
    echo "This tool requires either 'md5sum' or 'md5'" >&2
    exit 1
fi

function checksum
{
    # Computes the MD5 digest of a file.

    fpath="$1"

    if [[ "${checksum_cmd##*/}" == "md5" ]]; then
        command "${checksum_cmd}" -q "$fpath"
    else
        command "${checksum_cmd}" "$fpath" | cut -d ' ' -f 1
    fi
}

# Figure out whether xmlstarlet is called "xmlstarlet" (as on UPPMAX) or
# "xml" as on development machine.

xmlstarlet_cmd="$( command -v xmlstarlet || command -v xml )"

if [[ -z "$xmlstarlet_cmd" ]]; then
    echo "This tool requires XML Starlet" >&2
    exit 1
fi

function xmlstarlet
{
    # Calls XML Starlet.

    command "$xmlstarlet_cmd" "$@"
}

# Make sure we have Curl.

curl_cmd="$( command -v curl )"

if [[ -z "$curl_cmd" ]]; then
    echo "This tool requires Curl" >&2
    exit 1
fi

function curl
{
    # Calls Curl.

    command "$curl_cmd" "$@"
}

# vim: ft=sh
