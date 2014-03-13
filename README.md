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

- I found that from MS Windows, parallel builds may sometimes fail. Under Debian
I have had no issues building with 8 cores. Please note that some parts of the 
build are designed to be sequential.

