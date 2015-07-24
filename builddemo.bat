@echo off

set currentDir=%cd%
set sourceDir=%currentDir%\source

nim c -d:release --opt:size --path:%sourceDir% ^
--cincludes:%sourceDir% demo.nim

strip -s demo.exe
