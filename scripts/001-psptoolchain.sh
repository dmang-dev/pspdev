#!/bin/bash
# psptoolchain.sh by fjtrujy

## Download the source code.
REPO_URL="https://github.com/pspdev/psptoolchain"
REPO_FOLDER="psptoolchain"
BRANCH_NAME="master"
if test ! -d "$REPO_FOLDER"; then
	git clone --depth 1 -b $BRANCH_NAME $REPO_URL && cd $REPO_FOLDER || { exit 1; }
else
	cd $REPO_FOLDER && git fetch origin && git reset --hard origin/${BRANCH_NAME} || { exit 1; }
fi

## Build and install.
case "$(uname)" in
  MINGW*|MSYS_*|UCRT64*)
    # Windows/MSYS2: build the allegrex cross toolchain, then build
    # psptoolchain-extra WITHOUT psp-pacman.
    #
    # psp-pacman compiles fine under MSYS2, but its meson *install* step runs
    #   mkdir -p "$DESTDIR/<abs-path>"
    # and with an empty DESTDIR that yields a leading "//", which MSYS2 treats
    # as a UNC network path -> "cannot create directory '//i': Read-only file
    # system". Upstream already intends to skip psp-pacman on Windows (its
    # 001-psp-pacman.sh exit 0's on MINGW) -- it just doesn't catch the
    # MSYS_NT uname string. psp-pacman is unused on the Windows port anyway:
    # scripts/003-psp-packages.sh skips package install on MSYS2.
    #
    # psptoolchain-extra/build-all.sh takes step numbers; "2 3" runs
    # 002-psp-pkg-config.sh + 003-psp-cmake.sh and skips 001-psp-pacman.sh.
    ./toolchain.sh 1 || { exit 1; }   # 001-allegrex.sh -- the cross toolchain

    cd build || { echo "ERROR: psptoolchain/build missing"; exit 1; }
    EXTRA_URL="https://github.com/pspdev/psptoolchain-extra"
    if test ! -d psptoolchain-extra; then
      git clone "$EXTRA_URL" -b main || exit 1
    fi
    ( cd psptoolchain-extra \
        && git fetch origin \
        && git reset --hard origin/main \
        && git checkout main \
        && ./build-all.sh 2 3 ) || { exit 1; }
    ;;
  *)
    ./toolchain.sh || { exit 1; }
    ;;
esac
