#Requires AutoHotkey v2.0

; =========================================
; FORZA AFK LOOP - ULTIMATE EXE VERSION
; Copyright © LennyS
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

; --- Erzwinge Administratorrechte (Wichtig für Forza & INI-Schreiben als EXE) ---
if !A_IsAdmin {
    Run('*RunAs "' A_ScriptFullPath '"')
    ExitApp()
}

; --- Absoluter Config-Pfad ---
global configPath := A_ScriptDir "\config.ini"

; --- Werte aus Config laden ---
global savedStartHK   := IniRead(configPath, "Settings", "StartHotkey", "F6")
global savedStopHK    := IniRead(configPath, "Settings", "StopHotkey", "F7")
global savedKey       := IniRead(configPath, "Settings", "HoldKey", "W")
global savedSounds    := IniRead(configPath, "Settings", "PlaySounds", "1")
global savedAutoRe    := IniRead(configPath, "Settings", "AutoRestart", "0")

; --- Globale Variablen ---
global running := false
global state := "idle"
global phaseStart := 0
global selectedKey := "W"
global holdTime := 480000
global pauseTime := 2000
global mapEdits := []

; =========================================
; GUI SETUP
; =========================================

gui1 := Gui("+AlwaysOnTop -MaximizeBox", "LennyS | AFK Loop")
gui1.BackColor := "1A1A1A"
gui1.SetFont("s10 cFFFFFF", "Segoe UI")

; X schließt komplett und speichert
gui1.OnEvent("Close", AutoSaveAndExit)

gui1.AddText("x20 y15 w320 Center cA970FF w700", "LennyS AFK LOOP")
gui1.AddText("x10 y40 w340 h1 Background555555")

; --- 3er TAB SYSTEM ---
tabs := gui1.AddTab3("x10 y50 w340 h330 Background1A1A1A c000000", ["Main", "Map Codes", "Settings"])

; ================= TAB 1: MAIN =================
tabs.UseTab(1)

gui1.AddText("x20 y95 w90 cFFFFFF", "Hold-Taste:")
global txtHoldKey := gui1.AddEdit("x110 y92 w120 ReadOnly Background333333 cFFFFFF Center", savedKey)
global btnBind := gui1.AddButton("x240 y91 w80 h26", "Zuweisen")
btnBind.OnEvent("Click", RecordHoldKey)

gui1.AddText("x20 y135 w90 cFFFFFF", "Haltezeit:")
global timeDropdown := gui1.AddDropDownList("x110 y132 w210 Choose4", ["2 Minuten","3 Minuten","4 Minuten","5 Minuten","6 Minuten","7 Minuten","8 Minuten","10 Minuten","15 Minuten"])

; --- Status & Progress ---
global statusText := gui1.AddText("x20 y190 w320 Center cFFFFFF", "Status: Inaktiv")
global timerText := gui1.AddText("x20 y215 w320 Center c00FF99", "Verbleibend: 00:00")
global progress := gui1.AddProgress("x20 y245 w320 h15 cA970FF Background333333", 0)

global btnStart := gui1.AddButton("x20 y280 w150 h40", "START")
global btnStop := gui1.AddButton("x190 y280 w150 h40", "STOP")
btnStart.OnEvent("Click", Start)
btnStop.OnEvent("Click", Stop)


; ================= TAB 2: MAP CODES =================
tabs.UseTab(2)

gui1.AddText("x20 y85 w300 cA970FF", "Deine gespeicherten Map-Codes:")

yPos := 120
Loop 4 {
    gui1.AddText("x20 y" yPos " w50 cFFFFFF", "Slot " A_Index ":")
    savedCode := IniRead(configPath, "MapCodes", "Code" A_Index, "")
    
    ed := gui1.AddEdit("x80 y" yPos-3 " w180 Background333333 cFFFFFF", savedCode)
    mapEdits.Push(ed)
    
    btn := gui1.AddButton("x270 y" yPos-4 " w50 h26", "Copy")
    btn.OnEvent("Click", CreateCopyFunc(A_Index))
    
    yPos += 40
}


; ================= TAB 3: SETTINGS =================
tabs.UseTab(3)

gui1.AddText("x20 y90 w300 cA970FF", "Benutzerdefinierte Hotkeys:")

gui1.AddText("x20 y125 w100 cFFFFFF", "Start Taste:")
global hkStartCtrl := gui1.AddHotkey("x120 y122 w180", savedStartHK)

gui1.AddText("x20 y165 w100 cFFFFFF", "Stop Taste:")
global hkStopCtrl := gui1.AddHotkey("x120 y162 w180", savedStopHK)

gui1.AddText("x20 y210 w300 cA970FF", "Zusätzliche Features:")

global chkSounds := gui1.AddCheckbox("x20 y240 w300 cFFFFFF Checked" savedSounds, "Start / Stop Sounds abspielen")
global chkAutoRestart := gui1.AddCheckbox("x20 y270 w300 cFFFFFF Checked" savedAutoRe, "Auto Restart (drückt 'Enter' nach Zyklus)")

btnSave := gui1.AddButton("x20 y310 w320 h40", "Einstellungen Speichern")
btnSave.OnEvent("Click", SaveSettings)

; ================= ENDE TABS =================
tabs.UseTab()
gui1.AddText("x20 y390 w340 Center c777777", "Copyright © LennyS")

gui1.Show("w360 h420")

; --- Hotkeys initialisieren ---
try Hotkey(savedStartHK, Start)
try Hotkey(savedStopHK, Stop)

; =========================================
; FUNKTIONEN & LOGIK
; =========================================

CreateCopyFunc(index) {
    return (*) => (
        A_Clipboard := mapEdits[index].Text,
        ToolTip("Code aus Slot " index " kopiert!"),
        SetTimer(() => ToolTip(), -1500)
    )
}

RecordHoldKey(*) {
    btnBind.Text := "Drücke Taste..."
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
        IniWrite(chkAutoRestart.Value.ToString(), configPath, "Settings", "AutoRestart")
        
        Loop 4 {
            IniWrite(mapEdits[A_Index].Text, configPath, "MapCodes", "Code" A_Index)
        }

        global savedStartHK, savedStopHK
        try Hotkey(savedStartHK, "Off")
        try Hotkey(savedStopHK, "Off")
        
        savedStartHK := hkStartCtrl.Value
        savedStopHK := hkStopCtrl.Value
        
        try Hotkey(savedStartHK, Start)
        try Hotkey(savedStopHK, Stop)

        MsgBox("Alle Einstellungen & Map-Codes wurden erfolgreich gespeichert!", "LennyS Config", "Iconi T2")
    } catch Error as err {
        MsgBox("Fehler beim Speichern! Bitte Skript als Administrator ausführen.`n`nDetails: " err.Message, "Fehler", "IconX")
    }
}

AutoSaveAndExit(*) {
    try {
        IniWrite(hkStartCtrl.Value, configPath, "Settings", "StartHotkey")
        IniWrite(hkStopCtrl.Value, configPath, "Settings", "StopHotkey")
        IniWrite(txtHoldKey.Text, configPath, "Settings", "HoldKey")
        IniWrite(chkSounds.Value.ToString(), configPath, "Settings", "PlaySounds")
        IniWrite(chkAutoRestart.Value.ToString(), configPath, "Settings", "AutoRestart")
        Loop 4 {
            IniWrite(mapEdits[A_Index].Text, configPath, "MapCodes", "Code" A_Index)
        }
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
    statusText.Text := "Status: " selectedKey " wird gehalten"

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
    timerText.Text := "Verbleibend: 00:00"
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

            if (chkAutoRestart.Value) {
                statusText.Text := "Status: Auto-Restart aktiv..."
                Sleep(500)
                SendInput("{Enter down}")
                Sleep(150)
                SendInput("{Enter up}")
                Sleep(2000)
            }

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
            statusText.Text := "Status: " selectedKey " wird gehalten"
            return
        }
        progress.Value := (elapsed / pauseTime) * 100
    }

    seconds := Floor(remaining / 1000)
    mins := Floor(seconds / 60)
    secs := Mod(seconds, 60)

    timerText.Text := Format("Verbleibend: {:02}:{:02}", mins, secs)
}