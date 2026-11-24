# Сборка установщика Reelwise-Setup.exe встроенным в Windows IExpress (ничего скачивать не нужно).
# Запуск:  powershell -ExecutionPolicy Bypass -File installer\build.ps1
# Результат: dist\Reelwise-Setup.exe рядом с папкой Reelwise.
$ErrorActionPreference = 'Stop'
$root  = Split-Path -Parent $PSScriptRoot            # папка Reelwise
$stage = Join-Path $env:TEMP "reelwise-build"
$pay   = Join-Path $stage 'payload'
$dist  = Join-Path $root 'dist'
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $pay, "$pay\Lib", "$pay\assets", $dist | Out-Null

# что ставится пользователю (без личных settings.ini и журналов)
Copy-Item "$root\Reelwise.exe", "$root\Reelwise.ahk", "$root\README.txt" $pay
Copy-Item "$root\installer\uninstall.ahk" $pay
Copy-Item "$root\Lib\OCR.ahk", "$root\Lib\AutoHotkey-license.txt" "$pay\Lib"
Copy-Item "$root\assets\reelwise.ico", "$root\assets\logo44.png", "$root\assets\logo96.png", "$root\assets\switch_on.png", "$root\assets\switch_off.png" "$pay\assets"
Compress-Archive -Path "$pay\*" -DestinationPath "$stage\payload.zip" -Force
# тот же набор файлов — для самообновления (файл релиза на GitHub)
Copy-Item "$stage\payload.zip" (Join-Path $dist 'Reelwise-update.zip') -Force

# файлы самого установщика: среда AutoHotkey (под именем Reelwise.exe), скрипт установки, архив
Copy-Item "$root\Reelwise.exe" "$stage\Reelwise.exe"
Copy-Item "$root\installer\setup.ahk" "$stage\setup.ahk"

$target = Join-Path $stage 'Reelwise-Setup.exe'   # IExpress fails on paths with spaces: build in TEMP, then copy
$sed = @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=%InstallPrompt%
DisplayLicense=%DisplayLicense%
FinishMessage=%FinishMessage%
TargetName=%TargetName%
FriendlyName=%FriendlyName%
AppLaunched=%AppLaunched%
PostInstallCmd=%PostInstallCmd%
AdminQuietInstCmd=%AdminQuietInstCmd%
UserQuietInstCmd=%UserQuietInstCmd%
SourceFiles=SourceFiles
[Strings]
InstallPrompt=
DisplayLicense=
FinishMessage=
TargetName=$target
FriendlyName=Reelwise
AppLaunched=Reelwise.exe setup.ahk
PostInstallCmd=<None>
AdminQuietInstCmd=
UserQuietInstCmd=
FILE0="Reelwise.exe"
FILE1="setup.ahk"
FILE2="payload.zip"
[SourceFiles]
SourceFiles0=$stage\
[SourceFiles0]
%FILE0%=
%FILE1%=
%FILE2%=
"@
Set-Content -Path "$stage\reelwise.sed" -Value $sed -Encoding ASCII
Remove-Item $target -ErrorAction SilentlyContinue
$p = Start-Process -FilePath "$env:WINDIR\System32\iexpress.exe" -ArgumentList '/N', '/Q', "$stage\reelwise.sed" -Wait -PassThru   # no quotes: IExpress rejects a quoted SED path (TEMP has no spaces)
if (-not (Test-Path $target)) { throw "IExpress failed (exit code $($p.ExitCode))" }
Copy-Item $target (Join-Path $dist 'Reelwise-Setup.exe') -Force
Get-Item (Join-Path $dist 'Reelwise-Setup.exe') | Select-Object FullName, Length
