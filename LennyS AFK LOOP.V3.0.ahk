#Requires AutoHotkey v2.0

; --- Administrator-Check ganz oben ---
if !A_IsAdmin {
    Run('*RunAs "' A_ScriptFullPath '"')
    ExitApp()
}

; =================================================================
; 1. KEYAUTH KONFIGURATION & GLOBALE VARIABLEN
; =================================================================
global AppName   := "Forza AFK Loop"
global OwnerID   := "t6putT2vCN"
global Version   := "1.0"
global HWID      := DriveGetSerial("C:")
global authed    := false
global discordLink := "https://discord.gg/AV4m2Q3z8z"

; --- Bot Setup Variablen ---
global INTERNET_VERSION_URL := "https://raw.githubusercontent.com/Lennartsays/Forza-AFK-Loop/main/version.txt"
global DOWNLOAD_URL         := "https://github.com/Lennartsays/Forza-AFK-Loop"
global CURRENT_VERSION      := "3.0" ; <--- Version ist jetzt 3.0

global configPath := A_ScriptDir "\config.ini"
global staticMaps := [
    {Name: "1M+/h CR",      Code: "954356527"},
    {Name: "Route 67",      Code: "155491518"},
    {Name: "Route 67 2.0",  Code: "325907211"}
]

global spyX1_1 := 434,  spyY1_1 := 1341, targetColor1_1 := "0x000000"
global spyX1_2 := 426,  spyY1_2 := 1341, targetColor1_2 := "0xFFFFFF"
global spyX2_1 := 1276, spyY2_1 := 794,  targetColor2_1 := "0xFFFFFF"
global spyX2_2 := 1277, spyY2_2 := 766,  targetColor2_2 := "0xCAFF02"
global spyX3_1 := 562,  spyY3_1 := 867,  targetColor3_1 := "0xCAFF02"
global spyX3_2 := 560,  spyY3_2 := 886,  targetColor3_2 := "0xFFFFFF"

global tX1_1 := Round((spyX1_1 / 2560) * A_ScreenWidth), tY1_1 := Round((spyY1_1 / 1440) * A_ScreenHeight)
global tX1_2 := Round((spyX1_2 / 2560) * A_ScreenWidth), tY1_2 := Round((spyY1_2 / 1440) * A_ScreenHeight)
global tX2_1 := Round((spyX2_1 / 2560) * A_ScreenWidth), tY2_1 := Round((spyY2_1 / 1440) * A_ScreenHeight)
global tX2_2 := Round((spyX2_2 / 2560) * A_ScreenWidth), tY2_2 := Round((spyY2_2 / 1440) * A_ScreenHeight)
global tX3_1 := Round((spyX3_1 / 2560) * A_ScreenWidth), tY3_1 := Round((spyY3_1 / 1440) * A_ScreenHeight)
global tX3_2 := Round((spyX3_2 / 2560) * A_ScreenWidth), tY3_2 := Round((spyY3_2 / 1440) * A_ScreenHeight)

global savedStartHK   := IniRead(configPath, "Settings", "StartHotkey", "F6")
global savedStopHK    := IniRead(configPath, "Settings", "StopHotkey", "F7")
global savedKey       := IniRead(configPath, "Settings", "HoldKey", "W")
global savedSounds    := IniRead(configPath, "Settings", "PlaySounds", "1")
global savedAutoReset := IniRead(configPath, "Settings", "AutoRestart", "0")
global savedLicense   := IniRead(configPath, "Settings", "LicenseKey", "")

global running := false
global state := "idle"
global phaseStart := 0
global selectedKey := "W"
global holdTime := 480000
global pauseTime := 2000

; --- GUI Elemente global machen ---
global gui1, txtHoldKey, btnBind, timeDropdown, statusText, timerText, progress
global hkStartCtrl, hkStopCtrl, chkSounds, chkAutoReset
global loginGui, txtLicense, btnLogin

; =================================================================
; 2. SCRIPT START-PUNKT
; =================================================================
ShowLogin()
return 

; =================================================================
; 3. LOGIN GUI & ECHTE KEYAUTH LOGIK
; =================================================================
ShowLogin() {
    global loginGui, txtLicense, btnLogin, savedLicense
    loginGui := Gui("+AlwaysOnTop -MaximizeBox", "Forza Pro | Auth")
    loginGui.BackColor := "0A0A0A"
    loginGui.SetFont("s10 cFFFFFF", "Segoe UI")
    
    loginGui.SetFont("s14 w800 cBB86FC")
    loginGui.AddText("x20 y15 w260 Center BackgroundTrans", "🔐 SYSTEM LOGIN")
    
    loginGui.SetFont("s9 w400 cFFFFFF")
    loginGui.AddText("x20 y50 w260 Center", "Bitte Lizenzschlüssel eingeben:")
    
    txtLicense := loginGui.AddEdit("x20 y75 w260 h25 Background1A1A1A c00FF99 Center", savedLicense)
    
    btnLogin := loginGui.AddButton("x20 y115 w260 h35 +Default", "VERBINDEN")
    btnLogin.OnEvent("Click", CheckLicense)
    loginGui.Show("w300 h170")
}

CheckLicense(*) {
    global txtLicense, btnLogin, loginGui, authed, configPath
    global AppName, OwnerID, Version, HWID

    keyEingabe := txtLicense.Value
    if (keyEingabe = "") {
        MsgBox("Bitte Key eingeben!", "Fehler", "IconX")
        return
    }

    btnLogin.Text := "Authentifiziere..."
    btnLogin.Enabled := false

    loginErfolgreich := false
    fehlermeldung := ""

    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", "https://keyauth.win/api/1.2/", true)
        whr.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        whr.Send("type=init&name=" AppName "&ownerid=" OwnerID "&version=" Version)
        whr.WaitForResponse(5)
        resInit := whr.ResponseText
        
        if RegExMatch(resInit, '"sessionid":"([^"]+)"', &matchSession) {
            sessionID := matchSession[1]
            whr.Open("POST", "https://keyauth.win/api/1.2/", true)
            whr.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded")
            whr.Send("type=license&key=" keyEingabe "&hwid=" HWID "&sessionid=" sessionID "&name=" AppName "&ownerid=" OwnerID)
            whr.WaitForResponse(5)
            resLicense := whr.ResponseText
            
            if RegExMatch(resLicense, '"success":true') {
                loginErfolgreich := true
            } else {
                fehlermeldung := "Falscher oder abgelaufener Key!"
                if RegExMatch(resLicense, '"message":"([^"]+)"', &matchMsg)
                    fehlermeldung := matchMsg[1]
            }
        } else {
            fehlermeldung := "Konnte keine Server-Session aufbauen."
        }
    } catch {
        fehlermeldung := "Keine Internetverbindung oder Server offline!"
    }

    if (loginErfolgreich) {
        IniWrite(keyEingabe, configPath, "Settings", "LicenseKey")
        loginGui.Destroy() 
        authed := true
        StarteHauptBot()   
    } else {
        MsgBox("Login fehlgeschlagen:`n" fehlermeldung, "Zugriff verweigert", "IconX")
        btnLogin.Text := "VERBINDEN"
        btnLogin.Enabled := true
    }
}

; =================================================================
; 4. HAUPT-BOT GUI (PRO GAMING DESIGN)
; =================================================================
StarteHauptBot() {
    global 

    CheckForUpdates()

    gui1 := Gui("+AlwaysOnTop -MaximizeBox", "FORZA PRO AFK LOOP")
    gui1.BackColor := "0A0A0A" 
    gui1.SetFont("s10 cFFFFFF", "Segoe UI")
    gui1.OnEvent("Close", AutoSaveAndExit)

    ; --- HEADER BEREICH ---
    gui1.SetFont("s18 w800 cBB86FC") 
    gui1.AddText("x20 y12 w200 BackgroundTrans", "FORZA PRO")
    gui1.SetFont("s9 w400 c888888") 
    gui1.AddText("x22 y38 w200 BackgroundTrans", "AUTOMATION SYSTEM v" CURRENT_VERSION)
    
    ; Discord Button
    gui1.SetFont("s9 w700 cFFFFFF")
    btnDc := gui1.AddButton("x260 y15 w105 h35", "💬 DISCORD")
    btnDc.OnEvent("Click", (*) => Run(discordLink))
    
    ; Feine Trennlinie
    gui1.AddText("x15 y65 w350 h2 Background222222")

    ; --- TABS ---
    gui1.SetFont("s10 w400")
    tabs := gui1.AddTab3("x15 y75 w355 h350 Background0A0A0A", ["🎮 Dashboard", "📍 Strecken", "⚙️ Optionen"])

    ; ================= TAB 1: DASHBOARD =================
    tabs.UseTab(1)
    
    ; GRUPPE: STEUERUNG
    gui1.SetFont("s9 w700 cBB86FC")
    gui1.AddGroupBox("x25 y110 w335 h90 cBB86FC", " STEUERUNG ")
    
    gui1.SetFont("s10 w400 cFFFFFF")
    gui1.AddText("x40 y135 w100 h25 +0x200 BackgroundTrans", "Gas-Taste:")
    txtHoldKey := gui1.AddEdit("x140 y135 w90 h25 ReadOnly Background1A1A1A c00FF99 Center", savedKey)
    btnBind := gui1.AddButton("x240 y135 w100 h25", "Ändern")
    btnBind.OnEvent("Click", RecordHoldKey)

    gui1.AddText("x40 y165 w100 h25 +0x200 BackgroundTrans", "Timer-Limit:")
    timeDropdown := gui1.AddDropDownList("x140 y165 w200 Choose4 Background1A1A1A c000000", ["2 Minuten","3 Minuten","4 Minuten","5 Minuten","6 Minuten","7 Minuten","8 Minuten","10 Minuten","15 Minuten"])
    
    ; GRUPPE: LIVE STATUS
    gui1.SetFont("s9 w700 cBB86FC")
    gui1.AddGroupBox("x25 y210 w335 h140 cBB86FC", " LIVE STATUS ")

    gui1.SetFont("s12 w800 cFF3333")
    statusText := gui1.AddText("x35 y235 w315 Center BackgroundTrans", "🔴 INAKTIV")

    gui1.SetFont("s24 w800 c00FF99")
    timerText := gui1.AddText("x35 y260 w315 Center BackgroundTrans", "00:00")
    
    gui1.SetFont("s10 w400")
    progress := gui1.AddProgress("x40 y305 w305 h6 cBB86FC Background222222", 0) 

    ; KONTROLL-BUTTONS UNTEN
    btnStart := gui1.AddButton("x25 y365 w160 h40 +Default", "▶ START SESSION")
    btnStop := gui1.AddButton("x200 y365 w160 h40", "⏹ STOP SESSION")
    btnStart.OnEvent("Click", Start)
    btnStop.OnEvent("Click", Stop)

    ; ================= TAB 2: STRECKEN =================
    tabs.UseTab(2)
    gui1.SetFont("s11 w700 cBB86FC")
    gui1.AddText("x35 y115 w310 BackgroundTrans", "Verfügbare Map-Codes:")
    gui1.SetFont("s10 cFFFFFF w400")

    yPos := 145
    for index, mapObj in staticMaps {
        if (index > 4)
            break
        
        gui1.AddGroupBox("x25 y" yPos-15 " w335 h65 c444444", "") 
        gui1.SetFont("s10 w700 cFFFFFF")
        gui1.AddText("x40 y" yPos " w200 BackgroundTrans", mapObj.Name)
        gui1.SetFont("s9 w400 c888888")
        gui1.AddText("x40 y" (yPos+20) " w200 BackgroundTrans", "Code: " mapObj.Code)
        
        btn := gui1.AddButton("x260 y" (yPos+5) " w85 h30", "Kopieren")
        btn.OnEvent("Click", CreateCopyFunc(index))
        yPos += 75
    }

    ; ================= TAB 3: OPTIONEN =================
    tabs.UseTab(3)
    
    gui1.SetFont("s9 w700 cBB86FC")
    gui1.AddGroupBox("x25 y110 w335 h90 cBB86FC", " TASTATUR-HOTKEYS ")
    gui1.SetFont("s10 w400 cFFFFFF")

    gui1.AddText("x40 y135 w100 h25 +0x200 BackgroundTrans", "Start-Taste:")
    hkStartCtrl := gui1.AddHotkey("x140 y135 w200 h25", savedStartHK)

    gui1.AddText("x40 y165 w100 h25 +0x200 BackgroundTrans", "Stop-Taste:")
    hkStopCtrl := gui1.AddHotkey("x140 y165 w200 h25", savedStopHK)

    gui1.SetFont("s9 w700 cBB86FC")
    gui1.AddGroupBox("x25 y215 w335 h85 cBB86FC", " MODUS & SOUNDS ")
    gui1.SetFont("s10 w400 cFFFFFF")

    chkSounds := gui1.AddCheckbox("x40 y240 w300 h20 Checked" savedSounds " Background0A0A0A", "Akustische Signale (Beeps)")
    chkAutoReset := gui1.AddCheckbox("x40 y265 w300 h20 Checked" savedAutoReset " Background0A0A0A", "Auto-Restart Wächter nutzen")

    btnSave := gui1.AddButton("x25 y365 w335 h40", "💾 EINSTELLUNGEN SPEICHERN")
    btnSave.OnEvent("Click", SaveSettings)

    ; --- FUSSZEILE ---
    tabs.UseTab()
    gui1.SetFont("s8 c444444")
    gui1.AddText("x20 y435 w345 Center BackgroundTrans", "Lennartsays Pro Edition © 2026 | Powered by KeyAuth")

    gui1.Show("w385 h465") 

    try Hotkey(savedStartHK, Start)
    try Hotkey(savedStopHK, Stop)
}

; =================================================================
; 5. BOT FUNKTIONEN
; =================================================================

CheckForUpdates() {
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", INTERNET_VERSION_URL, true)
        whr.Send()
        whr.WaitForResponse(3)
        latestVersion := Trim(whr.ResponseText)
        
        ; Wenn die Internet-Version größer ist als die lokale...
        if (latestVersion != "" && latestVersion > CURRENT_VERSION) {
            
            ; Zwangsmeldung (nur OK-Button)
            MsgBox("Ein wichtiges Update (" latestVersion ") ist verfügbar und ZWINGEND erforderlich!`n`nDeine Version: " CURRENT_VERSION "`n`nDas Skript leitet dich nun zum Download weiter und schließt sich.", "Pflicht-Update!", "Iconi")
            
            ; Öffnet den Link und killt das Programm sofort
            Run(DOWNLOAD_URL)
            ExitApp() 
        }
    }
}

CreateCopyFunc(index) {
    return (*) => (
        A_Clipboard := staticMaps[index].Code,
        ToolTip("'" staticMaps[index].Name "' kopiert!"),
        SetTimer(() => ToolTip(), -1500)
    )
}

RecordHoldKey(*) {
    global txtHoldKey, btnBind
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
    btnBind.Text := "Ändern"
    btnBind.Enabled := true
}

SaveSettings(*) {
    global hkStartCtrl, hkStopCtrl, txtHoldKey, chkSounds, chkAutoReset
    try {
        IniWrite(hkStartCtrl.Value, configPath, "Settings", "StartHotkey")
        IniWrite(hkStopCtrl.Value, configPath, "Settings", "StopHotkey")
        IniWrite(txtHoldKey.Text, configPath, "Settings", "HoldKey")
        IniWrite(chkSounds.Value, configPath, "Settings", "PlaySounds")
        IniWrite(chkAutoReset.Value, configPath, "Settings", "AutoRestart")
        
        global savedStartHK, savedStopHK
        try Hotkey(savedStartHK, "Off")
        try Hotkey(savedStopHK, "Off")
        
        savedStartHK := hkStartCtrl.Value
        savedStopHK := hkStopCtrl.Value
        
        try Hotkey(savedStartHK, Start)
        try Hotkey(savedStopHK, Stop)

        MsgBox("Einstellungen erfolgreich gespeichert!", "Config", "Iconi T2")
    } catch Error as err {
        MsgBox("Fehler beim Speichern!`n`nDetails: " err.Message, "Fehler", "IconX")
    }
}

AutoSaveAndExit(*) {
    global hkStartCtrl, hkStopCtrl, txtHoldKey, chkSounds, chkAutoReset
    try {
        IniWrite(hkStartCtrl.Value, configPath, "Settings", "StartHotkey")
        IniWrite(hkStopCtrl.Value, configPath, "Settings", "StopHotkey")
        IniWrite(txtHoldKey.Text, configPath, "Settings", "HoldKey")
        IniWrite(chkSounds.Value, configPath, "Settings", "PlaySounds")
        IniWrite(chkAutoReset.Value, configPath, "Settings", "AutoRestart")
    }
    ExitApp()
}

Start(*) {
    global running, state, phaseStart, selectedKey, holdTime
    global txtHoldKey, chkSounds, timeDropdown, chkAutoReset, statusText

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
    
    statusText.SetFont("c00FF99") 
    if (chkAutoReset.Value)
        statusText.Text := "🟢 AUTOMODE AKTIV"
    else
        statusText.Text := "🟢 TIMER AKTIV"

    SendInput("{" selectedKey " down}")
    SetTimer(UpdateLoop, 100)
}

Stop(*) {
    global running, state, selectedKey
    global chkSounds, statusText, timerText, progress

    if (chkSounds.Value)
        SoundBeep(500, 200)

    running := false
    state := "idle"

    SendInput("{" selectedKey " up}")

    statusText.SetFont("cFF3333")
    statusText.Text := "🔴 INAKTIV"
    timerText.Text := "00:00"
    progress.Value := 0
}

UpdateLoop() {
    global running, state, phaseStart, holdTime, pauseTime, selectedKey
    global chkAutoReset, statusText, progress, timerText
    
    global tX1_1, tY1_1, targetColor1_1, tX1_2, tY1_2, targetColor1_2
    global tX2_1, tY2_1, targetColor2_1, tX2_2, tY2_2, targetColor2_2
    global tX3_1, tY3_1, targetColor3_1, tX3_2, tY3_2, targetColor3_2

    if !running
        return

    elapsed := A_TickCount - phaseStart

    if (chkAutoReset.Value) {
        if (state = "hold") {
            if (PixelGetColor(tX1_1, tY1_1) = targetColor1_1 && PixelGetColor(tX1_2, tY1_2) = targetColor1_2) {
                SendInput("{" selectedKey " up}")
                state := "wait_for_confirm"
                statusText.Text := "🏁 RENNEN ENDE"
                SendInput("{X}")
                Sleep(1200)
            }
            progress.Value := Mod(Floor(A_TickCount / 20), 100)
            timerText.Text := "SCANNING"
        }
        else if (state = "wait_for_confirm") {
            if (PixelGetColor(tX2_1, tY2_1) = targetColor2_1 && PixelGetColor(tX2_2, tY2_2) = targetColor2_2) {
                state := "wait_for_grid"
                statusText.Text := "🔄 RESTART..."
                SendInput("{Enter}")
                Sleep(2500)
            }
        }
        else if (state = "wait_for_grid") {
            if (PixelGetColor(tX3_1, tY3_1) = targetColor3_1 && PixelGetColor(tX3_2, tY3_2) = targetColor3_2) {
                statusText.Text := "🟢 VOLLGAS"
                SendInput("{Enter}")
                Sleep(3500)
                if !running
                    return
                SendInput("{" selectedKey " down}")
                state := "hold"
                phaseStart := A_TickCount
            }
            statusText.Text := "⏳ LÄDT..."
        }
        return
    }

    if (state = "hold") {
        remaining := holdTime - elapsed
        if (remaining <= 0) {
            SendInput("{" selectedKey " up}")
            state := "pause"
            phaseStart := A_TickCount
            statusText.SetFont("cFFFF00")
            statusText.Text := "🟡 PAUSE"
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
            statusText.SetFont("c00FF99")
            statusText.Text := "🟢 AKTIV"
            return
        }
        progress.Value := (elapsed / pauseTime) * 100
    }

    seconds := Floor(remaining / 1000)
    mins := Floor(seconds / 60)
    secs := Mod(seconds, 60)
    timerText.Text := Format("{:02}:{:02}", mins, secs)
}