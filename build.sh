#!/bin/bash
# Configuration options

root=$(pwd)

# Which branch to build against
GDC_BRANCH="gdc-4.8"
# Force a GDC Revision.  Empty uses head.
GDC_VERSION="6296cfbe9756572e6d91e83e5d786ce5477fcb1b"

set -e

if echo $PATH | grep " " ; then
  echo "Your PATH contain spaces, this may cause build issues when compiling binutils"
  echo "Please clean your PATH and retry"
  exit 3
fi

BUILD=$($root/config.guess | sed 's/-unknown-msys$/-pc-mingw32/')
echo "Build type: $BUILD"

export CFLAGS="-O2"
export CXXFLAGS="-O2"
export LDFLAGS="-s"

#trap "echo 'Spawning a rescue shell in current build directory'; bash" EXIT

CROSSDEV=$1
vendor="ace"

if [ -z "$CROSSDEV" ] ; then
  CROSSDEV=/crossdev
fi

export GCC_PREFIX="$CROSSDEV/gdc-4.8/release"

echo "Building in $CROSSDEV"

CACHE=$CROSSDEV/cache
mkdir -p $CROSSDEV/gdc-4.8/src
mkdir -p $CACHE

if [ -z "$MAKE" ]; then
  MAKE="make"
fi

export MAKE

function isMissing
{
  progName=$1
  echo -n "Checking for $progName ... "
  if which $progName 1>/dev/null 2>/dev/null; then
    echo "ok"
    return 1
  else
    return 0
  fi
}

if isMissing "wget"; then
	echo "wget not installed.  Please install with:"
	echo "pacman -S msys-wget"
  echo "or"
	echo "apt-get install wget"
	exit 1
fi

if isMissing "unzip"; then
	echo "unzip not installed.  Please install with:"
	echo "pacman -S msys/unzip"
  echo "or"
	echo "apt-get install unzip"
	exit 1
fi

if isMissing "tar"; then
	echo "tar not installed.  Please install with:"
	echo "mingw-get install tar"
  echo "or"
	echo "apt-get install tar"
	exit 1
fi

if isMissing "patch"; then
	echo "patch not installed.  Please install with:"
	echo "mingw-get install patch"
  echo "or"
	echo "apt-get install patch"
	exit 1
fi

if isMissing "7za" ; then
	echo "7za not installed.  Please install with:"
	echo "pacman -S p7zip"
  echo "or"
	echo "apt-get install p7zip-full"
	exit 1
fi

if isMissing "gcc" ; then
	echo "gcc not installed.  Please install with:"
	echo "pacman -S mingw-gcc"
  echo "or"
	echo "apt-get install gcc"
	exit 1
fi

if isMissing "git" ; then
	echo "git not installed.  Please install with:"
	echo "pacman -S mingw-git"
  echo "or"
	echo "apt-get install git"
	exit 1
fi

if isMissing "cmp" ; then
	echo "cmp not installed.  Please install with:"
	echo "pacman -S diffutils"
  echo "or"
	echo "apt-get install something"
	exit 1
fi

if isMissing "flex" ; then
	echo "flex not installed.  Please install with:"
	echo "pacman -S flex"
  echo "or"
	echo "apt-get install flex"
	exit 1
fi

if isMissing "bison" ; then
	echo "bison not installed.  Please install with:"
	echo "pacman -S bison"
  echo "or"
	echo "apt-get install bison"
	exit 1
fi

pushd $CROSSDEV/gdc-4.8/src

function lazy_download
{
  local file="$1"
  local url="$2"

	if [ ! -e "$file" ]; then
		wget "$url" -c -O "${file}.tmp"
    mv "${file}.tmp" "$file"
	fi
}

function lazy_extract
{
  local archive="$1"
  echo -n "Extracting $archive ... "
  local name=$(basename $archive .tar.gz)
  name=$(basename $name .tar.bz2)

	if [ -d $name ]; then
    echo "already extracted"
  else
    rm -rf ${name}.tmp
    mkdir ${name}.tmp
		tar -C ${name}.tmp -xlf "$CACHE/$archive"  --strip-components=1
    mv ${name}.tmp $name
    echo "ok"
  fi
}

# Download and install x86-64 build tools

function install_build_tools
{
  lazy_download "$CACHE/x86_64-4.8.2-release-win32-sjlj-rt_v3-rev0.7z" "http://sourceforge.net/projects/mingw-w64/files/Toolchains%20targetting%20Win64/Personal%20Builds/mingw-builds/4.8.2/threads-win32/sjlj/x86_64-4.8.2-release-win32-sjlj-rt_v3-rev0.7z/download"

  if [ ! -d "$CROSSDEV/mingw64" ]; then
    7za x -o$CROSSDEV $CACHE/x86_64-4.8.2-release-win32-sjlj-rt_v3-rev0.7z
  fi

  export PATH=$CROSSDEV/mingw64/bin:$PATH


  # Install some basic DLL dependencies
  mkdir -p $CROSSDEV/gdc-4.8/release/bin

  lazy_download "$CACHE/libiconv-1.14-3-mingw32-dll.tar.lzma" "http://sourceforge.net/projects/mingw/files/MinGW/Base/libiconv/libiconv-1.14-3/libiconv-1.14-3-mingw32-dll.tar.lzma/download"
  #	tar --lzma -xvf $CACHE/libiconv-1.14-3-mingw32-dll.tar.lzma -C $CROSSDEV/gdc-4.8/release

  lazy_download "$CACHE/gettext-0.18.3.1-1-mingw32-dll.tar.lzma" "http://sourceforge.net/projects/mingw/files/MinGW/Base/gettext/gettext-0.18.3.1-1/gettext-0.18.3.1-1-mingw32-dll.tar.lzma/download"
  #	tar --lzma -xvf $CACHE/gettext-0.18.3.1-1-mingw32-dll.tar.lzma -C $CROSSDEV/gdc-4.8/release

  lazy_download "$CACHE/gcc-core-4.8.1-3-mingw32-dll.tar.lzma" "http://hivelocity.dl.sourceforge.net/project/mingw/MinGW/Base/gcc/Version4/gcc-4.8.1-3/gcc-core-4.8.1-3-mingw32-dll.tar.lzma"
  #	tar --lzma -xvf $CACHE/gcc-core-4.8.1-3-mingw32-dll.tar.lzma -C $CROSSDEV/gdc-4.8/release bin/libgcc_s_dw2-1.dll
}

#install_build_tools

# Configure x86-64 build environment
gcc -v

# Create or restore a directory content
function mkgit {
  dir="$1"

  pushd "$dir"
  if [ ! -d ".git" ]; then
    echo "Creating git for $dir"
    # prune unnecessary folders.
    git init
    git config user.email "nobody@localhost"
    git config user.name "Nobody"
    git config core.autocrlf false
    git add -f *
    git commit -m "MinGW/GDC restore point"
  else
    echo "Restoring $dir from git restore point"
    git reset --hard
    git clean -f
  fi
  popd
}

# Compile binutils

lazy_download "$CACHE/binutils-2.23.2.tar.gz" "http://ftp.gnu.org/gnu/binutils/binutils-2.23.2.tar.gz"
lazy_extract "binutils-2.23.2.tar.gz"
mkgit "binutils-2.23.2"

if [ ! -e binutils-2.23.2/build/.built ]; then

  pushd binutils-2.23.2
  patch -p1 < $root/patches/mingw-tls-binutils-2.23.1.patch
  sed "s/^%.*//" -i bfd/doc/bfd.texinfo
  sed "s/^%.*//" -i ld/ld.texinfo
  mkdir -p build
  cd build
  ../configure \
    --prefix=$CROSSDEV/gdc-4.8/release \
    --build=$BUILD \
    --target=x86_64-$vendor-mingw32 \
    --disable-nls \
    --disable-multilib \
    --disable-bootstrap
	$MAKE
  $MAKE install
	touch .built
	popd
fi

# Add binutils to PATH
export PATH="$GCC_PREFIX/bin:$PATH"

function build_runtime
{
  lazy_download "$CACHE/mingw-w64-v3.0.0.tar.bz2" "http://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/mingw-w64-v3.0.0.tar.bz2/download"
  lazy_extract "mingw-w64-v3.0.0.tar.bz2"
  mkgit "mingw-w64-v3.0.0"

  pushd mingw-w64-v3.0.0

  echo "********************************************************************************"
  echo "Building runtime headers"
  pushd mingw-w64-headers
  mkdir -p build
  cd build
  if [ ! -e .built ] ; then
    ../configure \
      --prefix=$CROSSDEV/gdc-4.8/release/x86_64-$vendor-mingw32 \
      --build=$BUILD \
      --host=x86_64-$vendor-mingw32
    $MAKE
    $MAKE install
    touch .built
  fi
  popd

  echo "********************************************************************************"
  echo "Building runtime CRT"
  pushd mingw-w64-crt
  mkdir -p build
  cd build
  if [ ! -e .built ] ; then
    ../configure \
      --prefix=$CROSSDEV/gdc-4.8/release/x86_64-$vendor-mingw32 \
      --build=$BUILD \
      --host=x86_64-$vendor-mingw32
    $MAKE && $MAKE install
    touch .built
  fi
  popd

  echo "********************************************************************************"
  echo "Building pthreads"
  pushd mingw-w64-libraries/winpthreads
  mkdir -p build
  cd build
  if [ ! -e .built ] ; then
    ../configure \
      --prefix=$CROSSDEV/gdc-4.8/release/x86_64-$vendor-mingw32 \
      --build=$BUILD \
      --host=x86_64-$vendor-mingw32
    $MAKE
    $MAKE install
    touch .built
  fi
  popd

  popd
}

# Compile GMP
if [ ! -e gmp-4.3.2/build/.built ]; then

  lazy_download "$CACHE/gmp-4.3.2.tar.bz2" "http://ftp.gnu.org/gnu/gmp/gmp-4.3.2.tar.bz2"
  lazy_extract "gmp-4.3.2.tar.bz2"
  mkgit "gmp-4.3.2"

	pushd gmp-4.3.2
	patch -p1 < $root/patches/gmp-4.3.2-w64.patch

	# Make 64
	mkdir -p build/64
	cd build/64
	../../configure \
    --prefix=$CROSSDEV/gdc-4.8/gmp-4.3.2/64 \
    --build=$BUILD \
	  --enable-cxx --disable-static --enable-shared \
	  ABI=64
	$MAKE && $MAKE install
	cd ..
	touch .built
	popd
fi

# Compile MPFR
if [ ! -e mpfr-3.1.1/build/.built ]; then

  lazy_download "$CACHE/mpfr-3.1.1.tar.bz2" "http://ftp.gnu.org/gnu/mpfr/mpfr-3.1.1.tar.bz2"
  lazy_extract "mpfr-3.1.1.tar.bz2"
  mkgit "mpfr-3.1.1"

	pushd mpfr-3.1.1

	# Make 64
	mkdir -p build/64
	pushd build/64
	#export PATH="$(PATH):$(GMP_STAGE)/64/bin"
  CFLAGS+="-I$CROSSDEV/gdc-4.8/gmp-4.3.2/64/include" \
  LDFLAGS+="-L$CROSSDEV/gdc-4.8/gmp-4.3.2/64/lib" \
	../../configure \
    --prefix=$CROSSDEV/gdc-4.8/mpfr-3.1.1/64 \
    --build=$BUILD \
	  --disable-static \
    --enable-shared
	$MAKE
  $MAKE install
  popd

	touch build/.built
	popd
fi

# Compile MPC
if [ ! -e mpc-1.0.1/build/.built ]; then

  lazy_download "$CACHE/mpc-1.0.1.tar.gz" http://ftp.gnu.org/gnu/mpc/mpc-1.0.1.tar.gz

	if [ ! -d "mpc-1.0.1" ]; then
		tar -xlf $CACHE/mpc-1.0.1.tar.gz
		cd mpc-1.0.1
		# prune unnecessary folders.
		git init
		git config user.email "nobody@localhost"
		git config user.name "Nobody"
		git config core.autocrlf false
		git add *
		git commit -am "MinGW/GDC restore point"
		cd ..
	else
		cd mpc-1.0.1
		git reset --hard
		git clean -f
		cd ..
	fi


	pushd mpc-1.0.1

	# Make 64
	mkdir -p build/64
	cd build/64
  ../../configure \
    --prefix=$CROSSDEV/gdc-4.8/mpc-1.0.1/64 \
    --build=$BUILD \
	  --disable-static --enable-shared \
	  --with-gmp=$CROSSDEV/gdc-4.8/gmp-4.3.2/64 \
	  --with-mpfr=$CROSSDEV/gdc-4.8/mpfr-3.1.1/64
  $MAKE
  $MAKE install
	cd ..

	touch .built
	popd
fi

# Compile ISL
if [ ! -e isl-0.11.1/build/.built ]; then

  lazy_download "$CACHE/isl-0.11.1.tar.bz2" "ftp://gcc.gnu.org/pub/gcc/infrastructure/isl-0.11.1.tar.bz2"

	#mkgit isl-0.11.1.tar.bz2 isl-0.11.1
	if [ ! -d "isl-0.11.1" ]; then
		tar -xlf $CACHE/isl-0.11.1.tar.bz2
		cd isl-0.11.1

		# prune unnecessary folders.
		git init
		git config user.email "nobody@localhost"
		git config user.name "Nobody"
		git config core.autocrlf false
		git add *
		git commit -am "MinGW/GDC restore point"
		cd ..
	else
		cd isl-0.11.1
		git reset --hard
		git clean -f
		cd ..
	fi

	pushd isl-0.11.1

	# Make 64
	mkdir -p build/64
	cd build/64
	../../configure \
    --prefix=$CROSSDEV/gdc-4.8/isl-0.11.1/64 \
    --build=$BUILD \
	  --enable-shared \
	  --with-gmp-prefix=$CROSSDEV/gdc-4.8/gmp-4.3.2/64
	  $MAKE
    $MAKE install
	cd ..

	touch .built
	popd
fi

# Compile CLOOG
if [ ! -e cloog-0.18.0/build/.built ]; then

  lazy_download "$CACHE/cloog-0.18.0.tar.gz" "ftp://gcc.gnu.org/pub/gcc/infrastructure/cloog-0.18.0.tar.gz"
  lazy_extract "cloog-0.18.0.tar.gz"
  mkgit "cloog-0.18.0"

	pushd cloog-0.18.0

	# Build 64
	mkdir -p build/64
	cd build/64
	../../configure \
    --prefix=$CROSSDEV/gdc-4.8/cloog-0.18.0/64 \
    --build=$BUILD \
	  --disable-static \
    --enable-shared \
	  --with-gmp-prefix=$CROSSDEV/gdc-4.8/gmp-4.3.2/64 \
      --with-isl-prefix=$CROSSDEV/gdc-4.8/isl-0.11.1/64
	$MAKE
  $MAKE install
	cd ..
	touch .built
	popd
fi

# Copy runtime files to release
mkdir -p $GCC_PREFIX/x86_64-$vendor-mingw32
mkdir -p $GCC_PREFIX/x86_64-$vendor-mingw32/bin32
mkdir -p $GCC_PREFIX/x86_64-$vendor-mingw32/lib32

GMP_STAGE=$CROSSDEV/gdc-4.8/gmp-4.3.2/
MPFR_STAGE=$CROSSDEV/gdc-4.8/mpfr-3.1.1/
MPC_STAGE=$CROSSDEV/gdc-4.8/mpc-1.0.1/
ISL_STAGE=$CROSSDEV/gdc-4.8/isl-0.11.1/
CLOOG_STAGE=$CROSSDEV/gdc-4.8/cloog-0.18.0/

cp -Rp $GMP_STAGE/64/*		$GCC_PREFIX/x86_64-$vendor-mingw32/
cp -Rp $MPFR_STAGE/64/*     $GCC_PREFIX/x86_64-$vendor-mingw32
cp -Rp $MPC_STAGE/64/*     $GCC_PREFIX/x86_64-$vendor-mingw32
cp -Rp $ISL_STAGE/64/*     $GCC_PREFIX/x86_64-$vendor-mingw32
cp -Rp $CLOOG_STAGE/64/*     $GCC_PREFIX/x86_64-$vendor-mingw32

#cp -Rp $GCC_PREFIX/x86_64-$vendor-mingw32/bin/*.dll $GCC_PREFIX/bin

function download_gdc {

	# Clone and configure GDC
	if [ ! -d "GDC" ]; then
		git clone https://github.com/D-Programming-GDC/GDC.git -b $GDC_BRANCH
	else
		cd GDC
		git fetch
		git reset --hard origin/$GDC_BRANCH
		git clean -f -d
		cd ..
	fi

	pushd GDC

	if [ "$GDC_VERSION" != "" ]; then
		git checkout $GDC_VERSION
	fi

	popd
}

function download_gcc {

  lazy_download "$CACHE/gcc-4.8.1.tar.bz2" "http://ftp.gnu.org/gnu/gcc/gcc-4.8.1/gcc-4.8.1.tar.bz2"
  lazy_extract "gcc-4.8.1.tar.bz2"
  mkgit "gcc-4.8.1"
}

# Setup GDC and compile
function build_gdc_host {

  if [ -e gcc-4.8.1/build/.built ] ; then
    return 0
  fi

  download_gcc
  download_gdc

	pushd GDC
	#patch -p1 < $root/patches/mingw-gdc.patch
	#patch -p1 < $root/patches/mingw-gdc-remove-main-from-dmain2.patch
	# Should use git am
	for patch in $(find $root/patches/gdc -type f ); do
		echo "Patching $patch"
		patch -p1 -i $patch || exit
	done

	./setup-gcc.sh ../gcc-4.8.1
	popd

	pushd gcc-4.8.1
	patch -p1 < $root/patches/mingw-tls-gcc-4.8.patch

	# Should use git am
	for patch in $(find $root/patches/gcc -type f ); do
		echo "Patching $patch"
		git am $patch || exit
	done

	# Build GCC
	mkdir -p build
	cd build

	# Must build GCC using patched mingwrt
	export LPATH="$GCC_PREFIX/lib;$GCC_PREFIX/x86_64-$vendor-mingw32/lib"
	export CPATH="$GCC_PREFIX/include;$GCC_PREFIX/x86_64-$vendor-mingw32/include"
	#export BOOT_CFLAGS="-static-libgcc -static"
	../configure \
    --prefix=$GCC_PREFIX \
    --build=$BUILD \
    --with-local-prefix=$GCC_PREFIX \
	  --target=x86_64-$vendor-mingw32 \
	  --enable-languages=c,c++,d,lto \
    --enable-sjlj-exceptions \
	  --enable-lto \
    --disable-nls \
    --disable-multilib \
	  --disable-win32-registry \
    --with-gnu-ld \
    --disable-bootstrap
	$MAKE all-host
  $MAKE install-host
  touch .built
	popd
}

function build_gdc_target {
	pushd gcc-4.8.1/build
	$MAKE all-target
  $MAKE install-target
	popd
}

build_gdc_host
build_runtime
build_gdc_target

exit 0


# get DMD script
if [ ! -d "GDMD" ]; then
	git clone https://github.com/D-Programming-GDC/GDMD.git
else
	cd GDMD
	git pull
	cd ..
fi
pushd GDMD
#Ok to fail. results in testsuite not running
PATH=/c/strawberry/perl/bin:$PATH TMPDIR=. cmd /c "pp dmd-script -o gdmd.exe"
cp gdmd.exe $CROSSDEV/gdc-4.8/release/bin/
cp dmd-script $CROSSDEV/gdc-4.8/release/bin/gdmd
popd

# Test build
# Run unitests via check-d
# Verify gdmd exists.
# test commands need to avoid exit on error
echo -n "Checking for gdmd.exe..."
gdmd=$(which gdmd.exe 2>/dev/null)
if [ ! "$gdmd" ]; then
	echo "Unable to run DMD testsuite. gdmd.exe failed to compile"
	exit 1
fi

# Run testsuite via dmd
echo "dmd cloning"
if [ ! -d "dmd" ]; then
	git clone https://github.com/D-Programming-Language/dmd.git -b 2.062
else
	cd dmd
	git reset --hard
	git clean -f
	git pull
	# Reset RPO
	cd ..
fi
pushd dmd/test
patch -p2 < $root/patches/mingw-testsuite.patch
$MAKE
pushd
