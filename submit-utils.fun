# Bash shell utility functions.

function timestamp
{
    # Outputs a timestamp.
    # The timestamp will be on the form "YYYY-MM-DD hh:mm:ss", in the
    # UTC time zone.

    date -u +"%F %T"
}

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

    if [[ ! -f "$STATE_XML" ]]; then
        printf 'Can not find "%s".\n' "$STATE_XML"
        return
    fi

    echo "Current state:"
    cat "$STATE_XML"
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
        SAMPLE_SET)     submit_simple "$1" "sample"    ;;
        STUDY_SET)      submit_simple "$1" "study"     ;;
        ANALYSIS_SET)   submit_simple "$1" "analysis"   ;;
        *)
            printf 'Submissions of "%s" are currently not implemented\n' \
                "$2" >&2
            ;;
    esac
}

function submit_simple
{
    # Submits an XML file.
    #
    # Parameters:
    #
    #   1: File name
    #   2: Schema

    # See if this file has been submitted successfully before, in which
    # case the "action" must be "MODIFY" rather than "ADD".

    local submitted
    local action

    submitted="$( get_value "//file[@name='$1']/submission[@success='true']" <"$STATE_XML" )"

    if [[ -z "$submitted" ]]; then
        action="ADD"
    else
        action="MODIFY"
    fi

    # Create submission XML.

    local timestamp="$( timestamp )"

    init_xml "SUBMISSION" |
    add_attr "/SUBMISSION" "alias" "$USERNAME $timestamp" |
    add_attr "/SUBMISSION" "center_name" "$CENTER_NAME" |
    add_elem "/SUBMISSION" "ACTIONS" |
    add_elem "//ACTIONS" "ACTION" |
    add_elem "//ACTION" "$action" |
    add_attr "//$action" "source" "$1" |
    add_attr "//$action" "schema" "$2" >"$DATA_DIR"/submission.xml

    # Update the state XML

    tmpfile="$( mktemp )"

    add_elem "//file[@name='$1']" \
        "submission" "$USERNAME $timestamp" <"$STATE_XML" |
    add_attr "//file[@name='$1']/submission[last()]" \
        "action" "$action" >"$tmpfile"

    mv -f "$tmpfile" "$STATE_XML"

    process_submission "$1" "$2"
}

function process_submission
{
    # Submits the submission XML file created by submit_simple and
    # updates the state XML with the IDs that ENA gives us.  The state
    # XML will also hold the submission status (the attribute "success"
    # will be set to either "true" or "false").
    #
    # Parameters:
    #
    #   1: File name (of the file referenced by the submission XML)
    #   2: Schema (of that file)

    local response_xml
    response_xml="$DATA_DIR/submission-response.xml"

    if ! curl --fail --insecure \
        -o "$response_xml" \
        -F "SUBMISSION=@$DATA_DIR/submission.xml" \
        -F "${2^^}=@$DATA_DIR/$1" \
        "$ENA_TEST_URL?auth=ENA%20$USERNAME%20$PASSWORD"
    then
        printf 'curl failed to submit "%s"\n' "$1" >&2
        exit 1
    fi

    # TODO: Parse reply, put IDs in state XML (if successful).

    local success
    success="$( get_value "/RECEIPT/@success" <"$response_xml" )"

    local tmpfile
    tmpfile="$( mktemp )"
    trap 'rm -f "$tmpfile"' RETURN

    add_attr "//file[@name='$1']/submission[last()]" \
        "success" "$success" <"$STATE_XML" >"$tmpfile"

    echo "Informational messages:"
    get_value "//MESSAGES/INFO" <"$response_xml"

    if [[ "$success" != "true" ]]; then
        echo "The submission failed"
        echo "Errors:"
        get_value "//MESSAGES/ERROR" <"$response_xml"

        mv -f "$tmpfile" "$STATE_XML"

        return
    fi

    # Pick out the IDs from the response and store them in the state
    # XML.  Note that sample submissions also get a "biosample" ID in an
    # EXT_ID tag.

    local sub_accession
    local accession
    local alias
    local ext_id

    sub_accession="$( get_value "//SUBMISSION/@accession" <"$response_xml" )"
    accession="$( get_value "//${2^^}/@accession" <"$response_xml" )"
    alias="$( get_value "//${2^^}/@alias" <"$response_xml" )"
    ext_id="$( get_value "//${2^^}/EXT_ID/@accession" <"$response_xml" )"

    add_elem "//file[@name='$1']/submission[last()]" \
        "accession" "$alias" <"$tmpfile" |
    add_attr "//file[@name='$1']/submission[last()]/accession" \
        "ena" "$accession" |
    add_attr "//file[@name='$1']/submission[last()]/accession" \
        "ext" "$ext_id" |
    add_attr "//file[@name='$1']/submission[last()]" \
        "accession" "$sub_accession" >"$STATE_XML"
}

function make_upload
{

}


# vim: ft=sh
