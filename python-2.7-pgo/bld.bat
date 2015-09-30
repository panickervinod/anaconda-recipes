setlocal

set "CL=/GL"

REM ========== prepare source
REM -- We must be in top level directory before fetching external deps --
cd %SRC_DIR%
if "%ARCH%"=="64" (
  set "LINK=/OPT:REF,INC"
  set platf=x64
  call %SRC_DIR%\Tools\buildbot\external-amd64.bat
) else (
  set platf=Win32
  set "LINK=/OPT:REF"
  call %SRC_DIR%\Tools\buildbot\external.bat
)

set job1=..\lib\test\regrtest.py
set path1=..\lib
set PGI=%platf%-pgi
set PGO=%platf%-pgo

REM ========== actual compile step

call %SRC_DIR%\PCbuild\build.bat -p %platf% -c PGInstrument

%PGI%\python.exe rmpyc.py %path1%
del %PGI%\*.pgc
%PGI%\python.exe %job1%
if exist %PGO% del /s /q %PGO%
call %SRC_DIR%\PCbuild\build.bat -p %platf% -c PGUpdate
if errorlevel 1 exit 1

if "%ARCH%"=="64" (
    copy PCbuild\amd64\* PCbuild\
    if errorlevel 1 exit 1
)

REM ========== add stuff from official python.org msi

set MSI_DIR=\Pythons\2.7.10-%ARCH%
for %%x in (DLLs Doc libs tcl Tools) do (
    xcopy /s %MSI_DIR%\%%x %PREFIX%\%%x\
    if errorlevel 1 exit 1
)
copy %MSI_DIR%\LICENSE.txt %PREFIX%\LICENSE_PYTHON.txt
if errorlevel 1 exit 1

REM ========== add stuff from our own build

set PCB=%SRC_DIR%\PCbuild

xcopy /s %SRC_DIR%\Include %PREFIX%\include\
if errorlevel 1 exit 1
copy %SRC_DIR%\PC\pyconfig.h %PREFIX%\include\
if errorlevel 1 exit 1

for %%x in (python27.dll python.exe pythonw.exe) do (
    copy %PCB%\%%x %PREFIX%
    if errorlevel 1 exit 1
)
copy %PCB%\python27.lib %PREFIX%\libs\
if errorlevel 1 exit 1
del %PREFIX%\libs\libpython*.a
if errorlevel 1 exit 1

copy %PCB%\w9xpopen.exe %PREFIX%\
if errorlevel 1 exit 1

xcopy /s %SRC_DIR%\Lib %STDLIB_DIR%\
if errorlevel 1 exit 1
rd /s /q %PREFIX%\Lib\test
if errorlevel 1 exit 1

REM ========== bytecode compile standard library

%PYTHON% -Wi %STDLIB_DIR%\compileall.py -f -q -x "bad_coding|badsyntax|py3_" %STDLIB_DIR%
if errorlevel 1 exit 1

REM ========== add scripts

mkdir %SCRIPTS%
if errorlevel 1 exit 1
for %%x in (idle 2to3 pydoc) do (
    copy %SRC_DIR%\Tools\scripts\%%x %SCRIPTS%
    if errorlevel 1 exit 1
)
