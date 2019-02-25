#!/bin/bash

SCRIPT_DIR=$(readlink -f $(dirname $0))
BUILD_DIR=$SCRIPT_DIR/build
PREFIX=_install
HOST=arm-none-linux-gnueabi
JOBS=1
STAGE=build

export STAGING_DIR=$BUILD_DIR/stage
mkdir -p $STAGING_DIR

usage()
{
    echo "Usage: $0 [-h arm-none-linux] [-p /usr/local/] [-b ./build] [-j 4] [-s build|trim|pack]" 1>&2
    exit 1
}

while getopts ":h:p:b:j:s:" o; do
    case "${o}" in
        h)
            HOST=$OPTARG
            ;;
        p)
            PREFIX=$OPTARG
            ;;
        b)
            BUILD=$OPTARG
            ;;
        j)
            JOBS=$OPTARG
            ;;
        s)
            STAGE=$OPTARG
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

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
    local finish=$BUILD_DIR/finish-$name

    if [ -e $build ] && [ -e $finish ] && [ `cat $finish` -eq 1 ]; then
        echo -e "\033[32m($(date '+%Y-%m-%d %H:%M:%S')): Skip $1\033[0m"
        return
    fi

    echo -e "\033[32m($(date '+%Y-%m-%d %H:%M:%S')): Building $1\033[0m"
    mkdir -p $build && pushd $build

    # autogen
    [ ! -e $SCRIPT_DIR/$name/configure ] &&
        pushd $SCRIPT_DIR/$name && ./autogen.sh && popd

    # configure
    $SCRIPT_DIR/$name/configure $config_opts

    # make
    if [ $? -eq 0 ]; then
        if [ -z "$make_opts" ]; then
            $MAKE -j$JOBS && $MAKE install && echo 1 > $finish
        else
            $MAKE "$make_opts" -j$JOBS && $MAKE install && echo 1 > $finish
        fi
    fi

    popd
    echo -e "\033[32m($(date '+%Y-%m-%d %H:%M:%S')): Finished $1\033[0m"
}

stage_build()
{
    git submodule init
    git submodule update

    do_build_with_configure binutils-gdb "--prefix=$PREFIX --host=$HOST" \
        "CFLAGS=-g -O2 -DHAVE_FCNTL_H -DHAVE_LIMITS_H"

    do_build_with_configure valgrind "--prefix=$PREFIX --host=${HOST/arm/armv7}"

    do_build_with_configure gperftools "--prefix=$PREFIX --host=${HOST} --enable-libunwind"

    cd strace && ./bootstrap && cd -
    do_build_with_configure strace "--prefix=$PREFIX --host=${HOST} --enable-mpers=no"

    cd file && aclocal && autoheader && libtoolize --force && automake --add-missing && autoconf
    do_build_with_configure file "--prefix=$PREFIX --host=${HOST} LDFLAGS=$RPATH --enable-static --disable-shared"
}

stage_trim()
{
    pushd $PREFIX

    # Delete
    find lib \( -name '*.a' -or -name '*.la' \) -exec rm -f {} \;

    # Strip
    find bin -mindepth 1 -type f -exec $STRIP -s {} \; 2>/dev/null
    find lib -path $PREFIX/lib/valgrind -name '*.so*' -type f -exec $STRIP -s {} \;

    # Valgrind
    find /tmp/devtools/lib/valgrind/ -perm 0755 ! -name '*memcheck*' ! -name '*core*' -exec rm -f {} \;

    popd
}

stage_pack()
{
    pushd $PREFIX
    tar --transform 's#^#embedded-devtools/#' -czvf embedded-devtools.tar.gz bin lib share/misc/magic.mgc
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
