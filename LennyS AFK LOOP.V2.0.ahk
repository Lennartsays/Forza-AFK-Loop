#Requires AutoHotkey v2.0

; =================================================================
; FORZA AFK LOOP - LENNARTSAYS PRO EDITION (3-STUFEN-WÄCHTER)
; Copyright © Lennartsays
; =================================================================

; --- AUTOMATISCHES UPDATE SYSTEM ---
global INTERNET_VERSION_URL := "https://raw.githubusercontent.com/Lennartsays/Forza-AFK-Loop/main/version.txt"
global DOWNLOAD_URL         := "https://github.com/Lennartsays/Forza-AFK-Loop"
global CURRENT_VERSION      := "2.0" ; Version erhöht für den 3-Stufen-Wächter

; Starte die Update-Prüfung direkt beim Start
CheckForUpdates()

CheckForUpdates() {
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", INTERNET_VERSION_URL, true)
        whr.Send()
        whr.WaitForResponse(3)
        latestVersion := Trim(whr.ResponseText)
        
        if (latestVersion != "" && latestVersion > CURRENT_VERSION) {
            Antwort := MsgBox(
                "Eine neue Version (" latestVersion ") ist verfügbar!`nDeine Version: " CURRENT_VERSION "`n Mauell updaten?", 
                "Update Verfügbar", 
                "YesNo Iconi"
            )
            if (Antwort = "Yes") {
                Run(DOWNLOAD_URL)
                ExitApp()
            }
        }
    } catch {
        return
    }
}

; --- Erzwinge Administratorrechte ---
if !A_IsAdmin {
    Run('*RunAs "' A_ScriptFullPath '"')
    ExitApp()
}

; --- Absoluter Config-Pfad ---
global configPath := A_ScriptDir "\config.ini"

; --- STATISCHE MAP CODES ---
global staticMaps := [
    {Name: "1M+/h CR",      Code: "954356527"},
    {Name: "Route 67",  Code: "155491518"},
]

; =================================================================
; VOM USER ERMITTELTE WERTE (3-STUFEN-WÄCHTER AUF BASIS 2560x1440)
; =================================================================

; --- SCHRITT 1: NEUSTART BUTTON (Rennen vorbei) ---
global spyX1_1 := 434,  spyY1_1 := 1341, targetColor1_1 := "0x000000"
global spyX1_2 := 426,  spyY1_2 := 1341, targetColor1_2 := "0xFFFFFF"

; --- SCHRITT 2: BESTÄTIGEN BUTTON (Untermenü) ---
global spyX2_1 := 1276, spyY2_1 := 794,  targetColor2_1 := "0xFFFFFF"
global spyX2_2 := 1277, spyY2_2 := 766,  targetColor2_2 := "0xCAFF02"

; --- SCHRITT 3: RENNEN STARTEN BUTTON (Startaufstellung) ---
global spyX3_1 := 562,  spyY3_1 := 867,  targetColor3_1 := "0xCAFF02"
global spyX3_2 := 560,  spyY3_2 := 886,  targetColor3_2 := "0xFFFFFF"

; --- DYNAMISCHE AUFLÖSUNGS-ANPASSUNG ---
global tX1_1 := Round((spyX1_1 / 2560) * A_ScreenWidth), tY1_1 := Round((spyY1_1 / 1440) * A_ScreenHeight)
global tX1_2 := Round((spyX1_2 / 2560) * A_ScreenWidth), tY1_2 := Round((spyY1_2 / 1440) * A_ScreenHeight)

global tX2_1 := Round((spyX2_1 / 2560) * A_ScreenWidth), tY2_1 := Round((spyY2_1 / 1440) * A_ScreenHeight)
global tX2_2 := Round((spyX2_2 / 2560) * A_ScreenWidth), tY2_2 := Round((spyY2_2 / 1440) * A_ScreenHeight)

global tX3_1 := Round((spyX3_1 / 2560) * A_ScreenWidth), tY3_1 := Round((spyY3_1 / 1440) * A_ScreenHeight)
global tX3_2 := Round((spyX3_2 / 2560) * A_ScreenWidth), tY3_2 := Round((spyY3_2 / 1440) * A_ScreenHeight)


; --- Werte aus Config laden ---
global savedStartHK   := IniRead(configPath, "Settings", "StartHotkey", "F6")
global savedStopHK    := IniRead(configPath, "Settings", "StopHotkey", "F7")
global savedKey       := IniRead(configPath, "Settings", "HoldKey", "W")
global savedSounds    := IniRead(configPath, "Settings", "PlaySounds", "1")
global savedAutoReset := IniRead(configPath, "Settings", "AutoRestart", "0")

; --- Globale Variablen für Logik ---
global running := false
global state := "idle"
global phaseStart := 0
global selectedKey := "W"
global holdTime := 480000
global pauseTime := 2000

; =================================================================
; GUI SETUP
; =================================================================

gui1 := Gui("+AlwaysOnTop -MaximizeBox", "Lennartsays | AFK Loop Pro")
gui1.BackColor := "1A1A1A"
gui1.SetFont("s10 cFFFFFF", "Segoe UI")

; X schließt komplett und speichert Settings
gui1.OnEvent("Close", AutoSaveAndExit)

; Titelbereich
gui1.SetFont("s14 w700 cA970FF")
gui1.AddText("x20 y15 w340 Center", "Lennartsays AFK LOOP PRO")
gui1.SetFont("s10 w400 cFFFFFF")
gui1.AddText("x20 y45 w340 h1 Background444444")

; Tabs
tabs := gui1.AddTab3("x15 y60 w350 h340 Background1A1A1A", ["Main", "Map Codes", "Settings"])

; ================= TAB 1: MAIN =================
tabs.UseTab(1)

gui1.AddText("x35 y105 w100 h25 +0x200", "Hold-Taste:")
global txtHoldKey := gui1.AddEdit("x145 y105 w110 h25 ReadOnly Background2A2A2A cFFFFFF Center", savedKey)
global btnBind := gui1.AddButton("x265 y105 w80 h25", "Zuweisen")
btnBind.OnEvent("Click", RecordHoldKey)

gui1.AddText("x35 y145 w100 h25 +0x200", "Haltezeit:")
global timeDropdown := gui1.AddDropDownList("x145 y145 w200 Choose4 Background2A2A2A c000000", ["2 Minuten","3 Minuten","4 Minuten","5 Minuten","6 Minuten","7 Minuten","8 Minuten","10 Minuten","15 Minuten"])

gui1.AddText("x35 y190 w310 h1 Background333333")

gui1.SetFont("s11 w700 cFFFFFF")
global statusText := gui1.AddText("x35 y205 w310 Center", "Status: Inaktiv")

gui1.SetFont("s16 w700 c00FF99")
global timerText := gui1.AddText("x35 y230 w310 Center", "00:00")
gui1.SetFont("s10 w400 cFFFFFF")

global progress := gui1.AddProgress("x35 y270 w310 h12 cA970FF Background2A2A2A", 0)

global btnStart := gui1.AddButton("x35 y305 w150 h40 +Default", "START")
global btnStop := gui1.AddButton("x195 y305 w150 h40", "STOP")
btnStart.OnEvent("Click", Start)
btnStop.OnEvent("Click", Stop)


; ================= TAB 2: MAP CODES =================
tabs.UseTab(2)

gui1.SetFont("cA970FF w700")
gui1.AddText("x35 y100 w310", "Verfügbare Rennstrecken:")
gui1.SetFont("cFFFFFF w400")

yPos := 135
for index, mapObj in staticMaps {
    if (index > 4)
        break
        
    gui1.SetFont("w700 cFFFFFF q5")
    gui1.AddText("x35 y" yPos " w230", mapObj.Name)
    
    gui1.SetFont("w400 cAAAAAA q5")
    gui1.AddText("x35 y" (yPos+18) " w230", mapObj.Code)
    
    btn := gui1.AddButton("x285 y" (yPos+5) " w60 h26", "Copy")
    btn.OnEvent("Click", CreateCopyFunc(index))
    
    yPos += 55
}
gui1.SetFont("cFFFFFF w400")


; ================= TAB 3: SETTINGS =================
tabs.UseTab(3)

gui1.SetFont("cA970FF w700")
gui1.AddText("x35 y100 w310", "Tastatur-Hotkeys:")
gui1.SetFont("cFFFFFF w400")

gui1.AddText("x35 y135 w100 h25 +0x200", "Start-Taste:")
global hkStartCtrl := gui1.AddHotkey("x145 y135 w200 h25", savedStartHK)

gui1.AddText("x35 y175 w100 h25 +0x200", "Stop-Taste:")
global hkStopCtrl := gui1.AddHotkey("x145 y175 w200 h25", savedStopHK)

gui1.SetFont("cA970FF w700")
gui1.AddText("x35 y215 w310", "Optionen:")
gui1.SetFont("cFFFFFF w400")

global chkSounds := gui1.AddCheckbox("x35 y240 w310 h20 Checked" savedSounds, "Akustische Signale (Start / Stop)")
global chkAutoReset := gui1.AddCheckbox("x35 y265 w310 h20 Checked" savedAutoReset, "Auto-Restart (3-Stufen-Wächter)")

btnSave := gui1.AddButton("x35 y305 w310 h40", "Einstellungen Speichern")
btnSave.OnEvent("Click", SaveSettings)


; ================= ENDE TABS =================
tabs.UseTab()
gui1.SetFont("s8 c666666")
gui1.AddText("x20 y410 w340 Center", "Copyright © Lennartsays | Forza Pro Loop")

gui1.Show("w380 h435")

; --- Hotkeys registrieren ---
try Hotkey(savedStartHK, Start)
try Hotkey(savedStopHK, Stop)


; =================================================================
; LOGIK & STEUERUNG
; =================================================================

CreateCopyFunc(index) {
    return (*) => (
        A_Clipboard := staticMaps[index].Code,
        ToolTip("'" staticMaps[index].Name "' kopiert!"),
        SetTimer(() => ToolTip(), -1500)
    )
}

RecordHoldKey(*) {
    btnBind.Text := "Drücken..."
    btnBind.Enabled := false
    
    ih := InputHook("L1 M")
    ih.KeyOpt("{All}", "E")
    ih.Start()
    
    chosenKey := ""
    
    Loop {
        if (!ih.InProgress) {
            chosenKey := ih.EndKey
            break
        }
        for mBtn in ["LButton", "RButton", "MButton", "XButton1", "XButton2"] {
            if GetKeyState(mBtn, "P") {
                chosenKey := mBtn
                ih.Stop()
                break 2
            }
        }
        Loop 32 {
            if GetKeyState("Joy" A_Index, "P") {
                chosenKey := "Joy" A_Index
                ih.Stop()
                break 2
            }
        }
        Sleep(20)
    }
    
    if (chosenKey != "")
        txtHoldKey.Text := chosenKey
    
    btnBind.Text := "Zuweisen"
    btnBind.Enabled := true
}

SaveSettings(*) {
    try {
        IniWrite(hkStartCtrl.Value, configPath, "Settings", "StartHotkey")
        IniWrite(hkStopCtrl.Value, configPath, "Settings", "StopHotkey")
        IniWrite(txtHoldKey.Text, configPath, "Settings", "HoldKey")
        IniWrite(chkSounds.Value.ToString(), configPath, "Settings", "PlaySounds")
        IniWrite(chkAutoReset.Value.ToString(), configPath, "Settings", "AutoRestart")
        
        global savedStartHK, savedStopHK
        try Hotkey(savedStartHK, "Off")
        try Hotkey(savedStopHK, "Off")
        
        savedStartHK := hkStartCtrl.Value
        savedStopHK := hkStopCtrl.Value
        
        try Hotkey(savedStartHK, Start)
        try Hotkey(savedStopHK, Stop)

        MsgBox("Einstellungen wurden erfolgreich gespeichert!", "Config", "Iconi T2")
    } catch Error as err {
        MsgBox("Fehler beim Speichern!`n`nDetails: " err.Message, "Fehler", "IconX")
    }
}

AutoSaveAndExit(*) {
    try {
        IniWrite(hkStartCtrl.Value, configPath, "Settings", "StartHotkey")
        IniWrite(hkStopCtrl.Value, configPath, "Settings", "StopHotkey")
        IniWrite(txtHoldKey.Text, configPath, "Settings", "HoldKey")
        IniWrite(chkSounds.Value.ToString(), configPath, "Settings", "PlaySounds")
        IniWrite(chkAutoReset.Value.ToString(), configPath, "Settings", "AutoRestart")
    }
    ExitApp()
}

Start(*) {
    global running, state, phaseStart, selectedKey, holdTime

    if running
        return

    if (txtHoldKey.Text = "") {
        MsgBox("Bitte zuerst eine Hold-Taste zuweisen!", "Fehler", "IconX")
        return
    }

    if (chkSounds.Value)
        SoundBeep(1000, 200)

    selectedKey := txtHoldKey.Text
    selectedTime := timeDropdown.Text

    switch selectedTime {
        case "2 Minuten":  holdTime := 120000
        case "3 Minuten":  holdTime := 180000
        case "4 Minuten":  holdTime := 240000
        case "5 Minuten":  holdTime := 300000
        case "6 Minuten":  holdTime := 360000
        case "7 Minuten":  holdTime := 420000
        case "8 Minuten":  holdTime := 480000
        case "10 Minuten": holdTime := 600000
        case "15 Minuten": holdTime := 900000
    }

    running := true
    state := "hold"
    phaseStart := A_TickCount
    
    if (chkAutoReset.Value)
        statusText.Text := "Wächter aktiv... Fahre..."
    else
        statusText.Text := "Status: Aktiv"

    SendInput("{" selectedKey " down}")
    SetTimer(UpdateLoop, 100)
}

Stop(*) {
    global running, state, selectedKey

    if (chkSounds.Value)
        SoundBeep(500, 200)

    running := false
    state := "idle"

    SendInput("{" selectedKey " up}")

    statusText.Text := "Status: Inaktiv"
    timerText.Text := "00:00"
    progress.Value := 0
}

UpdateLoop() {
    global running, state, phaseStart, holdTime, pauseTime, selectedKey
    
    ; Pixel-Variablen holen
    global tX1_1, tY1_1, targetColor1_1, tX1_2, tY1_2, targetColor1_2
    global tX2_1, tY2_1, targetColor2_1, tX2_2, tY2_2, targetColor2_2
    global tX3_1, tY3_1, targetColor3_1, tX3_2, tY3_2, targetColor3_2

    if !running
        return

    elapsed := A_TickCount - phaseStart

    ; ================= MODUS A: DER 3-STUFEN-WÄCHTER =================
    if (chkAutoReset.Value) {
        
        ; STUFE 1: Ist das Rennen vorbei? (Wartet auf deinen Schwarz/Weiß Neustart-Button)
        if (state = "hold") {
            if (PixelGetColor(tX1_1, tY1_1) = targetColor1_1 && PixelGetColor(tX1_2, tY1_2) = targetColor1_2) {
                SendInput("{" selectedKey " up}") ; Sofort vom Gas gehen!
                state := "wait_for_confirm"
                statusText.Text := "Rennen vorbei! Drücke Weiter..."
                SendInput("{X}")
                Sleep(1200) ; Kurzer Schutzpuffer vor dem nächsten Menü
            }
            progress.Value := Mod(Floor(A_TickCount / 20), 100) ; Animierte Scanner-Bar
            timerText.Text := "BOT"
        }
        
        ; STUFE 2: Bestätigen-Untermenü da? (Wartet auf deinen Weiß/Neongelben Button)
        else if (state = "wait_for_confirm") {
            if (PixelGetColor(tX2_1, tY2_1) = targetColor2_1 && PixelGetColor(tX2_2, tY2_2) = targetColor2_2) {
                state := "wait_for_grid"
                statusText.Text := "Bestätige... Löse Neustart aus..."
                SendInput("{Enter}") ; Enter drückt "Rennen wiederholen"
                Sleep(2500) ; Gibt dem Spiel Zeit, in den Ladebildschirm zu wechseln
            }
        }
        
        ; STUFE 3: Zurück auf der Strecke? (Wartet auf deinen Neongelb/Weißen Start-Button)
        else if (state = "wait_for_grid") {
            if (PixelGetColor(tX3_1, tY3_1) = targetColor3_1 && PixelGetColor(tX3_2, tY3_2) = targetColor3_2) {
                statusText.Text := "Startgitter erkannt! Fliegender Start..."
                SendInput("{Enter}") ; Startet das Rennen im Gitter
                Sleep(3500) ; Wartet den 3-2-1 Countdown der Ampel ab
                
                if !running
                    return
                    
                SendInput("{" selectedKey " down}") ; Vollgas!
                state := "hold"
                phaseStart := A_TickCount
            }
            statusText.Text := "Warte auf Ladebildschirm..."
        }
        return
    }

    ; ================= MODUS B: STUR NACH ZEIT-TIMER =================
    if (state = "hold") {
        remaining := holdTime - elapsed
        if (remaining <= 0) {
            SendInput("{" selectedKey " up}")
            state := "pause"
            phaseStart := A_TickCount
            statusText.Text := "Status: Pause"
            return
        }
        progress.Value := (elapsed / holdTime) * 100
    }
    else if (state = "pause") {
        remaining := pauseTime - elapsed
        if (remaining <= 0) {
            SendInput("{" selectedKey " down}")
            state := "hold"
            phaseStart := A_TickCount
            statusText.Text := "Status: Aktiv"
            return
        }
        progress.Value := (elapsed / pauseTime) * 100
    }

    seconds := Floor(remaining / 1000)
    mins := Floor(seconds / 60)
    secs := Mod(seconds, 60)
    timerText.Text := Format("{:02}:{:02}", mins, secs)
}