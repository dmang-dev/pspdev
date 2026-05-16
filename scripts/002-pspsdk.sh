#!/bin/bash
# pspsdk.sh by fjtrujy

## Download the source code.
REPO_URL="https://github.com/pspdev/pspsdk"
REPO_FOLDER="pspsdk"
BRANCH_NAME="master"
if test ! -d "$REPO_FOLDER"; then
	git clone --depth 1 -b $BRANCH_NAME $REPO_URL && cd $REPO_FOLDER || { exit 1; }
else
	cd $REPO_FOLDER && git fetch origin && git reset --hard origin/${BRANCH_NAME} || { exit 1; }
fi

## Build and install pspsdk
./build-and-install.sh || { exit 1; }

## --- Windows post-install patches -------------------------------------
## Patch pspdev.cmake so it can derive PSPDEV from its own install path
## instead of relying on env-var or -D propagation. On Windows MSYS2,
## native cmake.exe filters arbitrary user env vars when launched from
## bash, and cmake's try_compile spawns child cmake processes that don't
## inherit parent -D flags either. Deriving PSPDEV from the file's own
## location (PSPDEV/psp/share/pspdev.cmake) sidesteps both issues.
case "$(uname)" in
  MINGW*|MSYS_*|UCRT64*)
    CMAKE_FILE="${PSPDEV}/psp/share/pspdev.cmake"
    if [ -f "$CMAKE_FILE" ] && ! grep -q 'CMAKE_CURRENT_LIST_DIR.*\.\./\.\.' "$CMAKE_FILE"; then
      echo "[windows-port] Patching pspdev.cmake to derive PSPDEV from install path"
      python3 - "$CMAKE_FILE" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read()
old = '''if(DEFINED ENV{PSPDEV})
    SET(PSPDEV $ENV{PSPDEV})
else()
    message(FATAL_ERROR "The environment variable PSPDEV needs to be defined.")
endif()'''
new = '''if(DEFINED ENV{PSPDEV})
    SET(PSPDEV $ENV{PSPDEV})
else()
    # Derive PSPDEV from this file's own install location:
    # PSPDEV/psp/share/pspdev.cmake -> PSPDEV is two dirs up.
    # Handles Windows MSYS2 where neither $ENV{PSPDEV} nor parent -D
    # flags propagate to try_compile child cmake invocations.
    get_filename_component(PSPDEV "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
endif()'''
if old in s:
    open(p, 'w').write(s.replace(old, new))
    print("  patched")
else:
    print("  WARN: expected block not found, skipping (already patched?)")
PYEOF
    fi
    ;;
esac
