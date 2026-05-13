#!/bin/bash
# psp-packages by fjtrujy

OSVER=$(uname)
IS_WINDOWS=0
if [ "${OSVER:0:5}" = "MINGW" ] || [ "${OSVER:0:5}" = "MSYS_" ] || [ "${OSVER:0:6}" = "UCRT64" ]; then
	IS_WINDOWS=1
fi

if [ "$IS_WINDOWS" = "1" ] && [ -z "$LOCAL_PACKAGE_BUILD" ]; then
	# psp-pacman is not (yet) buildable on MSYS2 (see psptoolchain-extra
	# scripts/001-psp-pacman.sh which exits 0 on MINGW). Without psp-pacman
	# the binary package install path is unavailable on Windows.
	#
	# Options for the user:
	#   1. Skip extra packages (default here). The core toolchain still works
	#      for building PSP homebrew that only needs binutils/gcc/newlib/pspsdk.
	#   2. Re-run with LOCAL_PACKAGE_BUILD=1 to attempt building packages from
	#      source via psp-packages/build.sh.
	echo "[windows-port] Skipping psp-packages install on MSYS2: psp-pacman not available."
	echo "[windows-port] Re-run with LOCAL_PACKAGE_BUILD=1 to build packages from source."
	exit 0
fi

if [ -z "$LOCAL_PACKAGE_BUILD" ]; then
	# Install all packages
	psp-pacman -Sy && psp-pacman -S --noconfirm pspdev-default || { exit 1; }
else
	## Download the source code.
	REPO_URL="https://github.com/pspdev/psp-packages"
	REPO_FOLDER="psp-packages"
	BRANCH_NAME="master"
	if test ! -d "$REPO_FOLDER"; then
		git clone --depth 1 -b $BRANCH_NAME $REPO_URL && cd $REPO_FOLDER || { exit 1; }
	else
		cd $REPO_FOLDER && git fetch origin && git reset --hard origin/${BRANCH_NAME} || { exit 1; }
	fi

	# Build and install the packages
	./build.sh --install
fi
