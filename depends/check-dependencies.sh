#!/bin/bash

function check_library
{
    pkg-config --exists "$1"
    if [ $? -eq 0 ]; then
        return 0
    else
        missing_depends+=($1); return 1
    fi
}

function check_program
{
    which "$1" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        return 0
    else
        missing_depends+=($1); return 1
    fi
}

check_program   which
check_program   git
check_program   patch
check_program   autoconf
check_program   automake
check_program   make
check_program   cmake
check_program   gcc
check_program   g++
check_program   bison
check_program   flex
check_program   python3
check_program   pip3

# gpgme-tool is a command-line wrapper around libgpgme. psp-pacman links
# libgpgme directly (via libgpgme-devel installed in prepare.sh) and does
# not need the gpgme-tool binary at runtime. MSYS2 ships libgpgme but not
# the gpgme-tool binary, so we skip this check on MSYS2/MINGW.
UNAME_S="$(uname)"
case "$UNAME_S" in
    MINGW*|MSYS_*|UCRT64*)
        : ;; # skip on Windows
    *)
        check_program gpgme-tool ;;
esac

# macOS uses its own fork of libtool
case "$UNAME_S" in
    Darwin) check_program glibtoolize ;;
    *)      check_program libtoolize ;;
esac

check_library   libarchive
check_library   openssl         
check_library   ncurses

if [ ${#missing_depends[@]} -ne 0 ]; then
    echo "Couldn't find dependencies:"
    for dep in "${missing_depends[@]}"; do
        echo "  - $dep"
    done
	exit 1
fi
