#!/bin/bash
# Configuration options

# Which branch to build against
GDC_BRANCH="gdc-4.8"
# Force a GDC Revision.  Empty uses head.
GDC_VERSION="6296cfbe9756572e6d91e83e5d786ce5477fcb1b"

set -e

CROSSDEV=$1

if [ -z "$CROSSDEV" ] ; then
  CROSSDEV=/crossdev
fi

echo "Building in $CROSSDEV"

mkdir -p $CROSSDEV/gdc-4.8/src

function isMissing
{
  progName=$1
  if which $progName 2>/dev/null; then
    return 1
  else
    return 0
  fi
}

if isMissing "wget"; then
	echo "wget not installed.  Please install with:"
	echo "mingw-get install msys-wget"
  echo "or"
	echo "apt-get install wget"
	exit 1
fi

if isMissing "unzip"; then
	echo "unzip not installed.  Please install with:"
	echo "mingw-get install msys-unzip"
  echo "or"
	echo "apt-get install unzip"
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

root=$(pwd)
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

# Download and install x86-64 build tools

function install_build_tools
{
  lazy_download "x86_64-4.8.2-release-win32-sjlj-rt_v3-rev0.7z" "http://sourceforge.net/projects/mingw-w64/files/Toolchains%20targetting%20Win64/Personal%20Builds/mingw-builds/4.8.2/threads-win32/sjlj/x86_64-4.8.2-release-win32-sjlj-rt_v3-rev0.7z/download"

  if [ ! -d "$CROSSDEV/mingw64" ]; then
    7za x -o$CROSSDEV x86_64-4.8.2-release-win32-sjlj-rt_v3-rev0.7z
  fi

  export PATH=$CROSSDEV/mingw64/bin:$PATH


  # Install some basic DLL dependencies
  mkdir -p $CROSSDEV/gdc-4.8/release/bin

  lazy_download "libiconv-1.14-3-mingw32-dll.tar.lzma" "http://sourceforge.net/projects/mingw/files/MinGW/Base/libiconv/libiconv-1.14-3/libiconv-1.14-3-mingw32-dll.tar.lzma/download"
  #	tar --lzma -xvf libiconv-1.14-3-mingw32-dll.tar.lzma -C $CROSSDEV/gdc-4.8/release

  lazy_download "gettext-0.18.3.1-1-mingw32-dll.tar.lzma" "http://sourceforge.net/projects/mingw/files/MinGW/Base/gettext/gettext-0.18.3.1-1/gettext-0.18.3.1-1-mingw32-dll.tar.lzma/download"
  #	tar --lzma -xvf gettext-0.18.3.1-1-mingw32-dll.tar.lzma -C $CROSSDEV/gdc-4.8/release

  lazy_download "gcc-core-4.8.1-3-mingw32-dll.tar.lzma" "http://hivelocity.dl.sourceforge.net/project/mingw/MinGW/Base/gcc/Version4/gcc-4.8.1-3/gcc-core-4.8.1-3-mingw32-dll.tar.lzma"
  #	tar --lzma -xvf gcc-core-4.8.1-3-mingw32-dll.tar.lzma -C $CROSSDEV/gdc-4.8/release bin/libgcc_s_dw2-1.dll
}

#install_build_tools

# Configure x86-64 build environment
gcc -v


# Extracts archive and converts to git repo.
# If git repo exists, resets
# $1 - archive
# $2 - path, for now, must equal what the archive extracts to
function mkgit {
	return
	if [ ! -d "$2" ]; then
		# Determine archive type
		ext="${$1##*.}"
		switch $ext
		tar -xvjf $1
		cd $2

		# prune unnecessary folders.
		git init
		git config user.email "nobody@localhost"
		git config user.name "Nobody"
		git config core.autocrlf false
		git add -f *
		git commit -am "MinGW/GDC restore point"
		cd ..
	else
		cd $2
		git reset --hard
		git clean -f
		cd ..
	fi
}

# From this point forward, always exit on error
set -e

# Compile binutils
mkgit binutils-2.23.2.tar.gz binutils-2.23.2

if [ ! -e binutils-2.23.2/build/.built ]; then

  lazy_download "binutils-2.23.2.tar.gz" "http://ftp.gnu.org/gnu/binutils/binutils-2.23.2.tar.gz"

	#mkgit binutils-2.23.2.tar.gz binutils-2.23.2
	if [ ! -d "binutils-2.23.2" ]; then
		tar -xvzf binutils-2.23.2.tar.gz
		cd binutils-2.23.2
		# prune unnecessary folders.
		git init
		git config user.email "nobody@localhost"
		git config user.name "Nobody"
		git config core.autocrlf false
		git add *
		git commit -m "MinGW/GDC restore point"
		cd ..
	else
		cd binutils-2.23.2
		git reset --hard
		git clean -f
		cd ..
	fi
	pushd binutils-2.23.2
	patch -p1 < $root/patches/mingw-tls-binutils-2.23.1.patch
	mkdir -p build
	cd build
	../configure --prefix=$CROSSDEV/gdc-4.8/release --build=x86_64-w64-mingw32 \
	  --enable-targets=x86_64-w64-mingw32,i686-w64-mingw32 \
	  CFLAGS="-O2 -m32" LDFLAGS="-s -m32"
	make && make install
	touch .built
	popd
fi

function build_runtime 
{
  # Compile MinGW64 runtime
  if [ -e mingw-w64-v3.0.0/build/.built ]; then
    return 0
  fi

  lazy_download "mingw-w64-v3.0.0.tar.bz2" "http://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/mingw-w64-v3.0.0.tar.bz2/download"

  if [ ! -d "mingw-w64-v3.0.0" ]; then
    tar -xvjf mingw-w64-v3.0.0.tar.bz2
    cd mingw-w64-v3.0.0
    # prune unnecessary folders.
    git init
    git config user.email "nobody@localhost"
    git config user.name "Nobody"
    git config core.autocrlf false
    git add *
    git commit -am "MinGW/GDC restore point"
    cd ..
  else
    cd mingw-w64-v3.0.0
    git reset --hard
    git clean -f
    cd ..
  fi
  pushd mingw-w64-v3.0.0
  mkdir -p build
  cd build
  ../configure --prefix=$CROSSDEV/gdc-4.8/release --build=x86_64-w64-mingw32 \
    --enable-lib32 --enable-sdk=all
  make && make install
  touch .built
  popd
}

build_runtime

# Compile GMP
if [ ! -e gmp-4.3.2/build/.built ]; then

  lazy_download "gmp-4.3.2.tar.bz2" "http://ftp.gnu.org/gnu/gmp/gmp-4.3.2.tar.bz2"

	if [ ! -d "gmp-4.3.2" ]; then
		tar -xvjf gmp-4.3.2.tar.bz2
		cd gmp-4.3.2
		# prune unnecessary folders.
		git init
		git config user.email "nobody@localhost"
		git config user.name "Nobody"
		git config core.autocrlf false
		git add *
		git commit -am "MinGW/GDC restore point"
		cd ..
	else
		cd gmp-4.3.2
		git reset --hard
		git clean -f
		cd ..
	fi

	pushd gmp-4.3.2
	patch -p1 < $root/patches/gmp-4.3.2-w64.patch

	# Make 32
	mkdir -p build/32
	cd build/32
	../../configure --prefix=$CROSSDEV/gdc-4.8/gmp-4.3.2/32 \
	  --build=x86_64-w64-mingw32 --enable-cxx --disable-static --enable-shared \
	  LD="ld.exe -m i386pe" CFLAGS="-O2 -m32" CXXFLAGS="-O2 -m32" \
	  LDFLAGS="-m32 -s" ABI=32
	make && make install
	cd ../..

	# Make 64
	mkdir -p build/64
	cd build/64
	../../configure --prefix=$CROSSDEV/gdc-4.8/gmp-4.3.2/64 \
	  --build=x86_64-w64-mingw32 --enable-cxx --disable-static --enable-shared \
	  CFLAGS="-O2" CXXFLAGS="-O2" LDFLAGS="-s" ABI=64 \
	  NM=$CROSSDEV/mingw64/bin/nm
	make && make install
	cd ..
	touch .built
	popd
fi

# Compile MPFR
if [ ! -e mpfr-3.1.1/build/.built ]; then

  lazy_download "mpfr-3.1.1.tar.bz2" "http://ftp.gnu.org/gnu/mpfr/mpfr-3.1.1.tar.bz2"

	if [ ! -d "mpfr-3.1.1" ]; then
		tar -xvjf mpfr-3.1.1.tar.bz2
		cd mpfr-3.1.1
		# prune unnecessary folders.
		git init
		git config user.email "nobody@localhost"
		git config user.name "Nobody"
		git config core.autocrlf false
		git add *
		git commit -am "MinGW/GDC restore point"
		cd ..
	else
		cd mpfr-3.1.1
		git reset --hard
		git clean -f
		cd ..
	fi

	pushd mpfr-3.1.1

	# Make 32
	mkdir -p build/32
	pushd build/32
	#export PATH="$(PATH):$(GMP_STAGE)/32/bin"
	../../configure --prefix=$CROSSDEV/gdc-4.8/mpfr-3.1.1/32 \
	  --build=x86_64-w64-mingw32 --disable-static --enable-shared \
	  CFLAGS="-O2 -m32 -I$CROSSDEV/gdc-4.8/gmp-4.3.2/32/include" \
	  LDFLAGS="-m32 -s -L$CROSSDEV/gdc-4.8/gmp-4.3.2/32/lib"
	make && make install
  popd

	# Make 64
	mkdir -p build/64
	pushd build/64
	#export PATH="$(PATH):$(GMP_STAGE)/64/bin"
	../../configure --prefix=$CROSSDEV/gdc-4.8/mpfr-3.1.1/64 \
	  --build=x86_64-w64-mingw32 --disable-static --enable-shared \
	  CFLAGS="-O2 -I$CROSSDEV/gdc-4.8/gmp-4.3.2/64/include" \
	  LDFLAGS="-s -L$CROSSDEV/gdc-4.8/gmp-4.3.2/64/lib"
	make && make install
  popd

	touch build/.built
	popd
fi

# Compile MPC
if [ ! -e mpc-1.0.1/build/.built ]; then

  lazy_download "mpc-1.0.1.tar.gz" http://ftp.gnu.org/gnu/mpc/mpc-1.0.1.tar.gz

	if [ ! -d "mpc-1.0.1" ]; then
		tar -xvzf mpc-1.0.1.tar.gz
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
	# Make 32
	mkdir -p build/32
	cd build/32
	../../configure --prefix=$CROSSDEV/gdc-4.8/mpc-1.0.1/32 \
	  --build=x86_64-w64-mingw32 --disable-static --enable-shared \
	  --with-gmp=$CROSSDEV/gdc-4.8/gmp-4.3.2/32 \
	  --with-mpfr=$CROSSDEV/gdc-4.8/mpfr-3.1.1/32 \
	  CFLAGS="-O2 -m32" LDFLAGS="-m32 -s"
	make && make install
	cd ../..
	# Make 64
	mkdir -p build/64
	cd build/64
	../../configure --prefix=$CROSSDEV/gdc-4.8/mpc-1.0.1/64 \
	  --build=x86_64-w64-mingw32 --disable-static --enable-shared \
	  --with-gmp=$CROSSDEV/gdc-4.8/gmp-4.3.2/64 \
	  --with-mpfr=$CROSSDEV/gdc-4.8/mpfr-3.1.1/64 \
	  CFLAGS="-O2" LDFLAGS="-s"
	  make && make install
	cd ..

	touch .built
	popd
fi

# Compile ISL
if [ ! -e isl-0.11.1/build/.built ]; then

  lazy_download "isl-0.11.1.tar.bz2" "ftp://gcc.gnu.org/pub/gcc/infrastructure/isl-0.11.1.tar.bz2"

	#mkgit isl-0.11.1.tar.bz2 isl-0.11.1
	if [ ! -d "isl-0.11.1" ]; then
		tar -xvjf isl-0.11.1.tar.bz2
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
	mkdir -p build/32
	cd build/32
	../../configure --prefix=$CROSSDEV/gdc-4.8/isl-0.11.1/32 \
	  --build=x86_64-w64-mingw32 --enable-shared \
	  --with-gmp-prefix=$CROSSDEV/gdc-4.8/gmp-4.3.2/32 \
	  CFLAGS="-O2 -m32" LDFLAGS="-m32 -s"
	make && make install
	cd ../..
	# Make 64
	mkdir -p build/64
	cd build/64
	../../configure --prefix=$CROSSDEV/gdc-4.8/isl-0.11.1/64 \
	  --build=x86_64-w64-mingw32 --enable-shared \
	  --with-gmp-prefix=$CROSSDEV/gdc-4.8/gmp-4.3.2/64 \
	  CFLAGS="-O2" LDFLAGS="-s"
	  make && make install
	cd ..

	touch .built
	popd
fi

# Compile CLOOG
if [ ! -e cloog-0.18.0/build/.built ]; then

  lazy_download "cloog-0.18.0.tar.gz" "ftp://gcc.gnu.org/pub/gcc/infrastructure/cloog-0.18.0.tar.gz"

	#mkgit cloog-0.18.0.tar.gz cloog-0.18.0
	if [ ! -d "cloog-0.18.0" ]; then
		tar -xvzf cloog-0.18.0.tar.gz
		cd cloog-0.18.0

		# prune unnecessary folders.
		git init
		git config user.email "nobody@localhost"
		git config user.name "Nobody"
		git config core.autocrlf false
		git add -f *
		git commit -am "MinGW/GDC restore point"
		cd ..
	else
		cd cloog-0.18.0
		git reset --hard
		git clean -f
		cd ..
	fi

	pushd cloog-0.18.0
	# Build 32
	mkdir -p build/32
	cd build/32
	 #export PATH="$(PATH):$(GMP_STAGE)/32/bin:$(PPL_STAGE)/32/bin"
	../../configure --prefix=$CROSSDEV/gdc-4.8/cloog-0.18.0/32 \
	  --build=x86_64-w64-mingw32 --disable-static --enable-shared \
	  --with-gmp-prefix=$CROSSDEV/gdc-4.8/gmp-4.3.2/32 \
      --with-isl-prefix=$CROSSDEV/gdc-4.8/isl-0.11.1/32 \
	  CFLAGS="-O2 -m32" CXXFLAGS="-O2 -m32" LDFLAGS="-s -m32"
	  make && make install
	cd ../..
	# Build 64
	mkdir -p build/64
	cd build/64
	 #export PATH="$(PATH):$(GMP_STAGE)/32/bin:$(PPL_STAGE)/32/bin"
	../../configure --prefix=$CROSSDEV/gdc-4.8/cloog-0.18.0/64 \
	  --build=x86_64-w64-mingw32 --disable-static --enable-shared \
	  --with-gmp-prefix=$CROSSDEV/gdc-4.8/gmp-4.3.2/64 \
      --with-isl-prefix=$CROSSDEV/gdc-4.8/isl-0.11.1/64 \
	  CFLAGS="-O2" CXXFLAGS="-O2" LDFLAGS="-s"
	make && make install
	cd ..
	touch .built
	popd
fi

export GCC_PREFIX="$CROSSDEV/gdc-4.8/release"

# Copy runtime files to release
mkdir -p $GCC_PREFIX/x86_64-w64-mingw32
mkdir -p $GCC_PREFIX/x86_64-w64-mingw32/bin32
mkdir -p $GCC_PREFIX/x86_64-w64-mingw32/lib32

GMP_STAGE=$CROSSDEV/gdc-4.8/gmp-4.3.2/
MPFR_STAGE=$CROSSDEV/gdc-4.8/mpfr-3.1.1/
MPC_STAGE=$CROSSDEV/gdc-4.8/mpc-1.0.1/
ISL_STAGE=$CROSSDEV/gdc-4.8/isl-0.11.1/
CLOOG_STAGE=$CROSSDEV/gdc-4.8/cloog-0.18.0/

cp -Rp $GMP_STAGE/64/*		$GCC_PREFIX/x86_64-w64-mingw32/
cp -Rp $GMP_STAGE/32/bin/*	$GCC_PREFIX/x86_64-w64-mingw32/bin32
cp -Rp $GMP_STAGE/32/lib/*	$GCC_PREFIX/x86_64-w64-mingw32/lib32

cp -Rp $MPFR_STAGE/64/*     $GCC_PREFIX/x86_64-w64-mingw32
cp -Rp $MPFR_STAGE/32/bin/* $GCC_PREFIX/x86_64-w64-mingw32/bin32
cp -Rp $MPFR_STAGE/32/lib/* $GCC_PREFIX/x86_64-w64-mingw32/lib32

cp -Rp $MPC_STAGE/64/*     $GCC_PREFIX/x86_64-w64-mingw32
cp -Rp $MPC_STAGE/32/bin/* $GCC_PREFIX/x86_64-w64-mingw32/bin32
cp -Rp $MPC_STAGE/32/lib/* $GCC_PREFIX/x86_64-w64-mingw32/lib32

cp -Rp $ISL_STAGE/64/*     $GCC_PREFIX/x86_64-w64-mingw32
#cp -Rp $ISL_STAGE/32/bin/* $GCC_PREFIX/x86_64-w64-mingw32/bin32
cp -Rp $ISL_STAGE/32/lib/* $GCC_PREFIX/x86_64-w64-mingw32/lib32

cp -Rp $CLOOG_STAGE/64/*     $GCC_PREFIX/x86_64-w64-mingw32
cp -Rp $CLOOG_STAGE/32/bin/* $GCC_PREFIX/x86_64-w64-mingw32/bin32
cp -Rp $CLOOG_STAGE/32/lib/* $GCC_PREFIX/x86_64-w64-mingw32/lib32

cp -Rp $GCC_PREFIX/x86_64-w64-mingw32/bin/*.dll $GCC_PREFIX/bin


# Setup GDC and compile
function build_gdc {

  lazy_download "gcc-4.8.1.tar.bz2" "http://ftp.gnu.org/gnu/gcc/gcc-4.8.1/gcc-4.8.1.tar.bz2"

	# Extract and configure a git repo to allow fast restoration for future builds.
	# mkgit gcc-4.8.1.tar.bz2 gcc-4.8.1
	if [ ! -d "gcc-4.8.1" ]; then
		tar -xvjf gcc-4.8.1.tar.bz2
		cd gcc-4.8.1
		# prune unnecessary folders.
		git init
		git config user.email "nobody@localhost"
		git config user.name "Nobody"
		git config core.autocrlf false
		git add *
		git commit -am "MinGW/GDC restore point"
		git tag mingw_build
		cd ..
	else
		cd gcc-4.8.1
		git reset --hard mingw_build
		git clean -f -d
		cd ..
	fi
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

	#patch -p1 < $root/patches/mingw-gdc.patch
	#patch -p1 < $root/patches/mingw-gdc-remove-main-from-dmain2.patch
	# Should use git am
	for patch in $(find $root/patches/gdc -type f ); do
		echo "Patching $patch"
		git am $patch || exit
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
	export LPATH="$GCC_PREFIX/lib;$GCC_PREFIX/x86_64-w64-mingw32/lib"
	export CPATH="$GCC_PREFIX/include;$GCC_PREFIX/x86_64-w64-mingw32/include"
	#export BOOT_CFLAGS="-static-libgcc -static"
	../configure --prefix=$GCC_PREFIX --with-local-prefix=$GCC_PREFIX \
	  --build=x86_64-w64-mingw32 --enable-targets=all \
	  --enable-languages=c,c++,d,lto --enable-sjlj-exceptions \
	  --enable-lto --enable-version-specific-runtime-libs \
	  --disable-win32-registry --with-gnu-ld \
	  --with-pkgversion="MinGW-GDC64" \
	  --with-bugurl="http://gdcproject.org/bugzilla/" \
	  --disable-shared --disable-bootstrap
	make && make install
	popd
}
export PATH="$GCC_PREFIX/bin:$PATH"
build_gdc

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
make
pushd
