#!/bin/sh
VER=`cat Version`
ZIPNAME=cheesecutter-$VER-win32.zip
ZIPDLLNAME=cheesecutter-$VER-dlls-win32.zip
rm -f $ZIPNAME $ZIPDLLNAME
make -f Makefile.win32 clean all
strip ccutter.exe
strip ct2util.exe
zip $ZIPNAME ccutter.exe ct2util.exe README COPYING tunes/*
zip $ZIPDLLNAME ccutter.exe ct2util.exe README COPYING tunes/*
zip -j $ZIPDLLNAME ../dll/*
