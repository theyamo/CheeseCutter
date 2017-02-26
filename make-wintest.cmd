@echo off
REM Expecting directory ..\DLL to contain SDL.dll

set /p VER=<Version
set ZIPNAME=cheesecutter-%VER%-win32.zip
set ZIPDLLNAME=cheesecutter-%VER%-dlls-win32.zip
del %ZIPNAME% %ZIPDLLNAME%
make -f Makefile.win32 clean all
strip ccutter.exe
strip ct2util.exe
zip %ZIPNAME% ccutter.exe ct2util.exe README.md tunes\*.*
zip %ZIPDLLNAME% ccutter.exe ct2util.exe README.md tunes\*.*
zip -j %ZIPDLLNAME% ..\dll\*.*
set ZIPNAME=
set ZIPDLLNAME=
set VER=
