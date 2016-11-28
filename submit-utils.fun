# Bash shell utility functions.

function display_state
{
    # Will eventually display the current state of submissions by
    # parsing the state.xml file in the data directory (written after
    # submitting a file).  This XML file contains information about what
    # submissions has been made, and what IDs we've got back from the
    # ENA.
    #
    # For now, it simply displays the raw contents of the state.xml
    # file, if it exists.

    if [[ ! -f "$state_xml" ]]; then
        printf "Can not find '%s'.  No submissions made yet?\n" "$state_xml"
        return
    fi

    echo "Current state:"
    cat "$state_xml"
}

# vim: ft=sh
