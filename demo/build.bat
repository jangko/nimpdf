@echo off
if "%1" == "" goto needarg

set currentDir=%cd%
set sourceDir=%~dp0..\source

nim c --path:%sourceDir% ^
--cincludes:%sourceDir% ^
%currentDir%\%1.nim

%1.exe
goto finish

:needarg
echo argument needed
echo usage: build source

:finish