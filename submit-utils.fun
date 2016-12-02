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

function make_submission
{
    # Given the name and type of an XML file, submits it to the ENA.
    # The response from ENA is parsed and, if the submission was
    # successful, the returned ENA IDs etc. are stored in the state XML
    # file.

    # Parameters:
    #
    #   1:  File name
    #   2:  File type

    case "$2" in
        SAMPLE_SET) submit_generic "$1" "sample"    ;;
        STUDY_SET)  submit_generic "$1" "study"     ;;
        *)
            printf "Submissions of '%s' are currently not implemented\n" \
                "$2" >&2
            ;;
    esac
}

function submit_generic
{
    # Submits an XML file.
    #
    # Parameters:
    #
    #   1: File name
    #   2: Schema

    # See if this file has been submitted before, in which case the
    # "action" must be "MODIFY" rather than "ADD".

    local action
    local submitted=$( get_value "/state/file[@name='$1']/@submitted" <"$state_xml" )

    if [[ "$submitted" != "true" ]]; then
        action="ADD"
    else
        action="MODIFY"
    fi

    init_xml "SUBMISSION" |
    add_attr "/SUBMISSION" "alias" "$username $timestamp" |
    add_attr "/SUBMISSION" "center_name" "$center_name" |
    add_elem "/SUBMISSION" "ACTIONS" |
    add_elem "//ACTIONS" "ACTION" |
    add_elem "//ACTION" "$action" |
    add_attr "//$action" "source" "$1" |
    add_attr "//$action" "schema" "$2"
}

# vim: ft=sh
