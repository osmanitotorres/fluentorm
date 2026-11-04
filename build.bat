@echo off
rem ---------------------------------------------------------------------------
rem FluentORM - compila biblioteca, testes, ferramenta e exemplos e roda os testes.
rem Resultado completo em build.log (na mesma pasta deste arquivo).
rem Uso: build.bat [Win32|Win64]   (padrao Win64)
rem ---------------------------------------------------------------------------
setlocal EnableDelayedExpansion
set ROOT=%~dp0
if "%ROOT:~-1%"=="\" set ROOT=%ROOT:~0,-1%
set LOG=%ROOT%\build.log
set TARGET=%1
if "%TARGET%"=="" set TARGET=Win64

set RSVARS=
for %%V in (37.0 23.0 22.0) do (
  if not defined RSVARS if exist "C:\Program Files (x86)\Embarcadero\Studio\%%V\bin\rsvars.bat" set "RSVARS=C:\Program Files (x86)\Embarcadero\Studio\%%V\bin\rsvars.bat"
)
if not defined RSVARS (
  echo rsvars.bat do Delphi nao encontrado. > "%LOG%"
  type "%LOG%"
  exit /b 1
)
call "%RSVARS%"

if /I "%TARGET%"=="Win32" (set DCC=dcc32) else (set DCC=dcc64)
set OUT=%ROOT%\Build\%TARGET%
if not exist "%OUT%\dcu" mkdir "%OUT%\dcu"
set NS=System;Xml;Data;Datasnap;Web;Soap;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell;Winapi;System.Win;Data.Win;FireDAC
set FLAGS=-B -Q -NS"%NS%" -U"%ROOT%" -I"%ROOT%" -E"%OUT%" -NU"%OUT%\dcu"

echo FluentORM build %DATE% %TIME% - %TARGET% > "%LOG%"
echo Delphi: %RSVARS% >> "%LOG%"
set FAILED=0

call :compile "%ROOT%\Tests\FluentORM.Tests.dpr"
call :compile "%ROOT%\Tests\FluentORM.MSSQLSmoke.dpr"
call :compile "%ROOT%\Tools\FluentORM.DtoGenerator\FluentORM.DtoGenerator.dpr"
call :compile "%ROOT%\Samples\Sample03_MultiBanco\Sample03.dpr"
call :compile "%ROOT%\Samples\Sample04_MySQL_VCL\Sample04.dpr"
call :compile "%ROOT%\Samples\Sample06_DuasBases_VCL\Sample06.dpr"
call :compile "%ROOT%\Samples\Sample02\Sample02.dpr"
call :compile "%ROOT%\Samples\Sample01.dpr"

echo. >> "%LOG%"
echo ==== Testes ==== >> "%LOG%"
if exist "%OUT%\FluentORM.Tests.exe" (
  "%OUT%\FluentORM.Tests.exe" >> "%LOG%" 2>&1
  if errorlevel 1 set FAILED=1
) else (
  echo FluentORM.Tests.exe nao foi gerado. >> "%LOG%"
  set FAILED=1
)

echo. >> "%LOG%"
if "%FAILED%"=="0" (echo RESULTADO: OK >> "%LOG%") else (echo RESULTADO: FALHOU >> "%LOG%")
type "%LOG%"
exit /b %FAILED%

:compile
echo. >> "%LOG%"
echo ==== %~nx1 ==== >> "%LOG%"
pushd "%~dp1"
%DCC% %FLAGS% "%~nx1" >> "%LOG%" 2>&1
if errorlevel 1 (
  echo ** ERRO DE COMPILACAO em %~nx1 >> "%LOG%"
  set FAILED=1
)
popd
exit /b 0
