#!/bin/bash

usage()
{
    echo "Usage: $0 \
        [-h arm-none-linux] \
        [-p <PREFIX>] \
        [-b <BUILD_DIR>] \
        [-j 4] \
        [-s build|trim|pack]" 1>&2
    exit 1
}

while getopts ":h:p:b:j:s:" o; do
    case "${o}" in
        h) HOST=$OPTARG ;;
        p) PREFIX=$OPTARG ;;
        b) BUILD_DIR=$OPTARG ;;
        j) JOBS=$OPTARG ;;
        s) STAGE=$OPTARG ;;
        *) usage ;;
    esac
done
shift $((OPTIND-1))

SCRIPT_DIR=$(readlink -f $(dirname $0))
[ -z $HOST ] && HOST=arm-none-linux-gnueabi
[ -z $PREFIX ] && PREFIX=$SCRIPT_DIR/_install/$HOST
[ -z $BUILD_DIR ] && BUILD_DIR=$SCRIPT_DIR/build/$HOST
[ -z $JOBS ] && JOBS=4
[ -z $STAGE ] && STAGE=build

export MAKE=make
export CC=$HOST-gcc
export CXX=$HOST-g++
export CPP=$HOST-cpp
export AS=$HOST-as
export LD=$HOST-ld
export STRIP=$HOST-strip
RPATH='-Wl,-rpath,$$\ORIGIN:$$\ORIGIN/../lib'

do_build()
{
    echo -e "\033[32m($(date '+%Y-%m-%d %H:%M:%S')): Building $1\033[0m"
    $*
    echo -e "\033[32m($(date '+%Y-%m-%d %H:%M:%S')): Finished $1\033[0m"
}

do_build_with_configure()
{
    local name=$1
    local config_opts=$2
    local make_opts=$3
    local build=$BUILD_DIR/$name

    if [ -e $build ]; then
        $MAKE -C $build install
        echo -e "\033[32m($(date '+%Y-%m-%d %H:%M:%S')): Skip $1\033[0m"
        return
    fi

    echo -e "\033[32m($(date '+%Y-%m-%d %H:%M:%S')): Start building $1\033[0m"

    # autogen & configure
    if [ ! -e $SCRIPT_DIR/$name/configure ]; then
        pushd $SCRIPT_DIR/$name && ./autogen.sh && popd
    fi

    mkdir -p $build && pushd $build &&
        $SCRIPT_DIR/$name/configure $config_opts && popd

    if [ ! $? -eq 0 ]; then
        rm -rf $build
        echo -e "\033[32m($(date '+%Y-%m-%d %H:%M:%S')): Failed to configure $1\033[0m"
        return
    fi

    # make
    if [ -z "$make_opts" ]; then
        $MAKE -C $build -j$JOBS
    else
        $MAKE -C $build "$make_opts" -j$JOBS
    fi

    if [ ! $? -eq 0 ]; then
        rm -rf $build
        echo -e "\033[32m($(date '+%Y-%m-%d %H:%M:%S')): Failed to make $1\033[0m"
    else
        $MAKE -C $build install
        echo -e "\033[32m($(date '+%Y-%m-%d %H:%M:%S')): Finished $1\033[0m"
    fi
}

stage_build()
{
    git submodule init
    git submodule update

    do_build_with_configure binutils-gdb "--prefix=$PREFIX --host=$HOST" \
        "CFLAGS=-g -O2 -DHAVE_FCNTL_H -DHAVE_LIMITS_H"

    do_build_with_configure valgrind "--prefix=$PREFIX --host=${HOST/arm/armv7}"

    do_build_with_configure gperftools "--prefix=$PREFIX --host=${HOST} \
        --enable-libunwind"

    [ ! -e $BUILD_DIR/strace ] && cd strace && ./bootstrap && cd -
    do_build_with_configure strace "--prefix=$PREFIX --host=${HOST} \
        --enable-mpers=no"

    [ ! -e $BUILD_DIR/file ] && cd file && aclocal && autoheader && \
        libtoolize --force && automake --add-missing && autoconf
    do_build_with_configure file "--prefix=$PREFIX --host=${HOST} \
        LDFLAGS=$RPATH --enable-static --disable-shared"
}

stage_trim()
{
    pushd $PREFIX

    # Delete
    find lib \( -name '*.a' -or -name '*.la' \) -exec rm -f {} \;

    # Strip
    find bin -mindepth 1 -type f -exec $STRIP -s {} \; 2>/dev/null
    find lib -path lib/valgrind -name '*.so*' -type f -exec $STRIP -s {} \;

    # Valgrind
    find lib/valgrind/ -perm 0755 \
        ! -name '*core*' \
        ! -name '*memcheck*' \
        ! -name '*helgrind*' \
        -exec rm -f {} \;

    popd
}

stage_pack()
{
    pushd $PREFIX
    tar --transform 'flags=r;s#^#edt/#' -czvf edt-$HOST.tar.gz \
        share/misc/magic.mgc \
        lib \
        bin/elfedit \
        bin/file \
        bin/gdb* \
        bin/nm \
        bin/objdump \
        bin/readelf \
        bin/strace \
        bin/strings \
        bin/strip \
        bin/valgrind* \
        bin/vgdb
    popd
}

if [ "$STAGE" = build ]; then
    stage_build
    STAGE=trim
fi

if [ "$STAGE" = trim ]; then
    stage_trim
    STAGE=pack
fi

if [ "$STAGE" = pack ]; then
    stage_pack
fi
