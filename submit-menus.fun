# Bash shell functions that drives the menus.

function main_menu
{
    # Main menu (also, main loop).

    while true; do

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

    for f in "${!xml_files[@]}"; do
        choices+=( "$( printf "Submit '%s' (%s)" "$f" "${xml_files[$f]}" )" )
        files+=( "$f" )
    done

    select thing in \
        "Go back to main menu" \
        "${choices[@]}"
    do
        case "$REPLY" in
            1)  break   ;;
            *)  if (( REPLY - 1 > ${#files[@]})); then
                    echo "Try again"
                else
                    local file="${files[$((REPLY - 2))]}"
                    printf "Submit '%s'?\n" "$file"
                    if [[ $( yesno_menu ) == "yes" ]]; then
                        make_submission "$file" "${xml_files[$file]}"
                    fi
                fi ;;
        esac
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

    local response

    while true; do
        printf "[Y]es/[N]o? > " >&2
        read -r response

        if [[ "$response" =~ ^[yY] ]]; then
            echo "yes"
            return
        elif [[ "$response" =~ ^[nN] ]]; then
            echo "no"
            return
        fi
    done
}

# vim: ft=sh
