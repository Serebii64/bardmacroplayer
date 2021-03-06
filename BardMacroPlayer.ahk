#NoTrayIcon

SendMode Event

; default note keys
global DefaultNoteKeys := {"C":"q","C#":"2","D":"w","Eb":"3","E":"e","F":"r","F#":"5","G":"t","G#":"6","A":"y","Bb":"7","B":"u","C+1":"i"}
global NoteKeys := {}
global BardRange := ["C-1", "C#-1", "D-1", "Eb-1", "E-1", "F-1", "F#-1", "G-1", "G#-1", "A-1", "Bb-1", "B-1", "C", "C#", "D", "Eb", "E", "F", "F#", "G", "G#", "A", "Bb", "B", "C+1", "C#+1", "D+1", "Eb+1", "E+1", "F+1", "F#+1", "G+1", "G#+1", "A+1", "Bb+1", "B+1", "C+2"]
global OctaveShift := 0
global SpeedShift := 10

global curVersion = 1.4
global Version := Format("v{:g}", curVersion)
global MidiInModule
global MainHwnd

global keybindFile := ""
global playerFiles := []
GetShortFile(i) {
	filename := playerFiles[i]
	track := -1
	if(InStr(filename, ".mid ")) {
		pos := InStr(filename, A_Space, false, 0, 1)
		len := StrLen(filename)+1
		track := SubStr(filename, pos+1, len - pos)
		filename := SubStr(filename, 1, pos-1)
	}
	SplitPath, filename,,,,filename
	if(track > 0) {
		filename := Format("[T{:d}] ", track) . filename
	}
	filename := Format("{:03d} {:s}", i, filename)
	return filename
}

global currentPlayer := 0
global mainWindowState := false

global settings := {ExitConfirmation: 1, HideHotkey: "Insert", LastKeybind: "", ShortcutStop: "F6", ShortcutPlay: "F7"}
ReadSettings() {
	for i, e in settings {
		IniRead, tempVal, BardMacroPlayer.ini, App, % i, % e
		if(tempVal != "ERROR") {
			settings[i] := tempVal
		}
	}
}

WriteSettings() {
	for i, e in settings {
		IniWrite, % e, BardMacroPlayer.ini, App, % i
	}
}

global fileSelectionOpen

global SongProgressBar
global FileSelectionControl
global FileLoadedControl
global StopControl
global PlayPauseControl
global LayoutControl
global OctaveSlider
global SpeedSlider

global trayIcon := "bard.ico"
ICON [trayIcon]
IfExist, %trayIcon%
	Menu, Tray, Icon, %trayIcon%

#Include configLoader.ahk
#Include notePlayer.ahk
#Include JSON.ahk

ShowParsedKeyboard() {
	WinGetPos, mainWindowX, mainWindowY, mainWindowWidth, mainWindowHeight, ahk_id %MainHwnd%
	ww := 180
	hh := 110
	xx := mainWindowX + mainWindowWidth/2 - ww/2
	yy := mainWindowY + mainWindowHeight/2 - hh/2
	
	sharps := [NoteKeys["C#"].key, NoteKeys["Eb"].key, NoteKeys["F#"].key, NoteKeys["G#"].key, NoteKeys["Bb"].key]
	keys := [NoteKeys["C"].key, NoteKeys["D"].key, NoteKeys["E"].key, NoteKeys["F"].key, NoteKeys["G"].key, NoteKeys["A"].key, NoteKeys["B"].key]
	
	Gui, KeyboardWindow: New, +ToolWindow +AlwaysOnTop
	
	Gui, Font, s8, Consolas
	
	Gui, Add, DropDownList, w%ww% x0 ym-3 vLayoutControl gSelectLayout, Automatic||
	for i, e in keybindFiles {
		found := RegExMatch(e, "FFXIV_CHR[A-Z0-9]+", ffxivChar)
		if(found) {
			if(ffxivChar == settings["LastKeybind"]) {
				ffxivChar := ffxivChar . "||"
			}
			GuiControl,, LayoutControl, %ffxivChar%
		}
	}
	row1 := 50
	row2 := (row1 + 20)
	
	Gui, Add, Text, x20, ** Parsed piano keys **
	Gui, Add, Button, Disabled x20 y%row1% w20,  % sharps[1]
	Gui, Add, Button, Disabled x40 y%row1% w20,  % sharps[2]
	Gui, Add, Button, Disabled x80 y%row1% w20,  % sharps[3]
	Gui, Add, Button, Disabled x100 y%row1% w20, % sharps[4]
	Gui, Add, Button, Disabled x120 y%row1% w20, % sharps[5]
	
	Gui, Add, Button, Disabled x10 y%row2% w20,  % keys[1]
	Gui, Add, Button, Disabled x30 y%row2% w20,  % keys[2]
	Gui, Add, Button, Disabled x50 y%row2% w20,  % keys[3]
	Gui, Add, Button, Disabled x70 y%row2% w20,  % keys[4]
	Gui, Add, Button, Disabled x90 y%row2% w20,  % keys[5]
	Gui, Add, Button, Disabled x110 y%row2% w20, % keys[6]
	Gui, Add, Button, Disabled x130 y%row2% w20, % keys[7]
	
	Gui, KeyboardWindow: Show, x%xx% y%yy% w%ww% h%hh%, Keys
}

SelectLayout() {
	Gui, Submit, NoHide
	Gui, KeyboardWindow: Destroy
	
	keybindFile := LayoutControl
	if(keybindFile == "Automatic"){
		keybindFile := ""
	}
	
	settings["LastKeybind"] := keybindFile
	WriteSettings()
	ReadKeyConfig()
	
	ShowParsedKeyboard()
}

ToggleMainWindow() {

	Gui PlayWindow:+LastFoundExist
	if(!WinExist()) {
		MakeMainWindow()
	}
	UpdateMainWindow()

	if(mainWindowState) {
		Gui, PlayWindow: Hide
		Gui, ExitWindow: Hide
		mainWindowState := false
	} else {
		Gui, PlayWindow: Show, NoActivate
		mainWindowState := true
	}
}

MakeMainWindow() {
	global MainHwnd
	
	playWidth := 250
	playHeight := 115
	
	sliderWidth := 75
	
	Gui, PlayWindow: New, +hwndMainHwnd +AlwaysOnTop
	Gui, PlayWindow:+Owner +OwnDialogs
	Gui, PlayWindow: Show, Hide w%playWidth% h%playHeight%, FFXIV Bard Macro Player %Version%
	
	if(WinExist("ahk_class FFXIVGAME") != 0x00) {
		WinGetPos, ffxivX, ffxivY, ffxivWidth, ffxivHeight, ahk_class FFXIVGAME
		mainWindowX := (ffxivX + ffxivWidth - playWidth * 2)
		mainWindowY := (ffxivY + ffxivHeight / 2 - playHeight * 2)
		Gui, PlayWindow: Show, Hide x%mainWindowX% y%mainWindowY%
	}
	Gui, PlayWindow: Show
	
	Gui, Add, DropDownList, w%playWidth% r20 ym-3 xm-20 x0 vFileSelectionControl gLoadMusicFile AltSubmit, ||
	
	Gui, Font, s18, Webdings
	Gui, Add, Button, Hide xs Section w30 h30 vStopControl gStopSubmit, <
	Gui, Add, Button, Hide ys w30 h30 vPlayPauseControl gPausePlaySubmit, `;
	Gui, Add, Slider, xs Thick10 vOctaveSlider Range-4-4 w%sliderWidth% h10, 0
	Gui, Add, Slider, xs Thick10 vSpeedSlider Range0-20 w%sliderWidth% h10, 10
	
	Gui, Font, s8 w400, Segoe UI
	Gui, Add, Text, Section ys w180 h45 vFileLoadedControl, [ Bard Macro Player %Version% ]`n by Freya Katva @ Ultros
	Gui, Add, Progress, xs w150 h10 c222222 BackgroundCCCCCC vSongProgressBar
	
	OnMessage(0x111, "MainWindowCommand")
	OnMessage(0x203, "MainWindowDoubleClick")
	OnMessage(0x200, "MainWindowMove")
	OnMessage(0x201, "MainWindowDown")
	OnMessage(0x202, "MainWindowUp")
	OnMessage(0x20A, "MainWindowWheel")
	OnMessage(0x47 , "MainWindowPos")
	
	Menu, AppMenu, Add, Parsed keys, ShowParsedKeyboard
	Menu, AppMenu, Add, Project site, LaunchGithub
	Menu, AppMenu, Add, Exit, ExitApplication
	Menu, MainMenu, Add, App, :AppMenu
	Gui, Menu, MainMenu
}

LaunchGithub() {
	Run https://github.com/parulina/bardmacroplayer
}
LaunchGithubReleases() {
	Run https://github.com/parulina/bardmacroplayer/releases
	GuiControl, +g, FileLoadedControl, 0
	Gui, Font, cBlack
	GuiControl, Font, FileLoadedControl
}
SetOctaveSlider() {
	if(OctaveShift < -4) {
		OctaveShift := -4
	} else if(OctaveShift > 4) {
		OctaveShift := 4
	}
	if(currentPlayer) {
		currentPlayer.octaveShift := OctaveShift
	}
}
SetSpeedSlider() {
	if(SpeedShift < 1) {
		SpeedShift := 1
	} else if(SpeedShift > 20) {
		SpeedShift := 20
	}
	if(currentPlayer) {
		currentPlayer.speedShift := SpeedShift / 10
	}
}
StopSubmit() {
	Gui, Submit, NoHide
	SetTimer, UpdateProgressBar, Off
	if(currentPlayer) {
		LoadFile(currentPlayer.filename, currentPlayer.trackIndex)
	}
	UpdateMainWindow()
}
PausePlaySubmit() {
	Gui, Submit, NoHide
	if(currentPlayer) {
		if(currentPlayer.IsPlaying()) {
			currentPlayer.Pause()
			SetTimer, UpdateProgressBar, Off
		} else {
			currentPlayer.Play()
			WinActivate, ahk_class FFXIVGAME
			SetTimer, UpdateProgressBar, 100
		}
	}
	UpdateMainWindow()
}

PlayWindowGuiEscape() {
	PlayWindowGuiClose()
}
PlayWindowGuiClose() {
	if(settings["ExitConfirmation"]) {
		WinGetPos, mainWindowX, mainWindowY, mainWindowWidth, mainWindowHeight, ahk_id %MainHwnd%
		ww := 90
		hh := 50
		xx := mainWindowX + mainWindowWidth/2 - ww/2
		yy := mainWindowY + mainWindowHeight/2 - hh/2
		
		Gui, ExitWindow: Destroy
		Gui, ExitWindow: New, +OwnerPlayWindow +AlwaysOnTop +ToolWindow
		Gui, ExitWindow: Show, x%xx% y%yy% w%ww% h%hh%, Exit
		Gui, Add, Text, Section, Exit player?
		Gui, Add, Button, xs Section Default gExitApplication, Yes
		Gui, Add, Button, ys gReturnApplication, No
		Gui, PlayWindow: +Disabled
		return 1
		
	} else {
		ExitApplication()
	}
}

ExitWindowGuiEscape() {
	ExitWindowGuiClose()
}
ExitWindowGuiClose() {
	ReturnApplication()
}

ExitApplication() {
	ExitApp
}

ReturnApplication() {
	Gui, PlayWindow: -Disabled
	Gui, ExitWindow: Destroy
}

SetPlayButtonsVisibility(visible) {
	v := (visible ? 1 : 0)
	GuiControl, PlayWindow:Show%v%, StopControl
	GuiControl, PlayWindow:Show%v%, PlayPauseControl
}

SetPlayPauseButton(play) {
	if(play) {
		GuiControl,PlayWindow:, PlayPauseControl, 4
	} else {
		GuiControl,PlayWindow:, PlayPauseControl, `;
	}
}

UpdateMidiDevices() {
	if(MidiInModule) {
		curDev := DllCall("midi_in.dll\getCurDevID", Int)
		Menu, MidiMenu, Add, Empty, MidiMenuSelect
		Menu, MidiMenu, Delete
		Loop, % DllCall("midi_in.dll\getNumDevs") {
			dev := A_Index-1
			item := Format("opt{:d}", dev)
			name := Format("[{:d}] {:s}", dev, DllCall("midi_in.dll\getDevName", Int,dev, Str))
			
			Menu, MidiMenu, Add, % item, MidiMenuSelect, +Radio
			if(dev == curDev) {
				Menu, MidiMenu, Check, % item
			}
			Menu, MidiMenu, Rename, % item, % name
		}
		Menu, MainMenu, Add, Midi devices, :MidiMenu
	}
}

MainWindowCommand(wParam, lParam) {
	l := (wParam >> 16)
	if(l == 7) {
		fileSelectionOpen := true
	}
	if(l == 8) {
		fileSelectionOpen := false
	}
}
MainWindowDoubleClick(wParam, lParam) {
	if(A_GuiControl == "FileSelectionControl") {
		if(fileSelectionOpen) {
			return 0
		}
		MainWindowDown(wParam, lParam)
	}
}
MainWindowMove(wParam, lParam, msg := 0, hwnd := 0) {
	MouseGetPos,,,, hoverControl
	WinGetPos, mainWindowX, mainWindowY, mainWindowWidth, mainWindowHeight, ahk_id %MainHwnd%
	ControlGetPos, progX, progY, progWidth, progHeight, %hoverControl%, ahk_id %MainHwnd%
	tx := mainWindowX + progX + progWidth
	ty := mainWindowY + progY - 5
	
	CoordMode, ToolTip, Screen
	if(A_GuiControl == "OctaveSlider") {
		ToolTip, Octave shift: [%OctaveShift%], tx, ty, 3
		
	} else if(A_GuiControl == "SpeedSlider") {
		ss := (SpeedShift * 10)
		ToolTip, Speed shift: [%ss%`%], tx, ty, 3
		
	} else if(A_GuiControl == "SongProgressBar") {
		tx += -progWidth + 30
		ty += -20
		ToolTip, Song progress, tx, ty, 3
		
	} else {
		ToolTip,,,, 3
	}
}
MainWindowDown(wParam, lParam, msg := 0, hwnd := 0) {
	ToolTip,,,, 1
	if(A_GuiControl) {
		ctl := %A_GuiControl%
	}
	if(A_GuiControl == "SongProgressBar") {
		ControlGetPos, progX, progY, progWidth, progHeight, %ctl%, ahk_id %hwnd%
		MouseGetPos, mouseX, mouseY
		if(mouseX > progX && mouseX < progX+progWidth) {
			if(mouseY > progY && mouseY < progY+progHeight) {
				perc := (mouseX - progX) / progWidth
				currentPlayer.SetProgress(perc)
				UpdateProgressBar()
			}
		}
	}
	if(A_GuiControl == "FileSelectionControl" && !fileSelectionOpen) {
		GuiControl,, FileSelectionControl, Loading...||
		fileSelectionOpen := true
		UpdateFileList()
		
		VarSetCapacity(COMBOBOXINFO, (cbCOMBOBOXINFO := 40 + (A_PtrSize * 3)), 0)
		NumPut(cbCOMBOBOXINFO, COMBOBOXINFO, 0, "UInt")
		if (DllCall("GetComboBoxInfo", "Ptr", hwnd, "Ptr", &COMBOBOXINFO)) {
			hwndList := NumGet(COMBOBOXINFO, cbCOMBOBOXINFO - A_PtrSize, "Ptr")
			PostMessage, 0x202, % wParam, % lParam,, ahk_id %hwndList%
			; Focus the list itself. This is because of possible large delays with updating file list.
		}
	}
}
MainWindowUp(wParam, lParam, msg := 0, hwnd := 0) {
	if(A_GuiControl == "OctaveSlider") {
		Gui, Submit, NoHide
		OctaveShift := OctaveSlider
	}
	if(A_GuiControl == "SpeedSlider") {
		Gui, Submit, NoHide
		SpeedShift := SpeedSlider
	}
}
MainWindowWheel(wParam, lParam, msg := 0, hwnd := 0) {
global OctaveShift
global SpeedShift
	wh := (wParam >> 16)
	move := 1 * (wh < 0 ? 1 : -1)
	
	if(A_GuiControl == "OctaveSlider") {
		GuiControl,, OctaveSlider, +move
		Gui, Submit, NoHide
		
		OctaveShift := OctaveSlider + move
		SetOctaveSlider()
		
		MainWindowMove(wParam, lParam)
		return
		
	} else if(A_GuiControl == "SpeedSlider") {
		GuiControl,, SpeedSlider, +move
		Gui, Submit, NoHide
		
		SpeedShift := SpeedSlider + move
		SetSpeedSlider()
		
		MainWindowMove(wParam, lParam)
		return
	}
}

UpdateProgressBar() {
	if(currentPlayer) {
		prog := Floor(currentPlayer.GetProgress() * 100)
		GuiControl,PlayWindow:, SongProgressBar, % prog
	} else {
		GuiControl,PlayWindow:, SongProgressBar, 0
	}
}

UpdateSelectedFile() {
	text := currentPlayer.filename
	if(currentPlayer.trackIndex > 0) {
		text .= " "currentPlayer.trackIndex
	}
	index := -1
	for i, e in playerFiles {
		if(e == text) {
			index := i
			break
		}
	}
	if(index != -1) {
		GuiControl, ChooseString, FileSelectionControl, % GetShortFile(i)
	}
}

UpdateMainWindow() {
	UpdateProgressBar()
	SetPlayButtonsVisibility((currentPlayer != 0))
	if(currentPlayer) {
		text := ""
		UpdateSelectedFile()
		if(currentPlayer.trackIndex > 0) {
			text .= Format("Track {:d}`n", currentPlayer.trackIndex)
		}
		if(currentPlayer.GetNumNotes() > 1) {
			text .= Format("Note count: {:d}`n", currentPlayer.GetNumNotes()-1)
		}
		GuiControl,, FileLoadedControl, % text
		SetPlayPauseButton(!currentPlayer.playing)
	}
}

LoadMusicFile() {
	Gui, Submit, NoHide
	
	filename := playerFiles[FileSelectionControl]
	track := 1
	if(InStr(filename, ".mid ")) {
		pos := InStr(filename, A_Space, false, 0, 1)
		len := StrLen(filename)+1
		track := SubStr(filename, pos+1, len - pos)
		filename := SubStr(filename, 1, pos-1)
	}
	LoadFile(filename, track)
}


UpdateFileList() {
	playerFiles := []
	Loop, songs\* {
		file := A_LoopFileFullPath
		if(A_LoopFileExt == "mid") {
			midi := new MidiFile(file, false, false)
			if(midi.midiNumTracks > 1) {
				Loop % midi.midiNumTracks {
					track := midi.midiTracks[A_Index]
					nn := track.trackNumNotes
					if(nn > 1) {
						sf := file . " "A_Index
						playerFiles.Push(sf)
					}
				}
			} else {
				playerFiles.Push(file)
			}
		}
		if(A_LoopFileExt == "txt") {
			; todo parse and check count
			playerFiles.Push(file)
		}
	}
	GuiControl,, FileSelectionControl, |
	for i, e in playerFiles {
		f := GetShortFile(i)
		GuiControl,, FileSelectionControl, %f%
	}
	UpdateSelectedFile()
}

MidiMenuSelect(name, pos) {
	UseMidiDevice(pos - 1)
}

UseMidiDevice(device) {

	DllCall("midi_in.dll\stop")
	if(DllCall("midi_in.dll\getCurDevID", Int) >= 0) {
		res := DllCall("midi_in.dll\close")
		if(res) {
			MsgBox, Error closing midi device`n%res%
			return
		}
	}
	res := DllCall("midi_in.dll\open", UInt,MainHwnd, Int,device, Int)
	if(res) {
		MsgBox, Error opening midi device`n%res%
		return
	}
	DllCall("midi_in.dll\start")
	msgNum := 0x2000
	DllCall("midi_in.dll\listenNoteRange", int,36, int,72, int,0x00, int,0, int,msgNum)
	OnMessage(msgNum, "PlayMidiInput")
	UpdateMidiDevices()
}

req := ComObjCreate("Msxml2.XMLHTTP")
CheckUpdate() {
	global req
	req.open("GET", "https://api.github.com/repos/parulina/bardmacroplayer/releases/latest", true)
	req.onreadystatechange := Func("CheckUpdateEnd")
	req.send()
}

CheckUpdateEnd() {
	global req
	if (req.readyState != 4) {
		return
	}
	if (req.status != 200) {
		return
	}
	json := JSON.Load(req.responseText)
	if(json) {
		found := RegExMatch(json.tag_name, "v(\d\.\d+)", newVersion)
		if(found) {
			if(newVersion1 > curVersion) {
				GuiControl,, FileLoadedControl, [ New version %newVersion1% available! ]`n by Freya Katva @ Ultros
				Gui, Font, cRed
				GuiControl, Font, FileLoadedControl
				
				f := Func("LaunchGithubReleases")
				GuiControl, +g, FileLoadedControl, % f
			}
		}
	}
}

ReadSettings()
ToggleMainWindow()
ReadKeyConfig()
CheckUpdate()
Hotkey, % settings["HideHotkey"], ToggleWindow
Hotkey, % settings["ShortcutStop"], StopSubmit
Hotkey, % settings["ShortcutPlay"], PausePlaySubmit

if((MidiInModule := DllCall("LoadLibrary", Str,"midi_in.dll")) != 0) {
	if((devs := DllCall("midi_in.dll\getNumDevs")) > 0) {
		UseMidiDevice(0)
	}
}


ToggleWindow() {
	if(WinActive("ahk_class FFXIVGAME")) {
		Thread, NoTimers
		ReadKeyConfig()
		ToggleMainWindow()
	}
}

LoadFile(file, track := 1) {
	if(currentPlayer) {
		Thread, NoTimers
		currentPlayer.Stop()
	}
	currentPlayer := 0
	if(SubStr(file, -3) == ".mid") {
		currentPlayer := new MidiPlayer(file, track)
		
	} else {
		currentPlayer := new TxtPlayer(file)
	}
	if(currentPlayer) {
		currentPlayer.noteCallback := Func("PlayNoteCallback")
		currentPlayer.updateCallback := Func("UpdateMainWindow")
		currentPlayer.octaveShift := OctaveShift
		currentPlayer.speedShift := SpeedShift / 10
	}
	UpdateMainWindow()
}

PlayMidiInput(note, vel) {
	noteLetter := BardRange[(note + 1 -(12 * (3 - OctaveShift)))]
	if(vel) {
		PlayNoteCallback(noteLetter, -1)
	} else {
		PlayNoteEnd(noteLetter)
	}
}

PlayNoteCallback(note, ms := 100)
{
	key := NoteKeys[note].key
	mod := NoteKeys[note].mod
	
	down := NoteKeys[note].Down()
	downmod := NoteKeys[note].DownMod()
	down := downmod . down
	if(WinExist("ahk_class FFXIVGAME")) {
		if(ms > 0) {
			upFunc := Func("PlayNoteEnd").Bind(note)
			SetTimer, % upFunc, % -Abs(ms)
	;		ToolTip, %down% to %ms%
		}
		ControlSend,, %down%, ahk_class FFXIVGAME
	}
	return
}

PlayNoteEnd(note)
{
	up := NoteKeys[note].Up()
	upmod := NoteKeys[note].UpMod()
	up := up . upmod
	if(WinExist("ahk_class FFXIVGAME")) {
		ControlSend,, %up%, ahk_class FFXIVGAME
	;	ToolTip, OK
	}
}