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
    # psp-pacman (with our destdir patch) followed by psptoolchain-extra
    # steps 2+3 (pkg-config + cmake).
    #
    # Historical context: upstream pacman's meson.build does
    #   meson.add_install_script('sh', '-c', 'mkdir -p "$DESTDIR/@0@"'...)
    # which yields "//<abs-path>" when DESTDIR is empty. Linux mkdir treats
    # "//" like "/", but MSYS2/Cygwin interpret "//" as a UNC share prefix
    # and fail with "cannot create directory '//i': Read-only file system".
    # patches/psp-pacman/fix-destdir-double-slash.patch corrects this by
    # dropping the slash between $DESTDIR and the absolute path -- a
    # one-character fix that is the standard Autotools-era pattern and is
    # equivalent on Linux/macOS.
    #
    # We can't just run psptoolchain-extra's 001-psp-pacman.sh because
    # (a) upstream short-circuits it with `exit 0` on MINGW (and that check
    # ends up matching our MINGW64_NT uname), and (b) we need to inject our
    # patch into the cloned psp-pacman tree before pacman.sh runs.
    ./toolchain.sh 1 || { exit 1; }   # 001-allegrex.sh -- the cross toolchain

    cd build || { echo "ERROR: psptoolchain/build missing"; exit 1; }

    # --- Build psp-pacman with our patches ---------------------------
    PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/patches/psp-pacman"
    if [ ! -d "$PATCH_DIR" ]; then
      echo "ERROR: patch directory not found at $PATCH_DIR"
      exit 1
    fi

    if test ! -d psp-pacman; then
      git clone https://github.com/pspdev/psp-pacman --depth 1 || exit 1
    fi
    (
      cd psp-pacman || exit 1
      cp "$PATCH_DIR"/*.patch patches/
      # Inject our apply_patch lines into pacman.sh, after the existing
      # apply_patch for 147. Guard with grep so re-runs don't dup.
      #   - fix-destdir-double-slash: unblocks `ninja install` on MSYS2
      #     (the "//" UNC bug)
      #   - fix-syshookdir-doubled-prefix: cleans up runtime Hook Dirs
      #     listing when prefix != / (a cosmetic verbose-output bug)
      if ! grep -q 'apply_patch fix-destdir-double-slash' pacman.sh; then
        sed -i '/^apply_patch 147/a apply_patch fix-destdir-double-slash' pacman.sh
      fi
      if ! grep -q 'apply_patch fix-syshookdir-doubled-prefix' pacman.sh; then
        sed -i '/^apply_patch fix-destdir-double-slash/a apply_patch fix-syshookdir-doubled-prefix' pacman.sh
      fi
      ./pacman.sh
    ) || { exit 1; }

    # --- Then psptoolchain-extra pkg-config + cmake ------------------
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
