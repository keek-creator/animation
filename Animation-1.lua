-- EmoteBrowser v3 for Delta
-- Tabs: Emotes | Animations | Customize
-- Customize: set idle/walk/run/jump/fall/swim/climb independently

if _G.EmoteBrowserRunning then
    pcall(function() if _G.EmoteBrowserDestroy then _G.EmoteBrowserDestroy() end end)
end
_G.EmoteBrowserRunning = true

local HttpService      = game:GetService("HttpService")
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui          = game:GetService("CoreGui")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")

-- ── State ──────────────────────────────────────────────────────────────
local allEmotes     = {}
local allAnimPacks  = {}
local filtEmotes    = {}
local filtPacks     = {}
local currentPage   = 1
local PER_PAGE      = 16
local currentTab    = "emotes"   -- "emotes" | "packs" | "customize"
local currentTrack  = nil
local freezeEnabled = false
local emoteSpeed    = 1.0
local guiOpen       = true
local connections   = {}
local moveConn      = nil

-- customize slots: each key = Animate folder name, value = animationId string or nil
local SLOTS = { "idle", "walk", "run", "jump", "fall", "swim", "climb" }
local SLOT_LABELS = {
    idle  = "🧍 IDLE",
    walk  = "🚶 WALK",
    run   = "🏃 RUN",
    jump  = "⬆ JUMP",
    fall  = "⬇ FALL",
    swim  = "🏊 SWIM",
    climb = "🧗 CLIMB",
}
local customSlots = {}  -- slot -> { id=animId, name=packName }
local animPackCache = {} -- packId -> mappings table

-- ── Helpers ────────────────────────────────────────────────────────────
local function tw(o, t, p) TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad), p):Play() end
local function corner(p, r) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 6); c.Parent=p end
local function stroke(p, col, th) local s=Instance.new("UIStroke"); s.Color=col or Color3.fromRGB(22,42,62); s.Thickness=th or 1; s.Parent=p end

-- ── Destroy old ────────────────────────────────────────────────────────
pcall(function() if CoreGui:FindFirstChild("EmoteBrowserV3") then CoreGui.EmoteBrowserV3:Destroy() end end)

local root = Instance.new("ScreenGui")
root.Name="EmoteBrowserV3"; root.ResetOnSpawn=false; root.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
if not pcall(function() root.Parent=CoreGui end) then root.Parent=player.PlayerGui end

_G.EmoteBrowserDestroy = function()
    _G.EmoteBrowserRunning = false
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    if moveConn then moveConn:Disconnect() end
    pcall(function() root:Destroy() end)
end

-- ══════════════════════════════════════════════════════════════════════
--  PILL TOGGLE BUTTON
-- ══════════════════════════════════════════════════════════════════════
local pillFrame = Instance.new("Frame")
pillFrame.Size=UDim2.new(0,52,0,52); pillFrame.Position=UDim2.new(0,14,1,-66)
pillFrame.BackgroundTransparency=1; pillFrame.ZIndex=20; pillFrame.Parent=root

local pillBg = Instance.new("Frame")
pillBg.Size=UDim2.new(1,0,1,0); pillBg.BackgroundColor3=Color3.fromRGB(5,12,22)
pillBg.BorderSizePixel=0; pillBg.ZIndex=20; pillBg.Parent=pillFrame
corner(pillBg,15)

local pillStroke=Instance.new("UIStroke"); pillStroke.Color=Color3.fromRGB(0,200,255)
pillStroke.Thickness=2; pillStroke.Parent=pillBg
TweenService:Create(pillStroke,TweenInfo.new(1.4,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Thickness=4.5}):Play()

local pillIcon=Instance.new("TextLabel"); pillIcon.Size=UDim2.new(1,0,1,0)
pillIcon.BackgroundTransparency=1; pillIcon.Text="▶"; pillIcon.TextColor3=Color3.fromRGB(0,215,255)
pillIcon.Font=Enum.Font.GothamBold; pillIcon.TextSize=22; pillIcon.ZIndex=21; pillIcon.Parent=pillBg

local pillBtn=Instance.new("TextButton"); pillBtn.Size=UDim2.new(1,0,1,0)
pillBtn.BackgroundTransparency=1; pillBtn.Text=""; pillBtn.ZIndex=22; pillBtn.Parent=pillFrame

-- ══════════════════════════════════════════════════════════════════════
--  MAIN PANEL
-- ══════════════════════════════════════════════════════════════════════
local panel=Instance.new("Frame"); panel.Name="Panel"
panel.Size=UDim2.new(0,430,0,490); panel.Position=UDim2.new(0.5,-215,0.5,-245)
panel.BackgroundColor3=Color3.fromRGB(7,12,20); panel.BorderSizePixel=0; panel.ZIndex=5; panel.Parent=root
corner(panel,10); stroke(panel,Color3.fromRGB(16,36,56),1.5)

-- title bar
local titleBar=Instance.new("Frame"); titleBar.Size=UDim2.new(1,0,0,34)
titleBar.BackgroundColor3=Color3.fromRGB(8,17,28); titleBar.BorderSizePixel=0; titleBar.ZIndex=6; titleBar.Parent=panel
corner(titleBar,10)
local tbPatch=Instance.new("Frame"); tbPatch.Size=UDim2.new(1,0,0.5,0); tbPatch.Position=UDim2.new(0,0,0.5,0)
tbPatch.BackgroundColor3=Color3.fromRGB(8,17,28); tbPatch.BorderSizePixel=0; tbPatch.ZIndex=6; tbPatch.Parent=titleBar

local titleLbl=Instance.new("TextLabel"); titleLbl.Size=UDim2.new(1,-80,1,0); titleLbl.Position=UDim2.new(0,12,0,0)
titleLbl.BackgroundTransparency=1; titleLbl.Text="EMOTE BROWSER"; titleLbl.TextColor3=Color3.fromRGB(0,200,255)
titleLbl.Font=Enum.Font.GothamBold; titleLbl.TextSize=13; titleLbl.TextXAlignment=Enum.TextXAlignment.Left
titleLbl.ZIndex=7; titleLbl.Parent=titleBar

local statusLbl=Instance.new("TextLabel"); statusLbl.Size=UDim2.new(0,110,1,0); statusLbl.Position=UDim2.new(0,165,0,0)
statusLbl.BackgroundTransparency=1; statusLbl.Text="loading..."; statusLbl.TextColor3=Color3.fromRGB(45,80,105)
statusLbl.Font=Enum.Font.Gotham; statusLbl.TextSize=10; statusLbl.TextXAlignment=Enum.TextXAlignment.Left
statusLbl.ZIndex=7; statusLbl.Parent=titleBar

local closeBtn=Instance.new("TextButton"); closeBtn.Size=UDim2.new(0,22,0,22); closeBtn.Position=UDim2.new(1,-28,0.5,-11)
closeBtn.BackgroundColor3=Color3.fromRGB(150,28,45); closeBtn.TextColor3=Color3.fromRGB(255,255,255)
closeBtn.Font=Enum.Font.GothamBold; closeBtn.TextSize=11; closeBtn.Text="✕"; closeBtn.BorderSizePixel=0
closeBtn.ZIndex=8; closeBtn.Parent=titleBar; corner(closeBtn,4)

-- ── 3 tabs ────────────────────────────────────────────────────────────
local tabBg=Instance.new("Frame"); tabBg.Size=UDim2.new(1,-16,0,26); tabBg.Position=UDim2.new(0,8,0,40)
tabBg.BackgroundColor3=Color3.fromRGB(10,18,30); tabBg.BorderSizePixel=0; tabBg.ZIndex=6; tabBg.Parent=panel
corner(tabBg,5)
local tpad=Instance.new("UIPadding"); tpad.PaddingLeft=UDim.new(0,3); tpad.PaddingRight=UDim.new(0,3)
tpad.PaddingTop=UDim.new(0,3); tpad.PaddingBottom=UDim.new(0,3); tpad.Parent=tabBg
local tlist=Instance.new("UIListLayout"); tlist.FillDirection=Enum.FillDirection.Horizontal
tlist.SortOrder=Enum.SortOrder.LayoutOrder; tlist.Padding=UDim.new(0,3); tlist.Parent=tabBg

local function makeTabBtn(text, order)
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(1/3,-3,1,0); b.BackgroundColor3=Color3.fromRGB(11,22,35)
    b.TextColor3=Color3.fromRGB(65,105,135); b.Font=Enum.Font.GothamBold; b.TextSize=10
    b.Text=text; b.BorderSizePixel=0; b.LayoutOrder=order; b.ZIndex=7; b.Parent=tabBg
    corner(b,4); return b
end
local tabEmoteBtn   = makeTabBtn("🎭  EMOTES",    1)
local tabPackBtn    = makeTabBtn("🏃  ANIMATIONS", 2)
local tabCustomBtn  = makeTabBtn("🎨  CUSTOMIZE",  3)

-- ── search bar ────────────────────────────────────────────────────────
local searchBg=Instance.new("Frame"); searchBg.Size=UDim2.new(1,-16,0,26); searchBg.Position=UDim2.new(0,8,0,72)
searchBg.BackgroundColor3=Color3.fromRGB(10,19,30); searchBg.BorderSizePixel=0; searchBg.ZIndex=6; searchBg.Parent=panel
corner(searchBg,5); stroke(searchBg,Color3.fromRGB(17,42,64),1)
local sIcon=Instance.new("TextLabel"); sIcon.Size=UDim2.new(0,22,1,0); sIcon.BackgroundTransparency=1
sIcon.Text="🔍"; sIcon.TextSize=11; sIcon.Font=Enum.Font.Gotham; sIcon.ZIndex=7; sIcon.Parent=searchBg
local searchBox=Instance.new("TextBox"); searchBox.Size=UDim2.new(1,-24,1,0); searchBox.Position=UDim2.new(0,22,0,0)
searchBox.BackgroundTransparency=1; searchBox.Text=""; searchBox.PlaceholderText="Search..."
searchBox.PlaceholderColor3=Color3.fromRGB(50,80,100); searchBox.TextColor3=Color3.fromRGB(195,218,238)
searchBox.Font=Enum.Font.Gotham; searchBox.TextSize=12; searchBox.TextXAlignment=Enum.TextXAlignment.Left
searchBox.ClearTextOnFocus=false; searchBox.ZIndex=7; searchBox.Parent=searchBg

-- ── controls row ──────────────────────────────────────────────────────
local ctrlRow=Instance.new("Frame"); ctrlRow.Size=UDim2.new(1,-16,0,26); ctrlRow.Position=UDim2.new(0,8,0,104)
ctrlRow.BackgroundTransparency=1; ctrlRow.ZIndex=6; ctrlRow.Parent=panel

local function ctrlBtn(text, x, w, bg, tc)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(0,w,0,22); b.Position=UDim2.new(0,x,0.5,-11)
    b.BackgroundColor3=bg or Color3.fromRGB(11,22,36); b.TextColor3=tc or Color3.fromRGB(175,205,225)
    b.Font=Enum.Font.GothamBold; b.TextSize=11; b.Text=text; b.BorderSizePixel=0; b.ZIndex=7; b.Parent=ctrlRow
    corner(b,4); stroke(b,Color3.fromRGB(20,44,66),1); return b
end

local spLbl=Instance.new("TextLabel"); spLbl.Size=UDim2.new(0,40,1,0); spLbl.BackgroundTransparency=1
spLbl.Text="SPEED"; spLbl.TextColor3=Color3.fromRGB(75,120,155); spLbl.Font=Enum.Font.GothamBold
spLbl.TextSize=10; spLbl.ZIndex=7; spLbl.Parent=ctrlRow

local spDown   = ctrlBtn("−", 40, 22)
local spValLbl = Instance.new("TextLabel"); spValLbl.Size=UDim2.new(0,34,0,20); spValLbl.Position=UDim2.new(0,64,0.5,-10)
spValLbl.BackgroundColor3=Color3.fromRGB(10,20,32); spValLbl.TextColor3=Color3.fromRGB(255,205,50)
spValLbl.Font=Enum.Font.GothamBold; spValLbl.TextSize=12; spValLbl.Text="1.0x"; spValLbl.ZIndex=7; spValLbl.Parent=ctrlRow
corner(spValLbl,4)
local spUp     = ctrlBtn("+",100,22)
local freezeBtn= ctrlBtn("❄ FREEZE: OFF",130,108,Color3.fromRGB(7,22,15),Color3.fromRGB(0,195,115)); freezeBtn.TextSize=10
local stopBtn  = ctrlBtn("■ STOP",244,58,Color3.fromRGB(22,7,7),Color3.fromRGB(255,75,75)); stopBtn.TextSize=10

-- divider
local div=Instance.new("Frame"); div.Size=UDim2.new(1,-16,0,1); div.Position=UDim2.new(0,8,0,136)
div.BackgroundColor3=Color3.fromRGB(14,32,50); div.BorderSizePixel=0; div.ZIndex=6; div.Parent=panel

-- ── SCROLL LIST (emotes / packs) ──────────────────────────────────────
local scrollFrame=Instance.new("ScrollingFrame"); scrollFrame.Size=UDim2.new(1,-16,0,308)
scrollFrame.Position=UDim2.new(0,8,0,142); scrollFrame.BackgroundTransparency=1
scrollFrame.BorderSizePixel=0; scrollFrame.ScrollBarThickness=3
scrollFrame.ScrollBarImageColor3=Color3.fromRGB(0,130,180); scrollFrame.ZIndex=6; scrollFrame.Parent=panel

local listLayout=Instance.new("UIListLayout"); listLayout.SortOrder=Enum.SortOrder.LayoutOrder
listLayout.Padding=UDim.new(0,3); listLayout.Parent=scrollFrame

-- ── CUSTOMIZE PANEL (hidden by default) ───────────────────────────────
local customPanel=Instance.new("ScrollingFrame"); customPanel.Size=UDim2.new(1,-16,0,308)
customPanel.Position=UDim2.new(0,8,0,142); customPanel.BackgroundTransparency=1
customPanel.BorderSizePixel=0; customPanel.ScrollBarThickness=3
customPanel.ScrollBarImageColor3=Color3.fromRGB(0,130,180); customPanel.ZIndex=6
customPanel.Visible=false; customPanel.Parent=panel

local customLayout=Instance.new("UIListLayout"); customLayout.SortOrder=Enum.SortOrder.LayoutOrder
customLayout.Padding=UDim.new(0,4); customLayout.Parent=customPanel

-- pagination bar
local pageRow=Instance.new("Frame"); pageRow.Size=UDim2.new(1,-16,0,24); pageRow.Position=UDim2.new(0,8,1,-30)
pageRow.BackgroundTransparency=1; pageRow.ZIndex=6; pageRow.Parent=panel

local prevBtn=Instance.new("TextButton"); prevBtn.Size=UDim2.new(0,64,1,0)
prevBtn.BackgroundColor3=Color3.fromRGB(9,19,32); prevBtn.TextColor3=Color3.fromRGB(0,185,235)
prevBtn.Font=Enum.Font.GothamBold; prevBtn.TextSize=11; prevBtn.Text="◀ PREV"
prevBtn.BorderSizePixel=0; prevBtn.ZIndex=7; prevBtn.Parent=pageRow; corner(prevBtn,4); stroke(prevBtn,Color3.fromRGB(16,46,70),1)

local pageLbl=Instance.new("TextLabel"); pageLbl.Size=UDim2.new(1,-140,1,0); pageLbl.Position=UDim2.new(0,70,0,0)
pageLbl.BackgroundTransparency=1; pageLbl.Text="Page 1 / 1"; pageLbl.TextColor3=Color3.fromRGB(55,90,115)
pageLbl.Font=Enum.Font.Gotham; pageLbl.TextSize=11; pageLbl.ZIndex=7; pageLbl.Parent=pageRow

local nextBtn=Instance.new("TextButton"); nextBtn.Size=UDim2.new(0,64,1,0); nextBtn.Position=UDim2.new(1,-64,0,0)
nextBtn.BackgroundColor3=Color3.fromRGB(9,19,32); nextBtn.TextColor3=Color3.fromRGB(0,185,235)
nextBtn.Font=Enum.Font.GothamBold; nextBtn.TextSize=11; nextBtn.Text="NEXT ▶"
nextBtn.BorderSizePixel=0; nextBtn.ZIndex=7; nextBtn.Parent=pageRow; corner(nextBtn,4); stroke(nextBtn,Color3.fromRGB(16,46,70),1)

-- ══════════════════════════════════════════════════════════════════════
--  PLAYBACK HELPERS
-- ══════════════════════════════════════════════════════════════════════
local function unfreezeChar()
    local c=player.Character; if not c then return end
    local h=c:FindFirstChild("Humanoid"); if not h then return end
    h.WalkSpeed=16; h.JumpPower=50
end

local function stopEmote()
    if currentTrack then pcall(function() currentTrack:Stop() end); currentTrack=nil end
    if not freezeEnabled then unfreezeChar() end
end

local function resolveAnimId(id)
    local ok,objects=pcall(function() return game:GetObjects("rbxassetid://"..tostring(id)) end)
    if ok and objects then
        local function findAnim(obj)
            if obj:IsA("Animation") then
                local raw=obj.AnimationId:gsub("rbxassetid://",""):gsub("http://www.roblox.com/asset/%?id=","")
                local n=tonumber(raw); if n and n>0 then return n end
            end
            for _,c in ipairs(obj:GetChildren()) do local f=findAnim(c); if f then return f end end
        end
        for _,obj in ipairs(objects) do
            pcall(function() obj.Parent=workspace end)
            local found=findAnim(obj)
            task.delay(1,function() pcall(function() obj:Destroy() end) end)
            if found then return found end
        end
    end
    return tonumber(id)
end

local function playEmoteItem(item)
    local c=player.Character; if not c then return end
    local h=c:FindFirstChild("Humanoid"); if not h then return end
    local a=h:FindFirstChild("Animator"); if not a then return end
    stopEmote()
    task.spawn(function()
        local animId=resolveAnimId(item.id); if not animId then return end
        local anim=Instance.new("Animation"); anim.AnimationId="rbxassetid://"..tostring(animId)
        local ok2,track=pcall(function() return a:LoadAnimation(anim) end)
        if not ok2 or not track then return end
        track:Play(); track:AdjustSpeed(emoteSpeed); currentTrack=track
        if freezeEnabled then
            h.WalkSpeed=0; h.JumpPower=0
            track.Stopped:Connect(function() if freezeEnabled then unfreezeChar() end end)
        end
    end)
end

-- resolve full animation pack mappings (all 7 slots)
local function resolveMappings(pack)
    local cacheKey=tostring(pack.id)
    if animPackCache[cacheKey] then return animPackCache[cacheKey] end
    local mappings={}
    local bundledItems=pack.bundledItems
    if type(bundledItems)~="table" then return mappings end
    for _, assetIds in pairs(bundledItems) do
        local ids = type(assetIds)=="table" and assetIds or {assetIds}
        for _, assetId in ipairs(ids) do
            local ok,objects=pcall(function() return game:GetObjects("rbxassetid://"..tostring(assetId)) end)
            if ok and objects then
                local function searchTree(parent, path)
                    for _,child in pairs(parent:GetChildren()) do
                        if child:IsA("Animation") then
                            local parts=(path.."."..child.Name):split(".")
                            mappings[#mappings+1]={
                                category=parts[#parts-1],
                                name=parts[#parts],
                                animationId=child.AnimationId
                            }
                        elseif #child:GetChildren()>0 then
                            searchTree(child, path.."."..child.Name)
                        end
                    end
                end
                for _,obj in pairs(objects) do
                    searchTree(obj, obj.Name)
                    obj.Parent=workspace
                    task.delay(1,function() pcall(function() obj:Destroy() end) end)
                end
            end
        end
    end
    animPackCache[cacheKey]=mappings
    return mappings
end

-- apply full pack to all slots at once
local function applyFullPack(pack)
    local c=player.Character; if not c then return end
    local h=c:FindFirstChild("Humanoid"); if not h then return end
    local animate=c:FindFirstChild("Animate"); if not animate then return end
    for _,track in pairs(h:GetPlayingAnimationTracks()) do track:Stop() end
    task.spawn(function()
        local mappings=resolveMappings(pack)
        if #mappings==0 then return end
        for _,m in pairs(mappings) do
            local catFolder=animate:FindFirstChild(m.category)
            if catFolder then
                for _,animObj in ipairs(catFolder:GetChildren()) do
                    if animObj:IsA("Animation") then
                        animObj.AnimationId=m.animationId
                    end
                end
            end
        end
        animate.Disabled=true; animate.Disabled=false
    end)
end

-- apply one specific slot (e.g. "walk") with a specific animation id
local function applySlot(slotName, animId)
    local c=player.Character; if not c then return end
    local h=c:FindFirstChild("Humanoid"); if not h then return end
    local animate=c:FindFirstChild("Animate"); if not animate then return end
    local catFolder=animate:FindFirstChild(slotName)
    if not catFolder then return end
    for _,animObj in ipairs(catFolder:GetChildren()) do
        if animObj:IsA("Animation") then
            animObj.AnimationId="rbxassetid://"..tostring(animId)
        end
    end
    animate.Disabled=true; animate.Disabled=false
end

-- stop on move
local function setupMoveStop(char)
    if moveConn then moveConn:Disconnect(); moveConn=nil end
    local h=char:FindFirstChildOfClass("Humanoid"); if not h then return end
    moveConn=h:GetPropertyChangedSignal("MoveDirection"):Connect(function()
        if h.MoveDirection.Magnitude>0 and currentTrack then stopEmote(); unfreezeChar() end
    end)
end
setupMoveStop(character)

-- ══════════════════════════════════════════════════════════════════════
--  RENDER LIST (emotes & animation packs)
-- ══════════════════════════════════════════════════════════════════════
local function getList()
    return currentTab=="emotes" and filtEmotes or filtPacks
end

local function clearList()
    for _,c in ipairs(scrollFrame:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
end

local function renderPage()
    clearList()
    local list=getList()
    local total=math.max(1,math.ceil(#list/PER_PAGE))
    currentPage=math.clamp(currentPage,1,total)
    pageLbl.Text="Page "..currentPage.." / "..total
    prevBtn.TextTransparency=currentPage==1 and 0.55 or 0
    nextBtn.TextTransparency=currentPage==total and 0.55 or 0

    local s=(currentPage-1)*PER_PAGE+1
    local e=math.min(s+PER_PAGE-1,#list)

    for i=s,e do
        local item=list[i]; if not item then break end
        local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,32)
        row.BackgroundColor3=Color3.fromRGB(10,18,28); row.BorderSizePixel=0
        row.LayoutOrder=i; row.ZIndex=7; row.Parent=scrollFrame; corner(row,5)

        local nameLbl=Instance.new("TextLabel"); nameLbl.Size=UDim2.new(1,-68,1,0); nameLbl.Position=UDim2.new(0,9,0,0)
        nameLbl.BackgroundTransparency=1; nameLbl.Text=item.name; nameLbl.TextColor3=Color3.fromRGB(180,208,228)
        nameLbl.Font=Enum.Font.Gotham; nameLbl.TextSize=12; nameLbl.TextXAlignment=Enum.TextXAlignment.Left
        nameLbl.TextTruncate=Enum.TextTruncate.AtEnd; nameLbl.ZIndex=8; nameLbl.Parent=row

        local playBtn=Instance.new("TextButton"); playBtn.Size=UDim2.new(0,50,0,22); playBtn.Position=UDim2.new(1,-55,0.5,-11)
        playBtn.BackgroundColor3=Color3.fromRGB(0,46,74); playBtn.TextColor3=Color3.fromRGB(0,205,255)
        playBtn.Font=Enum.Font.GothamBold; playBtn.TextSize=10
        playBtn.Text=currentTab=="emotes" and "▶ PLAY" or "⚡ APPLY"
        playBtn.BorderSizePixel=0; playBtn.ZIndex=9; playBtn.Parent=row; corner(playBtn,4); stroke(playBtn,Color3.fromRGB(0,90,140),1)

        row.MouseEnter:Connect(function() tw(row,0.07,{BackgroundColor3=Color3.fromRGB(13,25,40)}) end)
        row.MouseLeave:Connect(function() tw(row,0.07,{BackgroundColor3=Color3.fromRGB(10,18,28)}) end)

        playBtn.MouseButton1Click:Connect(function()
            tw(playBtn,0.07,{BackgroundColor3=Color3.fromRGB(0,70,110)})
            task.delay(0.13,function() tw(playBtn,0.07,{BackgroundColor3=Color3.fromRGB(0,46,74)}) end)
            if currentTab=="emotes" then
                playEmoteItem(item)
            else
                applyFullPack(item)
            end
        end)
    end

    scrollFrame.CanvasSize=UDim2.new(0,0,0,listLayout.AbsoluteContentSize.Y+6)
    scrollFrame.CanvasPosition=Vector2.new(0,0)
end

-- ══════════════════════════════════════════════════════════════════════
--  CUSTOMIZE TAB
-- ══════════════════════════════════════════════════════════════════════
local slotFrames = {}  -- slot -> { frame, nameLbl, clearBtn }

local function buildCustomizeTab()
    -- clear old
    for _,c in ipairs(customPanel:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    slotFrames={}

    -- header note
    local hdr=Instance.new("TextLabel"); hdr.Size=UDim2.new(1,0,0,24); hdr.BackgroundTransparency=1
    hdr.Text="Set each slot independently. Click a pack row then choose slot."
    hdr.TextColor3=Color3.fromRGB(60,100,130); hdr.Font=Enum.Font.Gotham; hdr.TextSize=10
    hdr.TextWrapped=true; hdr.ZIndex=7; hdr.LayoutOrder=0; hdr.Parent=customPanel

    for idx, slot in ipairs(SLOTS) do
        local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,44)
        row.BackgroundColor3=Color3.fromRGB(9,17,27); row.BorderSizePixel=0
        row.LayoutOrder=idx; row.ZIndex=7; row.Parent=customPanel; corner(row,6)

        -- slot label
        local slotLbl=Instance.new("TextLabel"); slotLbl.Size=UDim2.new(0,82,1,0); slotLbl.Position=UDim2.new(0,8,0,0)
        slotLbl.BackgroundTransparency=1; slotLbl.Text=SLOT_LABELS[slot]
        slotLbl.TextColor3=Color3.fromRGB(0,190,240); slotLbl.Font=Enum.Font.GothamBold; slotLbl.TextSize=11
        slotLbl.TextXAlignment=Enum.TextXAlignment.Left; slotLbl.ZIndex=8; slotLbl.Parent=row

        -- current value display
        local valLbl=Instance.new("TextLabel"); valLbl.Size=UDim2.new(1,-172,1,0); valLbl.Position=UDim2.new(0,90,0,0)
        valLbl.BackgroundTransparency=1
        valLbl.Text=customSlots[slot] and customSlots[slot].name or "— default —"
        valLbl.TextColor3=customSlots[slot] and Color3.fromRGB(0,220,130) or Color3.fromRGB(50,80,100)
        valLbl.Font=Enum.Font.Gotham; valLbl.TextSize=11; valLbl.TextXAlignment=Enum.TextXAlignment.Left
        valLbl.TextTruncate=Enum.TextTruncate.AtEnd; valLbl.ZIndex=8; valLbl.Parent=row

        -- clear button
        local clearBtn=Instance.new("TextButton"); clearBtn.Size=UDim2.new(0,50,0,22); clearBtn.Position=UDim2.new(1,-56,0.5,-11)
        clearBtn.BackgroundColor3=Color3.fromRGB(22,8,8); clearBtn.TextColor3=Color3.fromRGB(255,70,70)
        clearBtn.Font=Enum.Font.GothamBold; clearBtn.TextSize=10; clearBtn.Text="RESET"
        clearBtn.BorderSizePixel=0; clearBtn.ZIndex=9; clearBtn.Parent=row; corner(clearBtn,4)

        slotFrames[slot]={valLbl=valLbl, clearBtn=clearBtn}

        clearBtn.MouseButton1Click:Connect(function()
            customSlots[slot]=nil
            valLbl.Text="— default —"; valLbl.TextColor3=Color3.fromRGB(50,80,100)
        end)

        row.MouseEnter:Connect(function() tw(row,0.07,{BackgroundColor3=Color3.fromRGB(12,22,36)}) end)
        row.MouseLeave:Connect(function() tw(row,0.07,{BackgroundColor3=Color3.fromRGB(9,17,27)}) end)
    end

    -- apply all button
    local applyAllBtn=Instance.new("TextButton"); applyAllBtn.Size=UDim2.new(1,0,0,34)
    applyAllBtn.BackgroundColor3=Color3.fromRGB(0,45,72); applyAllBtn.TextColor3=Color3.fromRGB(0,210,255)
    applyAllBtn.Font=Enum.Font.GothamBold; applyAllBtn.TextSize=13; applyAllBtn.Text="⚡  APPLY ALL CUSTOM SLOTS"
    applyAllBtn.BorderSizePixel=0; applyAllBtn.ZIndex=7; applyAllBtn.LayoutOrder=99; applyAllBtn.Parent=customPanel
    corner(applyAllBtn,6); stroke(applyAllBtn,Color3.fromRGB(0,100,150),1)

    applyAllBtn.MouseButton1Click:Connect(function()
        local applied=0
        for slot, data in pairs(customSlots) do
            if data and data.id then
                applySlot(slot, data.id)
                applied=applied+1
            end
        end
        statusLbl.Text=applied.." slots applied"
    end)

    -- reset all button
    local resetAllBtn=Instance.new("TextButton"); resetAllBtn.Size=UDim2.new(1,0,0,28)
    resetAllBtn.BackgroundColor3=Color3.fromRGB(22,8,8); resetAllBtn.TextColor3=Color3.fromRGB(255,70,70)
    resetAllBtn.Font=Enum.Font.GothamBold; resetAllBtn.TextSize=11; resetAllBtn.Text="🗑  RESET ALL SLOTS"
    resetAllBtn.BorderSizePixel=0; resetAllBtn.ZIndex=7; resetAllBtn.LayoutOrder=100; resetAllBtn.Parent=customPanel
    corner(resetAllBtn,6)

    resetAllBtn.MouseButton1Click:Connect(function()
        customSlots={}
        buildCustomizeTab()
    end)

    customPanel.CanvasSize=UDim2.new(0,0,0,customLayout.AbsoluteContentSize.Y+10)
    customPanel.CanvasPosition=Vector2.new(0,0)
end

-- ── slot picker popup ─────────────────────────────────────────────────
-- appears when you right-click (or long-tap) an animation pack row
-- Shows 7 slot buttons to assign that pack's animation to a specific slot

local slotPicker = Instance.new("Frame"); slotPicker.Size=UDim2.new(0,210,0,240)
slotPicker.BackgroundColor3=Color3.fromRGB(9,16,26); slotPicker.BorderSizePixel=0; slotPicker.ZIndex=30
slotPicker.Visible=false; slotPicker.Parent=root; corner(slotPicker,8); stroke(slotPicker,Color3.fromRGB(0,160,210),1.5)

local spTitle=Instance.new("TextLabel"); spTitle.Size=UDim2.new(1,0,0,28); spTitle.BackgroundTransparency=1
spTitle.Text="ASSIGN SLOT"; spTitle.TextColor3=Color3.fromRGB(0,200,255); spTitle.Font=Enum.Font.GothamBold
spTitle.TextSize=12; spTitle.ZIndex=31; spTitle.Parent=slotPicker

local spClose=Instance.new("TextButton"); spClose.Size=UDim2.new(0,20,0,20); spClose.Position=UDim2.new(1,-24,0,4)
spClose.BackgroundColor3=Color3.fromRGB(140,25,40); spClose.TextColor3=Color3.fromRGB(255,255,255)
spClose.Font=Enum.Font.GothamBold; spClose.TextSize=11; spClose.Text="✕"; spClose.BorderSizePixel=0
spClose.ZIndex=32; spClose.Parent=slotPicker; corner(spClose,4)
spClose.MouseButton1Click:Connect(function() slotPicker.Visible=false end)

local spPackLbl=Instance.new("TextLabel"); spPackLbl.Size=UDim2.new(1,-8,0,18); spPackLbl.Position=UDim2.new(0,4,0,28)
spPackLbl.BackgroundTransparency=1; spPackLbl.Text=""; spPackLbl.TextColor3=Color3.fromRGB(80,130,160)
spPackLbl.Font=Enum.Font.Gotham; spPackLbl.TextSize=10; spPackLbl.ZIndex=31; spPackLbl.TextTruncate=Enum.TextTruncate.AtEnd
spPackLbl.Parent=slotPicker

local spBtnHolder=Instance.new("Frame"); spBtnHolder.Size=UDim2.new(1,-8,1,-50); spBtnHolder.Position=UDim2.new(0,4,0,48)
spBtnHolder.BackgroundTransparency=1; spBtnHolder.ZIndex=31; spBtnHolder.Parent=slotPicker
local spList=Instance.new("UIListLayout"); spList.SortOrder=Enum.SortOrder.LayoutOrder; spList.Padding=UDim.new(0,3); spList.Parent=spBtnHolder

local currentPickerPack = nil

local function showSlotPicker(pack, mousePos)
    currentPickerPack = pack
    spPackLbl.Text = pack.name
    -- position picker near mouse
    local sx = math.clamp(mousePos.X - 105, 4, root.AbsoluteSize.X - 214)
    local sy = math.clamp(mousePos.Y - 20, 4, root.AbsoluteSize.Y - 244)
    slotPicker.Position = UDim2.new(0, sx, 0, sy)
    slotPicker.Visible = true

    -- rebuild slot buttons
    for _,c in ipairs(spBtnHolder:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end

    for idx, slot in ipairs(SLOTS) do
        local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,0,26)
        btn.BackgroundColor3=Color3.fromRGB(11,21,34); btn.TextColor3=Color3.fromRGB(165,200,225)
        btn.Font=Enum.Font.GothamBold; btn.TextSize=11; btn.BorderSizePixel=0
        btn.LayoutOrder=idx; btn.ZIndex=32; btn.Parent=spBtnHolder; corner(btn,4)
        -- show current assignment
        local assigned = customSlots[slot]
        local indicator = assigned and " ✓" or ""
        btn.Text = SLOT_LABELS[slot] .. indicator
        btn.TextColor3 = assigned and Color3.fromRGB(0,220,130) or Color3.fromRGB(165,200,225)

        btn.MouseButton1Click:Connect(function()
            -- resolve which animation id to use for this slot
            task.spawn(function()
                local mappings = resolveMappings(pack)
                -- find mapping matching slot
                local animId = nil
                local slotLower = slot:lower()
                for _, m in ipairs(mappings) do
                    if m.category:lower() == slotLower then
                        animId = m.animationId:gsub("rbxassetid://","")
                        break
                    end
                end
                if not animId then
                    -- fallback: use pack id directly
                    animId = tostring(pack.id)
                end
                customSlots[slot] = { id=animId, name=pack.name }
                -- update customize tab if visible
                if slotFrames[slot] then
                    slotFrames[slot].valLbl.Text = pack.name
                    slotFrames[slot].valLbl.TextColor3 = Color3.fromRGB(0,220,130)
                end
                -- immediately apply
                applySlot(slot, animId)
                slotPicker.Visible = false
            end)
        end)

        btn.MouseEnter:Connect(function() tw(btn,0.07,{BackgroundColor3=Color3.fromRGB(0,45,70)}) end)
        btn.MouseLeave:Connect(function()
            btn.BackgroundColor3 = customSlots[slot] and Color3.fromRGB(0,32,22) or Color3.fromRGB(11,21,34)
        end)
    end
end

-- ══════════════════════════════════════════════════════════════════════
--  TABS
-- ══════════════════════════════════════════════════════════════════════
local function refreshTabs()
    local tabs={emotes=tabEmoteBtn, packs=tabPackBtn, customize=tabCustomBtn}
    for name, btn in pairs(tabs) do
        if name==currentTab then
            btn.BackgroundColor3=Color3.fromRGB(0,52,82); btn.TextColor3=Color3.fromRGB(0,205,255)
        else
            btn.BackgroundColor3=Color3.fromRGB(11,22,35); btn.TextColor3=Color3.fromRGB(65,105,135)
        end
    end
    -- show/hide panels
    local isList = currentTab=="emotes" or currentTab=="packs"
    scrollFrame.Visible = isList
    pageRow.Visible     = isList
    searchBg.Visible    = isList
    customPanel.Visible = currentTab=="customize"
end

local function switchTab(tab)
    currentTab=tab; currentPage=1
    if tab~="customize" then
        searchBox.Text=""
        filtEmotes=allEmotes; filtPacks=allAnimPacks
        statusLbl.Text=(tab=="emotes" and #allEmotes or #allAnimPacks).." loaded"
        renderPage()
    else
        buildCustomizeTab()
        statusLbl.Text="customize slots"
    end
    refreshTabs()
end

tabEmoteBtn.MouseButton1Click:Connect(function() switchTab("emotes") end)
tabPackBtn.MouseButton1Click:Connect(function()  switchTab("packs")  end)
tabCustomBtn.MouseButton1Click:Connect(function() switchTab("customize") end)
refreshTabs()

-- ══════════════════════════════════════════════════════════════════════
--  RIGHT-CLICK on pack row = slot picker
-- (We intercept this by adding a secondary invisible button overlay)
-- We rebuild renderPage to add right-click support for packs
-- ══════════════════════════════════════════════════════════════════════
-- Override renderPage to also add right-click for packs
local _origRenderPage = renderPage
renderPage = function()
    _origRenderPage()
    if currentTab ~= "packs" then return end
    -- add right-click listener to each pack row's play button area
    for _, row in ipairs(scrollFrame:GetChildren()) do
        if row:IsA("Frame") then
            local item = allAnimPacks[row.LayoutOrder]
            if not item then
                -- try from filtPacks
                local idx = row.LayoutOrder
                local s=(currentPage-1)*PER_PAGE+1
                local relIdx = idx - s + 1
                item = filtPacks[idx]
            end
            if item then
                local rightBtn=Instance.new("TextButton"); rightBtn.Size=UDim2.new(1,-58,1,0)
                rightBtn.Position=UDim2.new(0,0,0,0); rightBtn.BackgroundTransparency=1; rightBtn.Text=""
                rightBtn.ZIndex=10; rightBtn.Parent=row

                -- InputBegan for right-click
                rightBtn.InputBegan:Connect(function(inp)
                    if inp.UserInputType==Enum.UserInputType.MouseButton2 then
                        showSlotPicker(item, inp.Position)
                    end
                end)
                rightBtn.MouseButton1Click:Connect(function()
                    -- left click still does full apply via the play btn
                end)
            end
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════
--  SEARCH
-- ══════════════════════════════════════════════════════════════════════
local searchDebounce
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    if searchDebounce then task.cancel(searchDebounce) end
    searchDebounce=task.delay(0.2,function()
        local q=searchBox.Text:lower():gsub("^%s+",""):gsub("%s+$","")
        local src=currentTab=="emotes" and allEmotes or allAnimPacks
        local out=q=="" and src or (function()
            local t={}; for _,v in ipairs(src) do if v.name:lower():find(q,1,true) then t[#t+1]=v end end; return t
        end)()
        if currentTab=="emotes" then filtEmotes=out else filtPacks=out end
        statusLbl.Text=#out..(currentTab=="emotes" and " emotes" or " packs")
        currentPage=1; renderPage()
    end)
end)

-- ══════════════════════════════════════════════════════════════════════
--  SPEED / FREEZE / STOP
-- ══════════════════════════════════════════════════════════════════════
local function updateSpLbl() spValLbl.Text=string.format("%.1fx",emoteSpeed) end

spDown.MouseButton1Click:Connect(function()
    emoteSpeed=math.max(0.1,math.floor((emoteSpeed-0.1)*10+0.5)/10); updateSpLbl()
    if currentTrack and currentTrack.IsPlaying then currentTrack:AdjustSpeed(emoteSpeed) end
end)
spUp.MouseButton1Click:Connect(function()
    emoteSpeed=math.min(5.0,math.floor((emoteSpeed+0.1)*10+0.5)/10); updateSpLbl()
    if currentTrack and currentTrack.IsPlaying then currentTrack:AdjustSpeed(emoteSpeed) end
end)
freezeBtn.MouseButton1Click:Connect(function()
    freezeEnabled=not freezeEnabled
    if freezeEnabled then freezeBtn.Text="❄ FREEZE: ON"; freezeBtn.BackgroundColor3=Color3.fromRGB(0,38,25); freezeBtn.TextColor3=Color3.fromRGB(0,255,145)
    else freezeBtn.Text="❄ FREEZE: OFF"; freezeBtn.BackgroundColor3=Color3.fromRGB(7,22,15); freezeBtn.TextColor3=Color3.fromRGB(0,195,115); unfreezeChar() end
end)
stopBtn.MouseButton1Click:Connect(function() stopEmote(); unfreezeChar() end)

-- ══════════════════════════════════════════════════════════════════════
--  PAGINATION
-- ══════════════════════════════════════════════════════════════════════
prevBtn.MouseButton1Click:Connect(function()
    if currentPage>1 then currentPage-=1; renderPage() end
end)
nextBtn.MouseButton1Click:Connect(function()
    local total=math.ceil(#getList()/PER_PAGE)
    if currentPage<total then currentPage+=1; renderPage() end
end)

-- ══════════════════════════════════════════════════════════════════════
--  OPEN / CLOSE
-- ══════════════════════════════════════════════════════════════════════
local function setOpen(open)
    guiOpen=open
    if open then
        panel.Visible=true; panel.BackgroundTransparency=0
        pillIcon.Text="✕"; pillIcon.TextColor3=Color3.fromRGB(255,75,75)
        tw(pillBg,0.18,{BackgroundColor3=Color3.fromRGB(25,6,10)}); pillStroke.Color=Color3.fromRGB(255,80,80)
    else
        tw(panel,0.14,{BackgroundTransparency=1})
        task.delay(0.15,function() if not guiOpen then panel.Visible=false end end)
        pillIcon.Text="▶"; pillIcon.TextColor3=Color3.fromRGB(0,215,255)
        tw(pillBg,0.18,{BackgroundColor3=Color3.fromRGB(5,12,22)}); pillStroke.Color=Color3.fromRGB(0,200,255)
    end
end
pillBtn.MouseButton1Click:Connect(function() setOpen(not guiOpen) end)
closeBtn.MouseButton1Click:Connect(function() setOpen(false) end)

-- ══════════════════════════════════════════════════════════════════════
--  DRAG
-- ══════════════════════════════════════════════════════════════════════
do
    local dragging,dragStart,startPos=false,nil,nil
    titleBar.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; dragStart=inp.Position; startPos=panel.Position end
    end)
    table.insert(connections,UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType==Enum.UserInputType.MouseMovement then
            local d=inp.Position-dragStart
            panel.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end))
    table.insert(connections,UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
    end))
end

-- ══════════════════════════════════════════════════════════════════════
--  CHARACTER RESPAWN
-- ══════════════════════════════════════════════════════════════════════
table.insert(connections,player.CharacterAdded:Connect(function(char)
    character=char; humanoid=char:WaitForChild("Humanoid"); currentTrack=nil; setupMoveStop(char)
end))

-- ══════════════════════════════════════════════════════════════════════
--  LOAD DATA
-- ══════════════════════════════════════════════════════════════════════
task.spawn(function()
    -- Emotes
    local ok1,r1=pcall(function() return game:HttpGet("https://raw.githubusercontent.com/7yd7/sniper-Emote/refs/heads/test/EmoteSniper.json") end)
    if ok1 and r1 then
        local ok2,data=pcall(function() return HttpService:JSONDecode(r1) end)
        if ok2 and data and data.data then allEmotes=data.data; filtEmotes=allEmotes end
    end

    -- Animation packs
    local ok3,r3=pcall(function() return game:HttpGet("https://raw.githubusercontent.com/7yd7/sniper-Emote/refs/heads/test/AnimationSniper.json") end)
    if ok3 and r3 then
        local ok4,data=pcall(function() return HttpService:JSONDecode(r3) end)
        if ok4 and data and data.data then allAnimPacks=data.data; filtPacks=allAnimPacks end
    end

    if currentTab=="emotes" then statusLbl.Text=#allEmotes.." emotes"
    elseif currentTab=="packs" then statusLbl.Text=#allAnimPacks.." packs" end
    renderPage()
end)
