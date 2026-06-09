#Requires AutoHotkey v2.0
SetWorkingDir(A_ScriptDir)

; 1. Load and parse the text file
Channels := Map()
DisplayList := []

if !FileExist("channel_list.txt") {
    MsgBox("Error: channel_list.txt not found.")
    ExitApp()
}

FileContent := FileRead("channel_list.txt")
Loop Parse, FileContent, "`n", "`r" {
    if (Trim(A_LoopField) = "")
        continue
    if RegExMatch(A_LoopField, '"(.+?)":\s*"(.+?)"', &Match) {
        Channels[Match[1]] := Match[2]
        DisplayList.Push(Match[1])
    }
}

if (DisplayList.Length = 0) {
    MsgBox("Error: No channels found in channel_list.txt")
    ExitApp()
}

; 2. Create the GUI
MyGui := Gui(, "Watch TV on VLC")
MyGui.SetFont("s10", "Segoe UI")

; Set fixed margins for easier centering
MyGui.MarginX := 20
MyGui.MarginY := 15

; --- TOP LABEL (Left Aligned) ---
MyGui.Add("Text", "w410", "Select a Channel/Category: ")

; --- DROPDOWN (Left Aligned items) ---
Choice := MyGui.Add("DropDownList", "vChannelSelect w410 Choose1", DisplayList)

; --- CENTERED BUTTONS ---
; Window width is 450px.
; Buttons total width: 100 + 10 (gap) + 100 = 210px.
; To center: (450 - 210) / 2 = 120.
PlayBtn := MyGui.Add("Button", "Default x120 y+20 w100 h32", "Watch")
PlayBtn.OnEvent("Click", LaunchVLC)

ExitBtn := MyGui.Add("Button", "x+10 w100 h32", "Close")
ExitBtn.OnEvent("Click", (*) => ExitApp())

; --- CENTERED CREDITS ---
MyGui.SetFont("s9")
; Because Link controls don't center well via styles, we position it manually.
; 'Made with <3 by: shawmik7' is roughly 150 pixels wide.
; (450 - 150) / 2 = 150
MyGui.Add("Link", "x150 y+20 w150 Center", 'Made with <3 by: <a href="https://github.com/shawmik7/">shawmik7</a>')

MyGui.Show("w450") ; Force the window to be 450px wide

; 3. The Play Logic
LaunchVLC(*) {
    SelectedName := Choice.Text
    StreamLink := Channels[SelectedName]
    
    VLC_Path := "C:\Program Files\VideoLAN\VLC\vlc.exe"
    VLC_Path_x86 := "C:\Program Files (x86)\VideoLAN\VLC\vlc.exe"
    
    FinalPath := ""
    if FileExist(VLC_Path)
        FinalPath := VLC_Path
    else if FileExist(VLC_Path_x86)
        FinalPath := VLC_Path_x86

    if (FinalPath != "") {
        Run('"' FinalPath '" "' StreamLink '"')
    } else {
        NotFound := Gui(, "VLC Not Found")
        NotFound.Add("Text",, "VLC Media Player is not installed. ")
        DLBtn := NotFound.Add("Button",, "Download VLC Player")
        DLBtn.OnEvent("Click", (*) => Run("https://www.videolan.org/vlc/"))
        CloseBtn := NotFound.Add("Button", "x+10", "Close")
        CloseBtn.OnEvent("Click", (*) => NotFound.Destroy())
        NotFound.Show()
    }
}
