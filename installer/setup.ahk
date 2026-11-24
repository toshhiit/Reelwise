; =====================================================================
;  Установщик Reelwise. Запускается из Reelwise-Setup.exe (IExpress распаковывает рядом
;  Reelwise.exe — среду AutoHotkey — этот файл и payload.zip, и запускает «Reelwise.exe setup.ahk»).
;  Ставит в %LOCALAPPDATA%\Programs\Reelwise (права администратора не нужны), делает ярлыки
;  в «Пуске» и (по желанию) на рабочем столе, добавляет удаление в «Приложения».
;  Настройки (settings.ini) при переустановке сохраняются.
; =====================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon
DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

global APP := "Reelwise", VER := "2.1"
global DEST := EnvGet("LOCALAPPDATA") "\Programs\" APP
global C_BG := "161B22", C_FIELD := "212833", C_LINE := "2E3744", C_TXT := "DCE3EA", C_MUTED := "8B96A5"
global C_ACC := "5CC8B8", C_ACC_HI := "7FD8CB", C_HOVER := "2A3340", C_BAD := "E07A7A"
global Desk := true, Busy := false, Done := false

; ресурсы лежат в payload.zip; логотип для окна установщика достаём заранее во временную папку
global TMP := A_Temp "\reelwise-setup-" A_TickCount
DirCreate(TMP)
Unzip(A_ScriptDir "\payload.zip", TMP)

G := Gui("-MaximizeBox -DPIScale", "Установка " APP)
G.BackColor := C_BG
G.OnEvent("Close", (*) => Leave())
if FileExist(TMP "\assets\logo96.png")
    G.Add("Picture", "x28 y28 w96 h96 BackgroundTrans", TMP "\assets\logo96.png")
G.SetFont("s22 bold c" C_TXT, "Segoe UI Semibold")
G.Add("Text", "x148 y30 w360 h40 BackgroundTrans", APP)
G.SetFont("s10 norm c" C_MUTED, "Segoe UI")
G.Add("Text", "x150 y74 w360 h20 BackgroundTrans", "Авто-рыбалка и оценка мутаций для Fisch  ·  v" VER)
G.Add("Text", "x150 y98 w360 h20 BackgroundTrans", "Права администратора не нужны")
G.Add("Text", "x28 y146 w484 h1 Background" C_LINE, "")

G.SetFont("s9 norm c" C_MUTED, "Segoe UI")
G.Add("Text", "x28 y160 w484 h18 BackgroundTrans", "Папка установки")
G.SetFont("s10 norm c" C_TXT, "Segoe UI")
PathBox := G.Add("Text", "x28 y180 w484 h28 +0x200 Background" C_FIELD, "   " DEST)
G.SetFont("s10 norm c" C_TXT, "Segoe UI")
TgDeskLbl := G.Add("Text", "x28 y216 w260 h24 +0x200 BackgroundTrans", "Ярлык на рабочем столе")
TgDesk := G.Add("Picture", "x290 y216 w44 h24", TMP "\assets\switch_on.png")
TgDesk.OnEvent("Click", (*) => FlipDesk())
TgDeskLbl.OnEvent("Click", (*) => FlipDesk())
G.SetFont("s10 norm c" C_MUTED, "Segoe UI")
Msg := G.Add("Text", "x28 y248 w484 h40 BackgroundTrans", "")

G.SetFont("s11 bold", "Segoe UI")
BtnGo := G.Add("Text", "x292 y298 w220 h42 Center +0x200 Background" C_ACC " c" C_BG, "Установить")
BtnGo.OnEvent("Click", (*) => Go())
G.SetFont("s11 norm", "Segoe UI")
BtnNo := G.Add("Text", "x28 y298 w140 h42 Center +0x200 Background" C_FIELD " c" C_MUTED, "Отмена")
BtnNo.OnEvent("Click", (*) => Leave())
G.Show("w540 h364")
for c in [BtnGo, BtnNo, PathBox]
    RoundCorners(c, 12)
DllCall("dwmapi\DwmSetWindowAttribute", "ptr", G.Hwnd, "int", 20, "int*", 1, "int", 4)
DllCall("dwmapi\DwmSetWindowAttribute", "ptr", G.Hwnd, "int", 34, "int*", 0x93A04A, "int", 4)
DllCall("dwmapi\DwmSetWindowAttribute", "ptr", G.Hwnd, "int", 35, "int*", 0x221B16, "int", 4)
if FileExist(TMP "\assets\reelwise.ico")
    for sz in [[16, 0], [32, 1]]
        if (h := DllCall("LoadImage", "ptr", 0, "str", TMP "\assets\reelwise.ico", "uint", 1, "int", sz[1], "int", sz[1], "uint", 0x10, "ptr"))
            SendMessage(0x80, sz[2], h, G)
if FileExist(DEST "\Reelwise.ahk")
    Msg.Text := "Reelwise уже установлен — будет обновлён. Настройки сохранятся."
return

FlipDesk() {
    global Desk
    if Busy || Done
        return
    Desk := !Desk
    TgDesk.Value := TMP "\assets\switch_" (Desk ? "on" : "off") ".png"
}

Go() {
    global Busy, Done
    if Done {                                        ; кнопка стала «Запустить»
        Run('"' DEST '\Reelwise.exe"', DEST)
        Leave()
        return
    }
    if Busy
        return
    Busy := true
    BtnGo.Text := "Устанавливаю…"
    try {
        CloseRunning()
        DirCreate(DEST)
        Unzip(A_ScriptDir "\payload.zip", DEST)
        exe := DEST "\Reelwise.exe", ico := DEST "\assets\reelwise.ico"
        FileCreateShortcut(exe, A_Programs "\" APP ".lnk", DEST, , "Авто-рыбалка для Fisch", ico)
        if Desk
            FileCreateShortcut(exe, A_Desktop "\" APP ".lnk", DEST, , "Авто-рыбалка для Fisch", ico)
        key := "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\" APP
        RegWrite(APP, "REG_SZ", key, "DisplayName")
        RegWrite(VER, "REG_SZ", key, "DisplayVersion")
        RegWrite(APP, "REG_SZ", key, "Publisher")
        RegWrite(ico, "REG_SZ", key, "DisplayIcon")
        RegWrite(DEST, "REG_SZ", key, "InstallLocation")
        RegWrite('"' exe '" "' DEST '\uninstall.ahk"', "REG_SZ", key, "UninstallString")
        RegWrite(1, "REG_DWORD", key, "NoModify")
        RegWrite(1, "REG_DWORD", key, "NoRepair")
        RegWrite(1500, "REG_DWORD", key, "EstimatedSize")
    } catch as e {
        Busy := false
        BtnGo.Text := "Установить"
        Msg.Opt("c" C_BAD), Msg.Text := "Не получилось: " e.Message
        return
    }
    Busy := false, Done := true
    Msg.Opt("c" C_ACC)
    Msg.Text := "Готово. Reelwise есть в меню «Пуск»" (Desk ? " и на рабочем столе" : "") ".`n"
        . "В игре включи навигацию по интерфейсу (клавиша \), потом F6."
    BtnGo.Text := "Запустить Reelwise"
    BtnNo.Text := "Закрыть"
}

; распаковка zip средствами Windows (PowerShell Expand-Archive, есть в Windows 10/11).
; Shell.Application.CopyHere асинхронный, а имена в zip он отдаёт без расширений — ждать его было ненадёжно
Unzip(zip, dest) {
    q(x) => "'" StrReplace(x, "'", "''") "'"
    DirCreate(dest)
    code := RunWait('powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '
        . q(zip) ' -DestinationPath ' q(dest) ' -Force"', , "Hide")
    if code
        throw Error("не удалось распаковать файлы (код " code ")")
}

; закрыть уже запущенный Reelwise из папки установки (по пути: сам установщик тоже Reelwise.exe)
CloseRunning() {
    for p in ComObjGet("winmgmts:").ExecQuery("SELECT ProcessId, ExecutablePath FROM Win32_Process WHERE Name='Reelwise.exe'")
        if (p.ExecutablePath && InStr(p.ExecutablePath, DEST) = 1)
            try ProcessClose(p.ProcessId)
    Sleep 300
}

RoundCorners(c, r) {
    c.GetPos(, , &w, &h)
    DllCall("SetWindowRgn", "ptr", c.Hwnd, "ptr", DllCall("CreateRoundRectRgn", "int", 0, "int", 0, "int", w + 1, "int", h + 1, "int", r, "int", r, "ptr"), "int", 1)
}

Leave() {
    try DirDelete(TMP, true)
    ExitApp
}
