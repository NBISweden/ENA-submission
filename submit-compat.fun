# Code and functions for portability and compatibility between systems.

# Make sure we have GNU Date.  Test it by calling it with '--version'
# (the output shold mention "coreutils").

date_cmd="$( which gdate 2>/dev/null || which date 2>/dev/null )"

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

# Figure out whether xmlstarlet is called "xmlstarlet" (as on UPPMAX) or
# "xml" as on development machine.

xmlstarlet_cmd="$( which xmlstarlet 2>/dev/null || which xml 2>/dev/null )"

if [[ -z "$xmlstarlet_cmd" ]]; then
    echo "This tool requires XML Starlet" >&2
    exit 1
fi

function xmlstarlet
{
    # Calls xmlstarlet.

    command "$xmlstarlet_cmd" "$@"
}

# vim: ft=sh
