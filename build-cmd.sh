#!/usr/bin/env bash

cd "$(dirname "$0")"

# turn on verbose debugging output for logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x
# make errors fatal
set -e
# bleat on references to undefined shell variables
set -u

top="$(pwd)"
stage="$top"/stage

VERSION="2.56.0"
SOURCE_DIR="${top}/glib-${VERSION}"

FFI_VERSION="3.3"
FFI_SOURCE_DIR="${top}/libffi-${FFI_VERSION}"

# load autobuild provided shell functions and variables
case "$AUTOBUILD_PLATFORM" in
    windows*)
        autobuild="$(cygpath -u "$AUTOBUILD")"
    ;;
    *)
        autobuild="$AUTOBUILD"
    ;;
esac
source_environment_tempfile="$stage/source_environment.sh"
"$autobuild" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

build=${AUTOBUILD_BUILD_ID:=0}
echo "${VERSION}.${build}" > "${stage}/VERSION.txt"

pushd "$SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in

        # ------------------------ windows, windows64 ------------------------
        windows*)
        ;;

        # ------------------------- darwin, darwin64 -------------------------
        darwin*)
			;;
        linux64)
			FLAGS="${AUTOBUILD_GCC_ARCH} $LL_BUILD_RELEASE -I${stage}/include -Wno-format-overflow"
			export CFLAGS="${FLAGS}" CXXFLAGS="${FLAGS}"
			export PKG_CONFIG_PATH=${stage}/lib/pkgconfig

			pushd ${FFI_SOURCE_DIR}
			autoreconf -fi
			# libffi does not seem to work well with --libdir, so those *.a need to be copied later
			./configure --enable-static --disable-shared --disable-docs --prefix=${stage}
			make -j `nproc` && make install && make distclean
			popd

			echo "Name: libpcre" > ${stage}/lib/pkgconfig/libpcre.pc
			echo "Description: PCRE library" >> ${stage}/lib/pkgconfig/libpcre.pc
			echo "Version: 8.35" >> ${stage}/lib/pkgconfig/libpcre.pc
			echo "Libs: -L${stage}/packages/lib/release -lpcre" >> ${stage}/lib/pkgconfig/libpcre.pc
			echo "Cflags: -I${stage}/packages/include/pcre" >> ${stage}/lib/pkgconfig/libpcre.pc

			autoreconf -fi
			./configure --enable-static --disable-shared --disable-selinux --disable-gtk-doc-html --disable-libmount  --prefix=${stage} --libdir="$stage/lib/release"
			make -j `nproc` && make install && make clean

			test -f ${stage}/lib/libffi.a && cp -a ${stage}/lib/libffi.* "$stage/lib/release/"
			test -f ${stage}/lib64/libffi.a && cp -a ${stage}/lib64/libffi.* "$stage/lib/release/"
        ;;
    esac
    mkdir -p "$stage/LICENSES"
    cp COPYING "$stage/LICENSES/glib.txt"
popd

