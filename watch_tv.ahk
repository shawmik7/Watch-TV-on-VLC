#Requires AutoHotkey v2.0
SetWorkingDir(A_ScriptDir)

; --- 1. Load the main list ---
Channels := Map()
DisplayList := ["Favorites"] 
PendingRemove := false
PendingName := ""

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

; --- 2. Create the GUI ---
MyGui := Gui("+LastFound", "VLC TV Streamer")
MyGui.BackColor := "1A1A1A"  
MyGui.SetFont("s10 cWhite", "Segoe UI")
MyGui.MarginX := 25
MyGui.MarginY := 20

; --- Header Section ---
MyGui.SetFont("s14 w700")
MyGui.Add("Text", "w750 c1E90FF", "📺 VLC TV Streamer") 
MyGui.SetFont("s10 w400")

; --- LEFT COLUMN (Selection) ---
MyGui.Add("GroupBox", "x20 y60 w280 h395 c808080", " 1. Select a Category ") 
MainChoice := MyGui.Add("ListBox", "vMainSelect x30 y85 w260 r18 Background252525 cWhite Choose1", DisplayList)
MainChoice.OnEvent("Change", OnCategoryChange)

; --- RIGHT COLUMN (Channel List) ---
MyGui.SetFont("s10 w600")
ChLabel := MyGui.Add("Text", "x320 y60 w460 c1E90FF", "2. Available Channels: ")
MyGui.SetFont("s10 w400")
ChList := MyGui.Add("ListBox", "vChList x320 y85 w460 r18 Background252525 cWhite") 
ChList.OnEvent("DoubleClick", LaunchVLC)

; --- BOTTOM BUTTONS ---
PlayBtn := MyGui.Add("Button", "Default x320 y+20 w110 h40", "▶ Watch Now")
PlayBtn.OnEvent("Click", LaunchVLC)

OpenPlBtn := MyGui.Add("Button", "x+10 w110 h40", "📂 Open Playlist")
OpenPlBtn.OnEvent("Click", LaunchPlaylist)

FavBtn := MyGui.Add("Button", "x+10 w60 h40", "❤️") 
FavBtn.OnEvent("Click", ToggleFavorite)

ExitBtn := MyGui.Add("Button", "x+10 w110 h40", "✕ Close")
ExitBtn.OnEvent("Click", (*) => ExitApp())

; --- FOOTER (Credits) ---
MyGui.SetFont("s9")
MyGui.Add("Link", "x20 y465 w280", 'Made with ♥ by: <a href="https://github.com/shawmik7/">shawmik7</a>')

SubChannels := Map() 
MyGui.Show("w800 h510")

OnCategoryChange()

; --- 3. Parsing Logic ---
OnCategoryChange(*) {
    global PendingRemove := false
    ChList.Delete()
    SubChannels.Clear()

    if (MainChoice.Text = "Favorites") {
        if FileExist("favorites.txt") {
            FavContent := FileRead("favorites.txt")
            Names := []
            Loop Parse, FavContent, "`n", "`r" {
                if RegExMatch(A_LoopField, '"(.+?)":\s*"(.+?)"', &Match) {
                    SubChannels[Match[1]] := Match[2]
                    Names.Push(Match[1])
                }
            }
            if (Names.Length > 0) {
                ChList.Add(Names)
                ChLabel.Text := "❤ Favorite Channels (" Names.Length " available):"
            } else {
                ChList.Add(["No favorites added yet..."])
                ChLabel.Text := "Favorites Empty"
            }
        } else {
            ChList.Add(["No favorites added yet..."])
            ChLabel.Text := "Favorites Empty"
        }
        return
    }

    SelectedURL := Channels[MainChoice.Text]
    if !RegExMatch(SelectedURL, "i)\.m3u8?$") {
        ChList.Add([MainChoice.Text])
        SubChannels[MainChoice.Text] := SelectedURL
        ChLabel.Text := "2. Available Channels (1 available): "
        return
    }

    try {
        ChLabel.Text := "⌛ Fetching Channels... "
        Http := ComObject("WinHttp.WinHttpRequest.5.1")
        Http.Open("GET", SelectedURL, true)
        Http.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        Http.Send()
        
        if (Http.WaitForResponse(5)) {
            M3UContent := Http.ResponseText
            Names := []
            currentName := ""

            Loop Parse, M3UContent, "`n", "`r" {
                line := Trim(A_LoopField)
                if RegExMatch(line, 'i)^#EXTINF:.*?,(.*)', &m) {
                    currentName := Trim(m[1])
                } else if RegExMatch(line, 'i)^https?://', &u) && (currentName != "") {
                    SubChannels[currentName] := line
                    Names.Push(currentName)
                    currentName := "" 
                }
            }
            
            if (Names.Length > 0) {
                ChList.Add(Names)
                ChLabel.Text := "✔ Available Channels (" Names.Length " available): "
            } else {
                ChList.Add(["No channels found in playlist... "])
                ChLabel.Text := "No Available Channels... "
            }
        }
    } catch {
        ChList.Add(["Failed to connect to playlist... "])
        ChLabel.Text := "❌ Error Fetching Channels... "
    }
}

; --- 4. Logic Functions ---
LaunchVLC(*) {
    if (ChList.Text = "" || ChList.Text ~= "No channels|Failed to connect|Possible Errors|Please check|No favorites")
        return
    FinalURL := SubChannels[ChList.Text]
    VLC_Path := "C:\Program Files\VideoLAN\VLC\vlc.exe"
    VLC_Path_x86 := "C:\Program Files (x86)\VideoLAN\VLC\vlc.exe"
    FinalPath := FileExist(VLC_Path) ? VLC_Path : (FileExist(VLC_Path_x86) ? VLC_Path_x86 : "")
    if (FinalPath != "")
        Run('"' FinalPath '" "' FinalURL '"')
    else
        VlcNotFound()
}

LaunchPlaylist(*) {
    if (MainChoice.Text = "" || MainChoice.Text = "Favorites")
        return
    FinalURL := Channels[MainChoice.Text]
    VLC_Path := "C:\Program Files\VideoLAN\VLC\vlc.exe"
    VLC_Path_x86 := "C:\Program Files (x86)\VideoLAN\VLC\vlc.exe"
    FinalPath := FileExist(VLC_Path) ? VLC_Path : (FileExist(VLC_Path_x86) ? VLC_Path_x86 : "")
    if (FinalPath != "")
        Run('"' FinalPath '" "' FinalURL '"')
    else
        VlcNotFound()
}

ToggleFavorite(*) {
    global PendingRemove, PendingName
    if (ChList.Text = "" || ChList.Text ~= "No channels|Failed to connect|Possible Errors|Please check|No favorites")
        return

    ; REMOVE LOGIC
    if (MainChoice.Text = "Favorites") {
        if (PendingRemove && PendingName == ChList.Text) {
            SetTimer(ResetChLabel, 0) ; Stop the 3s confirmation timer
            
            NameToRemove := ChList.Text
            NewFileContent := ""
            Loop Parse, FileRead("favorites.txt"), "`n", "`r" {
                if (A_LoopField != "" && !RegExMatch(A_LoopField, '^"' RegExEscape(NameToRemove) '":'))
                    NewFileContent .= A_LoopField "`n"
            }
            FileDelete("favorites.txt")
            if (Trim(NewFileContent) != "")
                FileAppend(NewFileContent, "favorites.txt")
            
            ChLabel.Text := "❌ " NameToRemove " removed from favorites"
            PendingRemove := false
            SetTimer(OnCategoryChange, -1000) ; Refresh after 1s
            return
        } else {
            PendingRemove := true
            PendingName := ChList.Text
            ChLabel.Text := "⚠️ Press again to remove from favorites..."
            SetTimer(ResetChLabel, -3000)
            return
        }
    }

    ; ADD LOGIC
    Name := ChList.Text
    URL := SubChannels[Name]
    FileAppend('"' Name '": "' URL '"' "`n", "favorites.txt")
    OriginalText := ChLabel.Text
    ChLabel.Text := "💖 " Name " added to favorites!"
    SetTimer(() => ChLabel.Text := OriginalText, -2000)
}

ResetChLabel() {
    global PendingRemove
    PendingRemove := false
    OnCategoryChange()
}

RegExEscape(Str) {
    return RegExReplace(Str, "([\\.*?+\[\{|\(\)\^$])", "\$1")
}

VlcNotFound() {
    NotFound := Gui("+AlwaysOnTop", "VLC Not Found")
    NotFound.BackColor := "1A1A1A"
    NotFound.SetFont("cWhite")
    NotFound.Add("Text",, "VLC Media Player is not installed. ")
    DLBtn := NotFound.Add("Button",, "Download VLC Player")
    DLBtn.OnEvent("Click", (*) => Run("https://www.videolan.org/vlc/"))
    CloseBtn := NotFound.Add("Button", "x+10", "Close")
    CloseBtn.OnEvent("Click", (*) => NotFound.Destroy())
    NotFound.Show()
}
