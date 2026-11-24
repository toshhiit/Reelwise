; =====================================================================
;  REELWISE — авто-рыбалка + авто-оценка (Drowned Appraiser) для Roblox Fisch
;  (бывший Fisch Macro 1.2). AutoHotkey v2. Roblox — на весь экран.
;
;  Вкладка «Рыбалка»: заброс -> Shake (Enter, навигация UI включена в игре) -> подсечка.
;  Вкладка «Оценка»:  жмёт «Can you appraise it again?», читает мутацию (Windows OCR)
;                     и останавливается на нужной.
;
;  Клавиши:  F6 — старт / пауза (после старта окно прячется, в паузе возвращается)    F8 — выход
;    Рыбалка: F1 — цвет рыбы под мышью, F7 — цвет полоски, F3 — тест зрения
;    Оценка:  F1 — точка клика, F2 — область (2 раза), F5 — стандартная область,
;             F3 — прочитать сейчас, F4 — показать рамки
;
;  Настройки сохраняются в settings.ini рядом с программой. Больше ничего на диск не пишется.
;  OCR: Lib\OCR.ahk (MIT, Descolada)
; =====================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
#Include Lib\OCR.ahk

CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
CoordMode "ToolTip", "Screen"
SetWorkingDir A_ScriptDir
SendMode "Input"
SetMouseDelay -1
DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
DllCall("winmm\timeBeginPeriod", "uint", 1)      ; точный Sleep (1 мс вместо ~16 мс)

global APP_NAME := "Reelwise", APP_VER := "2.1"
global INI := A_ScriptDir "\settings.ini"
global ROBLOX := "ahk_exe RobloxPlayerBeta.exe"
global AutoStart := false, QuitAfter := 0, StartTab := ""
; служебные параметры (для проверки): --window заголовок --ini файл --autostart --quit-after сек --tab fish|appraise
for i, a in A_Args {
    switch a {
        case "--window": ROBLOX := A_Args[i + 1]
        case "--ini": INI := A_Args[i + 1]
        case "--autostart": AutoStart := true
        case "--quit-after": QuitAfter := Integer(A_Args[i + 1])
        case "--tab": StartTab := A_Args[i + 1]
    }
}

Ld(sec, key, def) => IniRead(INI, sec, key, def)

; ---------- тема: тёмно-графитовая + мягкая бирюза (спокойнее для глаз, чем чёрный с розовым) ----------
global C_BG := "161B22", C_FIELD := "212833", C_LINE := "2E3744", C_TXT := "DCE3EA", C_MUTED := "8B96A5"
global C_ACC := "5CC8B8", C_ACC_HI := "7FD8CB", C_ACC_DIM := "4A9E93", C_HOVER := "2A3340"
global C_WARN := "E3B36A", C_BAD := "E07A7A"

; =============================== НАСТРОЙКИ: РЫБАЛКА ===============================
global BX := Integer(Ld("Bar", "X", Round(A_ScreenWidth * 0.29)))
global BY := Integer(Ld("Bar", "Y", Round(A_ScreenHeight * 0.85)))
global BW := Integer(Ld("Bar", "W", Round(A_ScreenWidth * 0.42)))
global BH := Integer(Ld("Bar", "H", Round(A_ScreenHeight * 0.04)))
global FishColor := Integer(Ld("Colors", "Fish", "0x434B5B"))
global FishVar := Integer(Ld("Colors", "FishVariation", 8))
global BarColor := Integer(Ld("Colors", "Bar", "0xF1F1F1"))
global BarVar := Integer(Ld("Colors", "BarVariation", 18))
global EquipKey := Ld("Cast", "EquipKey", "")
global CastHoldMs := Integer(Ld("Cast", "CastHoldMs", 900))
global ShakeIntervalMs := Integer(Ld("Shake", "EnterIntervalMs", 120))
global ShakeTimeoutMs := Integer(Ld("Shake", "ShakeTimeoutMs", 30000))
global Stiffness := Integer(Ld("Reel", "Stiffness", 6))        ; 1-10: как резко тянуть к рыбе
global Smooth := Integer(Ld("Reel", "Damp", 3))                ; 0-10: гашение раскачки
global AutoTuneOn := Integer(Ld("Reel", "AutoTune", 0))
global FrameMs := Integer(Ld("Reel", "FrameMs", 17))           ; кадр игры (60 FPS)
global GameLagMs := Integer(Ld("Reel", "GameLagMs", 60))       ; через сколько игра реагирует на клик
global BarAccel := Float(Ld("Reel", "BarAccelPx", 650))        ; разгон полоски, px/с²
global HoldBias := Max(0.35, Min(0.65, Float(Ld("Reel", "HoldBias", 0.5))))
global CenterPull := Float(Ld("Reel", "CenterPull", 0.3))      ; запас под рывок к центру (0 = выкл.)
global CenterMaxPx := Float(Ld("Reel", "CenterMaxPx", 40))
global CenterDeadPx := Float(Ld("Reel", "CenterDeadPx", 100))
global ReelEndMs := Integer(Ld("Reel", "ReelEndMs", 1500))
global AfterCatchMs := Integer(Ld("Reel", "AfterCatchMs", 2500))
global AriaMode := Integer(Ld("Rod", "Aria", 0))              ; Pinion's Aria: ноты, своя полоса

; =============================== НАСТРОЙКИ: ОЦЕНКА ===============================
global MUTATIONS := ["Abyssal", "Albino", "Amber", "Big", "Giant", "Bioluminescent", "Boreal"
    , "Coral", "Crimson", "Darkened", "Decayed", "Electric", "Entrenched", "Fallen"
    , "Fossilized", "Frozen", "Glossy", "Greedy", "Gusty", "Hexed", "Honey", "Lunar"
    , "Midas", "Mosaic", "Mourned", "Mythical", "Negative", "Petrified", "Poisoned"
    , "Scorched", "Shiny", "Shrouded", "Silver", "Sparkling", "Spirit", "Translucent", "Vined"]
; по умолчанию — положения для 1920×1080, пересчитанные под любой экран
global ClickX := Integer(Ld("Appraise", "ClickX", Round(A_ScreenWidth * 0.530)))
global ClickY := Integer(Ld("Appraise", "ClickY", Round(A_ScreenHeight * 0.494)))
global RX := Integer(Ld("Appraise", "RegionX", Round(A_ScreenWidth * 0.878)))
global RY := Integer(Ld("Appraise", "RegionY", Round(A_ScreenHeight * 0.685)))
global RW := Integer(Ld("Appraise", "RegionW", Round(A_ScreenWidth * 0.121)))
global RH := Integer(Ld("Appraise", "RegionH", Round(A_ScreenHeight * 0.073)))
global Targets := StrSplit(Ld("Appraise", "Targets", "Mourned"), ",", " `t")
global DelayAfterClick := Integer(Ld("Appraise", "DelayAfterClickMs", 1600))
global DelayBetween := Integer(Ld("Appraise", "DelayBetweenMs", 400))
global MaxAttempts := Integer(Ld("Appraise", "MaxAttempts", 5000))
global UseKey1 := Integer(Ld("Appraise", "PressKey1InsteadOfClick", 0))

; =============================== ОКНО ===============================
global OnTop := Integer(Ld("Window", "OnTop", 1))
global GameHints := Integer(Ld("Window", "GameHints", 1))
global WinX := Ld("Window", "X", ""), WinY := Ld("Window", "Y", "")
global HideOnStart := Integer(Ld("Window", "HideOnStart", 1))   ; прятать окно после старта
; самообновление: релизы GitHub-репозитория (владелец/имя); пусто — не проверять
global UPDATE_REPO := Ld("Update", "Repo", "toshhiit/Reelwise")
global AutoUpdate := Integer(Ld("Update", "Auto", 1)), UpdBusy := false
global ShowSettings := Integer(Ld("Window", "ShowSettings", 1))  ; правая колонка с настройками
global CurTab := StartTab != "" ? StartTab : Ld("Window", "Tab", "fish")

; =============================== СОСТОЯНИЕ ===============================
global Running := false, RunMode := "", Testing := false, Holding := false
global FrameGuis := [], AFrameGuis := [], Corner1 := 0
global Casts := 0, Reels := 0, Fails := 0, Attempts := 0, Found := 0
global RunMs := 0, RunStart := 0, ErrCount := 0, TuneLast := "", TunePrev := 0
global PREVIEW_CHARS := 46
global QPF := 0
DllCall("QueryPerformanceFrequency", "int64*", &QPF)
global Cap := 0
global FISH_STD := 0x434B5B, BAR_STD := 0xF1F1F1
global LastFx := "", LastFxMiss := 99, LearnF := [], LearnB := [], LearnP := [], LearnLast := 0
global ReelStartMs := 0, AriaTrack := false                          ; дорожка Aria видна в последнем кадре
global AriaTop := 800                              ; сколько строк над полосой захватываем (до y≈120 экрана)
; строка y≈130 (dy 788) добавлена 24.11: с двумя верхними строками y≈200/350 нота подтверждалась лишь за ~0,72 с
; до приземления, и зона не успевала перегнаться на 300+ px (2 промаха). Теперь подтверждение за ~1,1 с
global NoteRows := [788, 718, 568, 418, 268, 118], NotePend := [], NotePrev := [[], [], [], [], [], []], NoteGot := 0, NoteMiss := 0, TestNow := ""

; самопроверка распознавания: --selftest картинка.png x y w h out.txt
if (A_Args.Length >= 7 && A_Args[1] = "--selftest") {
    SelfTest()
    ExitApp
}
; самопроверка зрения рыбалки на записанных кадрах: --fishtest список.txt out.txt
; (полоса — из settings.ini, координаты внутри картинки)
global TestMode := A_Args.Length >= 3 && A_Args[1] = "--fishtest"
if TestMode {
    FishSelfTest(A_Args[2], A_Args[3])
    ExitApp
}

global Btns := Map(), Toggles := Map(), TabCtl := Map("fish", [], "appraise", [], "common", []), RightCtl := Map(), BuildCol := "L"
BuildGui()
SaveSettings()
OnError(HandleError)
SetTimer(HoverTick, 60)
ShowTab(CurTab)
AddLog(APP_NAME " " APP_VER " запущен")
if AutoUpdate {
    SetTimer(() => CheckUpdate(true), -3000)      ; при запуске
    SetTimer(UpdateTick, 3 * 3600 * 1000)         ; и раз в 3 часа, если не рыбачим
}
if AutoStart
    SetTimer(ToggleRun, -1500)
if QuitAfter
    SetTimer(Quit, -QuitAfter * 1000)

; ============================================================================
;                                   ОКНО
; ============================================================================
BuildGui() {
    global G, StatusTxt, StatsTxt, BtnStart, BtnTest, TabFish, TabApp, LogBox, FooterTxt, BtnGear, ColLine
    global PrevFish, PrevBar, SeeTxt, RegionTxt, TgAria, AriaHint
    global EdCast, EdKp, EdKd, EdShake, EdAfter, EdLag, EdEquip, TgAuto
    global ATextTxt, AMutTxt, AInfoTxt, ACoordTxt, EdTargets, EdDelay1, EdDelay2, EdMax, TgKey1
    global TgTop, TgHints, TgHide, TgUpd, BuildCol

    ; Слева — главное: вкладки, статус, Старт/Тест, режим нот, что видит макрос, журнал.
    ; Справа — настройки; «⚙ Настройки» прячет правую колонку, и окно становится узким.
    L := 20, CW := 410, R := 470, RW := 410, R2 := 680
    G := Gui((OnTop ? "+AlwaysOnTop " : "") "-MaximizeBox -DPIScale", APP_NAME)
    G.BackColor := C_BG
    G.MarginX := 20, G.MarginY := 16
    G.OnEvent("Close", (*) => Quit())
    G.SetFont("s10 c" C_TXT, "Segoe UI")

    ; ===================== левая колонка =====================
    BuildCol := "L"
    logo := A_ScriptDir "\assets\logo44.png"
    if FileExist(logo)
        G.Add("Picture", "x" L " y14 w44 h44", logo)
    G.SetFont("s18 bold c" C_TXT, "Segoe UI Semibold")
    G.Add("Text", "x76 y12 w220 h32 BackgroundTrans", APP_NAME)
    G.SetFont("s9 norm c" C_MUTED, "Segoe UI")
    G.Add("Text", "x78 y42 w220 h18 BackgroundTrans", "для Fisch  ·  v" APP_VER)
    G.SetFont("s10 bold", "Segoe UI")
    BtnGear := MkBtn(L + CW - 132, 18, 132, 36, "⚙  Настройки", (*) => ToggleSettings(), "ghost")

    TabFish := MkBtn(L, 74, 201, 36, "Рыбалка", (*) => ShowTab("fish"), "tab")
    TabApp := MkBtn(L + 209, 74, 201, 36, "Оценка", (*) => ShowTab("appraise"), "tab")

    G.SetFont("s12 bold", "Segoe UI")
    StatusTxt := G.Add("Text", "x" L " y124 w" CW " h24 BackgroundTrans", "")
    G.SetFont("s9 norm c" C_MUTED, "Segoe UI")
    StatsTxt := G.Add("Text", "x" L " y150 w" CW " h18 BackgroundTrans", "")
    G.SetFont("s11 bold", "Segoe UI")
    BtnStart := MkBtn(L, 176, 270, 46, "▶   Старт   F6", (*) => ToggleRun(), "main")
    BtnTest := MkBtn(L + 280, 176, CW - 280, 46, "Тест   F3", (*) => (CurTab = "fish" ? ToggleTest() : ATest()), "ghost")

    T := "fish"
    TgAria := MkToggle(T, L, 238, CW, "Ноты Pinion's Aria", AriaMode, (*) => (ApplySettings(), UpdateAriaHint()))
    G.SetFont("s9 norm c" C_MUTED, "Segoe UI")
    AriaHint := Add(T, "Text", "x" L " y264 w" CW " h18 BackgroundTrans", "")
    UpdateAriaHint()
    Hdr(T, "ЧТО ВИДИТ МАКРОС", L, 292, CW)
    G.SetFont("s10 norm", "Consolas")
    PrevFish := Add(T, "Text", "x" L " y318 w" CW " h18 BackgroundTrans c" C_ACC, "")
    PrevBar := Add(T, "Text", "x" L " y336 w" CW " h18 BackgroundTrans c" C_MUTED, "")
    G.SetFont("s9 norm c" C_MUTED, "Segoe UI")
    SeeTxt := Add(T, "Text", "x" L " y358 w" CW " h18 BackgroundTrans", "Нажми «Тест» во время мини-игры подсечки.")
    UpdatePreview("", 0)

    T := "appraise"
    Hdr(T, "ЧТО ПРОЧИТАНО", L, 238, CW)
    G.SetFont("s9 norm c" C_TXT, "Segoe UI")
    ATextTxt := Add(T, "Text", "x" L " y264 w" CW " h36 BackgroundTrans", "—")
    G.SetFont("s13 bold c" C_ACC, "Segoe UI")
    AMutTxt := Add(T, "Text", "x" L " y304 w" CW " h26 BackgroundTrans", "Мутация: —")
    G.SetFont("s9 norm c" C_MUTED, "Segoe UI")
    AInfoTxt := Add(T, "Text", "x" L " y334 w" CW " h18 BackgroundTrans", "")

    Hdr("", "ЖУРНАЛ", L, 386, CW)
    G.SetFont("s9 norm", "Segoe UI")
    LogBox := G.Add("ListBox", "x" L " y412 w" CW " h124 0x100 -E0x200 Background" C_FIELD " c" C_TXT)
    RoundCorners(LogBox, 10)
    G.SetFont("s8 norm c" C_MUTED, "Segoe UI")
    FooterTxt := G.Add("Text", "x" L " y546 w" CW " h18 BackgroundTrans", "")

    ; ===================== правая колонка (настройки) =====================
    BuildCol := "R"
    ColLine := Add("common", "Text", "x450 y18 w1 h546 Background" C_LINE, "")

    T := "fish"
    Hdr(T, "ПОЛОСА МИНИ-ИГРЫ", R, 18, RW)
    G.SetFont("s10 bold", "Segoe UI")
    Push(T, MkBtn(R, 44, 200, 34, "Выделить полосу", (*) => SelectRegion(), "ghost"))
    Push(T, MkBtn(R2, 44, 200, 34, "Как по умолчанию", (*) => DefaultRegion(), "ghost"))
    G.SetFont("s9 norm c" C_MUTED, "Segoe UI")
    RegionTxt := Add(T, "Text", "x" R " y86 w" RW " h18 BackgroundTrans", "")

    Hdr(T, "ПАРАМЕТРЫ", R, 116, RW)
    EdCast := Field(T, R, 142, "Сила заброса, мс", CastHoldMs)
    EdAfter := Field(T, R2, 142, "Пауза после улова", AfterCatchMs)
    EdKp := Field(T, R, 178, "Жёсткость (1–10)", Stiffness)
    EdKd := Field(T, R2, 178, "Гашение (0–10)", Smooth)
    EdShake := Field(T, R, 214, "Ждать Shake, сек", ShakeTimeoutMs // 1000)
    EdLag := Field(T, R2, 214, "Задержка игры, мс", GameLagMs)
    EdEquip := Field(T, R, 250, "Слот удочки", EquipKey, false)
    TgAuto := MkToggle(T, R2, 251, 200, "Автоподстройка", AutoTuneOn, (*) => ApplySettings())
    G.SetFont("s9 norm c" C_MUTED, "Segoe UI")
    Add(T, "Text", "x" R " y290 w" RW " h34 BackgroundTrans"
        , "Shake жмётся клавишей Enter — включи в игре навигацию по интерфейсу (клавиша \). "
        . "Слот удочки пустой — удочка уже в руке.")

    T := "appraise"
    Hdr(T, "НАСТРОЙКА", R, 18, RW)
    G.SetFont("s10 bold", "Segoe UI")
    Push(T, MkBtn(R, 44, 200, 34, "Точка клика   F1", (*) => AHint("click"), "ghost"))
    Push(T, MkBtn(R2, 44, 200, 34, "Область текста   F2", (*) => AHint("region"), "ghost"))
    Push(T, MkBtn(R, 86, 200, 34, "Как по умолчанию   F5", (*) => ADefaultRegion(), "ghost"))
    Push(T, MkBtn(R2, 86, 200, 34, "Показать рамки   F4", (*) => AToggleFrames(), "ghost"))
    G.SetFont("s9 norm c" C_MUTED, "Segoe UI")
    ACoordTxt := Add(T, "Text", "x" R " y128 w" RW " h18 BackgroundTrans", "")
    Add(T, "Text", "x" R " y148 w" RW " h34 BackgroundTrans"
        , "Точка — кнопка «Can you appraise it again?». Область — текст «Mutation Changed»: "
        . "F2 в левом-верхнем и F2 в правом-нижнем углу.")
    Hdr(T, "ПАРАМЕТРЫ", R, 190, RW)
    G.SetFont("s10 norm c" C_TXT, "Segoe UI")
    Add(T, "Text", "x" R " y216 w" RW " h20 BackgroundTrans", "Искать мутации (через запятую)")
    EdTargets := Add(T, "Edit", "x" R " y238 w" RW " h28 -E0x200 Background" C_FIELD " c" C_TXT, JoinArr(Targets, ", "))
    RoundCorners(EdTargets, 8)
    EdTargets.OnEvent("Change", (*) => ApplySettings())
    EdDelay1 := Field(T, R, 276, "Пауза после клика", DelayAfterClick)
    EdDelay2 := Field(T, R2, 276, "Пауза между, мс", DelayBetween)
    EdMax := Field(T, R, 312, "Лимит попыток", MaxAttempts)
    TgKey1 := MkToggle(T, R2, 313, 200, "Жать 1 вместо клика", UseKey1, (*) => ApplySettings())

    T := "common"
    Hdr(T, "ОКНО", R, 438, RW)
    TgHide := MkToggle(T, R, 464, 200, "Прятать после старта", HideOnStart, (*) => ApplySettings())
    TgTop := MkToggle(T, R2, 464, 200, "Поверх игры", OnTop, (*) => ApplySettings())
    TgHints := MkToggle(T, R, 500, 200, "Подсказки в игре", GameHints, (*) => ApplySettings())
    TgUpd := MkToggle(T, R2, 500, 200, "Обновляться сам", AutoUpdate, (*) => ApplySettings())
    BuildCol := "L"

    UpdateCalibInfo(), UpdateACoords()
    pos := (WinX != "" && WinY != "") ? "x" Max(0, Min(Integer(WinX), A_ScreenWidth - 460)) " y" Max(0, Min(Integer(WinY), A_ScreenHeight - 600)) " " : ""
    G.Show(pos "w" (ShowSettings ? 900 : 450) " h574")
    SetAppIcon()
    ; тёмный заголовок окна и бирюзовая рамка (Windows 10/11; цвет в DWM — 0x00BBGGRR)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", G.Hwnd, "int", 20, "int*", 1, "int", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", G.Hwnd, "int", 34, "int*", 0x93A04A, "int", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", G.Hwnd, "int", 35, "int*", 0x221B16, "int", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", G.Hwnd, "int", 33, "int*", 2, "int", 4)   ; скруглённые углы окна (Win 11)
    LogBox.Focus()                                   ; чтобы поле ввода не было выделено при старте
}

UpdateAriaHint() {
    AriaHint.Text := TgVal(TgAria)
        ? "Зона ловит падающие ноты, рыба — ближе к центру зоны."
        : "Обычная подсечка: зона держится на рыбе."
}

; «⚙ Настройки»: показать/спрятать правую колонку (окно 900 ↔ 460 px)
ToggleSettings() {
    global ShowSettings
    ShowSettings := !ShowSettings
    ShowTab(CurTab)
    G.Show("NA w" (ShowSettings ? 900 : 450))
    try IniWrite(ShowSettings, INI, "Window", "ShowSettings")
}

; иконка окна и трея; в трее — «Показать окно» (окно прячется после старта)
SetAppIcon() {
    ico := A_ScriptDir "\assets\reelwise.ico"
    if FileExist(ico) {
        TraySetIcon(ico)
        for sz in [[16, 0], [32, 1]] {
            h := DllCall("LoadImage", "ptr", 0, "str", ico, "uint", 1, "int", sz[1], "int", sz[1], "uint", 0x10, "ptr")
            if h
                SendMessage(0x80, sz[2], h, G)           ; WM_SETICON: 0 — маленькая, 1 — большая
        }
    }
    A_IconTip := APP_NAME
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Показать окно", (*) => ShowWindow())
    A_TrayMenu.Add("Старт / пауза   F6", (*) => ToggleRun())
    A_TrayMenu.Add("Проверить обновления", (*) => CheckUpdate(false))
    A_TrayMenu.Add()
    A_TrayMenu.Add("Выход   F8", (*) => Quit())
    A_TrayMenu.Default := "Показать окно"
    A_TrayMenu.ClickCount := 1
}
ShowWindow() {
    G.Show("NA")                                     ; без фокуса: не отнимать клавиатуру у игры
}

; --- элементы оформления ---
Add(tab, type, opts, text := "") {
    c := G.Add(type, opts, text)
    Push(tab, c)
    return c
}
; tab: "fish" / "appraise" — видно на своей вкладке, "common" — всегда; "" — не прячется никогда.
; Всё, что создано в правой колонке, прячется вместе с настройками
Push(tab, c) {
    if (tab != "")
        TabCtl[tab].Push(c)
    if (BuildCol = "R")
        RightCtl[c.Hwnd] := true
    return c
}
Hdr(tab, title, x, y, w) {
    G.SetFont("s8 bold c" C_ACC, "Segoe UI")
    Add(tab, "Text", "x" x " y" y " w" w " h16 BackgroundTrans", title)
    Add(tab, "Text", "x" x " y" (y + 18) " w" w " h1 Background" C_LINE, "")
}
; скруглить углы элемента (регион окна элемента; фон под ним — фон окна)
RoundCorners(c, r) {
    c.GetPos(, , &w, &h)
    rgn := DllCall("CreateRoundRectRgn", "int", 0, "int", 0, "int", w + 1, "int", h + 1, "int", r, "int", r, "ptr")
    DllCall("SetWindowRgn", "ptr", c.Hwnd, "ptr", rgn, "int", 1)
}
; подпись + поле ввода (числовое по умолчанию)
Field(tab, x, y, label, value, numeric := true) {
    G.SetFont("s10 norm c" C_TXT, "Segoe UI")
    Add(tab, "Text", "x" x " y" (y + 4) " w140 h20 BackgroundTrans", label)
    G.SetFont("s10 norm c" C_TXT, "Segoe UI")
    e := Add(tab, "Edit", "x" (x + 141) " y" y " w64 h28 Center -E0x200 " (numeric ? "Number " : "Limit1 ")
        . "Background" C_FIELD " c" C_TXT, value)
    RoundCorners(e, 8)
    e.OnEvent("Change", (*) => ApplySettings())
    return e
}
; плоская кнопка со скруглёнными углами: main — акцентная, ghost — тёмная, tab — вкладка
MkBtn(x, y, w, h, label, fn, kind) {
    bg := kind = "main" ? C_ACC : C_FIELD
    fg := kind = "main" ? C_BG : kind = "tab" ? C_MUTED : C_TXT
    hov := kind = "main" ? C_ACC_HI : C_HOVER
    c := G.Add("Text", Format("x{} y{} w{} h{} Center +0x200 Background{} c{}", x, y, w, h, bg, fg), label)
    c.OnEvent("Click", fn)
    RoundCorners(c, 12)
    Btns[c.Hwnd] := {ctl: c, bg: bg, hov: hov, fg: fg}
    return c
}
SetBtnColors(c, bg, fg, hov) {
    b := Btns[c.Hwnd]
    b.bg := bg, b.fg := fg, b.hov := hov
    c.Opt("+Background" bg " c" fg), c.Redraw()
}
; переключатель: подпись слева, тумблер справа (картинки assets\switch_on/off.png); клик по любому
MkToggle(tab, x, y, w, label, val, fn) {
    G.SetFont("s10 norm c" C_TXT, "Segoe UI")
    lbl := Add(tab, "Text", Format("x{} y{} w{} h24 +0x200 BackgroundTrans", x, y, w - 52), label)
    pic := Add(tab, "Picture", Format("x{} y{} w44 h24", x + w - 44, y), SwitchImg(val))
    t := {lbl: lbl, pic: pic, val: val ? 1 : 0}
    Toggles[lbl.Hwnd] := t, Toggles[pic.Hwnd] := t
    lbl.OnEvent("Click", (*) => (FlipToggle(lbl), fn()))
    pic.OnEvent("Click", (*) => (FlipToggle(lbl), fn()))
    return lbl
}
SwitchImg(on) => A_ScriptDir "\assets\switch_" (on ? "on" : "off") ".png"
FlipToggle(c) {
    t := Toggles[c.Hwnd]
    t.val := !t.val
    t.pic.Value := SwitchImg(t.val)
}
TgVal(c) => Toggles[c.Hwnd].val

; подсветка кнопки под мышью
HoverTick() {
    static cur := 0
    try MouseGetPos(, , &win, &hw, 2)
    catch
        return
    if (cur && cur != hw && Btns.Has(cur)) {
        b := Btns[cur]
        try b.ctl.Opt("+Background" b.bg), b.ctl.Redraw()
        cur := 0
    }
    if (hw && hw != cur && Btns.Has(hw) && win = G.Hwnd) {
        b := Btns[hw]
        try b.ctl.Opt("+Background" b.hov), b.ctl.Redraw()
        cur := hw
    }
}

ShowTab(tab) {
    global CurTab
    if Running && tab != RunMode {
        SetState("Сначала останови текущий режим (F6)", C_WARN)
        return
    }
    if Testing
        ToggleTest()
    CurTab := (tab = "appraise") ? "appraise" : "fish"
    for name, list in TabCtl
        for c in list
            c.Visible := (name = CurTab || name = "common") && (ShowSettings || !RightCtl.Has(c.Hwnd))
    SetBtnColors(TabFish, CurTab = "fish" ? C_ACC : C_FIELD, CurTab = "fish" ? C_BG : C_MUTED, CurTab = "fish" ? C_ACC_HI : C_HOVER)
    SetBtnColors(TabApp, CurTab = "appraise" ? C_ACC : C_FIELD, CurTab = "appraise" ? C_BG : C_MUTED, CurTab = "appraise" ? C_ACC_HI : C_HOVER)
    SetBtnColors(BtnGear, ShowSettings ? C_HOVER : C_FIELD, ShowSettings ? C_ACC : C_TXT, C_HOVER)
    FooterTxt.Text := CurTab = "fish"
        ? "F6 старт / пауза   ·   F3 тест   ·   F8 выход"
        : "F6 старт   ·   F1 точка   ·   F2 область   ·   F3 тест   ·   F8 выход"
    if !Running
        SetState(CurTab = "fish" ? "Готов к рыбалке" : "Готов к оценке", C_MUTED)
    UpdateStats()
    try IniWrite(CurTab, INI, "Window", "Tab")
}

; ============================================================================
;                              ГОРЯЧИЕ КЛАВИШИ
; ============================================================================
F6:: ToggleRun()
F8:: Quit()
F3:: (CurTab = "fish") ? ToggleTest() : ATest()
#HotIf CurTab = "appraise"
F1:: APickClick()
#HotIf
#HotIf CurTab = "appraise"
F2:: ARegionCorner()
F4:: AToggleFrames()
F5:: ADefaultRegion()
#HotIf

ToggleRun() {
    global Running, RunStart, RunMs, ErrCount, RunMode
    if Running {
        Running := false
        RunMs += A_TickCount - RunStart
        ReleaseMouse()
        SetTimer(UpdateStats, 0)
        BtnStart.Text := "▶   Старт   F6"
        SetState("Пауза", C_WARN)
        AddLog("Пауза")
        UpdateStats()
        SaveSettings()
        ShowWindow()                                 ; окно было спрятано на время работы
        return
    }
    if !WinExist(ROBLOX) {
        SetState("Roblox не запущен — открой Fisch", C_BAD)
        return
    }
    if (CurTab = "appraise" && (!ClickX || !RW)) {
        SetState("Сначала настрой точку клика (F1) и область (F2)", C_BAD)
        return
    }
    if Testing
        ToggleTest()
    ApplySettings()
    RunMode := CurTab
    Running := true, RunStart := A_TickCount, ErrCount := 0
    BtnStart.Text := "❚❚   Пауза   F6"
    SetState(RunMode = "fish" ? "Рыбачу…" : "Оцениваю…", C_ACC)
    AddLog(RunMode = "fish" ? "Старт: рыбалка" : "Старт: оценка, ищу " JoinArr(Targets, ", "))
    if HideOnStart
        G.Hide()                                     ; не мешать игре; вернётся по F6 (пауза) или из трея
    WinActivate(ROBLOX)
    SetTimer(UpdateStats, 1000)
    SetTimer(MainLoop, -300)
}

; общий цикл: ошибка -> в журнал, отпустить мышь и продолжить
MainLoop() {
    global Running, ErrCount
    while Running {
        try {
            if (RunMode = "fish")
                FishLoop()
            else
                AppraiseLoop()
            break
        } catch as e {
            ReleaseMouse()
            ErrCount++
            LogError(e)
            if (ErrCount >= 5) {
                StopRun("Остановлен: 5 ошибок подряд", C_BAD)
                break
            }
            SetState("Была ошибка — продолжаю (" ErrCount "/5)", C_WARN)
            Sleep 1500
        }
    }
    ReleaseMouse()
}

StopRun(msg, color) {
    global Running, RunMs
    if Running
        RunMs += A_TickCount - RunStart
    Running := false
    ReleaseMouse()
    SetTimer(UpdateStats, 0)
    BtnStart.Text := "▶   Старт   F6"
    SetState(msg, color)
    AddLog(msg)
    UpdateStats()
    ShowWindow()
}

; ============================================================================
;                                РЫБАЛКА
; ============================================================================
FishLoop() {
    global Casts, Reels, Fails, ErrCount
    while Running {
        if !WaitRoblox()
            break
        ; мини-игра уже идёт (макрос запущен посреди подсечки) — не бросать, а сразу вести рыбу
        if ReelVisible() {
            AddLog("Мини-игра уже идёт — веду рыбу без заброса")
            global LastFxMiss := 99
            ResetNotes()
            r := Reel()
            Reels++
            AddLog("Рыба #" Reels ": " Round(r.ms / 1000, 1) " с · на рыбе " r.onPct "%"
                . (AriaMode ? " · ноты " NoteGot " из " (NoteGot + NoteMiss) : ""))
            UpdateStats()
            Sleep AfterCatchMs
            continue
        }
        ; 1. заброс
        if (EquipKey != "") {
            Send "{" EquipKey "}"
            Sleep 400
        }
        ; заброс с проверкой: пока ЛКМ зажата, у персонажа должна появиться шкала силы заброса.
        ; Нет шкалы — удочка не закинута (клик ушёл в анимацию улова или удочка уже была в воде и
        ; этим нажатием смоталась) — сразу бросаем ещё раз, а не ждём мини-игру 30 с (живая проверка 24.11)
        castOk := false, barKnown := false
        Loop 3 {
            MouseMove(A_ScreenWidth // 2, A_ScreenHeight // 3, 0)
            Sleep 50
            Click "Down"
            tc := A_TickCount, seen := false
            while (A_TickCount - tc < CastHoldMs) {
                if (!seen && A_TickCount - tc >= 300)
                    seen := CastBarSeen()
                Sleep 10
            }
            Click "Up"
            if seen {
                castOk := true
                break
            }
            if !Running
                break
            AddLog("Заброс: шкала силы не появилась — удочка не закинута, бросаю ещё раз (" A_Index "/3)")
            Sleep 1200
        }
        if !castOk && Running
            AddLog("Заброс: шкалу так и не увидел — жду мини-игру как обычно")
        Casts++
        SetState("Заброс #" Casts " — жду поклёвку", C_ACC)
        Sleep 600
        ; 2. shake: навигация по UI включена в игре — просто Enter до начала мини-игры
        t0 := A_TickCount, started := false, trackFrames := 0
        while Running && (A_TickCount - t0 < ShakeTimeoutMs) {
            if ReelVisible() {
                started := true
                break
            }
            trackFrames += AriaMode && AriaTrack
            Send "{Enter}"
            Sleep ShakeIntervalMs
        }
        if !Running
            break
        if !started {
            Fails++
            ; диагностика (24.11: 4 таких заброса подряд, на экране «It got away..»): видна ли была дорожка
            ; мини-игры — тогда не узнал рыбу/зону; не видна — Shake не сработал (навигация «\» слетела?)
            AddLog("Заброс #" Casts ": мини-игра не началась — перезаброс"
                . (AriaMode ? (trackFrames ? " (дорожку видел " trackFrames " раз — не узнал рыбу/зону)"
                    : " (дорожки не было — Shake не нажался? проверь навигацию «\»)") : ""))
            Click
            Sleep 1500
            continue
        }
        ; 3. подсечка
        SetState("Заброс #" Casts " — подсекаю", C_ACC)
        global LastFxMiss := 99                    ; новая рыба — не держаться за прошлую
        ResetNotes()
        r := Reel()
        Reels++, ErrCount := 0
        AddLog("Рыба #" Reels ": " Round(r.ms / 1000, 1) " с · на рыбе " r.onPct "% · по центру " r.centerPct "%"
            . (AriaMode ? " · ноты " NoteGot " из " (NoteGot + NoteMiss)
                . (r.resTimes ? " · Resonance " Round(r.resMs / 1000, 1) " с" : "") : ""))
        AutoTune(r)
        UpdateStats()
        SetState("Рыба #" Reels " поймана", C_ACC)
        Sleep AfterCatchMs
    }
    ReleaseMouse()
}

; ---------------------------------------------------------------------
;  Подсечка. Физика измерена по записям настоящей игры:
;   - ЛКМ зажата -> полоска разгоняется вправо, отпущена -> влево (±BarAccel)
;   - игра видит клик с опозданием ~60 мс (GameLagMs)
;  Регулятор ПРЕДСКАЗЫВАЕТ, где окажется полоска, когда сработают уже отправленные клики,
;  и управляет этим будущим положением. Каждый кадр игры — одно решение (частые клики).
; ---------------------------------------------------------------------
Reel() {
    global HoldBias
    ; у Pinion's Aria зона разгоняется вдвое быстрее — те же нажатия дают вдвое больше, усиление меньше
    accel := AriaMode ? BarAccel * 2 : BarAccel, f := BarAccel / accel
    Kp := Stiffness * 0.5 * f, Kd := Smooth * 0.4 * Sqrt(f), Ki := 0.0001
    hist := []
    t0 := QpcMs(), lastSeen := t0, lastT := 0, lastC := "", lastF := "", dbg := ""   ; dbg — покадровый журнал (reel_log.csv)
    bv := 0, fv := 0, lastDraw := 0, acc := 0
    frames := 0, onFish := 0, centered := 0, sumAbsE := 0, crossings := 0, lastSign := 0, lastHalf := 40
    ; Pinion's Aria: стартовая ширина зоны этой рыбы и Resonance (зона сжалась — рыба сама идёт за зоной)
    firstBar := 0, wStart := [], baseW := 0, reson := false, resCnt := 0, resSince := 0, resMs := 0, resTimes := 0, loopPrev := t0, jd := ""
    streak := 0, wLast := [], maxW := 0, minW := 0
    while Running {
        now := QpcMs()
        sn := Sense(), fx := sn.fx, bar := sn.bar
        if (fx = "") {
            if (now - lastSeen > ReelEndMs)
                break
            SetHold(false)
            WaitUntil(now + 5)
            continue
        }
        ; конец подсечки — когда пропала РЫБА ИЛИ ПОЛОСКА: живая проверка 23.11 — тёмные швы досок моста
        ; похожи на линию рыбы, после улова «рыба» не пропадала и макрос вечно стоял в подсечке
        if bar
            lastSeen := now
        else if (now - lastSeen > ReelEndMs)
            break
        predicted := false
        if !bar {
            if (lastC != "" && now - lastT < 300) {
                pc := lastC + bv * (now - lastT)          ; полоска на миг пропала — ведём по инерции
                bar := [pc - lastHalf, pc + lastHalf], predicted := true
            } else {
                SetHold(fx > BX + BW / 2)
                lastC := ""
                WaitUntil(now + FrameMs)
                continue
            }
        }
        c := (bar[1] + bar[2]) / 2
        half := Max((bar[2] - bar[1]) / 2, 8)
        if !predicted {
            if (lastC != "") {
                dt := Max(now - lastT, 1)
                bv := 0.55 * bv + 0.45 * (c - lastC) / dt
                fv := 0.55 * fv + 0.45 * (fx - lastF) / dt
            }
            lastT := now, lastC := c, lastF := fx, lastHalf := half
        }
        ; прогноз положения полоски через GameLagMs от уже отправленных кликов
        vv := bv * 1000, px := c, tt := 0, k := 1
        pend := []
        for h in hist
            if (h[1] > now - GameLagMs)
                pend.Push(h[2])
        lastP := hist.Length ? hist[hist.Length][2] : 0
        while (tt < GameLagMs) {
            aa := (k <= pend.Length ? pend[k] : lastP) ? accel : -accel
            d := Min(FrameMs, GameLagMs - tt) / 1000
            px += vv * d + 0.5 * aa * d * d, vv += aa * d
            tt += FrameMs, k++
        }
        ; у края дорожки рыба чаще рвёт к центру — держим там небольшой запас
        dc := (BX + BW / 2) - fx
        off := 0
        if (Abs(dc) > CenterDeadPx)
            off := Max(-CenterMaxPx, Min(CenterMaxPx, CenterPull * (Abs(dc) - CenterDeadPx) * (dc > 0 ? 1 : -1)))
        tgt := fx + off + fv * GameLagMs, tv := fv
        hn := half
        if AriaMode {
            jd := JudgeNotes(now, predicted ? 0 : bar)
            ; серия пойманных нот подряд (в игре 7 подряд = Resonance, промах обнуляет)
            if InStr(jd, "-")
                streak := 0, maxW := 0
            else
                Loop Parse jd, " "
                    streak += SubStr(A_LoopField, 1, 1) = "+"
            ; Resonance — по ширине зоны относительно стартовой этой же рыбы (без пикселей: у зачарованных
            ; удочек зона шире). Видео 24.11: каждая нота +~8% ширины, Resonance сжимает зону за ~5 с до ~35%,
            ; промах ноты — скачком снова стартовая ширина. Стартовая = медиана ширины 0,4–1,2 с после появления
            if !predicted {
                zw := bar[2] - bar[1]
                if !firstBar
                    firstBar := now
                if (!baseW && now - firstBar >= 400)
                    wStart.Push(zw)
                if (!baseW && now - firstBar >= 1200 && wStart.Length >= 5)
                    baseW := Median(wStart)
                ; сглаженная ширина (медиана 5 кадров — одиночные ошибки зрения не в счёт), её максимум и минимум
                wLast.Push(zw)
                if (wLast.Length > 5)
                    wLast.RemoveAt(1)
                zm := Median(wLast)
                if baseW
                    maxW := Max(maxW, zm), minW := reson ? Min(minW, zm) : zm
                if baseW {
                    ; вход: (а) зона уже 80% стартовой после ≥3 нот; (б) живая проверка 24.11 — после 7-й ноты зона
                    ; плавно сужается от своего максимума (357→341→327→303), а рыба часто ловится раньше, чем
                    ; зона станет уже стартовой: серия ≥6 нот и зона ≤92% максимума, но шире стартовой (при промахе
                    ; она скачком стала бы стартовой). Выход: зона снова ≥90% стартовой и выросла от минимума на 30%
                    if (reson ? zm >= 0.9 * baseW && zm > 1.3 * minW
                        : (zm < 0.8 * baseW && NoteGot >= 3) || (streak >= 6 && zm <= 0.92 * maxW && zm > 1.05 * baseW)) {
                        if !resCnt++
                            resSince := now
                    } else
                        resCnt := 0
                    ; не меньше 5 кадров и 0,4 с подряд: живая проверка 24.11 — зона «мигнула» узкой на 5 кадров
                    ; (~0,1 с) и дала ложный Resonance; настоящее сжатие длится секунды
                    if (resCnt >= 5 && now - resSince >= 400) {
                        reson := !reson, resCnt := 0, resTimes += reson, minW := zm
                        if !reson
                            maxW := zm, streak := 0
                        AddLog(reson ? "Resonance: зона " Round(zw) " из " Round(baseW) " — рыба идёт за зоной, ловлю только ноты"
                            : "Resonance закончился (нота пропущена?) — зона снова " Round(zw))
                    }
                }
            }
            if reson
                resMs += Min(now - loopPrev, 100)
            loopPrev := now
            ; узкая зона (Resonance) не должна делать регулятор резче: ошибка в долях не меньше стартовой зоны
            if baseW
                hn := Max(half, baseW * 0.3)
            if (n := NextNote(now)) {
                ; нота важнее рыбы (пропуск = нет Perfect Catch). Зона под ноту, рыба — как можно ближе к центру
                m := Max(half - Max(12, half * 0.3), 4)
                nt := Max(n.x - m, Min(n.x + m, fx))
                ; вне Resonance, пока зона не на рыбе, прогресс падает — уходим к ноте не раньше, чем нужно:
                ; время перегона d px с разгоном и торможением 2·√(d/a), с запасом ×1,3 + задержка игры.
                ; В Resonance рыба идёт за зоной сама — встаём под ноту сразу
                d := Abs(nt - c)
                if (reson || n.t - now <= GameLagMs + 120 + 2600 * Sqrt(d / accel))
                    tgt := nt, tv := 0
            }
        }
        e := (tgt - px) / hn
        ed := (tv * 1000 - vv) / hn
        ; статистика
        raw := (fx - c) / half
        frames++, sumAbsE += Abs(raw)
        onFish += Abs(raw) <= 1
        centered += Abs(raw) <= 0.2
        s := raw > 0.1 ? 1 : raw < -0.1 ? -1 : 0
        if (s && lastSign && s != lastSign)
            crossings++
        if s
            lastSign := s
        if (Abs(raw) < 0.6)
            HoldBias := Max(0.35, Min(0.65, HoldBias + Ki * raw * FrameMs))
        ; желаемое ускорение -> доля нажатых кадров; сигма-дельта по кадрам
        duty := Max(0, Min(1, HoldBias + (Kp * e + Kd * ed) / 2))
        acc += duty
        press := acc >= 0.5
        if press
            acc -= 1
        SetHold(press)
        nn := AriaMode ? NextNote(now) : 0
        dbg .= Round(now - t0) "," Round(fx) "," Round(bar[1]) "," Round(bar[2]) "," predicted "," (nn ? Round(nn.x) "," Round(nn.t - now) : ",")
            . "," Round(tgt) "," Round(px) "," press "," (reson ? 1 : 0) "," Round(baseW) "," jd "`n"
        hist.Push([now, press])
        if (hist.Length > 40)
            hist.RemoveAt(1)
        WaitUntil(now + FrameMs)
        if (now - lastDraw > 150) {
            UpdatePreview(fx, bar)
            SeeTxt.Text := "На рыбе: " Round(onFish * 100 / frames) "%   ·   по центру: " Round(centered * 100 / frames) "%"
            lastDraw := now
        }
    }
    ReleaseMouse()
    UpdatePreview("", 0)
    try FileAppend("# рыба " FormatTime(, "HH:mm:ss") "`nt_ms,fish,zone_l,zone_r,predicted,note_x,note_eta,target,pred_center,press,resonance,zone_start_w,note_judged`n" dbg
        , A_ScriptDir "\reel_log.csv", "UTF-8")
    secs := Max((QpcMs() - t0) / 1000, 0.1)
    return {ms: QpcMs() - t0, frames: frames
        , onPct: frames ? Round(onFish * 100 / frames) : 0
        , centerPct: frames ? Round(centered * 100 / frames) : 0
        , meanE: frames ? sumAbsE / frames : 1
        , swingsPerSec: crossings / secs, resMs: resMs, resTimes: resTimes}
}

; пробуем шаг жёсткости/гашения; если следующая рыба вышла хуже — откатываем
AutoTune(r) {
    global Stiffness, Smooth, TuneLast, TunePrev
    static S_MIN := 3, S_MAX := 8, D_MIN := 3, D_MAX := 9
    if !AutoTuneOn || (r.frames < 40)
        return
    score := r.centerPct + r.onPct / 2
    msg := ""
    if (TuneLast != "" && score < TunePrev - 2) {
        switch TuneLast {
            case "S+": Stiffness--
            case "S-": Stiffness++
            case "D+": Smooth--
            default: Smooth++
        }
        msg := "откат → жёсткость " Stiffness ", гашение " Smooth
        TuneLast := ""
    } else {
        TunePrev := score, TuneLast := ""
        if (r.swingsPerSec > 2.5 && r.meanE > 0.12) {
            if (Smooth < D_MAX)
                Smooth++, TuneLast := "D+"
            else if (Stiffness > S_MIN)
                Stiffness--, TuneLast := "S-"
        } else if (r.meanE > 0.22 && r.swingsPerSec < 1.2) {
            if (Stiffness < S_MAX)
                Stiffness++, TuneLast := "S+"
            else if (Smooth > D_MIN)
                Smooth--, TuneLast := "D-"
        }
        if (TuneLast != "")
            msg := "пробую жёсткость " Stiffness ", гашение " Smooth
    }
    if (msg != "") {
        EdKp.Value := Stiffness, EdKd.Value := Smooth
        AddLog("Автоподстройка: " msg)
    }
    SaveSettings()
}

SetHold(want) {
    global Holding
    if (want = Holding)
        return
    Click(want ? "Down" : "Up")
    Holding := want
}

QpcMs() {
    DllCall("QueryPerformanceCounter", "int64*", &t := 0)
    return t * 1000 / QPF
}

WaitUntil(t) {
    rem := t - QpcMs()
    if (rem >= 1)
        Sleep Floor(rem)
}

; ---------------------------------------------------------------------
;  Pinion's Aria (переключатель на вкладке «Рыбалка»). Измерено по записи живой игры 23.11:
;   - полоса на ~15 px выше обычной: дорожка серо-сиреневая (синий ~185–210), зона ярко-сиреневая
;     (синий ≥ 240), ширина зоны ~256 px; зона разгоняется вдвое быстрее обычной;
;   - рыба — бирюзовая линия, над ней всегда белое пёрышко (~33 px) — по нему и ищем рыбу;
;   - ноты (♪/♫, бело-сиреневые, 20–60 px) появляются ~310 px над полосой и падают прямо вниз
;     ~0,78 px/мс: от появления до полосы ~350 мс. Пойманная нота = зона под ней в момент падения.
;  Ноты замечаем на трёх строках над полосой; первая встреча ноты со строкой даёт время приземления
;  (проверено на записи: ошибка прогноза ±50 мс). Перед приземлением зона ведётся так, чтобы нота
;  оказалась внутри неё, а рыба — как можно ближе к центру.
; ---------------------------------------------------------------------

NowMs() => TestNow != "" ? TestNow : QpcMs()

; строка y (в захвате): отрезки пикселей нужного вида с дырками до gap -> [[a, b], ...]
; каждый второй пиксель и без вызовов функций на пиксель: захват экрана и так занимает 12–17 мс на кадр
; (замер 23.11), первый вариант с Px() на каждый пиксель опускал рыбалку до 32–39 кадров/с
AriaRuns(y, kind, gap) {
    w := Cap.w, out := [], a := -1, b := -1000, base := Cap.bits + y * w * 4, x := 0
    while (x < w) {
        p := NumGet(base, x * 4, "uint"), r := (p >> 16) & 0xFF, g := (p >> 8) & 0xFF, bl := p & 0xFF
        if (kind = 1)                                   ; зона: обычная (синий ≥ 232) или покрасневшая
            ; (рыба вне зоны). Живая проверка 24.11: красная зона бывает и (193,72,81)/(172,105,115)
            hit := bl >= 232 || (r >= 130 && bl >= 140 && bl <= 175 && g <= 160) || (r >= 150 && r - g >= 50 && r - bl >= 40)
        else if (kind = 4)                              ; дорожка (серо-сиреневая ~170/185/215) или зона
            hit := (bl >= 195 && g >= 160 && r >= 145) || bl >= 232 || (r >= 130 && bl >= 140 && bl <= 175 && g <= 160)
                || (r >= 150 && r - g >= 50 && r - bl >= 40)
        else if (kind = 2)                              ; рамка зоны / пёрышко: светлое с синим
            hit := bl >= 235 && g >= 195 && r >= 150
        else      ; нота: бело-сиреневая (231,204,249) или бирюзово-голубая (177,208,255) — зависит от места;
                  ; синий заметно больше красного — так не проходит белая пена на воде (240,245,250)
            hit := bl >= 225 && r >= 150 && g >= 165 && bl - r >= 15
        if hit {
            if (x - b > gap) {
                if (a >= 0)
                    out.Push([a, b])
                a := x
            }
            b := x
        }
        x += 2
    }
    if (a >= 0)
        out.Push([a, b + 1])
    return out
}

SenseAria() {
    global LastFx, LastFxMiss, NotePend, NotePrev
    static frameNo := 0
    CapInit()
    ; захват экрана — самое дорогое (живая проверка 24.11: 26–40 кадров/с, когда каждый кадр брали высоту
    ; ~760 строк). Высокую область с нотами берём через кадр, в остальных — только полосу (~100 строк)
    tall := TestMode || Mod(++frameNo, 2) = 1
    y0 := tall ? 0 : AriaTop - 60
    if !DllCall("BitBlt", "ptr", Cap.mdc, "int", 0, "int", y0, "int", Cap.w, "int", Cap.h - y0
        , "ptr", Cap.scr, "int", BX, "int", BY - AriaTop + y0, "uint", 0xCC0020)
        return {fx: "", bar: 0}
    now := NowMs(), w := Cap.w
    ; есть ли мини-игра вообще: дорожка вместе с зоной — сплошная полоса почти во всю ширину (видео: ~97%).
    ; Живая проверка 24.11: после улова предметы сцены читались как неподвижная «рыба» и узкая «зона»,
    ; подсечка тянулась ещё ~10 с и включался ложный Resonance
    tr := 0
    for r in AriaRuns(AriaTop + 6, 4, 20)
        tr := Max(tr, r[2] - r[1])
    global AriaTrack := tr >= w * 0.6
    if !AriaTrack {
        LastFxMiss++
        return {fx: "", bar: 0}
    }
    ; зона: по цвету на строке BY+6 и по светлой рамке на строке BY-15 (рамка видна, даже когда зона
    ; покраснела, — рыба вышла из неё); берём более широкую. Дырки до 20 px — линия рыбы посреди зоны
    ; (живая проверка 24.11: с дырками до 8 px зона «укорачивалась» до 74–144 px из ~200)
    bar := LongestRun(AriaRuns(AriaTop + 6, 1, 20), w)
    b2 := LongestRun(AriaRuns(AriaTop - 15, 2, 32), w)   ; рамку рвут ноты/пёрышко: дырки до ~26 px (24.11)
    ; ширина зоны не ограничена в пикселях: она растёт с каждой пойманной нотой (+~8%), в Resonance сжимается
    ; до ~35%, а у зачарованных удочек и сама больше (видео 24.11: 237 -> 360 px, в Resonance 83 px)
    if (b2 && b2[2] - b2[1] <= w * 0.92 && (!bar || b2[2] - b2[1] > bar[2] - bar[1]))
        bar := b2
    ; рыба: пёрышко на строке BY-53; из нескольких — ближайшее к прошлой рыбе
    ref := (LastFx != "" && LastFxMiss < 18) ? LastFx : bar ? (bar[1] + bar[2]) / 2 : w / 2
    fx := "", best := 1e9
    for r in AriaRuns(AriaTop - 53, 2, 4)
        if (r[2] - r[1] >= 6 && r[2] - r[1] <= 50 && Abs((r[1] + r[2]) / 2 - ref) < best)
            fx := (r[1] + r[2]) / 2, best := Abs(fx - ref)
    if (fx = "")
        LastFxMiss++
    else
        LastFx := fx, LastFxMiss := 0
    ; ноты: 5 строк от y≈200 экрана до полосы; нота только что пересекла строку -> время приземления
    ; по закону падения (запись всего экрана 23.11: нота появляется у верха экрана и падает ~1,4 с с ускорением)
    for i, dy in NoteRows {
        if !tall                                       ; строки нот в этом кадре не обновлялись
            break
        cur := []
        for r in AriaRuns(AriaTop - dy, 3, 4) {
            x := (r[1] + r[2]) / 2
            if (r[2] - r[1] < 2 || r[2] - r[1] > 80 || (dy < 60 && fx != "" && Abs(x - fx) < 35))
                continue
            cur.Push(x)
            seen := false
            for px in NotePrev[i]
                seen := seen || Abs(px - x) < 30
            if seen
                continue
            tl := now + NoteFallMs(BY - dy)
            ; нота падает ~1,44 с от верха экрана; если по закону падения она «появилась» раньше начала мини-игры —
            ; это не нота (живая проверка 24.11, тёмная пещера: через 0,26 с после старта «нота» с ETA 0,56 с,
            ; зона уезжала к ней через всю дорожку и возвращалась к рыбе)
            if (ReelStartMs && tl - NoteFallMs(80) < ReelStartMs - 250)
                continue
            ; та же нота, замеченная на строке выше раньше, — подтверждение падения. Персонаж (белые и сиреневые
            ; части тела) пересекает строки одновременно и не «падает» по закону — подтверждения не получит
            hits := 1, first := now, keep := []
            for n in NotePend
                if (Abs(n.x - (BX + x)) < 45 && Abs(n.t - tl) < 150 && now - n.first >= 60 && n.row < i)
                    hits := n.hits + 1, first := n.first
                else
                    keep.Push(n)
            keep.Push({x: BX + x, t: tl, hits: hits, first: first, row: i, judged: false})
            NotePend := keep
        }
        NotePrev[i] := cur
    }
    return {fx: fx = "" ? "" : BX + fx, bar: bar ? [BX + bar[1], BX + bar[2]] : 0}
}

Median(arr) {
    s := ""
    for v in arr
        s .= (s = "" ? "" : "`n") Round(v)
    s := StrSplit(Sort(s, "N"), "`n")
    return Integer(s[(s.Length + 1) // 2])
}
LongestRun(rr, w) {
    best := 0
    for r in rr
        if (r[2] - r[1] >= w * 0.035 && !(r[1] <= 2 && r[2] >= w - 3) && (!best || r[2] - r[1] > best[2] - best[1]))
            best := r
    return best
}
; ближайшая нота, которая ещё не упала (или падает прямо сейчас)
; закон падения ноты (подгонка по записи всего экрана, 1920×1080): y = 80 + 0,3255·t + 0,00017·t² (y — низ ноты,
; t — мс от появления), до полосы (y = 905) ~1440 мс. -> сколько мс ноте осталось падать с высоты y
NoteFallMs(y) {
    static a := 0.00017, b := 0.3255, c := 80.2
    T(yy) => (-b + Sqrt(b * b - 4 * a * (c - Min(yy, 905)))) / (2 * a)
    return T(905) - T(y)
}
; ближайшая нота из ещё не упавших; замеченная на одной строке — не нота (персонаж, свет).
; Когда именно вести под неё зону, решает Reel(): по расстоянию (вне Resonance) или сразу (в Resonance)
NextNote(now) {
    best := 0
    for n in NotePend
        if (n.hits >= 2 && n.t >= now - 30 && (!best || n.t < best.t))
            best := n
    return best
}
; итог по нотам: в момент падения нота над зоной? (для журнала)
; Судим только по кадру, где зона действительно видна (живая проверка 24.11: на последней ноте рыба
; ловилась, мини-игра исчезала, и нота считалась пропущенной, хотя зона стояла под ней).
; Одна нота, замеченная дважды (x отличается до ~45 px), засчитывается один раз.
; -> строка для журнала: "+x" поймана, "-x" пропущена
JudgeNotes(now, bar) {
    global NotePend, NoteGot, NoteMiss
    keep := [], out := ""
    for n in NotePend {
        if (bar && !n.judged && n.hits >= 2 && n.t <= now && now - n.t < 150) {
            n.judged := true
            dup := false
            for o in NotePend
                if (o != n && o.judged && Abs(o.x - n.x) < 60 && Abs(o.t - n.t) < 300)
                    dup := true
            if !dup {
                ; игра ловит ноту шире видимой зоны: живая проверка 24.11 — центр ноты в 7–44 px за краем,
                ; а зона после неё всё равно выросла (нота засчитана)
                ok := n.x >= bar[1] - 50 && n.x <= bar[2] + 50
                ok ? NoteGot++ : NoteMiss++
                out .= (ok ? "+" : "-") Round(n.x) " "
            }
        }
        if (n.t > now - 600)
            keep.Push(n)
    }
    NotePend := keep
    return out
}
NoteDump() {
    s := ""
    for n in NotePend
        s .= Round(n.x) "/" Round(n.t) "/" n.hits "/r" n.row " "
    return s
}
ResetNotes() {
    global NotePend := [], NotePrev := [[], [], [], [], [], []], NoteGot := 0, NoteMiss := 0
    global ReelStartMs := NowMs()                   ; начало мини-игры (ResetNotes зовут, как только её увидели)
}

; --- зрение рыбалки: один захват полосы за шаг, поиск в памяти ---
CapInit() {
    global Cap
    h := BH + (AriaMode ? AriaTop : 0)
    if Cap && Cap.w = BW && Cap.h = h
        return
    CapFree()
    scr := DllCall("GetDC", "ptr", 0, "ptr")
    mdc := DllCall("CreateCompatibleDC", "ptr", scr, "ptr")
    bi := Buffer(40, 0)
    NumPut("uint", 40, bi, 0), NumPut("int", BW, bi, 4), NumPut("int", -h, bi, 8)
    NumPut("ushort", 1, bi, 12), NumPut("ushort", 32, bi, 14)
    hbm := DllCall("CreateDIBSection", "ptr", mdc, "ptr", bi, "uint", 0, "ptr*", &bits := 0, "ptr", 0, "uint", 0, "ptr")
    old := DllCall("SelectObject", "ptr", mdc, "ptr", hbm, "ptr")
    Cap := {scr: scr, mdc: mdc, hbm: hbm, old: old, bits: bits, w: BW, h: h}
}
CapFree() {
    global Cap
    if !Cap
        return
    DllCall("SelectObject", "ptr", Cap.mdc, "ptr", Cap.old)
    DllCall("DeleteObject", "ptr", Cap.hbm)
    DllCall("DeleteDC", "ptr", Cap.mdc)
    DllCall("ReleaseDC", "ptr", 0, "ptr", Cap.scr)
    Cap := 0
}
; ---------------------------------------------------------------------
;  Зрение 1.2 = зрение 1.0 (цвет рыбы и цвет полоски на средней строке) + три правки,
;  проверенные на записях игры (dist\debug_frames, ~29 тыс. кадров):
;   1. Полоска шире 70% области больше не отбрасывается (широкая зона удочек ~700 px была
;      «не видна» в половине кадров). Отбрасывается только яркое «на всю строку» (фон).
;   2. Рыба — узкий отрезок цвета рыбы, который продолжается вверх и вниз (линия рыбы).
;      Тёмная вода рядом с дорожкой того же цвета больше не принимается за рыбу.
;      Если отрезков несколько — берётся ближайший к прошлой рыбе (рыба не прыгает).
;   3. Цвета подбираются сами: если видна полоска, а рыба нет — цвет рыбы берётся с узкой
;      вертикальной линии; если видна рыба, а полоски нет — цвет полоски берётся вокруг рыбы.
;      Новый цвет принимается после 3 одинаковых находок подряд. Стандартные цвета игры
;      проверяются всегда, так что неудачный подбор ничего не ломает.
; ---------------------------------------------------------------------

Px(x, y) => NumGet(Cap.bits, (y * Cap.w + x) * 4, "uint") & 0xFFFFFF
Near(p, col, v) => Abs(((p >> 16) & 0xFF) - ((col >> 16) & 0xFF)) <= v
    && Abs(((p >> 8) & 0xFF) - ((col >> 8) & 0xFF)) <= v && Abs((p & 0xFF) - (col & 0xFF)) <= v
ColDiff(p, q) => Max(Abs(((p >> 16) & 0xFF) - ((q >> 16) & 0xFF)), Abs(((p >> 8) & 0xFF) - ((q >> 8) & 0xFF))
    , Abs((p & 0xFF) - (q & 0xFF)))
Lum(p) => ((p >> 16) & 0xFF) + ((p >> 8) & 0xFF) + (p & 0xFF)

; {fx: центр рыбы или "", bar: [левый, правый] или 0}
Sense() {
    global LastFx, LastFxMiss
    if AriaMode
        return SenseAria()
    CapInit()
    if !DllCall("BitBlt", "ptr", Cap.mdc, "int", 0, "int", 0, "int", Cap.w, "int", Cap.h
        , "ptr", Cap.scr, "int", BX, "int", BY, "uint", 0xCC0020)
        return {fx: "", bar: 0}
    mid := Cap.h // 2
    ; сначала стандартные цвета игры, потом подобранные/выбранные: неудачный подбор не перебьёт стандарт
    bar := FindBar(mid, BAR_STD)
    if (!bar && BarColor != BAR_STD)
        bar := FindBar(mid, BarColor)
    ref := (LastFx != "" && LastFxMiss < 18) ? LastFx : bar ? (bar[1] + bar[2]) / 2 : Cap.w / 2
    fx := FindFish(mid, FISH_STD, ref)
    if (fx = "" && FishColor != FISH_STD)
        fx := FindFish(mid, FishColor, ref)
    if (fx = "")
        LastFxMiss++
    else
        LastFx := fx, LastFxMiss := 0
    if ((fx = "") != (!bar))                      ; видно одно из двух — подбираем цвет второго
        LearnColors(mid, fx, bar)
    else if (fx = "")                             ; не видно ничего — может, у удочки оба цвета свои
        LearnPair(mid)
    return {fx: fx = "" ? "" : BX + fx, bar: bar ? [BX + bar[1], BX + bar[2]] : 0}
}

; самый длинный отрезок цвета полоски (дырки до 40 px — иконка рыбы); «на всю строку» = фон
FindBar(row, col) {
    w := Cap.w, curL := -1, lastB := -1000, bestL := -1, bestR := -1, cnt := 0, bestN := 0
    loop w {
        x := A_Index - 1
        p := Px(x, row)
        if (Near(p, col, BarVar) && !Near(p, FishColor, FishVar)) {
            if (x - lastB > 40) {
                if (curL >= 0 && lastB - curL > bestR - bestL)
                    bestL := curL, bestR := lastB, bestN := cnt
                curL := x, cnt := 0
            }
            lastB := x, cnt++
        }
    }
    if (curL >= 0 && lastB - curL > bestR - bestL)
        bestL := curL, bestR := lastB, bestN := cnt
    if (bestL < 0 || bestR - bestL < 12 || (bestL <= 2 && bestR >= w - 3))
        return 0
    return [bestL, bestR, bestN / (bestR - bestL + 1)]     ; третье — доля закрашенного (буквы ~0,5, зона ~1)
}

; рыба: узкий отрезок цвета рыбы, подтверждённый строками выше и ниже; ближайший к ref
FindFish(mid, col, ref) {
    w := Cap.w, h := Cap.h
    for off in [0, -4, 4, -8, 8] {
        row := mid + off
        if (row < 0 || row >= h)
            continue
        best := "", bestD := 1e9, a := -1, b := -1
        loop w {
            x := A_Index - 1
            if Near(Px(x, row), col, FishVar) {
                if (a >= 0 && x - b <= 3)
                    b := x
                else {
                    if (a >= 0)
                        FishCand(a, b, row, col, ref, &best, &bestD)
                    a := x, b := x
                }
            }
        }
        if (a >= 0)
            FishCand(a, b, row, col, ref, &best, &bestD)
        if (best != "")
            return best
    }
    return ""
}
FishCand(a, b, row, col, ref, &best, &bestD) {
    if (b - a > 30 || a <= 1 || b >= Cap.w - 2)
        return
    c := (a + b) // 2, sup := 0, v := FishVar + 6
    for d in [-6, -3, 3, 6] {
        y := Max(0, Min(Cap.h - 1, row + d))
        if (Near(Px(c - 1, y), col, v) || Near(Px(c, y), col, v) || Near(Px(c + 1, y), col, v))
            sup++
    }
    if (sup < 3)
        return
    if (Abs((a + b) / 2 - ref) < bestD)
        best := (a + b) / 2, bestD := Abs(best - ref)
}

; --- автоподбор цветов (не чаще 10 раз/с) ---
LearnColors(mid, fx, bar) {
    global LearnLast, LearnF, LearnB
    t := A_TickCount
    if (t - LearnLast < 100 && !TestMode)
        return
    LearnLast := t
    if bar {
        ; только сплошная зона (не надпись «Click & Hold Anywhere!») и линия внутри неё
        ; (светящийся белый предмет ~20 px у края экрана — тоже не зона: настоящая шире 40 px)
        f := bar[3] >= 0.85 && bar[2] - bar[1] >= 40 ? FindFishLine(mid, [bar[1] - 8, bar[2] + 8]) : ""
        LearnF := Remember(LearnF, f)
        if Settled(LearnF)
            Adopt("fish", LearnF[3][1]), LearnF := []
    } else {
        c := BarAround(mid, fx)
        LearnB := Remember(LearnB, c = "" ? "" : [c, fx])
        if Settled(LearnB)
            Adopt("bar", LearnB[3][1]), LearnB := []
    }
}
; находки [цвет, x]: подряд одного цвета; принимаем после 3, если рыба за это время сдвинулась
; (у мини-игры рыба всё время движется, у неподвижного фона — нет)
Remember(arr, c) {
    if (c = "")
        return []
    if (arr.Length && ColDiff(arr[arr.Length][1], c[1]) > 16)
        return [c]
    arr.Push(c)
    if (arr.Length > 3)
        arr.RemoveAt(1)
    return arr
}
Settled(arr) => arr.Length >= 3 && (Abs(arr[3][2] - arr[1][2]) >= 2 || Abs(arr[2][2] - arr[1][2]) >= 2)
Adopt(which, c) {
    global FishColor, BarColor
    if (which = "fish")
        FishColor := c
    else
        BarColor := c
    SaveSettings()
    try UpdateCalibInfo()
    try AddLog("Цвет " (which = "fish" ? "рыбы" : "полоски") " подобран сам: " Format("0x{:06X}", c))
}
FishSelfTest(list, out) {
    global Cap
    CapInit()
    scr := Cap.scr, mdc := DllCall("CreateCompatibleDC", "ptr", scr, "ptr"), res := ""
    for path in StrSplit(FileRead(list, "UTF-8"), "`n", "`r") {
        if (path = "")
            continue
        if (path = "RESET") {                      ; новая мини-игра — забыть прошлую рыбу
            global LastFxMiss := 99
            continue
        }
        if InStr(path, "|") {
            pt := StrSplit(path, "|"), path := pt[1]
            global TestNow := Float(pt[2])
        }
        hb := LoadPicture(path)
        old := DllCall("SelectObject", "ptr", mdc, "ptr", hb, "ptr")
        Cap.scr := mdc
        s := Sense()
        Cap.scr := scr
        DllCall("SelectObject", "ptr", mdc, "ptr", old)
        DllCall("DeleteObject", "ptr", hb)
        res .= (s.fx = "" ? "" : Round(s.fx - BX, 1)) ";" (s.bar ? (s.bar[1] - BX) ";" (s.bar[2] - BX) : ";")
            . ";" Format("0x{:06X}", FishColor) ";" Format("0x{:06X}", BarColor)
            . ";" ((n := AriaMode ? NextNote(NowMs()) : 0) ? Round(n.x - BX) ";" Round(n.t) : ";")
            . ";" NoteDump() "`n"
    }
    DllCall("DeleteDC", "ptr", mdc)
    FileAppend(res, out, "UTF-8")
}
; узкая (2–16 px) ровная линия, заметно отличная от соседей слева и справа и того же цвета выше и ниже;
; ищется внутри полоски и рядом с ней
; оба цвета неизвестны: светлая ровная полоса + линия рыбы рядом, 3 раза подряд одинаковые цвета,
; и рыба за это время сдвинулась (неподвижный фон за мини-игру не примется)
LearnPair(mid) {
    global LearnLast, LearnP
    if (A_TickCount - LearnLast < 100 && !TestMode)
        return
    LearnLast := A_TickCount
    z := FlatBright(mid)
    f := z ? FindFishLine(mid, [z[1] - 60, z[2] + 60]) : ""
    if !f {
        LearnP := []
        return
    }
    zc := Px(z[1] + 3, mid)
    if (LearnP.Length && (ColDiff(LearnP[1][1], zc) > 16 || ColDiff(LearnP[1][2], f[1]) > 16))
        LearnP := []
    LearnP.Push([zc, f[1], f[2]])
    if (LearnP.Length < 3)
        return
    moved := Abs(LearnP[3][3] - LearnP[1][3]) >= 2 || Abs(LearnP[2][3] - LearnP[1][3]) >= 2
    if moved {
        Adopt("bar", LearnP[3][1]), Adopt("fish", LearnP[3][2])
        LearnP := []
    } else
        LearnP.RemoveAt(1)
}
; самый длинный ровный кусок строки (≥ 40 px), заметно светлее того, что за его краями
FlatBright(mid) {
    w := Cap.w, best := 0, l := 0, prev := Px(0, mid)
    loop w {
        x := A_Index
        p := x < w ? Px(x, mid) : -1
        if (x < w && ColDiff(p, prev) <= 10) {
            prev := p
            continue
        }
        r := x - 1
        if (r - l >= 40 && !(l <= 2 && r >= w - 3) && r - l <= w * 0.95 && (!best || r - l > best[2] - best[1])) {
            c := Px(l + 3, mid)
            outL := l > 3 ? Lum(Px(l - 3, mid)) : 9999, outR := r < w - 4 ? Lum(Px(r + 3, mid)) : 9999
            if (Lum(c) >= 360 && Lum(c) - Min(outL, outR) >= 60)
                best := [l, r]
        }
        l := x, prev := p
    }
    return best
}
FindFishLine(mid, bar) {
    w := Cap.w, h := Cap.h
    x0 := Max(6, bar[1]), x1 := Min(w - 7, bar[2])
    x := x0
    while (x <= x1) {
        p := Px(x, mid)
        if (ColDiff(p, Px(x - 4, mid)) < 45) {
            x++
            continue
        }
        e := x                                     ; конец ровного куска того же цвета
        while (e + 1 <= x1 && ColDiff(Px(e + 1, mid), p) <= 18 && e - x < 17)
            e++
        if (e - x >= 1 && e - x <= 15 && ColDiff(p, Px(Min(w - 1, e + 4), mid)) >= 45 && !Near(p, BarColor, BarVar)) {
            c := (x + e) // 2, pc := Px(c, mid), ok := 0
            for d in [-6, -3, 3, 6]
                ok += ColDiff(Px(c, Max(0, Min(h - 1, mid + d))), pc) <= 20
            if (ok >= 3)
                return [pc, c]
        }
        x := e + 1
    }
    return ""
}
; рыба внутри полоски: слева и справа от рыбы один и тот же ровный цвет, светлее того, что за краями полоски
BarAround(mid, fx) {
    w := Cap.w
    xl := Round(fx) - 8, xr := Round(fx) + 8
    if (xl < 2 || xr > w - 3)
        return ""
    pl := Px(xl, mid), pr := Px(xr, mid)
    if (ColDiff(pl, pr) > 16)
        return ""
    l := xl                                        ; ровный кусок влево и вправо
    while (l > 0 && ColDiff(Px(l - 1, mid), pl) <= 16)
        l--
    r := xr
    while (r < w - 1 && ColDiff(Px(r + 1, mid), pr) <= 16)
        r++
    if (r - l < 30 || (l <= 2 && r >= w - 3) || r - l > w * 0.95)
        return ""
    outL := l > 3 ? Lum(Px(l - 3, mid)) : 9999, outR := r < w - 4 ? Lum(Px(r + 3, mid)) : 9999
    if (Lum(pl) < 360 || Lum(pl) - Min(outL, outR) < 60)   ; полоска светлая и заметно светлее дорожки
        return ""
    return pl
}

; Шкала силы заброса. Живая проверка 24.11 (Pinion's Aria, Crystal Cove, снимки при зажатой ЛКМ):
; вертикальная шкала ~215 px в ~150 px левее центра экрана; рамка — две чёрные колонки по 1 px
; (0–14 яркости) на расстоянии ~9 px, внутри белая заливка снизу (186–254), пустая часть тёмная.
; (Python 2.5: шкала 77–120 px, рамка шире, пустое серое — правило ниже подходит и туда.)
; Ищем на строках через 8 px узор «чёрный | 2–12 px белого | чёрный»; шкала — если такой узор
; на одном x (±2) нашёлся хотя бы на 4 строках (заливка ≥ ~30 px). Снимки: 9–27 строк из 5 кадров.
CastBarSeen() {
    static g := 0
    s := A_ScreenHeight / 1080
    x0 := A_ScreenWidth // 2 - Round(300 * s), y0 := Round(A_ScreenHeight * 0.25)
    w := Round(600 * s), h := Round(A_ScreenHeight * 0.55)
    if !g {
        scr := DllCall("GetDC", "ptr", 0, "ptr"), mdc := DllCall("CreateCompatibleDC", "ptr", scr, "ptr")
        bi := Buffer(40, 0)
        NumPut("uint", 40, bi, 0), NumPut("int", w, bi, 4), NumPut("int", -h, bi, 8)
        NumPut("ushort", 1, bi, 12), NumPut("ushort", 32, bi, 14)
        hbm := DllCall("CreateDIBSection", "ptr", mdc, "ptr", bi, "uint", 0, "ptr*", &bits := 0, "ptr", 0, "uint", 0, "ptr")
        DllCall("SelectObject", "ptr", mdc, "ptr", hbm, "ptr")
        g := {scr: scr, mdc: mdc, bits: bits}
    }
    if !DllCall("BitBlt", "ptr", g.mdc, "int", 0, "int", 0, "int", w, "int", h
        , "ptr", g.scr, "int", x0, "int", y0, "uint", 0xCC0020)
        return false
    hits := Map()                                   ; x -> сколько строк с узором
    y := 0
    while (y < h) {
        base := g.bits + y * w * 4, x := 0
        while (x < w - 14) {
            p := NumGet(base, x * 4, "uint")
            if (((p >> 16) & 0xFF) < 25 && ((p >> 8) & 0xFF) < 25 && (p & 0xFF) < 25) {
                q := NumGet(base, (x + 1) * 4, "uint")
                if (((q >> 16) & 0xFF) > 165 && ((q >> 8) & 0xFF) > 165 && (q & 0xFF) > 165) {
                    dx := 2, ok := false
                    while (dx <= 13) {
                        q := NumGet(base, (x + dx) * 4, "uint"), r := (q >> 16) & 0xFF, gg := (q >> 8) & 0xFF, b := q & 0xFF
                        if (r < 25 && gg < 25 && b < 25) {
                            ok := dx >= 3          ; отдалённая камера (24.11): рамка через 3 px, внутри 2 px
                            break
                        }
                        if (r <= 165 || gg <= 165 || b <= 165)
                            break
                        dx++
                    }
                    if ok {
                        k := x // 3
                        hits[k] := (hits.Has(k) ? hits[k] : 0) + 1
                        n := hits[k] + (hits.Has(k - 1) ? hits[k - 1] : 0) + (hits.Has(k + 1) ? hits[k + 1] : 0)
                        if (n >= 4)
                            return true
                    }
                }
            }
            x++
        }
        y += 8
    }
    return false
}

ReelVisible() {
    s := Sense()
    return s.fx != "" && s.bar
}

; --- тест и настройка рыбалки ---
ToggleTest() {
    global Testing
    if Running
        return
    Testing := !Testing
    if Testing {
        BtnTest.Text := "■   СТОП"
        SetState("Тест: открой мини-игру — видит ли макрос рыбу и полоску", C_ACC)
        ShowFrame(-1)
        SetTimer(TestTick, 60)
    } else {
        SetTimer(TestTick, 0)
        BtnTest.Text := "ТЕСТ   F3"
        ShowFrame(0)
        UpdatePreview("", 0)
        SetState("Готов к рыбалке", C_MUTED)
    }
}
TestTick() {
    sn := Sense(), fx := sn.fx, bar := sn.bar
    UpdatePreview(fx, bar)
    SeeTxt.Text := "Рыба: " (fx != "" ? "вижу ✓" : "не вижу ✗") "     Полоска: " (bar ? "вижу ✓" : "не вижу ✗")
        . "`n" ((fx != "" && bar) ? "Всё в порядке — можно запускать." : "Если «не вижу» — выдели полосу или возьми цвет заново.")
}
DefaultRegion() {
    global BX, BY, BW, BH, FishColor, BarColor
    BX := Round(A_ScreenWidth * 0.29), BY := Round(A_ScreenHeight * 0.85)
    BW := Round(A_ScreenWidth * 0.42), BH := Round(A_ScreenHeight * 0.04)
    FishColor := FISH_STD, BarColor := BAR_STD
    SaveSettings(), UpdateCalibInfo()
    AddLog("Полоса и цвета: стандартные")
    ShowFrame(2500)
}
; затемнить экран и обвести полосу мышью (Esc — отмена)
SelectRegion() {
    global BX, BY, BW, BH
    if Running
        return
    G.Hide()
    if WinExist(ROBLOX)
        WinActivate(ROBLOX)
    Sleep 200
    ov := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
    ov.BackColor := "000000"
    ov.Show("x0 y0 w" A_ScreenWidth " h" A_ScreenHeight)
    WinSetTransparent(70, ov)
    ToolTip("Обведи мышью полосу подсечки (зажми ЛКМ и тяни).  Esc — отмена", A_ScreenWidth // 2 - 200, 40)
    ok := false, box := 0
    loop {
        if GetKeyState("Escape", "P")
            break
        if GetKeyState("LButton", "P") {
            MouseGetPos(&x1, &y1)
            x2 := x1, y2 := y1
            box := MakeBox(x1, y1, 4, 4, C_ACC, 2)
            while GetKeyState("LButton", "P") {
                MouseGetPos(&x2, &y2)
                MoveBox(box, Min(x1, x2), Min(y1, y2), Max(Abs(x2 - x1), 4), Max(Abs(y2 - y1), 4), 2)
                Sleep 15
            }
            if (Abs(x2 - x1) >= 100 && Abs(y2 - y1) >= 4)
                BX := Min(x1, x2), BY := Min(y1, y2), BW := Abs(x2 - x1), BH := Abs(y2 - y1), ok := true
            break
        }
        Sleep 15
    }
    ToolTip()
    try box.Destroy()
    ov.Destroy()
    G.Show()
    if ok {
        SaveSettings(), UpdateCalibInfo()
        AddLog("Полоса выделена: " BX "," BY "  " BW "×" BH)
        ShowFrame(2000)
    } else
        AddLog("Выделение отменено")
}
PickColorCountdown(which) {
    loop 3 {
        MouseGetPos(&mx, &my)
        ToolTip("Наведи на " (which = "fish" ? "РЫБУ" : "БЕЛУЮ ПОЛОСКУ") "…  " (4 - A_Index), mx + 20, my + 20)
        Sleep 1000
    }
    ToolTip()
    PickColor(which)
}
PickColor(which) {
    global FishColor, BarColor
    MouseGetPos(&mx, &my)
    ToolTip()
    c := PixelGetColor(mx, my)
    if (which = "fish")
        FishColor := c
    else
        BarColor := c
    SaveSettings(), UpdateCalibInfo()
    AddLog("Цвет " (which = "fish" ? "рыбы" : "полоски") ": " c)
}
UpdateCalibInfo() {
    RegionTxt.Text := "Полоса: x " BX ", y " BY ", " BW "×" BH "  ·  цвета подбираются сами"
}
; текстовая картинка полосы: ▼ — рыба, █ — полоска
UpdatePreview(fx, bar) {
    n := PREVIEW_CHARS
    a := bar ? PrevCol(bar[1], n) : 0, b := bar ? PrevCol(bar[2], n) : -1
    line := ""
    loop n
        line .= (A_Index >= a && A_Index <= b) ? "█" : "─"
    fishLine := ""
    if (fx != "") {
        loop PrevCol(fx, n) - 1
            fishLine .= " "
        fishLine .= "▼"
    }
    PrevFish.Text := fishLine
    PrevBar.Text := line
}
PrevCol(x, n) => Max(1, Min(n, Round((x - BX) / BW * (n - 1)) + 1))

ShowFrame(ms) {
    global FrameGuis
    for fg in FrameGuis
        try fg.Destroy()
    FrameGuis := []
    if (ms = 0)
        return
    FrameGuis.Push(MakeBox(BX - 2, BY - 2, BW + 4, BH + 4, C_ACC, 2))
    if (ms > 0)
        SetTimer(() => ShowFrame(0), -ms)
}

; ============================================================================
;                               ОЦЕНКА (APPRAISE)
; ============================================================================
AppraiseLoop() {
    global Attempts, Found
    lastMut := ""
    while Running {
        if !WaitRoblox()
            break
        if (Attempts >= MaxAttempts) {
            StopRun("Достигнут лимит попыток (" MaxAttempts ")", C_WARN)
            break
        }
        DoClick()
        Attempts++
        Sleep DelayAfterClick
        if !Running
            break
        res := ReadResult()
        DllCall("DeleteObject", "ptr", res.raw)
        ShowReading(res)
        if (res.mutation != "" && res.mutation != lastMut)
            AddLog("#" Attempts ": " res.mutation), lastMut := res.mutation
        hit := FindTarget(res)
        if (hit != "") {
            Found++
            StopRun("НАЙДЕНО: " hit " (попытка #" Attempts ")", C_ACC)
            Loop 5 {
                SoundBeep(1200, 200)
                Sleep 80
            }
            WinActivate(G)
            return
        }
        UpdateStats()
        Sleep DelayBetween
    }
}

DoClick() {
    if UseKey1 {
        Send "{1}"
        return
    }
    ; Roblox нужен «ховер», поэтому чуть шевелим мышь перед кликом
    MouseMove(ClickX, ClickY, 0)
    Sleep 40
    MouseMove(ClickX + 2, ClickY, 0)
    Sleep 40
    MouseMove(ClickX, ClickY, 0)
    Sleep 40
    Click
}

ShowReading(res) {
    ATextTxt.Text := res.text != "" ? StrReplace(res.text, " | ", "  ·  ") : "—"
    m := res.mutation = "" ? "—" : res.mutation = "removed" ? "мутация снята" : res.mutation
    AMutTxt.Text := "Мутация: " m
    AInfoTxt.Text := "Попыток: " Attempts "   ·   ищу: " JoinArr(Targets, ", ")
}

ATest() {
    if Running
        return
    if !RW {
        SetState("Сначала выдели область (F2, F2)", C_BAD)
        return
    }
    SetState("Читаю…", C_ACC)
    res := ReadResult()
    DllCall("DeleteObject", "ptr", res.raw)
    ShowReading(res)
    hit := FindTarget(res)
    SetState(hit != "" ? "Цель найдена: " hit : "Прочитано (цель не найдена)", hit != "" ? C_ACC : C_MUTED)
    AShowFrames(1500)
}

APickClick() {
    global ClickX, ClickY
    MouseGetPos(&ClickX, &ClickY)
    SaveSettings(), UpdateACoords()
    AddLog("Точка клика: " ClickX ", " ClickY)
    AShowFrames(1500)
}

ARegionCorner() {
    global Corner1, RX, RY, RW, RH
    MouseGetPos(&mx, &my)
    if !Corner1 {
        Corner1 := [mx, my]
        SetState("Левый-верхний угол запомнен. Теперь правый-нижний — F2", C_ACC)
        return
    }
    x1 := Min(Corner1[1], mx), y1 := Min(Corner1[2], my), w := Abs(mx - Corner1[1]), h := Abs(my - Corner1[2])
    Corner1 := 0
    if (w < 20 || h < 10) {
        SetState("Область слишком маленькая — ещё раз F2, F2", C_BAD)
        return
    }
    RX := x1, RY := y1, RW := w, RH := h
    SaveSettings(), UpdateACoords()
    SetState("Область сохранена — F3 проверить чтение", C_ACC)
    AddLog("Область: " RX "," RY "  " RW "×" RH)
    AShowFrames(2000)
}

ADefaultRegion() {
    global RX, RY, RW, RH
    RX := Round(A_ScreenWidth * 0.878), RY := Round(A_ScreenHeight * 0.685)
    RW := Round(A_ScreenWidth * 0.121), RH := Round(A_ScreenHeight * 0.073)
    SaveSettings(), UpdateACoords()
    AddLog("Область: стандартная")
    AShowFrames(2500)
}

AHint(what) {
    if (what = "click")
        SetState("Наведи мышь на «Can you appraise it again?» и нажми F1", C_ACC)
    else
        SetState("Наведи на левый-верхний угол текста — F2, потом на правый-нижний — F2", C_ACC)
}

AToggleFrames() => AShowFrames(AFrameGuis.Length ? 0 : -1)

; ms > 0 — скрыть через ms, -1 — держать, 0 — скрыть
AShowFrames(ms) {
    global AFrameGuis
    for fg in AFrameGuis
        try fg.Destroy()
    AFrameGuis := []
    if (ms = 0)
        return
    if RW
        AFrameGuis.Push(MakeBox(RX - 2, RY - 2, RW + 4, RH + 4, C_ACC, 2))
    if ClickX
        AFrameGuis.Push(MakeBox(ClickX - 7, ClickY - 7, 14, 14, C_ACC_HI, 3))
    if (ms > 0)
        SetTimer(() => AShowFrames(0), -ms)
}

UpdateACoords() {
    ACoordTxt.Text := "Точка клика: " ClickX ", " ClickY "    ·    область: " RX "," RY "  " RW "×" RH
    AInfoTxt.Text := "Попыток: " Attempts "   ·   ищу: " JoinArr(Targets, ", ")
}

; --- чтение уведомления «Mutation Changed → …» ---
;   1. Экран снимается один раз.
;   2. Белый текст выделяется маской и читается — так находится слово "Changed".
;   3. Справа от "Changed" пропускается стрелка, вырезается только название мутации.
;   4. Название читается ~30 способами, побеждает мутация с наибольшим числом голосов.
ReadResult() {
    raw := CaptureRaw(RX, RY, RW, RH)
    res := {text: "", mutation: "", detail: "", raw: raw.hbm}
    hitWord := 0
    for cfg in [[170, 3], [150, 3], [190, 3], [170, 2], [170, 4], [130, 3]] {
        wm := BuildVariant(raw, 0, 0, raw.w, raw.h, "white", cfg[1])
        words := OcrWords(wm, cfg[2])
        if (A_Index = 1)
            res.text := WordsText(words)
        for w in words {
            if (StrLen(Letters(w.text)) >= 5 && Similarity(Letters(w.text), "changed") >= 0.7) {
                hitWord := w
                break
            }
        }
        if hitWord {
            crop := MutationBox(raw, wm, hitWord)
            DllCall("DeleteObject", "ptr", wm.hbm)
            break
        }
        DllCall("DeleteObject", "ptr", wm.hbm)
        if (A_Index = 1 && !RegExMatch(res.text, "i)mutat|chang|utati"))
            break
    }
    if !hitWord {
        if RegExMatch(res.text, "i)remov")
            res.mutation := "removed"
        return res
    }
    if (crop.x1 - crop.x0 < 6) {
        res.mutation := "?"
        return res
    }
    votes := Map(), readings := Map(), order := []
    for v in [["rgb", 0], ["inv", 0], ["L", 0], ["R", 0], ["G", 0], ["B", 0]
            , ["max", 150], ["max", 180], ["max", 210], ["dist", 45]] {
        img := BuildVariant(raw, crop.x0, crop.y0, crop.x1, crop.y1, v[1], v[2])
        for sc in [3, 4, 6] {
            txt := Letters(WordsText(OcrWords(img, sc)))
            if (StrLen(txt) < 3)
                continue
            if !readings.Has(txt)
                readings[txt] := 0, order.Push(txt)
            readings[txt] += 1
            best := BestMutation(txt, &score)
            if (score >= 0.7)
                votes[best] := (votes.Has(best) ? votes[best] : 0) + score
        }
        DllCall("DeleteObject", "ptr", img.hbm)
    }
    top := "", topScore := 0
    for name, scv in votes
        if (scv > topScore)
            top := name, topScore := scv
    if (top != "")
        res.mutation := top
    else {
        common := "", cnt := 0
        for txt in order
            if (readings[txt] > cnt)
                common := txt, cnt := readings[txt]
        res.mutation := "? " common
    }
    res.detail := JoinArr(order, ", ")
    return res   ; вызывающий освобождает res.raw
}

Letters(s) => StrLower(RegExReplace(s, "[^A-Za-z]"))

WordsText(words) {
    s := ""
    for w in words
        s .= (A_Index > 1 ? (w.newline ? " | " : " ") : "") w.text
    return s
}

; прямоугольник с названием мутации: справа от "Changed", стрелка пропущена
MutationBox(raw, wm, w) {
    y0 := Max(0, Floor(w.y - w.h * 0.12)), y1 := Min(raw.h, Ceil(w.y + w.h * 1.35))
    cx := Max(0, Round(w.x + w.w))
    colInk(x) {
        Loop y1 - y0
            if !(NumGet(wm.bits, ((y0 + A_Index - 1 + wm.pad) * wm.w + x + wm.pad) * 4, "uint") & 0xFF)
                return true
        return false
    }
    while (cx < raw.w && !colInk(cx))
        cx++
    start := cx
    while (cx < raw.w && colInk(cx) && cx - start < w.h * 0.95)
        cx++
    return {x0: Min(raw.w, cx + 1), y0: y0, x1: raw.w, y1: y1}
}

; вариант обработки участка снимка (white/max/dist — маски, rgb/inv/L/R/G/B — как есть)
BuildVariant(raw, x0, y0, x1, y1, mode, t) {
    static PAD := 16
    cw := x1 - x0, ch := y1 - y0, W := cw + 2 * PAD, H := ch + 2 * PAD
    hbm := NewDib(W, H, &dst)
    src := raw.bits
    sr := 0, sg := 0, sb := 0, n := 0
    Loop ch {
        row := (y0 + A_Index - 1) * raw.w
        Loop cw {
            p := NumGet(src, (row + x0 + A_Index - 1) * 4, "uint")
            sb += p & 0xFF, sg += (p >> 8) & 0xFF, sr += (p >> 16) & 0xFF, n++
        }
    }
    mr := sr // Max(n, 1), mg := sg // Max(n, 1), mb := sb // Max(n, 1)
    switch mode {
        case "rgb":  fill := (mr << 16) | (mg << 8) | mb
        case "inv":  fill := ((255 - mr) << 16) | ((255 - mg) << 8) | (255 - mb)
        case "L":    l := (mr * 299 + mg * 587 + mb * 114) // 1000, fill := (l << 16) | (l << 8) | l
        case "R":    fill := (mr << 16) | (mr << 8) | mr
        case "G":    fill := (mg << 16) | (mg << 8) | mg
        case "B":    fill := (mb << 16) | (mb << 8) | mb
        default:     fill := 0xFFFFFF
    }
    fill |= 0xFF000000
    Loop W * H
        NumPut("uint", fill, dst, (A_Index - 1) * 4)
    Loop ch {
        yy := A_Index - 1
        srow := (y0 + yy) * raw.w + x0, drow := (yy + PAD) * W + PAD
        Loop cw {
            p := NumGet(src, (srow + A_Index - 1) * 4, "uint")
            b := p & 0xFF, g := (p >> 8) & 0xFF, r := (p >> 16) & 0xFF
            switch mode {
                case "white":
                    v := (r < g ? (r < b ? r : b) : (g < b ? g : b)) > t ? 0 : 0xFFFFFF
                case "max":
                    v := (r > g ? (r > b ? r : b) : (g > b ? g : b)) > t ? 0 : 0xFFFFFF
                case "dist":
                    v := Max(Abs(r - mr), Abs(g - mg), Abs(b - mb)) > t ? 0 : 0xFFFFFF
                case "rgb":  v := p & 0xFFFFFF
                case "inv":  v := ~p & 0xFFFFFF
                case "L":    l := (r * 299 + g * 587 + b * 114) // 1000, v := (l << 16) | (l << 8) | l
                case "R":    v := (r << 16) | (r << 8) | r
                case "G":    v := (g << 16) | (g << 8) | g
                case "B":    v := (b << 16) | (b << 8) | b
            }
            NumPut("uint", v | 0xFF000000, dst, (drow + A_Index - 1) * 4)
        }
    }
    return {hbm: hbm, bits: dst, w: W, h: H, pad: PAD}
}

; OCR варианта с увеличением; координаты слов — в пикселях снимка
OcrWords(img, scale) {
    big := ScaleHbm(img.hbm, img.w, img.h, scale)
    out := []
    try {
        r := OCR.FromBitmap(big, "en-US")
        for line in r.Lines {
            first := true
            for w in line.Words {
                out.Push({text: w.Text, x: w.x / scale - img.pad, y: w.y / scale - img.pad
                    , w: w.w / scale, h: w.h / scale, newline: first && out.Length > 0})
                first := false
            }
        }
    }
    DllCall("DeleteObject", "ptr", big)
    return out
}

GdipInit() {
    static token := 0
    if !token {
        DllCall("LoadLibrary", "str", "gdiplus", "ptr")
        si := Buffer(24, 0), NumPut("uint", 1, si)
        DllCall("gdiplus\GdiplusStartup", "ptr*", &token, "ptr", si, "ptr", 0)
    }
}

ScaleHbm(hbm, w, h, scale) {
    GdipInit()
    W := w * scale, H := h * scale
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbm, "ptr", 0, "ptr*", &src := 0)
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", W, "int", H, "int", 0, "int", 0x22009, "ptr", 0, "ptr*", &dst := 0)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", dst, "ptr*", &gr := 0)
    DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gr, "int", 7)
    DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", gr, "int", 4)
    DllCall("gdiplus\GdipDrawImageRectI", "ptr", gr, "ptr", src, "int", 0, "int", 0, "int", W, "int", H)
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "ptr", dst, "ptr*", &out := 0, "uint", 0xFFFFFFFF)
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
    DllCall("gdiplus\GdipDisposeImage", "ptr", dst)
    DllCall("gdiplus\GdipDisposeImage", "ptr", src)
    return out
}

NewDib(w, h, &pBits) {
    bi := Buffer(40, 0)
    NumPut("uint", 40, bi, 0), NumPut("int", w, bi, 4), NumPut("int", -h, bi, 8)
    NumPut("ushort", 1, bi, 12), NumPut("ushort", 32, bi, 14)
    return DllCall("CreateDIBSection", "ptr", 0, "ptr", bi, "uint", 0, "ptr*", &pBits := 0, "ptr", 0, "uint", 0, "ptr")
}

CaptureRaw(x, y, w, h) {
    hdcScreen := DllCall("GetDC", "ptr", 0, "ptr")
    hdc := DllCall("CreateCompatibleDC", "ptr", hdcScreen, "ptr")
    hbm := NewDib(w, h, &pBits)
    obm := DllCall("SelectObject", "ptr", hdc, "ptr", hbm, "ptr")
    DllCall("BitBlt", "ptr", hdc, "int", 0, "int", 0, "int", w, "int", h, "ptr", hdcScreen, "int", x, "int", y, "uint", 0x00CC0020)
    DllCall("SelectObject", "ptr", hdc, "ptr", obm)
    DllCall("DeleteDC", "ptr", hdc)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)
    return {hbm: hbm, bits: pBits, w: w, h: h}
}

; цель найдена, если прочитанная мутация совпала с одной из Targets
FindTarget(res) {
    for tg in Targets
        if (tg != "" && StrLower(res.mutation) = StrLower(tg))
            return tg
    if (res.mutation = "" || res.mutation = "?")
        for tg in Targets
            if (tg != "" && InStr(Letters(res.text), "changed" StrLower(tg)))
                return tg
    return ""
}

BestMutation(word, &score := 0) {
    best := "", score := 0
    for mu in MUTATIONS {
        s := Similarity(word, StrLower(mu))
        if (s > score)
            score := s, best := mu
    }
    return best
}

Similarity(a, b) {
    la := StrLen(a), lb := StrLen(b)
    if !la || !lb
        return 0
    prev := []
    Loop lb + 1
        prev.Push(A_Index - 1)
    Loop la {
        i := A_Index, ca := SubStr(a, i, 1)
        cur := [i]
        Loop lb {
            j := A_Index
            cost := (ca = SubStr(b, j, 1)) ? 0 : 1
            cur.Push(Min(prev[j + 1] + 1, cur[j] + 1, prev[j] + cost))
        }
        prev := cur
    }
    return 1 - prev[lb + 1] / Max(la, lb)
}

; самопроверка распознавания на картинке (для разработчика)
SelfTest() {
    global RX, RY, RW, RH
    out := A_Args[7]
    OnError((e, *) => (FileAppend("ERROR line " e.Line ": " e.Message "`n", out, "UTF-8"), ExitApp(3), 1))
    pg := Gui("+AlwaysOnTop -Caption -DPIScale")
    pg.MarginX := 0, pg.MarginY := 0
    pg.Add("Picture", , A_Args[2])
    pg.Show("x0 y0 NA")
    Sleep 500
    RX := Integer(A_Args[3]), RY := Integer(A_Args[4]), RW := Integer(A_Args[5]), RH := Integer(A_Args[6])
    t0 := A_TickCount
    res := ReadResult()
    DllCall("DeleteObject", "ptr", res.raw)
    FileAppend(res.text "`nMUTATION=" res.mutation "`nMS=" (A_TickCount - t0) "`n", out, "UTF-8")
}

; ============================================================================
;                                  ОБЩЕЕ
; ============================================================================
ApplySettings() {
    global CastHoldMs, Stiffness, Smooth, ShakeTimeoutMs, AfterCatchMs, EquipKey, GameLagMs, AutoTuneOn
    global Targets, DelayAfterClick, DelayBetween, MaxAttempts, UseKey1, OnTop, GameHints, HideOnStart, AutoUpdate
    CastHoldMs := Clamp(EdCast.Value, 100, 5000, CastHoldMs)
    Stiffness := Clamp(EdKp.Value, 1, 10, Stiffness)
    Smooth := Clamp(EdKd.Value, 0, 10, Smooth)
    ShakeTimeoutMs := Clamp(EdShake.Value, 5, 180, ShakeTimeoutMs // 1000) * 1000
    AfterCatchMs := Clamp(EdAfter.Value, 0, 15000, AfterCatchMs)
    GameLagMs := Clamp(EdLag.Value, 0, 300, GameLagMs)
    EquipKey := Trim(EdEquip.Value)
    AutoTuneOn := TgVal(TgAuto)
    global AriaMode
    if (AriaMode != TgVal(TgAria))
        AriaMode := TgVal(TgAria), CapFree()     ; другая высота захвата
    t := []
    for s in StrSplit(EdTargets.Value, ",", " `t")
        if (s != "")
            t.Push(s)
    Targets := t
    DelayAfterClick := Clamp(EdDelay1.Value, 100, 20000, DelayAfterClick)
    DelayBetween := Clamp(EdDelay2.Value, 0, 20000, DelayBetween)
    MaxAttempts := Clamp(EdMax.Value, 1, 1000000, MaxAttempts)
    UseKey1 := TgVal(TgKey1)
    OnTop := TgVal(TgTop), GameHints := TgVal(TgHints), HideOnStart := TgVal(TgHide), AutoUpdate := TgVal(TgUpd)
    G.Opt((OnTop ? "+" : "-") "AlwaysOnTop")
    if !GameHints
        ToolTip()
    SaveSettings()
}

Clamp(v, lo, hi, def) => IsInteger(v) ? Max(lo, Min(hi, Integer(v))) : def

WaitRoblox() {
    warned := false
    while Running && !WinActive(ROBLOX) {
        ReleaseMouse()
        if !warned {
            SetState("Жду, пока окно Roblox станет активным…", C_WARN)
            warned := true
        }
        Sleep 500
    }
    return Running
}

ReleaseMouse() {
    global Holding
    if Holding || GetKeyState("LButton")
        Click "Up"
    Holding := false
}

SetState(msg, color) {
    StatusTxt.SetFont("c" color)
    StatusTxt.Text := msg
    if GameHints && (Running || Testing) && WinActive(ROBLOX)
        ToolTip(APP_NAME ": " msg "`n(F6 — пауза)", 10, 10)
    else
        ToolTip()
}

UpdateStats() {
    ms := RunMs + (Running ? A_TickCount - RunStart : 0)
    s := Integer(ms // 1000)
    t := Format("{:02}:{:02}:{:02}", s // 3600, Mod(s // 60, 60), Mod(s, 60))
    if (CurTab = "fish") {
        perH := s >= 60 ? Round(Reels * 3600 / s) : "—"
        StatsTxt.Text := "Забросов " Casts "   ·   рыб " Reels "   ·   пусто " Fails "   ·   время " t "   ·   в час " perH
    } else
        StatsTxt.Text := "Попыток " Attempts "   ·   найдено " Found "   ·   время " t
}

AddLog(msg) {
    LogBox.Add([FormatTime(, "HH:mm:ss") "   " msg])
    try FileAppend(FormatTime(, "dd.MM HH:mm:ss") "   " msg "`n", A_ScriptDir "\macro_log.txt", "UTF-8")
    cnt := SendMessage(0x18B, 0, 0, LogBox)        ; LB_GETCOUNT
    if (cnt > 300)
        LogBox.Delete(1), cnt--
    SendMessage(0x197, Max(cnt - 6, 0), 0, LogBox)   ; LB_SETTOPINDEX — показать последние строки без выделения
}

HandleError(e, mode) {
    try ReleaseMouse()
    LogError(e)
    return 1
}
LogError(e) {
    try AddLog("Ошибка (строка " e.Line "): " e.Message)
}

Quit() {
    global WinX, WinY
    ReleaseMouse()
    try {
        WinGetPos(&x, &y, , , G)
        if (x > -10000)
            WinX := x, WinY := y
    }
    SaveSettings()
    try CapFree()
    DllCall("winmm\timeEndPeriod", "uint", 1)
    ExitApp
}

; рамка: окно с вырезанной серединой, клики проходят насквозь
MakeBox(x, y, w, h, color, d) {
    bg := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x20")
    bg.BackColor := color
    bg.Show(Format("x{} y{} w{} h{} NA", x, y, w, h))
    MoveBox(bg, x, y, w, h, d)
    return bg
}
MoveBox(bg, x, y, w, h, d) {
    bg.Move(x, y, w, h)
    WinSetRegion(Format("0-0 {1}-0 {1}-{2} 0-{2} 0-0  {3}-{3} {4}-{3} {4}-{5} {3}-{5} {3}-{3}"
        , w, h, d, w - d, h - d), bg)
}

JoinArr(arr, sep := ", ") {
    s := ""
    for v in arr
        s .= (A_Index > 1 ? sep : "") v
    return s
}

SaveSettings() {
    IniWrite(BX, INI, "Bar", "X"), IniWrite(BY, INI, "Bar", "Y")
    IniWrite(BW, INI, "Bar", "W"), IniWrite(BH, INI, "Bar", "H")
    IniWrite(Format("0x{:06X}", FishColor), INI, "Colors", "Fish")
    IniWrite(FishVar, INI, "Colors", "FishVariation")
    IniWrite(Format("0x{:06X}", BarColor), INI, "Colors", "Bar")
    IniWrite(BarVar, INI, "Colors", "BarVariation")
    IniWrite(EquipKey, INI, "Cast", "EquipKey")
    IniWrite(CastHoldMs, INI, "Cast", "CastHoldMs")
    IniWrite(ShakeIntervalMs, INI, "Shake", "EnterIntervalMs")
    IniWrite(ShakeTimeoutMs, INI, "Shake", "ShakeTimeoutMs")
    IniWrite(Stiffness, INI, "Reel", "Stiffness")
    IniWrite(Smooth, INI, "Reel", "Damp")
    IniWrite(AutoTuneOn, INI, "Reel", "AutoTune")
    IniWrite(AriaMode, INI, "Rod", "Aria")
    IniWrite(FrameMs, INI, "Reel", "FrameMs")
    IniWrite(GameLagMs, INI, "Reel", "GameLagMs")
    IniWrite(Round(BarAccel), INI, "Reel", "BarAccelPx")
    IniWrite(Round(HoldBias, 3), INI, "Reel", "HoldBias")
    IniWrite(Round(CenterPull, 3), INI, "Reel", "CenterPull")
    IniWrite(Round(CenterMaxPx), INI, "Reel", "CenterMaxPx")
    IniWrite(Round(CenterDeadPx), INI, "Reel", "CenterDeadPx")
    IniWrite(ReelEndMs, INI, "Reel", "ReelEndMs")
    IniWrite(AfterCatchMs, INI, "Reel", "AfterCatchMs")
    IniWrite(ClickX, INI, "Appraise", "ClickX"), IniWrite(ClickY, INI, "Appraise", "ClickY")
    IniWrite(RX, INI, "Appraise", "RegionX"), IniWrite(RY, INI, "Appraise", "RegionY")
    IniWrite(RW, INI, "Appraise", "RegionW"), IniWrite(RH, INI, "Appraise", "RegionH")
    IniWrite(JoinArr(Targets, ","), INI, "Appraise", "Targets")
    IniWrite(DelayAfterClick, INI, "Appraise", "DelayAfterClickMs")
    IniWrite(DelayBetween, INI, "Appraise", "DelayBetweenMs")
    IniWrite(MaxAttempts, INI, "Appraise", "MaxAttempts")
    IniWrite(UseKey1, INI, "Appraise", "PressKey1InsteadOfClick")
    IniWrite(OnTop, INI, "Window", "OnTop")
    IniWrite(GameHints, INI, "Window", "GameHints")
    IniWrite(HideOnStart, INI, "Window", "HideOnStart")
    IniWrite(AutoUpdate, INI, "Update", "Auto"), IniWrite(UPDATE_REPO, INI, "Update", "Repo")
    IniWrite(WinX, INI, "Window", "X"), IniWrite(WinY, INI, "Window", "Y")
}

; ============================================================================
;                              САМООБНОВЛЕНИЕ
;  Последняя версия — релиз на GitHub (UPDATE_REPO). В релизе файл Reelwise-update.zip —
;  те же файлы, что ставит установщик (без settings.ini и журналов). Проверка при запуске и раз
;  в 3 часа, только когда рыбалка/оценка не идёт. Новая версия ставится, только если её скрипт
;  проходит проверку AutoHotkey (/validate), иначе остаётся текущая.
; ============================================================================
CheckUpdate(auto := true) {
    global UpdBusy
    if UpdBusy || Running || Testing || (UPDATE_REPO = "")
        return
    UpdBusy := true
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("GET", "https://api.github.com/repos/" UPDATE_REPO "/releases/latest", false)
        req.SetRequestHeader("User-Agent", "Reelwise-updater")
        req.SetRequestHeader("Accept", "application/vnd.github+json")
        req.SetTimeouts(5000, 5000, 8000, 8000)
        req.Send()
        if (req.Status = 404)
            throw Error("релизов пока нет")
        if (req.Status != 200)
            throw Error("GitHub ответил " req.Status)
        js := req.ResponseText
        if !RegExMatch(js, '"tag_name"\s*:\s*"v?([0-9][0-9.]*)"', &m)
            throw Error("в ответе нет номера версии")
        ver := m[1]
        if (VerCmp(ver, APP_VER) <= 0) {
            if !auto
                AddLog("Обновлений нет: " APP_VER " — последняя версия")
            UpdBusy := false
            return
        }
        if !RegExMatch(js, '"browser_download_url"\s*:\s*"([^"]+/Reelwise-update\.zip)"', &u)
            throw Error("в релизе " ver " нет Reelwise-update.zip")
        AddLog("Есть версия " ver " — скачиваю и ставлю…")
        ApplyUpdate(u[1], ver)
    } catch as e {
        AddLog("Обновление: " e.Message)
    }
    UpdBusy := false
}

ApplyUpdate(url, ver) {
    q(x) => "'" StrReplace(x, "'", "''") "'"
    tmp := A_Temp "\reelwise-update"
    try DirDelete(tmp, true)
    DirCreate(tmp)
    zip := tmp "\update.zip", new := tmp "\new"
    Download(url, zip)
    code := RunWait('powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '
        . q(zip) ' -DestinationPath ' q(new) ' -Force"', , "Hide")
    if (code || !FileExist(new "\Reelwise.ahk"))
        throw Error("архив обновления повреждён — оставляю " APP_VER)
    ; новая версия должна хотя бы загружаться (синтаксис, файлы Lib) — иначе не трогаем рабочую
    if RunWait('"' A_AhkPath '" /ErrorStdOut /validate "' new '\Reelwise.ahk"', new, "Hide")
        throw Error("версия " ver " не прошла проверку — оставляю " APP_VER)
    if Running
        throw Error("рыбалка уже идёт — поставлю при следующей проверке")
    SaveSettings()
    exeNew := false
    Loop Files new "\*", "FR" {
        rel := SubStr(A_LoopFileFullPath, StrLen(new) + 2)
        if (rel = "settings.ini")
            continue
        if (rel = "Reelwise.exe") {                  ; сам себя не перезапишешь, пока запущен
            exeNew := FileGetSize(A_LoopFileFullPath) != FileGetSize(A_AhkPath)
            if exeNew
                FileCopy(A_LoopFileFullPath, A_ScriptDir "\Reelwise.exe.new", true)
            continue
        }
        dst := A_ScriptDir "\" rel
        SplitPath(dst, , &dir)
        DirCreate(dir)
        FileCopy(A_LoopFileFullPath, dst, true)
    }
    try DirDelete(tmp, true)
    AddLog("Обновлено до " ver " — перезапускаюсь")
    if exeNew {
        exe := A_ScriptDir "\Reelwise.exe"
        Run(A_ComSpec ' /c timeout /t 2 /nobreak >nul & move /y "' exe '.new" "' exe '" & start "" "' exe '"', A_ScriptDir, "Hide")
        ExitApp
    }
    Reload()
}

; "2.10" > "2.9": сравнение по числам через точку
VerCmp(a, b) {
    pa := StrSplit(a, "."), pb := StrSplit(b, ".")
    Loop Max(pa.Length, pb.Length) {
        x := A_Index <= pa.Length ? Integer(pa[A_Index]) : 0
        y := A_Index <= pb.Length ? Integer(pb[A_Index]) : 0
        if (x != y)
            return x > y ? 1 : -1
    }
    return 0
}

UpdateTick() {
    if AutoUpdate && !Running && !Testing
        CheckUpdate(true)
}
