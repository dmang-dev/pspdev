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
# Windows currently can't compile pspsh / usbhostfs_pc (they need a
# Linux-flavoured libusb). Upstream gates these on "${OSVER:0:5}" != MINGW,
# but under the MSYS2 *MSYS* shell uname reports "MSYS_NT-..." (not MINGW*),
# so the original check would still try -- and fail -- to build them.
# Skip the host debug-link tools on MINGW*, MSYS_* and UCRT64* alike.
case "$OSVER" in
	MINGW*|MSYS_*|UCRT64*)
		echo "[windows-port] Skipping pspsh / usbhostfs_pc (host USB tools) on $OSVER"
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
