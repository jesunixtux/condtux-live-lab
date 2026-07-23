#!/bin/sh

CONDTUX_XFCE_PREFIX="/opt/xfce-4.20"

if [ -d "$CONDTUX_XFCE_PREFIX" ]; then
    case ":${PATH:-}:" in
        *":$CONDTUX_XFCE_PREFIX/bin:"*) ;;
        *) PATH="$CONDTUX_XFCE_PREFIX/bin:${PATH:-/usr/local/bin:/usr/bin:/bin}" ;;
    esac

    XDG_CONFIG_DIRS="/etc/xdg:$CONDTUX_XFCE_PREFIX/etc/xdg${XDG_CONFIG_DIRS:+:$XDG_CONFIG_DIRS}"
    XDG_DATA_DIRS="$CONDTUX_XFCE_PREFIX/share:/usr/local/share:/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
    LD_LIBRARY_PATH="$CONDTUX_XFCE_PREFIX/lib:$CONDTUX_XFCE_PREFIX/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    GI_TYPELIB_PATH="$CONDTUX_XFCE_PREFIX/lib/girepository-1.0:$CONDTUX_XFCE_PREFIX/lib/x86_64-linux-gnu/girepository-1.0${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"

    export PATH XDG_CONFIG_DIRS XDG_DATA_DIRS LD_LIBRARY_PATH GI_TYPELIB_PATH
fi

export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_DESKTOP=xfce
export DESKTOP_SESSION=condtux-xfce
