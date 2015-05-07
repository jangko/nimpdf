@echo off
set path=c:\mingw\bin;c:\nim\bin

if "%1" == "" goto needarg

set currentDir=%cd%
set sourceDir=%~dp0..\source
set subsetterDir=%~dp0..\subsetter

nim c --path:%sourceDir% ^
--path:%subsetterDir% ^
--cincludes:%sourceDir% ^
%currentDir%\%1.nim

%1.exe
goto finish

:needarg
echo argument needed
echo usage: build source

:finish