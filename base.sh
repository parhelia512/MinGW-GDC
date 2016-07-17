
readonly SERVER_URL=http://ftp.gnu.org/gnu
readonly GCC_VERSION=5.4.0
readonly BINUTILS_VERSION=2.26

readonly GCC_LANGS="c,c++,d"

readonly BIN=$PWD/bin
readonly ARCHIVES=/tmp/archives

# Sanitize environment.
# Things like CC="ccache gcc" don't work with cross-build tools
unset CC
unset CXX

readonly MAKE="make -j`nproc` -k"
export LDFLAGS=-s

function extract_to
{
  local file=$1
  local dir=$2

	tar xlf "$file"
	rm -rf "$dir"
	mv "`tar tlf $file 2>/dev/null | head -n 1 | cut -f 1 -d '/'`" "$dir"
}

function lazy
{
  local readonly func="$1"

  if [ -f $BIN/flags/$func ] ; then
    return 0
  fi

  echo "$func ..."
  $func & # fork: prevent the callee to change the caller's environment
  pid=$!
  wait $pid

  mkdir -p $BIN/flags
  touch $BIN/flags/$func
}

function lazy_download
{
  local file="$1"
  local url="$2"

  if [ ! -e "$file" ]; then
    wget "$url" -c -O "${file}.tmp"
    mv "${file}.tmp" "$file"
  fi
}

