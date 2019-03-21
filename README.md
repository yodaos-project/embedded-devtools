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
export PATH=/opt/gcc_aarch64-linux-gnu/bin/:$PATH
```
2. Run build.sh
```
$ bash build.sh -h aarch64-linux-gnu -j 32
```
3. Check packed files
```
$ find _install -name '*edt-*.tar.gz'
```
