# Bash shell functions handling XML.
#
# Example:  The following returns "ok"
#
#   init_xml hello |
#   add_elem '/hello' 'world' |
#   add_attr '//world' 'done' '1' |
#   set_value '/hello/world/@done' 'ok' |
#   get_value '/hello/world/@done'


#-----------------------------------------------------------------------
# Functions for adding things to XML.
#-----------------------------------------------------------------------

function init_xml
{
    # Creates an XML stream on stdout containing an empty element.
    #
    # Parameters:
    #
    #   1:  Root element name
    #
    #   stdin:  none
    #   stdout: XML

    printf "<%s />" "$1"
}

function add_elem
{
    # Adds an element and its value.
    #
    # Parameters:
    #
    #   1: XPath
    #   2: Element name
    #   3: Element value (optional)
    #
    #   stdin:  XML
    #   stdout: XML

    xmlstarlet ed -s "$1" -t elem -n "$2" -v "$3"
}

function add_attr
{
    # Adds an attribute and its value.
    #
    # Parameters:
    #
    #   1: XPath
    #   2: Attribute name
    #   3: Attribute value (optional)
    #
    #   stdin:  XML
    #   stdout: XML

    xmlstarlet ed -i "$1" -t attr -n "$2" -v "$3"
}

#-----------------------------------------------------------------------
# Functions for getting things from XML.
#-----------------------------------------------------------------------

function get_value
{
    # Gets the value of an attribute or element (depending on the given
    # XPath).
    #
    # Parameters:
    #
    #   1: XPath
    #
    #   stdin:  XML
    #   stdout: value

    xmlstarlet sel -t -v "$1" -nl
}

#-----------------------------------------------------------------------
# Functions for modifying things in XML.
#-----------------------------------------------------------------------

function set_value
{
    # Sets the value of an attribute or element (depending on the given
    # XPath).
    #
    # Parameters:
    #
    #   1: XPath
    #   2: value (optional)
    #
    #   stdin:  XML
    #   stdout: XML

    xmlstarlet ed -u "$1" -v "$2"
}

# vim: ft=sh
