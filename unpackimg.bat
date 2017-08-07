@echo off
setlocal
set CYGWIN=nodosfilewarning

if "%~1" == "--help" echo usage: unpackimg.bat ^<file^> & goto end
if "[%~1]" == "[]" goto noargs
set "file=%~f1"
set "bin=%~dp0\android_win_tools"
set "cur=%cd%"
set "rel=..\android_win_tools"

echo Android Image Kitchen - UnpackImg Script
echo by osm0sis @ xda-developers
echo.

echo Supplied image: %~nx1
echo.

if exist split_img\nul set "noclean=1"
if exist ramdisk\nul set "noclean=1"
if defined noclean (
  echo Removing old work folders and files . . .
  echo.
  call cleanup.bat
)

echo Setting up work folders . . .
echo.
md split_img
md ramdisk

copy "%bin%"\androidbootimg.magic "%cur%"\androidbootimg.magic >nul
copy "%bin%"\magic "%cur%"\magic >nul

cd split_img
"%bin%"\file -m ..\androidbootimg.magic "%file%" | "%bin%"\cut -d: -f2- | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f3 | "%bin%"\cut -d, -f1 > "%~nx1-imgtype"
for /f "delims=" %%a in ('type "%~nx1-imgtype"') do @set "imgtest=%%a"
if "%imgtest%" == "signing" (
  "%bin%"\file -m ..\androidbootimg.magic "%file%" | "%bin%"\cut -d: -f2- | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f2 > "%~nx1-sigtype"
  for /f "delims=" %%a in ('type "%~nx1-sigtype"') do @set "sigtype=%%a" & echo Signature with "%%a" type detected, removing . . .
  echo.
)
if "%sigtype%" == "CHROMEOS" "%bin%"\futility vbutil_kernel --get-vmlinuz "%file%" --vmlinuz-out "%~nx1" & set "file=%~nx1"
if "%sigtype%" == "BLOB" (
  copy /b "%file%" . >nul
  "%bin%"\blobunpack "%~nx1" | findstr "Name:" | "%bin%"\cut -d" " -f2 > "%~nx1-blobtype" 2>nul
  move /y "%~nx1.LNX" "%~nx1" >nul 2>&1
  move /y "%~nx1.SOS" "%~nx1" >nul 2>&1
  set "file=%~nx1"
)
if "%sigtype%" == "SIN" (
  "%bin%"\kernel_dump . "%file%" >nul
  move /y "%~nx1.*" "%~nx1" >nul 2>&1
  set "file=%~nx1"
  del "%~nx1-sigtype"
)

"%bin%"\file -m ..\androidbootimg.magic "%file%" | "%bin%"\cut -d: -f2- | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f3 | "%bin%"\cut -d, -f1 > "%~nx1-imgtype"
for /f "delims=" %%a in ('type "%~nx1-imgtype"') do @set "imgtest=%%a"
if "%imgtest%" == "bootimg" (
  set "imgtest="
  "%bin%"\file -m ..\androidbootimg.magic "%file%" | "%bin%"\cut -d: -f2- | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f4 > "%~nx1-imgtype"
  for /f "delims=" %%a in ('type "%~nx1-imgtype"') do (
    if "%%a" == "PXA" set "imgtest=-%%a"
  )
  "%bin%"\file -m ..\androidbootimg.magic "%file%" | "%bin%"\cut -d: -f2- | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f2 > "%~nx1-imgtype"
  for /f "delims=" %%a in ('type "%~nx1-imgtype"') do @set "imgtype=%%a"
) else (
  call "%~dp0\cleanup.bat"
  echo Unrecognized format.
  goto error
)
set "imgtype=%imgtype%%imgtest%"
echo %imgtype%>"%~nx1-imgtype"
echo Image type: %imgtype%
echo.

if "%imgtype%" == "AOSP" set "supported=1"
if "%imgtype%" == "AOSP-PXA" set "supported=1"
if "%imgtype%" == "ELF" set "supported=1"
if "%imgtype%" == "U-Boot" set "supported=1"
if not defined supported call "%~dp0\cleanup.bat" & echo Unsupported format. & goto error

"%bin%"\file -m ..\androidbootimg.magic "%file%" | "%bin%"\cut -d: -f2- | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f4 > "%~nx1-lokitype"
for /f "delims=" %%a in ('type "%~nx1-lokitype"') do @set "lokitest=%%a"
if "%lokitest%" == "LOKI" (
  "%bin%"\file -m ..\androidbootimg.magic "%file%" | "%bin%"\cut -d: -f2- | "%bin%"\cut -d: -f2 | "%bin%"\cut -d( -f2 | "%bin%"\cut -d^) -f1 > "%~nx1-lokitype"
  for /f "delims=" %%a in ('type "%~nx1-lokitype"') do @echo Loki patch with "%%a" type detected, reverting . . .
  echo.
  echo Warning: A dump of your device's aboot.img is required to re-Loki!
  "%bin%"\loki_tool unlok "%file%" "%~nx1" >nul
  echo.
  set "file=%~nx1"
) else (
  del "%~nx1-lokitype"
)

"%bin%"\tail "%file%" 2>nul | "%bin%"\file -m ..\androidbootimg.magic - | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f2 > "%~nx1-tailtype"
for /f "delims=" %%a in ('type "%~nx1-tailtype"') do @set "tailtype=%%a"
if not "%tailtype%" == "AVB" if not "%tailtype%" == "SEAndroid" if not "%tailtype%" == "Bump" del "%~nx1-tailtype"
if "%tailtype%" == "AVB" (
  "%bin%"\tail "%file%" 2>nul | "%bin%"\file -m ..\androidbootimg.magic - | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f5 > "%~nx1-avbtype"
  echo Signature with "%tailtype%" type detected. & echo.
  move /y "%~nx1-tailtype" "%~nx1-sigtype" >nul
)
if exist "*-tailtype" echo Footer with "%tailtype%" type detected. & echo.

echo Splitting image to "split_img/" . . .
echo.
if "%imgtype%" == "AOSP" "%bin%"\unpackbootimg -i "%file%"
if "%imgtype%" == "AOSP-PXA" "%bin%"\pxa1088-unpackbootimg -i "%file%"
if "%imgtype%" == "ELF" "%bin%"\unpackelf -i "%file%"
if "%imgtype%" == "U-Boot" (
  "%bin%"\dumpimage -l "%file%"
  "%bin%"\dumpimage -l "%file%" > "%~nx1-header"
  type "%~nx1-header" | findstr "Name:" | "%bin%"\cut -c15- > "%~nx1-name"
  type "%~nx1-header" | findstr "Type:" | "%bin%"\cut -c15- | "%bin%"\cut -d" " -f1 > "%~nx1-arch"
  type "%~nx1-header" | findstr "Type:" | "%bin%"\cut -c15- | "%bin%"\cut -d" " -f2 > "%~nx1-os"
  type "%~nx1-header" | findstr "Type:" | "%bin%"\cut -c15- | "%bin%"\cut -d" " -f3 | "%bin%"\cut -d- -f1 > "%~nx1-type"
  type "%~nx1-header" | findstr "Type:" | "%bin%"\cut -d^( -f2 | "%bin%"\cut -d^) -f1 | "%bin%"\cut -d" " -f1 | "%bin%"\cut -d- -f1 > "%~nx1-comp"
  type "%~nx1-header" | findstr "Address:" | "%bin%"\cut -c15- > "%~nx1-addr"
  type "%~nx1-header" | findstr "Point:" | "%bin%"\cut -c15- > "%~nx1-ep"
  del "%~nx1-header"
  "%bin%"\dumpimage -i "%file%" -p 0 "%~nx1-zImage"
  for /f "delims=" %%a in ('type "%~nx1-type"') do (
    if not "%%a" == "Multi" echo. & echo No ramdisk found. & call "%~dp0\cleanup.bat" & goto error
  )
  "%bin%"\dumpimage -i "%file%" -p 1 "%~nx1-ramdisk.cpio.gz"
)
if errorlevel == 1 call "%~dp0\cleanup.bat" & goto error
echo.

"%bin%"\file -m ..\androidbootimg.magic *-zImage | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f2 > "%~nx1-mtktest"
for /f "delims=" %%a in ('type "%~nx1-mtktest"') do @set "mtktest=%%a"
if "%mtktest%" == "MTK" (
  set "mtk=1"
  echo MTK header found in zImage, removing . . .
  "%bin%"\dd bs=512 skip=1 conv=notrunc if="%~nx1-zImage" of="tempzimg" 2>nul
  move /y tempzimg "%~nx1-zImage" >nul
)
for /f "delims=" %%a in ('dir /b *-ramdisk*.gz') do @set "ramdiskname=%%a"
"%bin%"\file -m ..\androidbootimg.magic %ramdiskname% | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f2 > "%~nx1-mtktest"
for /f "delims=" %%a in ('type "%~nx1-mtktest"') do @set "mtktest=%%a"
"%bin%"\file -m ..\androidbootimg.magic %ramdiskname% | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f4 > "%~nx1-mtktype"
for /f "delims=" %%a in ('type "%~nx1-mtktype"') do @set "mtktype=%%a"
if "%mtktest%" == "MTK" (
  if not defined mtk echo Warning: No MTK header found in zImage! & set "mtk=1"
  echo MTK header found in "%mtktype%" type ramdisk, removing . . .
  "%bin%"\dd bs=512 skip=1 conv=notrunc if="%ramdiskname%" of="temprd" 2>nul
  move /y temprd "%ramdiskname%" >nul
) else (
  if defined mtk (
    if "[%mtktype%]" == "[]" (
      echo Warning: No MTK header found in ramdisk, assuming "rootfs" type!
      echo rootfs > "%~nx1-mtktype"
    )
  ) else (
    del "%~nx1-mtktype"
  )
)
del "%~nx1-mtktest"
if defined mtk echo.

if exist "*-dtb" (
  "%bin%"\file -m ..\androidbootimg.magic *-dtb | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f2 > "%~nx1-dtbtest"
  for /f "delims=" %%a in ('type "%~nx1-dtbtest"') do (
    if "%imgtype%" == "ELF" if not "%%a" == "QCDT" if not "%%a" == "ELF" (
      echo Non-QC DTB found, packing zImage and appending . . .
      echo.
      "%bin%"\gzip --no-name -9 "%~nx1-zImage"
      copy /b "%~nx1-zImage.gz"+"%~nx1-dtb" "%~nx1-zImage" >nul
      del *-dtb *-zImage.gz
    )
  )
  del "%~nx1-dtbtest"
)

"%bin%"\file -m ..\magic *-ramdisk*.gz | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f2 > "%~nx1-ramdiskcomp"
for /f "delims=" %%a in ('type "%~nx1-ramdiskcomp"') do @set "ramdiskcomp=%%a"
if "%ramdiskcomp%" == "gzip" set "unpackcmd=gzip -dc" & set "compext=gz"
if "%ramdiskcomp%" == "lzop" set "unpackcmd=lzop -dc" & set "compext=lzo"
if "%ramdiskcomp%" == "lzma" set "unpackcmd=xz -dc" & set "compext=lzma"
if "%ramdiskcomp%" == "xz" set "unpackcmd=xz -dc" & set "compext=xz"
if "%ramdiskcomp%" == "bzip2" set "unpackcmd=bzip2 -dc" & set "compext=bz2"
if "%ramdiskcomp%" == "lz4" set "unpackcmd=lz4 -dcq" & set "compext=lz4"
ren *ramdisk*.gz *ramdisk.cpio.%compext%
cd ..
if "%ramdiskcomp%" == "data" echo. & echo Unrecognized format. & goto error

echo Unpacking ramdisk to "ramdisk/" . . .
echo.
cd ramdisk
echo Compression used: %ramdiskcomp%
if not defined compext echo. & echo Unsupported format. & goto error
"%bin%"\%unpackcmd% "..\split_img\%~nx1-ramdisk.cpio.%compext%" | "%bin%"\cpio -i
if errorlevel == 1 goto error
cd ..
"%bin%"\chmod -fR +rw ramdisk split_img >nul 2>&1
echo.

echo Done!
goto end

:noargs
echo No image file supplied.

:error
echo Error!

:end
del "%cur%"\androidbootimg.magic 2>nul
del "%cur%"\magic 2>nul
echo.
echo %cmdcmdline% | findstr /i pushd >nul
if errorlevel 1 pause
