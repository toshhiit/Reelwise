; Удаление Reelwise (запускается из «Приложения» Windows: Reelwise.exe uninstall.ahk)
#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

APP := "Reelwise"
DEST := A_ScriptDir
if MsgBox("Удалить " APP " и его настройки?`n`n" DEST, "Удаление " APP, "YesNo Icon? Default2") != "Yes"
    ExitApp
; закрыть запущенный макрос (кроме себя)
for p in ComObjGet("winmgmts:").ExecQuery("SELECT ProcessId, ExecutablePath FROM Win32_Process WHERE Name='Reelwise.exe'")
    if (p.ProcessId != ProcessExist() && p.ExecutablePath && InStr(p.ExecutablePath, DEST) = 1)
        try ProcessClose(p.ProcessId)
try FileDelete(A_Programs "\" APP ".lnk")
try FileDelete(A_Desktop "\" APP ".lnk")
try RegDeleteKey("HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\" APP)
; папку удаляем после выхода: сам Reelwise.exe из неё сейчас запущен
Run(A_ComSpec ' /c timeout /t 2 /nobreak >nul & rmdir /s /q "' DEST '"', , "Hide")
MsgBox(APP " удалён.", "Удаление " APP, "Iconi T3")
ExitApp
