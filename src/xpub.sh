#!/usr/bin/env bash
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
    echo -e "Usage: xpub [OPTION]...\n\n
Options:\n\n
Information:\n
  none:\tPrints X environment based on the current tty
  -t:\tPrints X environment based on the TTY\n
Miscellaneous:\n
  -h:\tPrints this help and exits
  -v:\tPrints version and exits"
}

version() {
    echo -e "xpub 0.1
Copyright (C) 2016 Thomas \"Ventto\" Venries.
License MIT.
THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.\n"
}

main () {
    local tFlag=false
    local tArg

    OPTIND=1
    while getopts "hvt:" opt; do
        case $opt in
            t)  ! [[ "${OPTARG}" =~ ^tty[0-9]$ ]] && usage && exit 2
                tArg=${OPTARG}
                tFlag=true ;;
            h)  usage   && exit ;;
            v)  version && exit ;;
            \?) usage   && exit ;;
            :)  usage   && exit ;;
        esac
    done

    if [ "$(id -u)" != "0" ]; then
        echo "Run it with sudo."
        exit 1
    fi

    local xtty

    ${tFlag} && xtty=${tArg} || xtty=$(cat /sys/class/tty/tty0/active)

    local xuser=$(who | grep ${xtty} | head -n 1 | cut -d ' ' -f 1)

    if [ -z "${xuser}" ]; then
        echo "No user found from ${xtty}."
        exit 1
    fi

    xdisplay=$(ps -o command -p $(pgrep Xorg) | grep " vt${xtty:3:${#tty}}" | \
        grep -o ":[0-9]" | head -n 1)

    if [ -z "${xdisplay}" ] ; then
        echo "No X process found from ${xtty}."
        exit 1
    fi

    for pid in $(ps -u ${xuser} -o pid --no-headers) ; do
        env="/proc/${pid}/environ"
        display=$(grep -z "^DISPLAY=" ${env} | tr -d '\0' | cut -d '=' -f 2)
        if [ -n "${display}" ] ; then
            dbus=$(grep -z "DBUS_SESSION_BUS_ADDRESS=" ${env} | tr -d '\0' | \
                sed 's/DBUS_SESSION_BUS_ADDRESS=//g')
            if [ -n ${dbus} ] ; then
                xauth=$(grep -z "XAUTHORITY=" ${env} | tr -d '\0' | \
                    sed 's/XAUTHORITY=//g')
                break
            fi
        fi
    done

    if [ -z "${dbus}" ] ; then
        echo "No session bus address found."
        exit 1
    elif [ -z "${xauth}" ] ; then
        echo "No Xauthority found."
        exit 1
    fi

    if ! $tFlag ; then
        echo -e "TTY=${xtty}\nXUSER=${xuser}\nXAUTHORITY=${xauth}"
    else
        echo -e "XUSER=${xuser}\nXAUTHORITY=${xauth}"
    fi
    echo -e "DISPLAY=${display}\nDBUS_SESSION_BUS_ADDRESS=${dbus}"
}

main "$@"