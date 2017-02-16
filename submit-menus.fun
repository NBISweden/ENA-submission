# Bash shell functions that drives the menus.

function main_menu
{
    # Main menu (also, main loop).

    while true; do

        cat <<MENU_INFO_END
    ========================================================================
                            You're at the MAIN menu.
         At any time, just press enter to re-display the current menu.
    ========================================================================
MENU_INFO_END

        select thing in \
            "Exit" \
            "Submit an XML file" \
            "Replace locus tags in data file with biosample IDs" \
            "Upload a data file" \
            "Display current state of submissions"
        do
            case "$REPLY" in
                1)  exit 0  ;;
                2)  submit_menu
                    break   ;;
                3)  modify_data_menu
                    break   ;;
                4)  upload_menu
                    break   ;;
                5)  display_state
                    break   ;;
            esac
        done

    done
}

function submit_menu
{
    # Menu for submitting a single XML file.

    local -a choices
    local -a files

    # Make menu from available XML files.

    for f in "${!XML_FILES[@]}"; do
        choices+=( "$( printf 'Submit "%s" (%s)' "$f" "${XML_FILES[$f]}" )" )
        files+=( "$f" )
    done

    while true; do

        cat <<MENU_INFO_END
    ------------------------------------------------------------------------
                           You're at the SUBMIT menu.
         At any time, just press enter to re-display the current menu.
    ------------------------------------------------------------------------
MENU_INFO_END

        select thing in \
            "Go back to the main menu" \
            "${choices[@]}"
        do
            case "$REPLY" in
                1)  return   ;;
                *)  if [[ -z "$thing" ]]; then
                        # Not a valid choice
                        echo "Try again"
                        break
                    fi

                    local file="${files[$((REPLY - 2))]}"
                    printf 'Submit "%s"?\n' "$file"
                    if yesno; then
                        make_submission "$file" "${XML_FILES[$file]}"
                    fi

                    break ;;    # to re-display the menu
            esac
        done

    done
}

function upload_menu
{
    # Will conditionally upload the given data file to the ENA FTP server.

    if [[ -z "$DATA_FILE" ]]; then
        echo "ERROR: No data file was given on the command line"
        return
    fi

    while true; do
        cat <<MENU_INFO_END
    ------------------------------------------------------------------------
                           You're at the UPLOAD menu.
         At any time, just press enter to re-display the current menu.
    ------------------------------------------------------------------------
MENU_INFO_END

        select thing in \
            "Go back to the main menu" \
            "Submit the data file '$DATA_FILE'"
        do
            case "$REPLY" in
                1)  return  ;;
                2)  make_upload ;;
            esac
        done
    done
}

function modify_data_menu
{
    # Will offer to replace the locus tag in the sample XML file with
    # the biosample IDs received from the ENA.

    if [[ -z "$DATA_FILE" ]]; then
        echo "ERROR: No data file was given on the command line"
        return
    fi

    # Get the sample XML file name(s)
    local -a files=( $( get_value '//file[@type = "SAMPLE_SET"]/@name' <"$STATE_XML" ) )

    while true; do
        cat <<MENU_INFO_END
    ------------------------------------------------------------------------
                        You're at the MODIFY DATA menu.
         At any time, just press enter to re-display the current menu.
    ------------------------------------------------------------------------
MENU_INFO_END

        select thing in "${files[@]}"
        do
            echo "$REPLY"
        done

        # TODO: implement this
        return
    done
}

# vim: ft=sh
