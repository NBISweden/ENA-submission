# Bash shell functions that drives the menus.

function main_menu
{
    # Main menu (also, main loop).

    while true; do

        select actn in \
            "Exit" \
            "Submit an XML file" \
            "Upload a data file"
        do
            case "$REPLY" in
                1)  exit 0  ;;
                2)  submit_menu
                    break   ;;
                3)  upload_menu
                    break   ;;
            esac
        done

    done
}

function submit_menu
{
    # Menu for submitting a single XML file.

    # Examine the XML files in $data_dir to figure out what they are.
    # Creates the associative array xml_files with file names as keys and
    # the top-level XML element as values.

    declare -A xml_files
    declare -a choices

    for f in "$data_dir"/*.xml; do
        local f_basename="$( basename "$f" )"
        local f_type="$( xmlstarlet el "$f" | head -n 1 )"
        xml_files["$f_basename"]="$f_type"
        choices+=( "$( printf "Submit '%s' (%s)" "$f_basename" "$f_type" )" )
    done

    select file in \
        "Back" \
        "${choices[@]}"
    do
        case "$REPLY" in
            1)  break   ;;
        esac
    done

}

# vim: ft=sh
