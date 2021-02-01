#!/bin/sh
#
# The MIT License (MIT)
#
# Copyright (c) 2015-2016 Thomas "Ventto" Venriès <thomas.venries@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
usage() {
    printf '%s\n' 'Usage: xpub [-t TTY]

  -h:    Prints this help and exits.
  -v:    Prints the version and exits.
  -t:    Prints the logged user and its display environment variables
         from a graphical-session TTY or from the current one if no argument.'
}

version() {
    printf '%s\n' 'Xpub 0.6b

Copyright (C) 2016 Thomas "Ventto" Venries.

License MIT: <https://opensource.org/licenses/MIT>.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.'
}

main () {
    isXWayland=false
    tFlag=false

    while getopts 'hvt:' opt; do
        case $opt in
            t)  OPTARG="$(printf '%s' "$OPTARG" | tr '[:upper:]' '[:lower:]')"
                if ! printf '%s' "$OPTARG" | grep -E '^tty[0-9]$' > /dev/null; then
                    usage ; exit 2
                fi
                tArg="$OPTARG"
                tFlag=true     ;;
            h)  usage   ; exit ;;
            v)  version ; exit ;;
            \?) usage   ; exit ;;
            :)  usage   ; exit ;;
        esac
    done

    shift $((OPTIND - 1))

    [ "$(id -u)" -ne 0 ] && { printf 'Run it with sudo.\n'; exit 1; }

    $tFlag && xtty="$tArg" || read -r xtty </sys/class/tty/tty0/active

    xuser=$(who | awk -v xtty="$xtty" '$0~xtty {print $1; exit}')

    [ -z "$xuser" ] && { printf '%s\n' "No user found from $xtty." 1>&2; exit 1; }

    xpids=$(pgrep Xorg)
    vterm="vt${xtty#tty}"

    if [ -n "$xpids" ]; then
        for xpid in $xpids; do
            xdisplay=$(ps -o cmd= "$xpid" | grep "$vterm" | grep -Eo ':[0-9]')
            if [ "$?" -eq 0 ]; then
                xdisplay=$(printf '%s' "$xdisplay" | head -n1)
                break
            fi
        done
    fi

    if [ -z "$xdisplay" ]; then
        #Trying to get the active display from XWayland
        xdisplay=$(ps -A -o tty= -o cmd= | grep Xwayland |
            grep -v 'grep' | awk -v xtty="$xtty" '$0~xtty {print $3}')

        if [ -z "$xdisplay" ]; then
            printf '%s\n' "No X or XWayland process found from $xtty."
            exit 1
        fi

        isXWayland=true
    fi

    for pid in $(ps -u "$xuser" -o pid=); do
        env="/proc/$pid/environ"
        display=$(tr '\0' '\n' <$env | grep -E '^DISPLAY=' | cut -d= -f2)

        if [ -z "$display" ] || [ "$display" != "$xdisplay" ]; then
            continue
        fi

        dbus=$(tr '\0' '\n' <$env | grep -E '^DBUS_SESSION_BUS_ADDRESS=')

        if [ -n "$dbus" ]; then
            ! $isXWayland && xauth=$(tr '\0' '\n' <$env | grep -E '^XAUTHORITY=')
            break
        fi
    done

    if [ -z "$dbus" ]; then
        printf 'No session bus address found.\n' 1>&2
        exit 1
    fi

    # XWayland does not need Xauthority
    if ! $isXWayland && [ -z "$xauth" ]; then
        if [ ! -r "/home/$xuser/.Xauthority" ]; then
            printf 'No Xauthority found.\n' 1>&2
            exit 1
        fi
        xauth="XAUTHORITY=/home/$xuser/.Xauthority"
    fi

    $tFlag && printf '%s\n' "XUSER=$xuser" || printf '%s\n%s\n' "TTY=$xtty" "XUSER=$xuser"
    ! $isXWayland && printf '%s\n' "$xauth"

    printf '%s\n%s' "DISPLAY=$xdisplay" "$dbus"
}

main "$@"
