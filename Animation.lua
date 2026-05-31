-- Animation Browser v4 for Delta
-- Smaller UI | Emotes | Packs | Customize (per-slot mix)

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

local allEmotes    = {}
local allPacks     = {}
local filtEmotes   = {}
local filtPacks    = {}
local currentPage  = 1
local PER_PAGE     = 14
local currentTab   = "emotes"
local currentTrack = nil
local freezeOn     = false
local emoteSpeed   = 1.0
local guiOpen      = true
local conns        = {}
local moveConn     = nil
local packCache    = {}

-- per-slot assignments: slot -> {id, name}
local customSlots  = {}
local SLOTS = {"idle","walk","run","jump","fall","swim","climb"}
local SLOT_ICONS = {idle="🧍",walk="🚶",run="🏃",jump="⬆",fall="⬇",swim="🏊",climb="🧗"}

-- ── utils ─────────────────────────────────────────────────────────────
local function tw(o,t,p) TweenService:Create(o,TweenInfo.new(t,Enum.EasingStyle.Quad),p):Play() end
local function mkCorner(p,r) local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,r or 6);c.Parent=p end
local function mkStroke(p,col,th) local s=Instance.new("UIStroke");s.Color=col or Color3.fromRGB(20,40,60);s.Thickness=th or 1;s.Parent=p end
local function mkLabel(parent,text,size,color,font,xa)
    local l=Instance.new("TextLabel");l.BackgroundTransparency=1;l.Text=text
    l.TextSize=size or 12;l.TextColor3=color or Color3.fromRGB(180,210,230)
    l.Font=font or Enum.Font.Gotham;l.TextXAlignment=xa or Enum.TextXAlignment.Left
    l.Size=UDim2.new(1,0,1,0);l.ZIndex=8;l.Parent=parent;return l
end

-- ── cleanup ───────────────────────────────────────────────────────────
pcall(function()
    if CoreGui:FindFirstChild("AnimBrowserV4") then CoreGui.AnimBrowserV4:Destroy() end
end)
local root=Instance.new("ScreenGui");root.Name="AnimBrowserV4"
root.ResetOnSpawn=false;root.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
if not pcall(function() root.Parent=CoreGui end) then root.Parent=player.PlayerGui end

_G.EmoteBrowserDestroy=function()
    _G.EmoteBrowserRunning=false
    for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    if moveConn then moveConn:Disconnect() end
    pcall(function() root:Destroy() end)
end

-- ══════════════════════════════════════════════════════════════════════
--  PILL BUTTON
-- ══════════════════════════════════════════════════════════════════════
local pill=Instance.new("Frame");pill.Size=UDim2.new(0,46,0,46)
pill.Position=UDim2.new(0,12,1,-58);pill.BackgroundTransparency=1;pill.ZIndex=20;pill.Parent=root

local pillBg=Instance.new("Frame");pillBg.Size=UDim2.new(1,0,1,0)
pillBg.BackgroundColor3=Color3.fromRGB(5,11,20);pillBg.BorderSizePixel=0;pillBg.ZIndex=20;pillBg.Parent=pill
mkCorner(pillBg,13)
local pillS=Instance.new("UIStroke");pillS.Color=Color3.fromRGB(0,195,255);pillS.Thickness=2;pillS.Parent=pillBg
TweenService:Create(pillS,TweenInfo.new(1.4,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Thickness=4}):Play()

local pillIcon=Instance.new("TextLabel");pillIcon.Size=UDim2.new(1,0,1,0);pillIcon.BackgroundTransparency=1
pillIcon.Text="▶";pillIcon.TextColor3=Color3.fromRGB(0,210,255);pillIcon.Font=Enum.Font.GothamBold
pillIcon.TextSize=20;pillIcon.ZIndex=21;pillIcon.Parent=pillBg

local pillBtn=Instance.new("TextButton");pillBtn.Size=UDim2.new(1,0,1,0)
pillBtn.BackgroundTransparency=1;pillBtn.Text="";pillBtn.ZIndex=22;pillBtn.Parent=pill

-- ══════════════════════════════════════════════════════════════════════
--  MAIN PANEL  (smaller: 380x430, centered)
-- ══════════════════════════════════════════════════════════════════════
local panel=Instance.new("Frame");panel.Name="Panel"
panel.Size=UDim2.new(0,380,0,430);panel.Position=UDim2.new(0.5,-190,0.5,-215)
panel.BackgroundColor3=Color3.fromRGB(7,12,20);panel.BorderSizePixel=0;panel.ZIndex=5;panel.Parent=root
mkCorner(panel,10);mkStroke(panel,Color3.fromRGB(15,35,55),1.5)

-- title bar (draggable)
local titleBar=Instance.new("Frame");titleBar.Size=UDim2.new(1,0,0,30)
titleBar.BackgroundColor3=Color3.fromRGB(8,16,27);titleBar.BorderSizePixel=0;titleBar.ZIndex=6;titleBar.Parent=panel
mkCorner(titleBar,10)
local tbFix=Instance.new("Frame");tbFix.Size=UDim2.new(1,0,0.5,0);tbFix.Position=UDim2.new(0,0,0.5,0)
tbFix.BackgroundColor3=Color3.fromRGB(8,16,27);tbFix.BorderSizePixel=0;tbFix.ZIndex=6;tbFix.Parent=titleBar

local titleLbl=Instance.new("TextLabel");titleLbl.Size=UDim2.new(1,-70,1,0);titleLbl.Position=UDim2.new(0,10,0,0)
titleLbl.BackgroundTransparency=1;titleLbl.Text="ANIMATION BROWSER"
titleLbl.TextColor3=Color3.fromRGB(0,195,255);titleLbl.Font=Enum.Font.GothamBold;titleLbl.TextSize=12
titleLbl.TextXAlignment=Enum.TextXAlignment.Left;titleLbl.ZIndex=7;titleLbl.Parent=titleBar

local statusLbl=Instance.new("TextLabel");statusLbl.Size=UDim2.new(0,90,1,0);statusLbl.Position=UDim2.new(0,175,0,0)
statusLbl.BackgroundTransparency=1;statusLbl.Text="loading...";statusLbl.TextColor3=Color3.fromRGB(40,75,100)
statusLbl.Font=Enum.Font.Gotham;statusLbl.TextSize=9;statusLbl.TextXAlignment=Enum.TextXAlignment.Left
statusLbl.ZIndex=7;statusLbl.Parent=titleBar

local closeBtn=Instance.new("TextButton");closeBtn.Size=UDim2.new(0,20,0,20);closeBtn.Position=UDim2.new(1,-25,0.5,-10)
closeBtn.BackgroundColor3=Color3.fromRGB(140,25,42);closeBtn.TextColor3=Color3.fromRGB(255,255,255)
closeBtn.Font=Enum.Font.GothamBold;closeBtn.TextSize=11;closeBtn.Text="✕"
closeBtn.BorderSizePixel=0;closeBtn.ZIndex=8;closeBtn.Parent=titleBar;mkCorner(closeBtn,4)

-- ── 3 tabs ────────────────────────────────────────────────────────────
local tabBg=Instance.new("Frame");tabBg.Size=UDim2.new(1,-14,0,24);tabBg.Position=UDim2.new(0,7,0,36)
tabBg.BackgroundColor3=Color3.fromRGB(9,17,28);tabBg.BorderSizePixel=0;tabBg.ZIndex=6;tabBg.Parent=panel
mkCorner(tabBg,5)
do local p=Instance.new("UIPadding");p.PaddingLeft=UDim.new(0,2);p.PaddingRight=UDim.new(0,2)
   p.PaddingTop=UDim.new(0,2);p.PaddingBottom=UDim.new(0,2);p.Parent=tabBg end
do local l=Instance.new("UIListLayout");l.FillDirection=Enum.FillDirection.Horizontal
   l.SortOrder=Enum.SortOrder.LayoutOrder;l.Padding=UDim.new(0,2);l.Parent=tabBg end

local function mkTab(text,order)
    local b=Instance.new("TextButton");b.Size=UDim2.new(1/3,-2,1,0)
    b.BackgroundColor3=Color3.fromRGB(10,20,33);b.TextColor3=Color3.fromRGB(60,100,130)
    b.Font=Enum.Font.GothamBold;b.TextSize=10;b.Text=text
    b.BorderSizePixel=0;b.LayoutOrder=order;b.ZIndex=7;b.Parent=tabBg;mkCorner(b,4);return b
end
local tabE=mkTab("🎭 EMOTES",1)
local tabP=mkTab("🏃 PACKS",2)
local tabC=mkTab("🎨 CUSTOMIZE",3)

-- ── search ────────────────────────────────────────────────────────────
local searchBg=Instance.new("Frame");searchBg.Size=UDim2.new(1,-14,0,24);searchBg.Position=UDim2.new(0,7,0,66)
searchBg.BackgroundColor3=Color3.fromRGB(9,18,28);searchBg.BorderSizePixel=0;searchBg.ZIndex=6;searchBg.Parent=panel
mkCorner(searchBg,5);mkStroke(searchBg,Color3.fromRGB(16,40,60),1)
local sIco=Instance.new("TextLabel");sIco.Size=UDim2.new(0,20,1,0);sIco.BackgroundTransparency=1
sIco.Text="🔍";sIco.TextSize=10;sIco.Font=Enum.Font.Gotham;sIco.ZIndex=7;sIco.Parent=searchBg
local searchBox=Instance.new("TextBox");searchBox.Size=UDim2.new(1,-22,1,0);searchBox.Position=UDim2.new(0,20,0,0)
searchBox.BackgroundTransparency=1;searchBox.Text="";searchBox.PlaceholderText="Search..."
searchBox.PlaceholderColor3=Color3.fromRGB(45,75,95);searchBox.TextColor3=Color3.fromRGB(190,215,235)
searchBox.Font=Enum.Font.Gotham;searchBox.TextSize=11;searchBox.TextXAlignment=Enum.TextXAlignment.Left
searchBox.ClearTextOnFocus=false;searchBox.ZIndex=7;searchBox.Parent=searchBg

-- ── controls ─────────────────────────────────────────────────────────
local ctrlRow=Instance.new("Frame");ctrlRow.Size=UDim2.new(1,-14,0,24);ctrlRow.Position=UDim2.new(0,7,0,96)
ctrlRow.BackgroundTransparency=1;ctrlRow.ZIndex=6;ctrlRow.Parent=panel

local function mkCtrl(text,x,w,bg,tc)
    local b=Instance.new("TextButton");b.Size=UDim2.new(0,w,0,20);b.Position=UDim2.new(0,x,0.5,-10)
    b.BackgroundColor3=bg or Color3.fromRGB(10,20,34);b.TextColor3=tc or Color3.fromRGB(170,200,225)
    b.Font=Enum.Font.GothamBold;b.TextSize=10;b.Text=text;b.BorderSizePixel=0;b.ZIndex=7;b.Parent=ctrlRow
    mkCorner(b,4);mkStroke(b,Color3.fromRGB(18,40,62),1);return b
end
local spLbl2=Instance.new("TextLabel");spLbl2.Size=UDim2.new(0,36,1,0);spLbl2.BackgroundTransparency=1
spLbl2.Text="SPEED";spLbl2.TextColor3=Color3.fromRGB(70,115,150);spLbl2.Font=Enum.Font.GothamBold
spLbl2.TextSize=9;spLbl2.ZIndex=7;spLbl2.Parent=ctrlRow
local spDn=mkCtrl("−",36,20)
local spVal=Instance.new("TextLabel");spVal.Size=UDim2.new(0,32,0,18);spVal.Position=UDim2.new(0,58,0.5,-9)
spVal.BackgroundColor3=Color3.fromRGB(9,18,30);spVal.TextColor3=Color3.fromRGB(255,200,45)
spVal.Font=Enum.Font.GothamBold;spVal.TextSize=11;spVal.Text="1.0x";spVal.ZIndex=7;spVal.Parent=ctrlRow
mkCorner(spVal,3)
local spUp2=mkCtrl("+",92,20)
local frzBtn=mkCtrl("❄ OFF",118,58,Color3.fromRGB(6,20,14),Color3.fromRGB(0,190,110));frzBtn.TextSize=10
local stpBtn=mkCtrl("■ STOP",182,54,Color3.fromRGB(20,6,6),Color3.fromRGB(255,70,70));stpBtn.TextSize=10

-- divider
local div=Instance.new("Frame");div.Size=UDim2.new(1,-14,0,1);div.Position=UDim2.new(0,7,0,126)
div.BackgroundColor3=Color3.fromRGB(13,30,48);div.BorderSizePixel=0;div.ZIndex=6;div.Parent=panel

-- ── scroll frame (list) ───────────────────────────────────────────────
local scrollF=Instance.new("ScrollingFrame");scrollF.Size=UDim2.new(1,-14,0,260)
scrollF.Position=UDim2.new(0,7,0,132);scrollF.BackgroundTransparency=1
scrollF.BorderSizePixel=0;scrollF.ScrollBarThickness=3
scrollF.ScrollBarImageColor3=Color3.fromRGB(0,125,175);scrollF.ZIndex=6;scrollF.Parent=panel
local listL=Instance.new("UIListLayout");listL.SortOrder=Enum.SortOrder.LayoutOrder
listL.Padding=UDim.new(0,3);listL.Parent=scrollF

-- ── customize panel ───────────────────────────────────────────────────
local custF=Instance.new("ScrollingFrame");custF.Size=UDim2.new(1,-14,0,260)
custF.Position=UDim2.new(0,7,0,132);custF.BackgroundTransparency=1
custF.BorderSizePixel=0;custF.ScrollBarThickness=3
custF.ScrollBarImageColor3=Color3.fromRGB(0,125,175);custF.ZIndex=6
custF.Visible=false;custF.Parent=panel
local custL=Instance.new("UIListLayout");custL.SortOrder=Enum.SortOrder.LayoutOrder
custL.Padding=UDim.new(0,3);custL.Parent=custF

-- ── page bar ──────────────────────────────────────────────────────────
local pageRow=Instance.new("Frame");pageRow.Size=UDim2.new(1,-14,0,22);pageRow.Position=UDim2.new(0,7,1,-26)
pageRow.BackgroundTransparency=1;pageRow.ZIndex=6;pageRow.Parent=panel

local prevBtn=Instance.new("TextButton");prevBtn.Size=UDim2.new(0,58,1,0)
prevBtn.BackgroundColor3=Color3.fromRGB(8,18,30);prevBtn.TextColor3=Color3.fromRGB(0,180,230)
prevBtn.Font=Enum.Font.GothamBold;prevBtn.TextSize=10;prevBtn.Text="◀ PREV"
prevBtn.BorderSizePixel=0;prevBtn.ZIndex=7;prevBtn.Parent=pageRow;mkCorner(prevBtn,4)

local pageLbl2=Instance.new("TextLabel");pageLbl2.Size=UDim2.new(1,-124,1,0);pageLbl2.Position=UDim2.new(0,63,0,0)
pageLbl2.BackgroundTransparency=1;pageLbl2.Text="1 / 1";pageLbl2.TextColor3=Color3.fromRGB(50,85,110)
pageLbl2.Font=Enum.Font.Gotham;pageLbl2.TextSize=10;pageLbl2.ZIndex=7;pageLbl2.Parent=pageRow

local nextBtn=Instance.new("TextButton");nextBtn.Size=UDim2.new(0,58,1,0);nextBtn.Position=UDim2.new(1,-58,0,0)
nextBtn.BackgroundColor3=Color3.fromRGB(8,18,30);nextBtn.TextColor3=Color3.fromRGB(0,180,230)
nextBtn.Font=Enum.Font.GothamBold;nextBtn.TextSize=10;nextBtn.Text="NEXT ▶"
nextBtn.BorderSizePixel=0;nextBtn.ZIndex=7;nextBtn.Parent=pageRow;mkCorner(nextBtn,4)

-- ══════════════════════════════════════════════════════════════════════
--  PLAYBACK
-- ══════════════════════════════════════════════════════════════════════
local function unfreezeChar()
    local c=player.Character;if not c then return end
    local h=c:FindFirstChild("Humanoid");if not h then return end
    h.WalkSpeed=16;h.JumpPower=50
end
local function stopEmote()
    if currentTrack then pcall(function() currentTrack:Stop() end);currentTrack=nil end
    if not freezeOn then unfreezeChar() end
end
local function resolveAnimId(id)
    local ok,objects=pcall(function() return game:GetObjects("rbxassetid://"..tostring(id)) end)
    if ok and objects then
        local function findAnim(obj)
            if obj:IsA("Animation") then
                local raw=obj.AnimationId:gsub("rbxassetid://",""):gsub("http://www.roblox.com/asset/%?id=","")
                local n=tonumber(raw);if n and n>0 then return n end
            end
            for _,ch in ipairs(obj:GetChildren()) do local f=findAnim(ch);if f then return f end end
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
    local c=player.Character;if not c then return end
    local h=c:FindFirstChild("Humanoid");if not h then return end
    local a=h:FindFirstChild("Animator");if not a then return end
    stopEmote()
    task.spawn(function()
        local animId=resolveAnimId(item.id);if not animId then return end
        local anim=Instance.new("Animation");anim.AnimationId="rbxassetid://"..tostring(animId)
        local ok2,track=pcall(function() return a:LoadAnimation(anim) end)
        if not ok2 or not track then return end
        track:Play();track:AdjustSpeed(emoteSpeed);currentTrack=track
        if freezeOn then
            h.WalkSpeed=0;h.JumpPower=0
            track.Stopped:Connect(function() if freezeOn then unfreezeChar() end end)
        end
    end)
end

-- resolve full pack mappings (category -> animationId)
local function resolveMappings(pack)
    local key=tostring(pack.id)
    if packCache[key] then return packCache[key] end
    local mappings={}
    local bi=pack.bundledItems
    if type(bi)~="table" then return mappings end
    for _,assetIds in pairs(bi) do
        local ids=type(assetIds)=="table" and assetIds or {assetIds}
        for _,assetId in ipairs(ids) do
            local ok,objects=pcall(function() return game:GetObjects("rbxassetid://"..tostring(assetId)) end)
            if ok and objects then
                local function searchTree(parent,path)
                    for _,child in pairs(parent:GetChildren()) do
                        if child:IsA("Animation") then
                            local parts=(path.."."..child.Name):split(".")
                            mappings[#mappings+1]={category=parts[#parts-1],name=parts[#parts],animationId=child.AnimationId}
                        elseif #child:GetChildren()>0 then searchTree(child,path.."."..child.Name) end
                    end
                end
                for _,obj in pairs(objects) do
                    searchTree(obj,obj.Name);obj.Parent=workspace
                    task.delay(1,function() pcall(function() obj:Destroy() end) end)
                end
            end
        end
    end
    packCache[key]=mappings;return mappings
end

local function applySlot(slotName,animId)
    local c=player.Character;if not c then return end
    local h=c:FindFirstChild("Humanoid");if not h then return end
    local animate=c:FindFirstChild("Animate");if not animate then return end
    local cat=animate:FindFirstChild(slotName);if not cat then return end
    for _,animObj in ipairs(cat:GetChildren()) do
        if animObj:IsA("Animation") then animObj.AnimationId="rbxassetid://"..tostring(animId) end
    end
    animate.Disabled=true;animate.Disabled=false
end

local function applyFullPack(pack)
    local c=player.Character;if not c then return end
    local h=c:FindFirstChild("Humanoid");if not h then return end
    local animate=c:FindFirstChild("Animate");if not animate then return end
    for _,track in pairs(h:GetPlayingAnimationTracks()) do track:Stop() end
    task.spawn(function()
        local mappings=resolveMappings(pack)
        if #mappings==0 then return end
        for _,m in pairs(mappings) do
            local cat=animate:FindFirstChild(m.category)
            if cat then
                for _,animObj in ipairs(cat:GetChildren()) do
                    if animObj:IsA("Animation") then animObj.AnimationId=m.animationId end
                end
            end
        end
        animate.Disabled=true;animate.Disabled=false
    end)
end

local function setupMoveStop(char)
    if moveConn then moveConn:Disconnect();moveConn=nil end
    local h=char:FindFirstChildOfClass("Humanoid");if not h then return end
    moveConn=h:GetPropertyChangedSignal("MoveDirection"):Connect(function()
        if h.MoveDirection.Magnitude>0 and currentTrack then stopEmote();unfreezeChar() end
    end)
end
setupMoveStop(character)

-- ══════════════════════════════════════════════════════════════════════
--  CUSTOMIZE TAB  — each slot has its own mini pack picker
-- ══════════════════════════════════════════════════════════════════════
local activeSlotPicker = nil  -- which slot's picker is open

local function closeAllPickers()
    for _,slot in ipairs(SLOTS) do
        if custF:FindFirstChild("picker_"..slot) then
            custF:FindFirstChild("picker_"..slot):Destroy()
        end
    end
    activeSlotPicker=nil
end

local slotRowRefs = {}  -- slot -> {valLbl}

local function buildCustomizeTab()
    for _,c in ipairs(custF:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    slotRowRefs={}; activeSlotPicker=nil

    -- apply all btn
    local applyAll=Instance.new("TextButton");applyAll.Size=UDim2.new(1,0,0,28)
    applyAll.BackgroundColor3=Color3.fromRGB(0,42,68);applyAll.TextColor3=Color3.fromRGB(0,205,255)
    applyAll.Font=Enum.Font.GothamBold;applyAll.TextSize=11;applyAll.Text="⚡  APPLY ALL CUSTOM SLOTS"
    applyAll.BorderSizePixel=0;applyAll.ZIndex=7;applyAll.LayoutOrder=0;applyAll.Parent=custF
    mkCorner(applyAll,5);mkStroke(applyAll,Color3.fromRGB(0,90,140),1)
    applyAll.MouseButton1Click:Connect(function()
        local n=0
        for slot,data in pairs(customSlots) do
            if data and data.id then applySlot(slot,data.id);n+=1 end
        end
        statusLbl.Text=n.." slots applied!"
    end)

    -- reset all
    local resetAll=Instance.new("TextButton");resetAll.Size=UDim2.new(1,0,0,22)
    resetAll.BackgroundColor3=Color3.fromRGB(20,6,6);resetAll.TextColor3=Color3.fromRGB(255,65,65)
    resetAll.Font=Enum.Font.GothamBold;resetAll.TextSize=10;resetAll.Text="🗑  RESET ALL"
    resetAll.BorderSizePixel=0;resetAll.ZIndex=7;resetAll.LayoutOrder=1;resetAll.Parent=custF
    mkCorner(resetAll,5)
    resetAll.MouseButton1Click:Connect(function()
        customSlots={};buildCustomizeTab()
    end)

    -- one row per slot
    for idx,slot in ipairs(SLOTS) do
        local row=Instance.new("Frame");row.Name="slotrow_"..slot;row.Size=UDim2.new(1,0,0,36)
        row.BackgroundColor3=Color3.fromRGB(9,16,26);row.BorderSizePixel=0
        row.LayoutOrder=idx+1;row.ZIndex=7;row.Parent=custF;mkCorner(row,5)

        -- icon + slot name
        local iconLbl=Instance.new("TextLabel");iconLbl.Size=UDim2.new(0,58,1,0);iconLbl.Position=UDim2.new(0,6,0,0)
        iconLbl.BackgroundTransparency=1
        iconLbl.Text=SLOT_ICONS[slot].." "..slot:upper()
        iconLbl.TextColor3=Color3.fromRGB(0,185,235);iconLbl.Font=Enum.Font.GothamBold
        iconLbl.TextSize=10;iconLbl.ZIndex=8;iconLbl.Parent=row

        -- current assigned value
        local data=customSlots[slot]
        local valLbl=Instance.new("TextLabel");valLbl.Size=UDim2.new(1,-140,1,0);valLbl.Position=UDim2.new(0,66,0,0)
        valLbl.BackgroundTransparency=1
        valLbl.Text=data and data.name or "— default —"
        valLbl.TextColor3=data and Color3.fromRGB(0,215,125) or Color3.fromRGB(45,75,95)
        valLbl.Font=Enum.Font.Gotham;valLbl.TextSize=10;valLbl.TextXAlignment=Enum.TextXAlignment.Left
        valLbl.TextTruncate=Enum.TextTruncate.AtEnd;valLbl.ZIndex=8;valLbl.Parent=row
        slotRowRefs[slot]={valLbl=valLbl}

        -- CHANGE button — opens inline picker
        local chgBtn=Instance.new("TextButton");chgBtn.Size=UDim2.new(0,46,0,22);chgBtn.Position=UDim2.new(1,-106,0.5,-11)
        chgBtn.BackgroundColor3=Color3.fromRGB(0,40,65);chgBtn.TextColor3=Color3.fromRGB(0,195,255)
        chgBtn.Font=Enum.Font.GothamBold;chgBtn.TextSize=9;chgBtn.Text="CHANGE"
        chgBtn.BorderSizePixel=0;chgBtn.ZIndex=9;chgBtn.Parent=row;mkCorner(chgBtn,4)

        -- RESET button
        local rstBtn=Instance.new("TextButton");rstBtn.Size=UDim2.new(0,40,0,22);rstBtn.Position=UDim2.new(1,-52,0.5,-11)
        rstBtn.BackgroundColor3=Color3.fromRGB(20,6,6);rstBtn.TextColor3=Color3.fromRGB(255,65,65)
        rstBtn.Font=Enum.Font.GothamBold;rstBtn.TextSize=9;rstBtn.Text="RESET"
        rstBtn.BorderSizePixel=0;rstBtn.ZIndex=9;rstBtn.Parent=row;mkCorner(rstBtn,4)

        rstBtn.MouseButton1Click:Connect(function()
            customSlots[slot]=nil
            valLbl.Text="— default —";valLbl.TextColor3=Color3.fromRGB(45,75,95)
            closeAllPickers()
        end)

        -- CHANGE click → open inline pack picker below this row
        chgBtn.MouseButton1Click:Connect(function()
            -- toggle
            if activeSlotPicker==slot then closeAllPickers();return end
            closeAllPickers();activeSlotPicker=slot

            -- build picker frame inserted after the slot row
            local picker=Instance.new("Frame");picker.Name="picker_"..slot
            picker.Size=UDim2.new(1,0,0,160)
            picker.BackgroundColor3=Color3.fromRGB(7,14,22);picker.BorderSizePixel=0
            picker.LayoutOrder=idx+1+0.5;picker.ZIndex=10;picker.Parent=custF
            mkCorner(picker,5);mkStroke(picker,Color3.fromRGB(0,140,190),1)

            -- mini search inside picker
            local mSearch=Instance.new("Frame");mSearch.Size=UDim2.new(1,-8,0,22);mSearch.Position=UDim2.new(0,4,0,4)
            mSearch.BackgroundColor3=Color3.fromRGB(10,20,32);mSearch.BorderSizePixel=0;mSearch.ZIndex=11;mSearch.Parent=picker
            mkCorner(mSearch,4)
            local mBox=Instance.new("TextBox");mBox.Size=UDim2.new(1,-6,1,0);mBox.Position=UDim2.new(0,4,0,0)
            mBox.BackgroundTransparency=1;mBox.Text="";mBox.PlaceholderText="Search pack..."
            mBox.PlaceholderColor3=Color3.fromRGB(40,70,90);mBox.TextColor3=Color3.fromRGB(185,212,232)
            mBox.Font=Enum.Font.Gotham;mBox.TextSize=10;mBox.TextXAlignment=Enum.TextXAlignment.Left
            mBox.ClearTextOnFocus=false;mBox.ZIndex=12;mBox.Parent=mSearch

            -- mini list
            local mScroll=Instance.new("ScrollingFrame");mScroll.Size=UDim2.new(1,-8,0,128);mScroll.Position=UDim2.new(0,4,0,30)
            mScroll.BackgroundTransparency=1;mScroll.BorderSizePixel=0;mScroll.ScrollBarThickness=2
            mScroll.ScrollBarImageColor3=Color3.fromRGB(0,120,170);mScroll.ZIndex=11;mScroll.Parent=picker
            local mList=Instance.new("UIListLayout");mList.SortOrder=Enum.SortOrder.LayoutOrder
            mList.Padding=UDim.new(0,2);mList.Parent=mScroll

            local function buildMiniList(filter)
                for _,c2 in ipairs(mScroll:GetChildren()) do
                    if not c2:IsA("UIListLayout") then c2:Destroy() end
                end
                local src=filter=="" and allPacks or (function()
                    local t={};for _,v in ipairs(allPacks) do
                        if v.name:lower():find(filter,1,true) then t[#t+1]=v end
                    end;return t
                end)()
                for i,pack in ipairs(src) do
                    if i>50 then break end  -- cap at 50 in mini list
                    local pBtn=Instance.new("TextButton");pBtn.Size=UDim2.new(1,0,0,24)
                    pBtn.BackgroundColor3=Color3.fromRGB(10,19,30);pBtn.TextColor3=Color3.fromRGB(175,205,225)
                    pBtn.Font=Enum.Font.Gotham;pBtn.TextSize=10
                    pBtn.Text=pack.name;pBtn.TextXAlignment=Enum.TextXAlignment.Left
                    pBtn.BorderSizePixel=0;pBtn.LayoutOrder=i;pBtn.ZIndex=12;pBtn.Parent=mScroll
                    mkCorner(pBtn,4)
                    -- pad text
                    do local pp=Instance.new("UIPadding");pp.PaddingLeft=UDim.new(0,6);pp.Parent=pBtn end

                    pBtn.MouseEnter:Connect(function() tw(pBtn,0.06,{BackgroundColor3=Color3.fromRGB(0,42,68)}) end)
                    pBtn.MouseLeave:Connect(function() tw(pBtn,0.06,{BackgroundColor3=Color3.fromRGB(10,19,30)}) end)

                    pBtn.MouseButton1Click:Connect(function()
                        -- resolve the specific slot animation from this pack
                        task.spawn(function()
                            local mappings=resolveMappings(pack)
                            local animId=nil
                            for _,m in ipairs(mappings) do
                                if m.category:lower()==slot:lower() then
                                    animId=m.animationId:gsub("rbxassetid://","")
                                    break
                                end
                            end
                            if not animId then animId=tostring(pack.id) end
                            customSlots[slot]={id=animId,name=pack.name}
                            valLbl.Text=pack.name;valLbl.TextColor3=Color3.fromRGB(0,215,125)
                            applySlot(slot,animId)
                            closeAllPickers()
                        end)
                    end)
                end
                mScroll.CanvasSize=UDim2.new(0,0,0,mList.AbsoluteContentSize.Y+4)
            end

            buildMiniList("")
            local deb;mBox:GetPropertyChangedSignal("Text"):Connect(function()
                if deb then task.cancel(deb) end
                deb=task.delay(0.18,function() buildMiniList(mBox.Text:lower():gsub("^%s+",""):gsub("%s+$","")) end)
            end)

            custF.CanvasSize=UDim2.new(0,0,0,custL.AbsoluteContentSize.Y+8)
        end)

        row.MouseEnter:Connect(function() tw(row,0.06,{BackgroundColor3=Color3.fromRGB(11,20,33)}) end)
        row.MouseLeave:Connect(function() tw(row,0.06,{BackgroundColor3=Color3.fromRGB(9,16,26)}) end)
    end

    custF.CanvasSize=UDim2.new(0,0,0,custL.AbsoluteContentSize.Y+8)
end

-- ══════════════════════════════════════════════════════════════════════
--  RENDER LIST
-- ══════════════════════════════════════════════════════════════════════
local function getList()
    return currentTab=="emotes" and filtEmotes or filtPacks
end
local function clearList()
    for _,c in ipairs(scrollF:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
end
local function renderPage()
    clearList()
    local list=getList()
    local total=math.max(1,math.ceil(#list/PER_PAGE))
    currentPage=math.clamp(currentPage,1,total)
    pageLbl2.Text=currentPage.." / "..total
    prevBtn.TextTransparency=currentPage==1 and 0.55 or 0
    nextBtn.TextTransparency=currentPage==total and 0.55 or 0
    local s=(currentPage-1)*PER_PAGE+1
    local e=math.min(s+PER_PAGE-1,#list)
    for i=s,e do
        local item=list[i];if not item then break end
        local row=Instance.new("Frame");row.Size=UDim2.new(1,0,0,28)
        row.BackgroundColor3=Color3.fromRGB(9,17,27);row.BorderSizePixel=0
        row.LayoutOrder=i;row.ZIndex=7;row.Parent=scrollF;mkCorner(row,5)
        local nameLbl=Instance.new("TextLabel");nameLbl.Size=UDim2.new(1,-62,1,0);nameLbl.Position=UDim2.new(0,8,0,0)
        nameLbl.BackgroundTransparency=1;nameLbl.Text=item.name;nameLbl.TextColor3=Color3.fromRGB(175,205,228)
        nameLbl.Font=Enum.Font.Gotham;nameLbl.TextSize=11;nameLbl.TextXAlignment=Enum.TextXAlignment.Left
        nameLbl.TextTruncate=Enum.TextTruncate.AtEnd;nameLbl.ZIndex=8;nameLbl.Parent=row
        local pBtn=Instance.new("TextButton");pBtn.Size=UDim2.new(0,48,0,20);pBtn.Position=UDim2.new(1,-52,0.5,-10)
        pBtn.BackgroundColor3=Color3.fromRGB(0,42,68);pBtn.TextColor3=Color3.fromRGB(0,200,255)
        pBtn.Font=Enum.Font.GothamBold;pBtn.TextSize=10
        pBtn.Text=currentTab=="emotes" and "▶ PLAY" or "⚡ ALL"
        pBtn.BorderSizePixel=0;pBtn.ZIndex=9;pBtn.Parent=row;mkCorner(pBtn,4)
        row.MouseEnter:Connect(function() tw(row,0.06,{BackgroundColor3=Color3.fromRGB(12,23,38)}) end)
        row.MouseLeave:Connect(function() tw(row,0.06,{BackgroundColor3=Color3.fromRGB(9,17,27)}) end)
        pBtn.MouseButton1Click:Connect(function()
            tw(pBtn,0.06,{BackgroundColor3=Color3.fromRGB(0,65,105)})
            task.delay(0.12,function() tw(pBtn,0.06,{BackgroundColor3=Color3.fromRGB(0,42,68)}) end)
            if currentTab=="emotes" then playEmoteItem(item) else applyFullPack(item) end
        end)
    end
    scrollF.CanvasSize=UDim2.new(0,0,0,listL.AbsoluteContentSize.Y+6)
    scrollF.CanvasPosition=Vector2.new(0,0)
end

-- ══════════════════════════════════════════════════════════════════════
--  TABS
-- ══════════════════════════════════════════════════════════════════════
local function refreshTabs()
    local map={emotes=tabE,packs=tabP,customize=tabC}
    for name,btn in pairs(map) do
        btn.BackgroundColor3=name==currentTab and Color3.fromRGB(0,48,78) or Color3.fromRGB(10,20,33)
        btn.TextColor3=name==currentTab and Color3.fromRGB(0,200,255) or Color3.fromRGB(60,100,130)
    end
    local isList=currentTab~="customize"
    scrollF.Visible=isList;pageRow.Visible=isList;searchBg.Visible=isList
    custF.Visible=not isList
end
local function switchTab(tab)
    currentTab=tab;currentPage=1
    if tab~="customize" then
        searchBox.Text="";filtEmotes=allEmotes;filtPacks=allPacks
        statusLbl.Text=(tab=="emotes" and #allEmotes or #allPacks).." loaded"
        renderPage()
    else
        buildCustomizeTab()
        statusLbl.Text="customize"
    end
    refreshTabs()
end
tabE.MouseButton1Click:Connect(function() switchTab("emotes") end)
tabP.MouseButton1Click:Connect(function() switchTab("packs") end)
tabC.MouseButton1Click:Connect(function() switchTab("customize") end)
refreshTabs()

-- search
local sDebounce
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    if sDebounce then task.cancel(sDebounce) end
    sDebounce=task.delay(0.2,function()
        local q=searchBox.Text:lower():gsub("^%s+",""):gsub("%s+$","")
        local src=currentTab=="emotes" and allEmotes or allPacks
        local out=q=="" and src or (function()
            local t={};for _,v in ipairs(src) do if v.name:lower():find(q,1,true) then t[#t+1]=v end end;return t
        end)()
        if currentTab=="emotes" then filtEmotes=out else filtPacks=out end
        statusLbl.Text=#out..(currentTab=="emotes" and " emotes" or " packs")
        currentPage=1;renderPage()
    end)
end)

-- speed / freeze / stop
local function updSpVal() spVal.Text=string.format("%.1fx",emoteSpeed) end
spDn.MouseButton1Click:Connect(function()
    emoteSpeed=math.max(0.1,math.floor((emoteSpeed-0.1)*10+0.5)/10);updSpVal()
    if currentTrack and currentTrack.IsPlaying then currentTrack:AdjustSpeed(emoteSpeed) end
end)
spUp2.MouseButton1Click:Connect(function()
    emoteSpeed=math.min(5.0,math.floor((emoteSpeed+0.1)*10+0.5)/10);updSpVal()
    if currentTrack and currentTrack.IsPlaying then currentTrack:AdjustSpeed(emoteSpeed) end
end)
frzBtn.MouseButton1Click:Connect(function()
    freezeOn=not freezeOn
    if freezeOn then frzBtn.Text="❄ ON";frzBtn.BackgroundColor3=Color3.fromRGB(0,35,22);frzBtn.TextColor3=Color3.fromRGB(0,250,140)
    else frzBtn.Text="❄ OFF";frzBtn.BackgroundColor3=Color3.fromRGB(6,20,14);frzBtn.TextColor3=Color3.fromRGB(0,190,110);unfreezeChar() end
end)
stpBtn.MouseButton1Click:Connect(function() stopEmote();unfreezeChar() end)

-- pagination
prevBtn.MouseButton1Click:Connect(function() if currentPage>1 then currentPage-=1;renderPage() end end)
nextBtn.MouseButton1Click:Connect(function()
    if currentPage<math.ceil(#getList()/PER_PAGE) then currentPage+=1;renderPage() end
end)

-- open/close
local function setOpen(open)
    guiOpen=open
    if open then
        panel.Visible=true;panel.BackgroundTransparency=0
        pillIcon.Text="✕";pillIcon.TextColor3=Color3.fromRGB(255,70,70)
        tw(pillBg,0.15,{BackgroundColor3=Color3.fromRGB(22,5,9)});pillS.Color=Color3.fromRGB(255,75,75)
    else
        tw(panel,0.13,{BackgroundTransparency=1})
        task.delay(0.14,function() if not guiOpen then panel.Visible=false end end)
        pillIcon.Text="▶";pillIcon.TextColor3=Color3.fromRGB(0,210,255)
        tw(pillBg,0.15,{BackgroundColor3=Color3.fromRGB(5,11,20)});pillS.Color=Color3.fromRGB(0,195,255)
    end
end
pillBtn.MouseButton1Click:Connect(function() setOpen(not guiOpen) end)
closeBtn.MouseButton1Click:Connect(function() setOpen(false) end)

-- drag (entire title bar)
do
    local dragging,dragStart,startPos=false,nil,nil
    titleBar.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            dragging=true;dragStart=inp.Position;startPos=panel.Position
        end
    end)
    table.insert(conns,UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch then
            local d=inp.Position-dragStart
            panel.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end))
    table.insert(conns,UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            dragging=false
        end
    end))
end

-- respawn
table.insert(conns,player.CharacterAdded:Connect(function(char)
    character=char;currentTrack=nil;setupMoveStop(char)
end))

-- load data
task.spawn(function()
    local ok1,r1=pcall(function() return game:HttpGet("https://raw.githubusercontent.com/7yd7/sniper-Emote/refs/heads/test/EmoteSniper.json") end)
    if ok1 and r1 then
        local ok2,data=pcall(function() return HttpService:JSONDecode(r1) end)
        if ok2 and data and data.data then allEmotes=data.data;filtEmotes=allEmotes end
    end
    local ok3,r3=pcall(function() return game:HttpGet("https://raw.githubusercontent.com/7yd7/sniper-Emote/refs/heads/test/AnimationSniper.json") end)
    if ok3 and r3 then
        local ok4,data=pcall(function() return HttpService:JSONDecode(r3) end)
        if ok4 and data and data.data then allPacks=data.data;filtPacks=allPacks end
    end
    if currentTab=="emotes" then statusLbl.Text=#allEmotes.." emotes"
    elseif currentTab=="packs" then statusLbl.Text=#allPacks.." packs" end
    renderPage()
end)
