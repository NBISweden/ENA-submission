# Bash shell functions that trives the menus.

function do_main_menu
{
    # Main menu.

    select actn in \
        "Submit an XML file" \
        "Upload a flat file" \
        "Exit"
    do
        case "$REPLY" in
            1)  do_submit_menu  ;;
            2)  do_upload_menu  ;;
            3)  exit 0  ;;
        esac
    done
}
# vim: ft=sh
