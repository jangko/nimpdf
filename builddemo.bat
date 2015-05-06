@echo off
set path=c:\mingw\bin;c:\nim\bin

set currentDir=%cd%
set sourceDir=%currentDir%\source
set subsetterDir=%currentDir%\subsetter

nim c -d:release --opt:size --path:%sourceDir% ^
--path:%subsetterDir% ^
--cincludes:%sourceDir% ^
demo.nim

strip -s demo.exe