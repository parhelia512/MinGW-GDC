Authors
=======

- venix
- Ace17 (Sebastien Alaiwan: sebastien.alaiwan@gmail.com)

MinGW-GDC
=========

 * Lastest working:
   * D2.062 GCC 4.8.0

This is a script for building a GCC+GDC compiler targetting MS Windows.
The script can be run:
- from Windows, using MinGW's MSYS2 environment.
- from GNU/Linux (Tested under Debian).

The built compiler runs under the system it was built from.
The script handles all dependencies (automatic download).

Building
--------

* If building for MS Windows, install MSYS2 [[http://mingw.org]]

* Download the latest MinGW-GDC head

  $ git clone https://github.com/Ace17/MinGW-GDC.git

* Enter directory and run

  $ ./build.sh /path/to/output/directory

  To enable parallel builds, type instead:
  $ MAKE='make -j8' ./build.sh /path/to/output/directory


Common Issues
-------------

* Spaces in PATH. I have found 

* I have found that from MS Windows, parallel builds may sometimes fail. Under
  Debian I have had no issues building with 8 cores. Please note that some parts
  of the build will still be run sequentially, like downloads and some 
  subdirectories of binutils/gcc.

How it works internally
-----------------------

To build a GCC compiler targetting MS Windows, the script goes through the
following steps:

* Build binutils.
  This step provides "ld", "as", "objdump", etc. for the target.
  Technically, binutils isn't a GCC dependency, but the build process will need
  it later.

* Build GCC dependencies:
  * GMP
  * MPFR
  * MPC
  * CLOOG
  * ISL

* Build GCC: host part.
  This step will is achieved by running:
  $ make all-host
  A working compiler will be created. This compiler will enable to create ".o"
  files for the target. But at this stage you won't be able to link a full
  program, because the runtime libraries (crt1.o) are not built yet.
  And you can't build the runtime libraries without the Win32 API libraries,
  which are not available yet at this point.

* Build mingw64.
  This step provides 'windows.h', libkernel32.a, etc.
  mingw64 is split in several parts, we only use here the following parts:
  * mingw-w64-headers
  * mingw-w64-crt
  * winpthread

  All of these parts generate code which will be run under MS Windows. So they
  must be compiled using the GCC created in the previous step, which targets
  MS Windows.

  mingw-w64-headers must be built and installed first. Otherwise, mingw-w64-crt
  configuration will fail. Then mingw-w64-crt can be built and installed, then
  winpthread library.

* Finish GCC: target part.
  This step will is achieved by running:
  $ make all-target
  The build process will rely on the freshly built crt to generate a libgcc to
  be run under MS Windows.



