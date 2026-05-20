#Requires AutoHotkey v2.0

; =========================================
; FORZA AFK LOOP - DEVELOPER EDITION
; Copyright © Lennartsays
; =========================================

; --- AUTOMATISCHES UPDATE SYSTEM ---
global INTERNET_VERSION_URL := "https://raw.githubusercontent.com/Lennartsays/Forza-AFK-Loop/main/version.txt"
global DOWNLOAD_URL         := "https://github.com/Lennartsays/Forza-AFK-Loop"
global CURRENT_VERSION      := "1.0" 

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
                "Eine neue Version (" latestVersion ") ist verfügbar!`nDeine Version: " CURRENT_VERSION "`n`nMöchtest du das Update jetzt herunterladen?", 
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

; --- STATISCHE MAP CODES (NUR HIER IM CODE ÄNDERN!) ---
global staticMaps := [
    {Name: "Goliath XP Farm",      Code: "123 456 789"},
    {Name: "Guanajuato Rundkurs",  Code: "987 654 321"},
    {Name: "Sprintsaison 2026",    Code: "456 123 789"},
    {Name: "Lennartsays Custom",   Code: "111 222 333"}
]

; --- Werte aus Config laden (Nur noch Settings, keine Maps) ---
global savedStartHK   := IniRead(configPath, "Settings", "StartHotkey", "F6")
global savedStopHK    := IniRead(configPath, "Settings", "StopHotkey", "F7")
global savedKey       := IniRead(configPath, "Settings", "HoldKey", "W")
global savedSounds    := IniRead(configPath, "Settings", "PlaySounds", "1")

; --- Globale Variablen ---
global running := false
global state := "idle"
global phaseStart := 0
global selectedKey := "W"
global holdTime := 480000
global pauseTime := 2000

; =========================================
; GUI SETUP (NEW DESIGN)
; =========================================

gui1 := Gui("+AlwaysOnTop -MaximizeBox", "Lennartsays | AFK Loop")
gui1.BackColor := "1A1A1A"
gui1.SetFont("s10 cFFFFFF", "Segoe UI")

; X schließt komplett und speichert Settings
gui1.OnEvent("Close", AutoSaveAndExit)

; Titelbereich
gui1.SetFont("s14 w700 cA970FF")
gui1.AddText("x20 y15 w340 Center", "Lennartsays AFK LOOP")
gui1.SetFont("s10 w400 cFFFFFF")
gui1.AddText("x20 y45 w340 h1 Background444444")

; Tabs stylen
tabs := gui1.AddTab3("x15 y60 w350 h340 Background1A1A1A", ["Main", "Map Codes", "Settings"])

; ================= TAB 1: MAIN =================
tabs.UseTab(1)

gui1.AddText("x35 y105 w100 h25 +0x200", "Hold-Taste:")
global txtHoldKey := gui1.AddEdit("x145 y105 w110 h25 ReadOnly Background2A2A2A cFFFFFF Center", savedKey)
global btnBind := gui1.AddButton("x265 y105 w80 h25", "Zuweisen")
btnBind.OnEvent("Click", RecordHoldKey)

gui1.AddText("x35 y145 w100 h25 +0x200", "Haltezeit:")
global timeDropdown := gui1.AddDropDownList("x145 y145 w200 Choose4 Background2A2A2A c000000", ["2 Minuten","3 Minuten","4 Minuten","5 Minuten","6 Minuten","7 Minuten","8 Minuten","10 Minuten","15 Minuten"])

; Status-Box
gui1.AddText("x35 y190 w310 h1 Background333333")

; FIX: Schriftart separat setzen, danach das Element erstellen
gui1.SetFont("s11 w700 cFFFFFF")
global statusText := gui1.AddText("x35 y205 w310 Center", "Status: Inaktiv")

gui1.SetFont("s16 w700 c00FF99")
global timerText := gui1.AddText("x35 y230 w310 Center", "00:00")

; Wieder zurücksetzen auf Standard für die restlichen Elemente
gui1.SetFont("s10 w400 cFFFFFF")

global progress := gui1.AddProgress("x35 y270 w310 h12 cA970FF Background2A2A2A", 0)

; Buttons
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
        
    ; FIX: Qualität (+q5) wird jetzt direkt beim Setzen der Schriftart übergeben
    gui1.SetFont("w700 cFFFFFF q5")
    gui1.AddText("x35 y" yPos " w230", mapObj.Name)
    
    gui1.SetFont("w400 cAAAAAA q5")
    gui1.AddText("x35 y" (yPos+18) " w230", mapObj.Code)
    
    ; Copy Button daneben platzieren
    btn := gui1.AddButton("x285 y" (yPos+5) " w60 h26", "Copy")
    btn.OnEvent("Click", CreateCopyFunc(index))
    
    yPos += 55
}
; Schriftart wieder auf Standard zurücksetzen
gui1.SetFont("cFFFFFF w400")

; ================= TAB 3: SETTINGS =================
tabs.UseTab(3)

gui1.SetFont("cA970FF w700")
gui1.AddText("x35 y100 w310", "Tastatur-Hotkeys:")
gui1.SetFont("cFFFFFF w400")

gui1.AddText("x35 y135 w100 h25 +0x200", "Start-Taste:")
; FIX: Background2A2A2A entfernt, da Hotkey-Felder keine Hintergrundfarben unterstützen
global hkStartCtrl := gui1.AddHotkey("x145 y135 w200 h25", savedStartHK)

gui1.AddText("x35 y175 w100 h25 +0x200", "Stop-Taste:")
; FIX: Background2A2A2A entfernt
global hkStopCtrl := gui1.AddHotkey("x145 y175 w200 h25", savedStopHK)

gui1.SetFont("cA970FF w700")
gui1.AddText("x35 y225 w310", "Optionen:")
gui1.SetFont("cFFFFFF w400")

global chkSounds := gui1.AddCheckbox("x35 y255 w310 h25 Checked" savedSounds, "Akustische Signale (Start / Stop Sounds)")

btnSave := gui1.AddButton("x35 y305 w310 h40", "Einstellungen Speichern")
btnSave.OnEvent("Click", SaveSettings)

; ================= ENDE TABS =================
tabs.UseTab()
gui1.SetFont("s8 c666666")
gui1.AddText("x20 y410 w340 Center", "Copyright © Lennartsays | Forza Pro Loop")

gui1.Show("w380 h435")

; --- Hotkeys initialisieren ---
try Hotkey(savedStartHK, Start)
try Hotkey(savedStopHK, Stop)

; =========================================
; FUNKTIONEN & LOGIK
; =========================================

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
    
    if (chosenKey != "") {
        txtHoldKey.Text := chosenKey
    }
    
    btnBind.Text := "Zuweisen"
    btnBind.Enabled := true
}

SaveSettings(*) {
    try {
        IniWrite(hkStartCtrl.Value, configPath, "Settings", "StartHotkey")
        IniWrite(hkStopCtrl.Value, configPath, "Settings", "StopHotkey")
        IniWrite(txtHoldKey.Text, configPath, "Settings", "HoldKey")
        IniWrite(chkSounds.Value.ToString(), configPath, "Settings", "PlaySounds")
        
        global savedStartHK, savedStopHK
        try Hotkey(savedStartHK, "Off")
        try Hotkey(savedStopHK, "Off")
        
        savedStartHK := hkStartCtrl.Value
        savedStopHK := hkStopCtrl.Value
        
        try Hotkey(savedStartHK, Start)
        try Hotkey(savedStopHK, Stop)

        MsgBox("Einstellungen wurden erfolgreich gespeichert!", "LennyS Config", "Iconi T2")
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
    }
    ExitApp()
}

Start(*) {
    global running, state, phaseStart
    global selectedKey, holdTime

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
    global running, state, phaseStart
    global holdTime, pauseTime, selectedKey

    if !running
        return

    elapsed := A_TickCount - phaseStart

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