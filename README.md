# Embedded Develop Tools

EDT provide a bundle of develop tools run on embedded devices.

- binutils
- gdb
- valgrind
- strace
- gperftools
- file

## Build

1. Setup toolchains
```
export CROSS_COMPILE=aarch64-linux-gnu-
export CC=${CROSS_COMPILE}gcc
export CPP=${CROSS_COMPILE}cpp
export CXX=${CROSS_COMPILE}g++
export LD=${CROSS_COMPILE}ld
export AR=${CROSS_COMPILE}ar
```
2. Run build.sh
```
$ bash build.sh -h aarch64-linux-gnu -p /tmp/edt/ -j 32
```
