
readonly SERVER_URL=http://ftp.gnu.org/gnu
readonly GCC_VERSION=5.3.0
readonly BINUTILS_VERSION=2.25

readonly GCC_LANGS="c,c++,d"

readonly BIN=bin
readonly ARCHIVES=archives

unset CC
unset CXX
readonly MAKE="make -j`nproc` -k"
export LDFLAGS=-s
