@echo off
set currentDir=%cd%
set sourceDir=%~dp0..\source

if "%1" == "" goto needarg
if "%1" == "all" goto buildall

nim c --path:%sourceDir% --cincludes:%sourceDir% %currentDir%\%1.nim
%1.exe
goto finish

:buildall
SET files=basic_outline,curve,destination_outline,encoding_list
SET files=%files%,encrypted
SET files=%files%,hello
SET files=%files%,heirarchy_outline
SET files=%files%,link_annot
SET files=%files%,page_labels
SET files=%files%,test
SET files=%files%,text_annot
echo %files%

FOR %%A in (%files%) DO (
  nim c --path:%sourceDir% --cincludes:%sourceDir% %currentDir%\%%A.nim
  %%A.exe
)

goto finish

:needarg
echo argument needed
echo usage: build source
echo or   : build all

:finish