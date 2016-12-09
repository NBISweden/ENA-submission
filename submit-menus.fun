# Bash shell functions that drives the menus.

function main_menu
{
    # Main menu (also, main loop).

    while true; do

        cat <<MENU_INFO_END
    ========================================================================
                            You're at the main menu.
         At any time, just press enter to re-display the current menu.
    ========================================================================
MENU_INFO_END

        select thing in \
            "Exit" \
            "Submit an XML file" \
            "Upload a data file" \
            "Display current state of submissions"
        do
            case "$REPLY" in
                1)  exit 0  ;;
                2)  submit_menu
                    break   ;;
                3)  upload_menu
                    break   ;;
                4)  display_state
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
        choices+=( "$( printf "Submit '%s' (%s)" "$f" "${XML_FILES[$f]}" )" )
        files+=( "$f" )
    done

    while true; do

        cat <<MENU_INFO_END
    ------------------------------------------------------------------------
                          You're at the 'submit' menu.
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
                    printf "Submit '%s'?\n" "$file"
                    if [[ $( yesno_menu ) == "yes" ]]; then
                        make_submission "$file" "${XML_FILES[$file]}"
                    fi

                    break ;;    # to re-display the menu
            esac
        done

    done
}

function yesno_menu
{
    # Get a simple yes/no from the user.
    #
    # Parameters: none
    #
    #   stdin:  none
    #   stdout: "yes" or "no"

    select opt in "Yes" "No"; do
        case "$REPLY" in
            1)  echo "yes"
                break   ;;
            2)  echo "no"
                break   ;;
        esac
    done
}

# vim: ft=sh
