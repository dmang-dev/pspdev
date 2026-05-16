#!/bin/bash
# psplinkusb by fjtrujy

## Download the source code.
REPO_URL="https://github.com/pspdev/psplinkusb"
REPO_FOLDER="psplinkusb"
BRANCH_NAME="master"
if test ! -d "$REPO_FOLDER"; then
	git clone --depth 1 -b $BRANCH_NAME $REPO_URL && cd $REPO_FOLDER || { exit 1; }
else
	cd $REPO_FOLDER && git fetch origin && git reset --hard origin/${BRANCH_NAME} || { exit 1; }
fi

## Determine the maximum number of processes that Make can work with.
PROC_NR=$(getconf _NPROCESSORS_ONLN)
OSVER=$(uname)

## Compile and install.
make --quiet -j $PROC_NR clean          			|| { exit 1; }
make --quiet -j $PROC_NR all            			|| { exit 1; }
# pspsh / usbhostfs_pc are the PC-side USB host-link debug tools. They link
# libusb. MSYS2's msys namespace does NOT ship libusb (it needs native
# WinUSB driver access — only mingw-w64-* libusb packages exist). Building
# pspsh/usbhostfs_pc as MSYS-hosted binaries therefore can't work; they need
# to be built as standalone MinGW binaries against the mingw-w64 libusb.
# That's a real design change (mixed MSYS-cygwin + MinGW build), tracked at
# dmang-dev/pspdev-win#2.
case "$OSVER" in
	MINGW*|MSYS_*|UCRT64*)
		echo "[windows-port] Skipping pspsh / usbhostfs_pc on $OSVER -- needs MinGW build, see dmang-dev/pspdev-win#2"
		;;
	*)
		make --quiet -j $PROC_NR -C pspsh install 			|| { exit 1; }
		make --quiet -j $PROC_NR -C usbhostfs_pc install 	|| { exit 1; }
		;;
esac

## Store build information
BUILD_FILE="${PSPDEV}/build.txt"
if [[ -f "${BUILD_FILE}" ]]; then
  sed -i'' '/^psplinkusb /d' "${BUILD_FILE}"
fi
git log -1 --format="psplinkusb %H %cs %s" >> "${BUILD_FILE}"
