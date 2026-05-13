#!/bin/bash

echo "Detecting OS and installing packages required for PSP SDK"

UNAME_S="$(uname -s)"

# Handle MSYS2 / MinGW on Windows. uname reports MSYS_NT-*, MINGW64_NT-*,
# MINGW32_NT-*, or UCRT64_NT-* depending on the active subsystem. We always
# install packages from the MSYS shell namespace ("pacman -S <name>", no
# mingw-w64- prefix), because the toolchain build scripts run under bash and
# expect a POSIX-like host environment, not a mingw cross environment.
if [ "${UNAME_S:0:5}" = "MINGW" ] || [ "${UNAME_S:0:5}" = "MSYS_" ] || [ "${UNAME_S:0:6}" = "UCRT64" ]; then
  if ! command -v pacman >/dev/null 2>&1; then
    echo "ERROR: pacman not found. Install MSYS2 (https://www.msys2.org/) and run prepare.sh from an MSYS2 shell."
    exit 1
  fi

  echo "Detected MSYS2 / MinGW on Windows; installing host build dependencies via pacman"

  # MSYS2 namespace packages used to build the cross toolchain.
  # gcc/g++/make/binutils/etc. live under base-devel + msys/gcc.
  # NOT in the list (deliberate):
  #   - gpgme: only used by psp-pacman, which is skipped on Windows; also
  #     filtered out of devkitPro's bundled MSYS2 repos.
  #   - libusb: only used by pspsh / usbhostfs_pc, which are skipped on
  #     MINGW upstream; also filtered out of devkitPro's bundled MSYS2.
  #   - gmp / mpfr / mpc runtime libs: pulled in transitively by the
  #     corresponding -devel packages, no need to list separately.
  #
  # `--overwrite='/usr/share/info/*'` works around the autoconf/automake
  # version-bump trap: autoconf2.72 and autoconf2.73 both claim
  # /usr/share/info/autoconf.info.gz, and devkitPro's MSYS2 typically ships
  # an older autoconf version than the current upstream repos. Same for
  # automake1.17 vs 1.18 etc. .info files are documentation-only, so
  # overwriting them is safe; the freshly-installed version ships its own.
  pacman -S --needed --noconfirm --overwrite='/usr/share/info/*' \
    base-devel \
    git \
    patch \
    wget \
    tar \
    unzip \
    gcc \
    autoconf \
    automake \
    libtool \
    bison \
    flex \
    gettext \
    texinfo \
    pkgconf \
    cmake \
    python \
    python-pip \
    gmp-devel \
    mpfr-devel \
    mpc-devel \
    libarchive-devel \
    openssl-devel \
    ncurses-devel \
    libreadline-devel \
    zlib-devel \
    libtre-devel \
    gawk \
    diffutils \
    file \
    which || { echo "ERROR: pacman install failed"; exit 1; }

  # `gpgme-tool` is part of the upstream gpgme source release but is not built
  # in MSYS2's gpgme package. depends/check-dependencies.sh will complain.
  # The pspdev build does not actually invoke gpgme-tool at runtime; the check
  # is conservative. See I:\pspdev-win\README.md ("Known blockers") for the
  # current workaround.

  # MSYS2's `python` package historically only ships /usr/bin/python (a real
  # binary linked to python3.x); /usr/bin/python3 and /usr/bin/pip3 are not
  # guaranteed across package revisions. check-dependencies.sh greps for
  # python3 / pip3 specifically, so symlink them in if missing.
  if command -v python >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
    ln -sf /usr/bin/python /usr/bin/python3
  fi
  if command -v pip >/dev/null 2>&1 && ! command -v pip3 >/dev/null 2>&1; then
    ln -sf /usr/bin/pip /usr/bin/pip3
  fi

  echo "MSYS2 dependencies installed. Note: gpgme-tool is not packaged for MSYS2 (see README)."
  exit 0
fi

# Handle macOS first
if [ "$UNAME_S" = "Darwin" ]; then
  ## Check if using brew
  if command -v brew &> /dev/null; then
    brew update
    brew install \
    gettext texinfo bison \
    flex gnu-sed ncurses \
    gsl gmp mpfr \
    autoconf automake cmake \
    libusb libarchive gpgme \
    bash openssl libtool \
    zlib libmpc
    brew reinstall openssl # https://github.com/Homebrew/homebrew-core/issues/169728#issuecomment-2074958306
  fi
  ## Check if using MacPorts
  if command -v port &> /dev/null; then
    sudo port install autoconf automake cmake doxygen gsed libelf libtool pkgconfig
  fi
else
    if [ "$EUID" != 0 ]; then
        echo "Elevating to root so packages can be installed"
        sudo "$0"
        exit $?
    fi

    TESTOS=$(cat /etc/os-release | grep -w "ID" | cut -d '=' -f2 | tr -d '"')

    case $TESTOS in

    ubuntu | linuxmint | debian | pop)
        apt-get update
        apt-get -y install texinfo bison flex gettext libgmp3-dev libmpfr-dev libmpc-dev libusb-1.0-0-dev libreadline-dev libcurl4 \
        libcurl4-openssl-dev libssl-dev libarchive-dev libgpgme-dev python3-pip python3-venv cmake libncurses-dev automake pkg-config \
        wget libtool libz-dev
    ;;
    rhel | fedora)
         dnf -y install @development-tools gcc gcc-c++ g++ wget git autoconf automake python3 python3-pip make cmake pkgconf \
          libarchive-devel openssl-devel gpgme-devel libtool gettext texinfo bison flex gmp-devel mpfr-devel libmpc-devel ncurses-devel diffutils \
          libusb1-devel readline-devel libcurl-devel which glibc-gconv-extra xz gawk file
    ;;
    gentoo)
        emerge --noreplace net-misc/wget dev-vcs/git dev-python/pip sys-apps/fakeroot \
                                        app-arch/libarchive app-crypt/gpgme sys-devel/bison sys-devel/flex\
                                        dev-libs/mpc dev-libs/libusb
    ;;
    arch | manjaro | endeavouros | cachyos)
        pacman -Sy gcc clang make cmake patch git texinfo flex bison gettext wget gsl gmp mpfr libmpc libusb readline libarchive gpgme bash openssl libtool boost python-pip
    ;;
    opensuse*)
      zypper install -y gcc gcc-c++ clang binutils patch make cmake bison flex gpgme libgpgme-devel libarchive-devel openssl libopenssl-devel ncurses ncurses-devel gmp-devel mpfr-devel mpc-devel \
      automake
    ;;
    *)
        echo "$TESTOS not supported here"
    ;;
    esac

fi
