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
    # file.

    if [[ ! -f "$state_xml" ]]; then
        printf "Can not find '%s'.\n" "$state_xml"
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

    local submitted="$( get_value "//file[@name='$1']/submission" <"$state_xml" )"
    local action

    if [[ -z "$submitted" ]]; then
        action="ADD"
    else
        action="MODIFY"
    fi

    # Create submission XML.

    init_xml "SUBMISSION" |
    add_attr "/SUBMISSION" "alias" "$username $timestamp" |
    add_attr "/SUBMISSION" "center_name" "$center_name" |
    add_elem "/SUBMISSION" "ACTIONS" |
    add_elem "//ACTIONS" "ACTION" |
    add_elem "//ACTION" "$action" |
    add_attr "//$action" "source" "$1" |
    add_attr "//$action" "schema" "$2" >"$data_dir"/submission.xml

    process_submission "$1" "$2"

    # Update the state XML

    tmpfile="$( mktemp )"

    add_elem "//file[@name='$1']" \
        "submission" "$username $timestamp" <"$state_xml" |
    add_attr "//file[@name='$1']/submission[last()]" \
        "action" "$action" >"$tmpfile"

    mv -f "$tmpfile" "$state_xml"
}

function process_submission
{
    # Submits the submission XML file created by submit_generic and
    # updates the state XML with the IDs that ENA gives us.  The state
    # XML will also hold the submission status (the attribute "success"
    # will be set to either "true" or "false").
    #
    # Parameters:
    #
    #   1: File name (of the file referenced by the submission XML)
    #   2: Schema (of that file)

    if ! curl --fail --insecure \
        -o "$data_dir"/submission-response.xml \
        -F "SUBMISSION=@$data_dir/submission.xml" \
        -F "${2^^}=@$data_dir/$1" \
        "$ENA_TEST_URL?auth=ENA%20$username%20$password"
    then
        printf "curl failed to submit '%s'\n" "$1" >&2
        exit 1
    fi

    # TODO: Parse reply, put IDs in state XML (if successful).
}

# vim: ft=sh
