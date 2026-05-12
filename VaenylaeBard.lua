-- VaenylaeBard - Clean Version for Turtle WoW

-- Global variables
VaenylaeBardSongs = VaenylaeBardSongs or {}
VaenylaeBardSelectedSong = nil
VaenylaeBardSelectedLine = nil

-- Debug flag and helper (off by default — /vbard debug to toggle)
local VB_DEBUG = false

-- File-level locals for line editor channel and emote type state (DATA-01, DATA-02)
-- Must be file-level (not inside CreateLineEditorFrame) so SaveLine() can read them.
local VB_currentChannel = "SAY"
local VB_currentEmoteType = "custom"

-- Playback engine state (Phase 3: PLAY-01 through PLAY-05)
local VB_MIN_LINE_DELAY = 1.5  -- flood protection floor (seconds); estimate for Turtle WoW
local VB_isPlaying = false
local VB_isManual = false
local VB_isPaused = false
local VB_playIndex = 1
local VB_playbackElapsed = 0
local VB_playingSongName = nil  -- captured at start time (Pitfall 7: prevents mid-performance song switch)

local playbackFrame = CreateFrame("Frame", "VaenylaeBardPlaybackFrame", UIParent)

local function VBDebug(msg)
    if VB_DEBUG then
        print("|cff00ff00[VaenylaeBard Debug]|r " .. tostring(msg))
    end
end

VBDebug("Addon file loading...")

-- Playback engine functions (Phase 3: PLAY-01 through PLAY-05)

local function DispatchLine(line)
    if not line then return end

    local ch = line.channel or "SAY"
    local emote = line.emote or ""
    local emoteType = line.emoteType or "custom"

    VBDebug("DispatchLine: ch=" .. ch .. " emoteType=" .. emoteType .. " emote=" .. emote)

    -- EMOTE-channel with empty emote: skip silently (CONTEXT.md empty/skipped lines)
    if ch == "EMOTE" and emote == "" then
        VBDebug("Skipping empty EMOTE-channel line")
        return
    end

    -- Text dispatch (PLAY-04): text fires first
    if ch ~= "EMOTE" then
        local text = line.text or ""
        if text ~= "" then
            SendChatMessage(text, ch)
        end
    end

    -- Emote dispatch (PLAY-05): emote fires second, same tick
    if emote ~= "" then
        if emoteType == "builtin" then
            DoEmote(emote)
        else
            SendChatMessage(emote, "EMOTE")
        end
    end
end

function StopPerformance()
    VB_isPlaying = false
    VB_isManual = false
    VB_isPaused = false
    VB_playIndex = 1
    VB_playbackElapsed = 0
    VB_playingSongName = nil
    VBDebug("Performance stopped, reset to line 1")
    UpdatePerformanceControls()
end

function StartPerformance(mode)
    if VB_isPlaying then
        print("|cffff0000[Vaenylae Bard]|r Already performing. Use /vbard stop first.")
        return
    end
    if not VaenylaeBardSelectedSong then
        print("|cffff0000[Vaenylae Bard]|r No song selected. Open the manager and select a song first.")
        return
    end
    local song = VaenylaeBardSongs[VaenylaeBardSelectedSong]
    if not song or #song == 0 then
        print("|cffff0000[Vaenylae Bard]|r Selected song has no lines.")
        return
    end

    VB_isPlaying = true
    VB_isManual = (mode == "manual")
    VB_playIndex = 1
    VB_playbackElapsed = 0
    VB_playingSongName = VaenylaeBardSelectedSong

    if VB_isManual then
        print("|cff00ffff[Vaenylae Bard]|r Manual performance started. Use /vbard next to advance.")
    else
        print("|cff00ffff[Vaenylae Bard]|r Auto performance started.")
    end
    VBDebug("StartPerformance mode=" .. tostring(mode) .. " song=" .. VaenylaeBardSelectedSong .. " lines=" .. #song)
end

function AdvanceLine()
    if not VB_isPlaying or not VB_isManual then return end

    local song = VaenylaeBardSongs[VB_playingSongName]
    if not song then
        StopPerformance()
        return
    end

    local line = song[VB_playIndex]
    if not line then
        StopPerformance()
        return
    end

    DispatchLine(line)
    VB_playIndex = VB_playIndex + 1
    UpdateNowNext()

    if VB_playIndex > #song then
        StopPerformance()
    end
end

playbackFrame:SetScript("OnUpdate", function(self, elapsed)
    if not VB_isPlaying then return end
    if VB_isManual then return end
    if VB_isPaused then return end

    VB_playbackElapsed = VB_playbackElapsed + elapsed

    local song = VaenylaeBardSongs[VB_playingSongName]
    if not song then
        StopPerformance()
        return
    end

    local line = song[VB_playIndex]
    if not line then
        StopPerformance()
        return
    end

    local effectiveDelay = math.max(line.delay or 3, VB_MIN_LINE_DELAY)

    if VB_playbackElapsed >= effectiveDelay then
        VB_playbackElapsed = VB_playbackElapsed - effectiveDelay
        DispatchLine(line)
        VB_playIndex = VB_playIndex + 1
        UpdateNowNext()

        if VB_playIndex > #song then
            StopPerformance()
        end
    end
end)

-- Create event frame for addon initialization
local eventFrame = CreateFrame("Frame")
VBDebug("Event frame created")

-- Initialize addon
local function InitializeAddon()
    VBDebug("InitializeAddon called")

    -- Initialize saved variables
    if not VaenylaeBardDB then
        VaenylaeBardDB = { songs = {} }
        VBDebug("Created new VaenylaeBardDB")
    else
        VBDebug("Loaded existing VaenylaeBardDB")
    end
    VaenylaeBardSongs = VaenylaeBardDB.songs

    VBDebug("About to create main frame")
    -- Create UI
    CreateMainFrame()
    VBDebug("Main frame creation finished")

    CreateLineEditorFrame()
    VBDebug("Line editor creation finished")

    print("|cff00ffff[Vaenylae Bard]|r Manager loaded! Type /vbard to open.")
end

-- Event handler
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
-- In WoW 3.3.5a (Lua 5.1), extra event args are explicit function parameters.
-- OnEvent receives (self, event, ...) where ... are event-specific args.
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "VaenylaeBard" then
        VBDebug("Our addon loaded, initializing...")
        InitializeAddon()
    elseif event == "PLAYER_LOGOUT" then
        if VaenylaeBardDB then
            VaenylaeBardDB.songs = VaenylaeBardSongs
        end
    end
end)

-- Update NOW/NEXT live line display (UI-02, UI-03)
-- Called AFTER VB_playIndex is incremented; index now points to the next-to-fire line.
function UpdateNowNext()
    local nowLabel  = _G["VaenylaeBardNowLabel"]
    local nextLabel = _G["VaenylaeBardNextLabel"]
    if not nowLabel or not nextLabel then return end

    local song = VaenylaeBardSongs[VB_playingSongName]
    if not song then return end

    -- After index increment: VB_playIndex points to next-to-fire line
    -- Just-dispatched line is at VB_playIndex - 1
    local justFired = song[VB_playIndex - 1]
    local upcoming  = song[VB_playIndex]

    local nowText = (justFired and justFired.text) or ""
    if string.len(nowText) > 40 then
        nowText = string.sub(nowText, 1, 40) .. "..."
    end

    nowLabel:SetText("NOW: \"" .. nowText .. "\"")

    if upcoming then
        local nextStr = upcoming.text or ""
        if string.len(nextStr) > 40 then
            nextStr = string.sub(nextStr, 1, 40) .. "..."
        end
        nextLabel:SetText("NEXT: " .. nextStr)
    else
        nextLabel:SetText("NEXT: (last line)")
    end
end

-- Centralized UI sync function: reads engine state, updates all button labels and visibility.
-- Nil-guarded so it is safe to call from StopPerformance() before frames are created.
function UpdatePerformanceControls()
    local playPauseBtn = _G["VaenylaeBardPlayPauseButton"]
    if not playPauseBtn then return end  -- guard: frames not created yet
    local modeBtn     = _G["VaenylaeBardModeButton"]
    local controlsRow = _G["VaenylaeBardControlsRow"]
    local nowLabel    = _G["VaenylaeBardNowLabel"]
    local nextLabel   = _G["VaenylaeBardNextLabel"]

    if not VaenylaeBardSelectedSong then
        controlsRow:Hide()
        nowLabel:Hide()
        nextLabel:Hide()
        return
    end

    controlsRow:Show()

    if not VB_isPlaying then
        playPauseBtn:SetText("Play")
        modeBtn:Show()
        nowLabel:Hide()
        nextLabel:Hide()
    elseif VB_isManual then
        playPauseBtn:SetText("Next")
        modeBtn:Hide()
        nowLabel:Show()
        nextLabel:Show()
    elseif VB_isPaused then
        playPauseBtn:SetText("Play")
        modeBtn:Hide()
        nowLabel:Show()
        nextLabel:Show()
    else
        playPauseBtn:SetText("Pause")
        modeBtn:Hide()
        nowLabel:Show()
        nextLabel:Show()
    end
end

-- Create main frame (simplified version without backdrop to avoid path issues)
function CreateMainFrame()
    VBDebug("CreateMainFrame starting")

    local f = CreateFrame("Frame", "VaenylaeBardMainFrame", UIParent)
    VBDebug("Frame created: " .. tostring(f))

    f:SetWidth(350)
    f:SetHeight(400)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:Hide()

    -- Simple background instead of complex backdrop
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetTexture(0, 0, 0, 0.8)

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Close button
    local closeBtn = CreateFrame("Button", "VaenylaeBardMainFrameClose", f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -15)
    title:SetText("Vaenylae Bard Manager")

    -- Song list frame (simplified)
    local songList = CreateFrame("Frame", "VaenylaeBardSongList", f)
    songList:SetWidth(300)
    songList:SetHeight(180)
    songList:SetPoint("TOP", f, "TOP", 0, -45)

    -- Buttons
    local addBtn = CreateFrame("Button", "VaenylaeBardAddSongButton", f, "UIPanelButtonTemplate")
    addBtn:SetWidth(100)
    addBtn:SetHeight(25)
    addBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 15)
    addBtn:SetText("Add Song")
    addBtn:SetScript("OnClick", function()
        VBDebug("Add Song clicked")
        StaticPopup_Show("VAENYLAE_BARD_ADD_SONG")
    end)

    local removeBtn = CreateFrame("Button", "VaenylaeBardRemoveSongButton", f, "UIPanelButtonTemplate")
    removeBtn:SetWidth(100)
    removeBtn:SetHeight(25)
    removeBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 15)
    removeBtn:SetText("Remove Song")
    removeBtn:SetScript("OnClick", function()
        if VaenylaeBardSelectedSong then
            VaenylaeBardSongs[VaenylaeBardSelectedSong] = nil
            VaenylaeBardSelectedSong = nil
            UpdateSongList()
            UpdatePerformanceControls()   -- hide controls row on song removal
            print("Song removed.")
        else
            print("No song selected to remove.")
        end
    end)

    -- Instructions
    local instructions = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructions:SetPoint("BOTTOM", f, "BOTTOM", 0, 45)
    instructions:SetText("Click a song to edit its lines")

    -- NOW label (visible during playback only)
    local nowLabel = f:CreateFontString("VaenylaeBardNowLabel", "OVERLAY", "GameFontNormal")
    nowLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -235)
    nowLabel:SetText("NOW: \"\"")
    nowLabel:Hide()

    -- NEXT label (visible during playback only, dimmed)
    local nextLabel = f:CreateFontString("VaenylaeBardNextLabel", "OVERLAY", "GameFontNormal")
    nextLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -255)
    nextLabel:SetText("NEXT: ")
    nextLabel:SetTextColor(0.6, 0.6, 0.6)
    nextLabel:Hide()

    -- Controls row container (hidden until a song is selected)
    local controlsRow = CreateFrame("Frame", "VaenylaeBardControlsRow", f)
    controlsRow:SetWidth(310)
    controlsRow:SetHeight(35)
    controlsRow:SetPoint("TOP", f, "TOP", 0, -280)
    controlsRow:Hide()

    -- PlayPause button
    local playPauseBtn = CreateFrame("Button", "VaenylaeBardPlayPauseButton", controlsRow, "UIPanelButtonTemplate")
    playPauseBtn:SetWidth(70)
    playPauseBtn:SetHeight(25)
    playPauseBtn:SetPoint("LEFT", controlsRow, "LEFT", 5, 0)
    playPauseBtn:SetText("Play")
    playPauseBtn:SetScript("OnClick", function()
        if not VB_isPlaying then
            local mode = "auto"
            if _G["VaenylaeBardModeButton"] then
                local modeText = _G["VaenylaeBardModeButton"]:GetText()
                if modeText == "Manual" then mode = "manual" end
            end
            StartPerformance(mode)
            -- Set initial NOW/NEXT labels for line 1 and line 2
            local song = VaenylaeBardSongs[VB_playingSongName]
            if song then
                local firstLine = song[1]
                local secondLine = song[2]
                local nowLbl = _G["VaenylaeBardNowLabel"]
                local nextLbl = _G["VaenylaeBardNextLabel"]
                if nowLbl and firstLine then
                    local t = firstLine.text or ""
                    if string.len(t) > 40 then t = string.sub(t, 1, 40) .. "..." end
                    nowLbl:SetText("NOW: \"" .. t .. "\"")
                end
                if nextLbl then
                    if secondLine then
                        local t = secondLine.text or ""
                        if string.len(t) > 40 then t = string.sub(t, 1, 40) .. "..." end
                        nextLbl:SetText("NEXT: " .. t)
                    else
                        nextLbl:SetText("NEXT: (last line)")
                    end
                end
            end
        elseif VB_isManual then
            AdvanceLine()
        elseif VB_isPaused then
            VB_isPaused = false
            VBDebug("Performance resumed")
        else
            VB_isPaused = true
            VBDebug("Performance paused")
        end
        UpdatePerformanceControls()
    end)

    -- Stop button
    local stopBtn = CreateFrame("Button", "VaenylaeBardStopButton", controlsRow, "UIPanelButtonTemplate")
    stopBtn:SetWidth(60)
    stopBtn:SetHeight(25)
    stopBtn:SetPoint("LEFT", playPauseBtn, "RIGHT", 5, 0)
    stopBtn:SetText("Stop")
    stopBtn:SetScript("OnClick", function()
        StopPerformance()
        UpdatePerformanceControls()
    end)

    -- Mode toggle button
    local modeBtn = CreateFrame("Button", "VaenylaeBardModeButton", controlsRow, "UIPanelButtonTemplate")
    modeBtn:SetWidth(65)
    modeBtn:SetHeight(25)
    modeBtn:SetPoint("LEFT", stopBtn, "RIGHT", 5, 0)
    modeBtn:SetText("Auto")
    modeBtn:SetScript("OnClick", function(self)
        if self:GetText() == "Auto" then
            self:SetText("Manual")
        else
            self:SetText("Auto")
        end
        VBDebug("Mode toggled to: " .. self:GetText())
    end)

    UpdateSongList()
    VBDebug("CreateMainFrame finished successfully")
end

-- Helper: gray out / re-enable the Line Text box depending on channel (DATA-01, DATA-03)
-- Called by the channel cycle button OnClick and when loading a line in UpdateLineList().
local function UpdateTextBoxForChannel(channel)
    local tb = _G["VaenylaeBardLineTextBox"]
    if not tb then return end
    if channel == "EMOTE" then
        tb:EnableMouse(false)
        tb:SetTextColor(0.5, 0.5, 0.5)
        if tb:GetText() == "" then
            tb:SetText("No spoken text")
        end
    else
        tb:EnableMouse(true)
        tb:SetTextColor(1, 1, 1)
        if tb:GetText() == "No spoken text" then
            tb:SetText("")
        end
    end
end

-- Create simple line editor frame
function CreateLineEditorFrame()
    local f = CreateFrame("Frame", "VaenylaeBardLineEditorFrame", UIParent)
    f:SetWidth(320)
    f:SetHeight(465)
    f:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    f:Hide()

    -- Simple background
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetTexture(0, 0, 0, 0.8)

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -15)
    title:SetText("Song Line Editor")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    closeBtn:SetScript("OnClick", function()
        f:Hide()
        VaenylaeBardSelectedLine = nil
    end)

    -- Line list
    local lineList = CreateFrame("Frame", "VaenylaeBardLineList", f)
    lineList:SetWidth(280)
    lineList:SetHeight(120)
    lineList:SetPoint("TOP", f, "TOP", 0, -70)

    -- Input fields
    local textLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    textLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -200)
    textLabel:SetText("Line Text:")

    local textBox = CreateFrame("EditBox", "VaenylaeBardLineTextBox", f, "InputBoxTemplate")
    textBox:SetWidth(280)
    textBox:SetHeight(32)
    textBox:SetPoint("TOP", f, "TOP", 0, -220)
    textBox:SetAutoFocus(false)

    -- Channel cycle button (DATA-01, DATA-03)
    local channelLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -258)
    channelLabel:SetText("Channel:")

    local channelBtn = CreateFrame("Button", "VaenylaeBardChannelButton", f, "UIPanelButtonTemplate")
    channelBtn:SetWidth(80)
    channelBtn:SetHeight(25)
    channelBtn:SetPoint("LEFT", channelLabel, "RIGHT", 10, 0)
    channelBtn:SetText("SAY")
    -- SAY = white text (default)
    channelBtn:GetFontString():SetTextColor(1, 1, 1)
    channelBtn:SetScript("OnClick", function(self)
        if VB_currentChannel == "SAY" then
            VB_currentChannel = "YELL"
            self:SetText("YELL")
            self:GetFontString():SetTextColor(1, 1, 0)
        elseif VB_currentChannel == "YELL" then
            VB_currentChannel = "EMOTE"
            self:SetText("EMOTE")
            self:GetFontString():SetTextColor(1, 0.5, 1)
        else
            VB_currentChannel = "SAY"
            self:SetText("SAY")
            self:GetFontString():SetTextColor(1, 1, 1)
        end
        UpdateTextBoxForChannel(VB_currentChannel)
        VBDebug("Channel set to: " .. VB_currentChannel)
    end)

    local emoteLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emoteLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -295)
    emoteLabel:SetText("Emote:")

    local emoteBox = CreateFrame("EditBox", "VaenylaeBardLineEmoteBox", f, "InputBoxTemplate")
    emoteBox:SetWidth(200)
    emoteBox:SetHeight(32)
    emoteBox:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -315)
    emoteBox:SetAutoFocus(false)

    -- Emote type toggle (DATA-02, DATA-03)
    local emoteTypeBtn = CreateFrame("Button", "VaenylaeBardEmoteTypeButton", f, "UIPanelButtonTemplate")
    emoteTypeBtn:SetWidth(75)
    emoteTypeBtn:SetHeight(25)
    emoteTypeBtn:SetPoint("LEFT", emoteBox, "RIGHT", 5, 0)
    emoteTypeBtn:SetText("Custom")
    emoteTypeBtn:SetScript("OnClick", function(self)
        if VB_currentEmoteType == "custom" then
            VB_currentEmoteType = "builtin"
            self:SetText("Built-in")
        else
            VB_currentEmoteType = "custom"
            self:SetText("Custom")
        end
        VBDebug("Emote type set to: " .. VB_currentEmoteType)
    end)

    local delayLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    delayLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -355)
    delayLabel:SetText("Delay:")

    local delayBox = CreateFrame("EditBox", "VaenylaeBardLineDelayBox", f, "InputBoxTemplate")
    delayBox:SetWidth(100)
    delayBox:SetHeight(32)
    delayBox:SetPoint("TOP", f, "TOP", 0, -375)
    delayBox:SetAutoFocus(false)
    delayBox:SetText("3")

    -- Save button
    local saveBtn = CreateFrame("Button", "VaenylaeBardSaveLineButton", f, "UIPanelButtonTemplate")
    saveBtn:SetWidth(120)
    saveBtn:SetHeight(25)
    saveBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 15)
    saveBtn:SetText("Save Line")
    saveBtn:SetScript("OnClick", SaveLine)
end

-- Update song list
function UpdateSongList()
    local songList = _G["VaenylaeBardSongList"]
    if not songList then return end

    -- Clear existing buttons
    if songList.buttons then
        for _, btn in pairs(songList.buttons) do
            btn:Hide()
        end
    else
        songList.buttons = {}
    end

    local y = 0
    local buttonIndex = 1

    for songName, songData in pairs(VaenylaeBardSongs) do
        local btn = songList.buttons[buttonIndex]
        if not btn then
            btn = CreateFrame("Button", nil, songList, "UIPanelButtonTemplate")
            btn:SetWidth(280)
            btn:SetHeight(25)
            songList.buttons[buttonIndex] = btn
        end

        btn:SetPoint("TOP", songList, "TOP", 0, -y)
        btn:SetText(songName .. " (" .. #songData .. " lines)")
        local capturedName = songName  -- capture per-iteration; loop vars are shared in Lua 5.0
        btn:SetScript("OnClick", function()
            VaenylaeBardSelectedSong = capturedName
            _G["VaenylaeBardLineEditorFrame"]:Show()
            UpdateLineList()
            UpdatePerformanceControls()   -- show controls row on song select
            VBDebug("Selected song: " .. capturedName)
        end)
        btn:Show()

        y = y + 30
        buttonIndex = buttonIndex + 1
    end
end

-- Update line list
function UpdateLineList()
    local parent = _G["VaenylaeBardLineList"]
    if not parent then return end

    -- Pool init/clear: hide all pooled buttons, or create the pool table
    if parent.buttons then
        for _, btn in pairs(parent.buttons) do
            btn:Hide()
        end
    else
        parent.buttons = {}
    end

    local song = VaenylaeBardSongs[VaenylaeBardSelectedSong]
    if not song then return end

    local y = 0
    for i, line in ipairs(song) do
        local btn = parent.buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
            btn:SetWidth(260)
            btn:SetHeight(25)
            parent.buttons[i] = btn
        end
        btn:SetPoint("TOP", parent, "TOP", 0, -y)
        btn:SetText(i .. ". " .. line.text)
        local capturedIndex = i  -- capture per-iteration; loop vars are shared in Lua 5.0
        local capturedLine = line
        -- SetScript on every iteration: pooled buttons retain old closures
        btn:SetScript("OnClick", function()
            VaenylaeBardSelectedLine = capturedIndex
            _G["VaenylaeBardLineTextBox"]:SetText(capturedLine.text)
            _G["VaenylaeBardLineEmoteBox"]:SetText(capturedLine.emote or "")
            _G["VaenylaeBardLineDelayBox"]:SetText(tostring(capturedLine.delay or 3))

            -- Apply backward-compat defaults (DATA-01, DATA-02)
            local ch = capturedLine.channel or "SAY"
            local et = capturedLine.emoteType or "custom"

            -- Sync file-level locals
            VB_currentChannel = ch
            VB_currentEmoteType = et

            -- Sync channel button label and color
            _G["VaenylaeBardChannelButton"]:SetText(ch)
            if ch == "SAY" then
                _G["VaenylaeBardChannelButton"]:GetFontString():SetTextColor(1, 1, 1)
            elseif ch == "YELL" then
                _G["VaenylaeBardChannelButton"]:GetFontString():SetTextColor(1, 1, 0)
            else
                _G["VaenylaeBardChannelButton"]:GetFontString():SetTextColor(1, 0.5, 1)
            end

            -- Sync emote type toggle label
            if et == "builtin" then
                _G["VaenylaeBardEmoteTypeButton"]:SetText("Built-in")
            else
                _G["VaenylaeBardEmoteTypeButton"]:SetText("Custom")
            end

            -- Sync text box enabled/disabled state
            UpdateTextBoxForChannel(ch)
        end)
        btn:Show()
        y = y + 30
    end
    parent:Show()
end

-- Save line function
function SaveLine()
    if not VaenylaeBardSelectedSong then return end

    local text = _G["VaenylaeBardLineTextBox"]:GetText()
    -- EMOTE channel lines can have empty text (text box is disabled)
    if text == "" and VB_currentChannel ~= "EMOTE" then
        print("Please enter line text.")
        return
    end
    -- Clear placeholder hint if it snuck through
    if text == "No spoken text" then
        text = ""
    end

    local emote = _G["VaenylaeBardLineEmoteBox"]:GetText()
    local delay = tonumber(_G["VaenylaeBardLineDelayBox"]:GetText()) or 3
    local song = VaenylaeBardSongs[VaenylaeBardSelectedSong]

    local lineData = {
        text = text,
        emote = emote,
        delay = delay,
        channel = VB_currentChannel,
        emoteType = VB_currentEmoteType
    }

    if VaenylaeBardSelectedLine then
        song[VaenylaeBardSelectedLine] = lineData
        print("Line updated.")
    else
        table.insert(song, lineData)
        print("Line added.")
    end

    VaenylaeBardSelectedLine = nil
    _G["VaenylaeBardLineTextBox"]:SetText("")
    _G["VaenylaeBardLineEmoteBox"]:SetText("")
    _G["VaenylaeBardLineDelayBox"]:SetText("3")
    VB_currentChannel = "SAY"
    _G["VaenylaeBardChannelButton"]:SetText("SAY")
    _G["VaenylaeBardChannelButton"]:GetFontString():SetTextColor(1, 1, 1)
    VB_currentEmoteType = "custom"
    _G["VaenylaeBardEmoteTypeButton"]:SetText("Custom")
    UpdateTextBoxForChannel("SAY")
    UpdateLineList()
    UpdateSongList()
end

-- Static popup for adding songs
StaticPopupDialogs["VAENYLAE_BARD_ADD_SONG"] = {
    text = "Enter song name:",
    button1 = "Add",
    button2 = "Cancel",
    hasEditBox = true,
    OnShow = function(self)
        self.editBox:SetFocus()
    end,
    OnAccept = function(self)
        local songName = self.editBox:GetText()
        if songName and songName ~= "" then
            if VaenylaeBardSongs[songName] then
                print("Song with that name already exists!")
                return
            end
            VaenylaeBardSongs[songName] = {}
            UpdateSongList()
            print("Song '" .. songName .. "' added.")
        end
    end,
    EditBoxOnEnterPressed = function(self)
        self:GetParent().button1:Click()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- Slash command
SLASH_VAENYLAEBARD1 = "/vbard"
SLASH_VAENYLAEBARD2 = "/vaenylaebard"
SlashCmdList["VAENYLAEBARD"] = function(msg)
    -- Input normalization: lowercase, trim whitespace, collapse internal spaces
    msg = string.lower(msg or "")
    msg = string.gsub(msg, "^%s+", "")
    msg = string.gsub(msg, "%s+$", "")
    msg = string.gsub(msg, "%s+", " ")

    VBDebug("Slash command called with: " .. tostring(msg))

    if msg == "debug" then
        VB_DEBUG = not VB_DEBUG
        if VB_DEBUG then
            print("|cff00ff00[VaenylaeBard Debug]|r Debug mode ON")
        else
            print("|cff00ff00[VaenylaeBard Debug]|r Debug mode OFF")
        end
        return
    end

    if msg == "play" or msg == "play manual" then
        local mode = "auto"
        if msg == "play manual" then
            mode = "manual"
        end
        StartPerformance(mode)
        return
    end

    if msg == "stop" then
        StopPerformance()
        return
    end

    if msg == "next" then
        if VB_isManual and VB_isPlaying then
            AdvanceLine()
        end
        return
    end

    local mainFrame = _G["VaenylaeBardMainFrame"]
    if not mainFrame then
        print("|cffff0000[Vaenylae Bard]|r Frame not found! Try /vbard debug")
        return
    end

    if mainFrame:IsShown() then
        mainFrame:Hide()
        VBDebug("Manager hidden.")
    else
        mainFrame:Show()
        UpdatePerformanceControls()   -- sync controls when manager opens
        VBDebug("Manager opened.")
    end
end

VBDebug("Addon file loaded completely!")
