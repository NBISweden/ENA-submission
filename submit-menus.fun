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
                    if yesno; then
                        make_submission "$file" "${XML_FILES[$file]}"
                    fi

                    break ;;    # to re-display the menu
            esac
        done

    done
}

function yesno
{
    # Get a simple yes/no from the user.  Default answer is 'no' (1).
    #
    # Parameters: none
    #
    #   stdin:  none
    #   stdout: none
    #
    #   Returns 1 (no) or 0 (yes).
    #
    #   Example:
    #       if yesno; then echo "got 'yes'"; else echo "got 'no'"; fi

    echo -n "Yes/[N]o > "
    read -r

    if [[ "$REPLY" =~ ^[Yy] ]]; then
        return 0
    fi

    return 1
}

function upload_menu
{
    # Will conditionally upload the given data file to the ENA FTP server.

    true
}


# vim: ft=sh
