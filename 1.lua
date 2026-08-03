local Lurk = loadstring(game:HttpGet("https://raw.githubusercontent.com/AWLOID/Library/refs/heads/main/Anti.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local GuiService = game:GetService("GuiService")

local Settings = {
    LoopFlingAll = false,
    ClickMenu = false,
    Enabled = false,
    Murderer = false,
    Sheriff = false,
    Innocent = false,
    AutoAnnounceRoles = false,
    NotifyMyRole = false,
    ShowAvatar = false,
    Mode = "Highlight",
    ShowName = true,
    ShowDistance = true,
    ChinaHat = false,
    Trail = false,
    ChinaHatColor = Color3.fromRGB(255, 80, 80),
    TrailColor = Color3.fromRGB(120, 200, 255),
    DropGun = false,
    Tracers = false,
    KillAura = false,
    KillAuraRadius = 50,
    SilentAim = false,
    ShootButton = false,
    ShootButtonSize = 80,
    ShootButtonWH = false,
    ShootButtonWHSize = 80,
    WalkSpeed = 16,
    JumpPower = 50,
    Noclip = false,
    InfJump = false,
    AutoGrabGun = false,
    GrabGunButton = false,
    NotifyGun = false,
    GrabButtonSize = 70,
    Antifling = false,
    DelayedShoot = false,
    AutoKnifeThrow = false,
    ShowRole = false,
    Skeleton = false,
    SkeletonColor = Color3.fromRGB(255, 255, 255),
    FakeSpeedOn = false,
    FakeSpeedVal = 0,
    FlyOn = false,
    FlySpeed = 60,
    XRay = false,
}

local MAX_DIST = 1000

local BASE = {
    Murderer = Color3.fromRGB(255, 90, 90),
    Sheriff = Color3.fromRGB(110, 160, 255),
    Hero = Color3.fromRGB(255, 220, 110),
    Innocent = Color3.fromRGB(120, 230, 140),
}

function makeRole(base)
    return {
        bright = base,
        dark = base:Lerp(Color3.fromRGB(0, 0, 0), 0.78),
        outline = base:Lerp(Color3.fromRGB(255, 255, 255), 0.15),
    }
end

local COLORS = {}
function rebuildColors()
    for role, base in pairs(BASE) do
        COLORS[role] = makeRole(base)
    end
end
rebuildColors()

function getgui()
    local ok, g = pcall(function() return gethui() end)
    if ok and g then return g end
    return game:GetService("CoreGui")
end

local Holder = Instance.new("ScreenGui")
Holder.Name = "\0mm2esp"
Holder.IgnoreGuiInset = true
Holder.ResetOnSpawn = false
Holder.DisplayOrder = 999999
pcall(function() Holder.Parent = getgui() end)

local ChamsFolder = Instance.new("Folder")
ChamsFolder.Name = "\0mm2chams"
pcall(function() ChamsFolder.Parent = getgui() end)

local PlayerData = {}

-- X-Ray: makes map geometry locally translucent without changing characters.
local X_RAY_TRANSPARENCY = 0.65
local xRayOriginal = {}
local xRayGeneration = 0

local function isCharacterPart(part)
    local model = part:FindFirstAncestorOfClass("Model")
    return model and model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function applyXRayToPart(part)
    if not part:IsA("BasePart") or isCharacterPart(part) then return end
    if part.Transparency >= 1 then return end

    if xRayOriginal[part] == nil then
        xRayOriginal[part] = part.LocalTransparencyModifier
    end
    part.LocalTransparencyModifier = math.max(xRayOriginal[part], X_RAY_TRANSPARENCY)
end

local function restoreXRay()
    local originalsToRestore = xRayOriginal
    xRayOriginal = {}

    for part, transparency in pairs(originalsToRestore) do
        pcall(function()
            if part:IsA("BasePart") and part.Parent then
                part.LocalTransparencyModifier = transparency
            end
        end)
        originalsToRestore[part] = nil
    end
end

local function setXRay(enabled)
    xRayGeneration += 1
    Settings.XRay = enabled

    if enabled then
        for _, object in ipairs(Workspace:GetDescendants()) do
            applyXRayToPart(object)
        end
    else
        restoreXRay()
    end
end

Workspace.DescendantAdded:Connect(function(object)
    if not Settings.XRay then return end

    local scheduledGeneration = xRayGeneration
    task.defer(function()
        if Settings.XRay
            and scheduledGeneration == xRayGeneration
            and object.Parent
        then
            applyXRayToPart(object)
        end
    end)
end)

local DataEvent
do
    local ok, ev = pcall(function()
        return ReplicatedStorage:WaitForChild("Remotes", 5)
            :WaitForChild("Gameplay", 5)
            :WaitForChild("PlayerDataChanged", 5)
    end)
    if ok then DataEvent = ev end
end

local currentRound = ReplicatedStorage:FindFirstChild("Modules")
    and ReplicatedStorage.Modules:FindFirstChild("CurrentRoundClient")

local _roundModule
function getRoundModule()
    if _roundModule ~= nil then return _roundModule end
    if not currentRound then return nil end
    local ok, module = pcall(require, currentRound)
    if ok and module then
        _roundModule = module
        return module
    end
    return nil
end

local _liveCache, _liveFrame = nil, -1
local _frame = 0
function liveData()
    if _liveFrame == _frame then return _liveCache end
    _liveFrame = _frame
    local module = getRoundModule()
    if module and type(module.PlayerData) == "table" then
        _liveCache = module.PlayerData
    else
        _liveCache = nil
    end
    return _liveCache
end

function getData(plr)
    if not plr then return nil end
    local live = liveData()
    if live then
        local d = live[plr.Name]
        if d then return d end
        for _, v in pairs(live) do
            if type(v) == "table" and v.UserId == plr.UserId then
                return v
            end
        end
    end
    local d = PlayerData[plr.Name]
    if d then return d end
    for _, v in pairs(PlayerData) do
        if type(v) == "table" and v.UserId == plr.UserId then
            return v
        end
    end
    return nil
end

if DataEvent then
    DataEvent.OnClientEvent:Connect(function(data)
        if type(data) ~= "table" then return end
        for name, info in pairs(data) do
            if type(info) == "table" then
                PlayerData[name] = info
            end
        end
    end)
end

function roundActive()
    local live = liveData()
    return live ~= nil and next(live) ~= nil
end

-- forward declarations for the role-announce feature (bodies defined after findSheriff/findMurderer)
local sendChatMessage, announceRoles

local Me = { Role = nil, Dead = false, InLobby = false, Alive = false }

function holdsGun(plr)
    local ok, res = pcall(function()
        local char = plr.Character
        if char and char:FindFirstChild("Gun") then return true end
        local bp = plr:FindFirstChildOfClass("Backpack")
        if bp and bp:FindFirstChild("Gun") then return true end
        return false
    end)
    return ok and res
end

function resolveRole(plr, data)
    local role = data.Role
    if role == "Murderer" then return "Murderer" end
    if role == "Sheriff" then return "Sheriff" end
    if role == "Hero" then return "Hero" end
    if role == "Innocent" then
        if holdsGun(plr) then return "Hero" end
        return "Innocent"
    end
    return role
end

function refreshSelf()
    local d = getData(LocalPlayer)
    if not d then
        Me.Role, Me.Dead, Me.InLobby, Me.Alive = nil, false, false, false
        return
    end
    Me.Role = resolveRole(LocalPlayer, d)
    Me.Dead = d.Dead == true
    Me.InLobby = d.Dead == true
    Me.Alive = not Me.Dead
end

function shouldShow(role)
    if role == "Murderer" then return Settings.Murderer end
    if role == "Sheriff" then return Settings.Sheriff end
    if role == "Hero" then return Settings.Sheriff end
    if role == "Innocent" then return Settings.Innocent end
    return false
end

function shimmer(c)
    local t = (math.sin(os.clock() * 3) + 1) / 2
    return c.dark:Lerp(c.bright, t)
end

local ESP = {}

function newDrawing(class, props)
    local ok, obj = pcall(function() return Drawing.new(class) end)
    if not ok or not obj then return nil end
    for k, v in pairs(props) do
        pcall(function() obj[k] = v end)
    end
    return obj
end

function createESP(plr)
    if ESP[plr] then return ESP[plr] end
    local e = {}

    e.boxFrame = Instance.new("Frame")
    e.boxFrame.Name = "box"
    e.boxFrame.BackgroundColor3 = Color3.new(1, 1, 1)
    e.boxFrame.BackgroundTransparency = 0.4
    e.boxFrame.BorderSizePixel = 0
    e.boxFrame.AnchorPoint = Vector2.new(0, 0)
    e.boxFrame.Visible = false
    e.boxFrame.ZIndex = 2
    e.boxFrame.Parent = Holder

    e.gradient = Instance.new("UIGradient")
    e.gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
    })
    e.gradient.Parent = e.boxFrame

    e.stroke = Instance.new("UIStroke")
    e.stroke.Color = Color3.fromRGB(255, 255, 255)
    e.stroke.Thickness = 0.5
    e.stroke.Transparency = 0
    e.stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    e.stroke.Parent = e.boxFrame

    e.boxLine = newDrawing("Square", {
        Thickness = 1,
        Filled = false,
        Transparency = 0.9,
        Visible = false,
        Color = Color3.fromRGB(255, 255, 255),
        ZIndex = 5,
    })
    e.boxAccent = newDrawing("Square", {
        Thickness = 1,
        Filled = false,
        Transparency = 0.45,
        Visible = false,
        Color = Color3.fromRGB(0, 0, 0),
        ZIndex = 4,
    })

    e.tracer = newDrawing("Line", {
        Thickness = 1,
        Transparency = 1,
        Visible = false,
        Color = Color3.fromRGB(255, 255, 255),
        ZIndex = 3,
    })

    e.nameLabel = Instance.new("TextLabel")
    e.nameLabel.BackgroundTransparency = 1
    e.nameLabel.Font = Enum.Font.GothamSemibold
    e.nameLabel.TextSize = 13
    e.nameLabel.TextColor3 = Color3.new(1, 1, 1)
    e.nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    e.nameLabel.TextStrokeTransparency = 0.1
    e.nameLabel.AnchorPoint = Vector2.new(0.5, 1)
    e.nameLabel.Size = UDim2.fromOffset(220, 16)
    e.nameLabel.Visible = false
    e.nameLabel.ZIndex = 3
    e.nameLabel.Parent = Holder

    e.avatar = Instance.new("ImageLabel")
    e.avatar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    e.avatar.BackgroundTransparency = 0.2
    e.avatar.AnchorPoint = Vector2.new(1, 1)
    e.avatar.Size = UDim2.fromOffset(18, 18)
    e.avatar.Visible = false
    e.avatar.ZIndex = 3
    e.avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. plr.UserId .. "&w=48&h=48"
    local avCorner = Instance.new("UICorner")
    avCorner.CornerRadius = UDim.new(1, 0)
    avCorner.Parent = e.avatar
    e.avatar.Parent = Holder

    e.distLabel = Instance.new("TextLabel")
    e.distLabel.BackgroundTransparency = 1
    e.distLabel.Font = Enum.Font.Gotham
    e.distLabel.TextSize = 12
    e.distLabel.TextColor3 = Color3.new(1, 1, 1)
    e.distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    e.distLabel.TextStrokeTransparency = 0.1
    e.distLabel.AnchorPoint = Vector2.new(0.5, 0)
    e.distLabel.Size = UDim2.fromOffset(220, 16)
    e.distLabel.Visible = false
    e.distLabel.ZIndex = 3
    e.distLabel.Parent = Holder

    e.roleLabel = Instance.new("TextLabel")
    e.roleLabel.BackgroundTransparency = 1
    e.roleLabel.Font = Enum.Font.GothamBold
    e.roleLabel.TextSize = 12
    e.roleLabel.TextColor3 = Color3.new(1, 1, 1)
    e.roleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    e.roleLabel.TextStrokeTransparency = 0.1
    e.roleLabel.AnchorPoint = Vector2.new(0.5, 1)
    e.roleLabel.Size = UDim2.fromOffset(220, 14)
    e.roleLabel.Visible = false
    e.roleLabel.ZIndex = 3
    e.roleLabel.Parent = Holder

    e.chams = {}
    e.chamsChar = nil
    e.skel = {}
    ESP[plr] = e
    return e
end

function hideBox(e)
    if e.boxFrame then e.boxFrame.Visible = false end
    if e.boxLine then e.boxLine.Visible = false end
    if e.boxAccent then e.boxAccent.Visible = false end
    if e.tracer then e.tracer.Visible = false end
    if e.tracerShadow then e.tracerShadow.Visible = false end
end

local SKEL_BONES_R15 = {
    { "Head", "UpperTorso" },
    { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" },
    { "LeftUpperArm", "LeftLowerArm" },
    { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" },
    { "RightUpperArm", "RightLowerArm" },
    { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" },
    { "LeftUpperLeg", "LeftLowerLeg" },
    { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" },
    { "RightUpperLeg", "RightLowerLeg" },
    { "RightLowerLeg", "RightFoot" },
}
local SKEL_BONES_R6 = {
    { "Head", "Torso" },
    { "Torso", "Left Arm" },
    { "Torso", "Right Arm" },
    { "Torso", "Left Leg" },
    { "Torso", "Right Leg" },
}

function hideSkel(e)
    if e.skel then
        for _, s in ipairs(e.skel) do
            if s.line then s.line.Visible = false end
            if s.shadow then s.shadow.Visible = false end
        end
    end
end

function hideText(e)
    if e.nameLabel then e.nameLabel.Visible = false end
    if e.avatar then e.avatar.Visible = false end
    if e.distLabel then e.distLabel.Visible = false end
    if e.roleLabel then e.roleLabel.Visible = false end
    hideSkel(e)
end

function disableHighlight(plr)
    local e = ESP[plr]
    if e and e.highlight then e.highlight.Enabled = false end
end

function hideChams(e)
    if e.chams then
        for _, a in ipairs(e.chams) do
            if a then a.Visible = false end
        end
    end
end

function clearChams(e)
    if e.chams then
        for _, a in ipairs(e.chams) do pcall(function() a:Destroy() end) end
    end
    e.chams = {}
    e.chamsChar = nil
end

function destroyESP(plr)
    local e = ESP[plr]
    if not e then return end
    if e.boxFrame then pcall(function() e.boxFrame:Destroy() end) end
    if e.boxLine then pcall(function() e.boxLine:Remove() end) end
    if e.boxAccent then pcall(function() e.boxAccent:Remove() end) end
    if e.tracer then pcall(function() e.tracer:Remove() end) end
    if e.tracerShadow then pcall(function() e.tracerShadow:Remove() end) end
    if e.nameLabel then pcall(function() e.nameLabel:Destroy() end) end
    if e.avatar then pcall(function() e.avatar:Destroy() end) end
    if e.distLabel then pcall(function() e.distLabel:Destroy() end) end
    if e.roleLabel then pcall(function() e.roleLabel:Destroy() end) end
    if e.skel then
        for _, s in ipairs(e.skel) do
            if s.line then pcall(function() s.line:Remove() end) end
            if s.shadow then pcall(function() s.shadow:Remove() end) end
        end
        e.skel = {}
    end
    if e.highlight then pcall(function() e.highlight:Destroy() end) end
    if e.tagBtn then pcall(function() e.tagBtn:Destroy() end) end
    if e.tagMenu then pcall(function() e.tagMenu:Destroy() end) end
    clearChams(e)
    ESP[plr] = nil
end

function getHighlight(plr, char)
    local e = ESP[plr] or createESP(plr)
    local hl = e.highlight
    if not hl or not hl.Parent then
        if hl then pcall(function() hl:Destroy() end) end
        hl = Instance.new("Highlight")
        hl.Name = "\0esp"
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        pcall(function() hl.Parent = char end)
        e.highlight = hl
    end
    return hl
end

function applyHighlight(plr, char, c)
    local hl = getHighlight(plr, char)
    if hl.Adornee ~= char then hl.Adornee = char end
    local col = c.bright
    if hl.FillColor ~= col then hl.FillColor = col end
    if hl.OutlineColor ~= c.outline then hl.OutlineColor = c.outline end
    if hl.FillTransparency ~= 0.4 then hl.FillTransparency = 0.4 end
    if hl.OutlineTransparency ~= 0 then hl.OutlineTransparency = 0 end
    if not hl.Enabled then hl.Enabled = true end
end

function applyChams(plr, char, c)
    local e = ESP[plr] or createESP(plr)
    if e.chamsChar ~= char then
        clearChams(e)
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                local a = Instance.new("BoxHandleAdornment")
                a.Name = "\0c"
                a.Adornee = part
                a.Size = part.Size + Vector3.new(0.05, 0.05, 0.05)
                a.AlwaysOnTop = true
                a.ZIndex = 0
                a.Transparency = 0.4
                pcall(function() a.Parent = ChamsFolder end)
                table.insert(e.chams, a)
            end
        end
        e.chamsChar = char
    end
    local col = c.bright
    for _, a in ipairs(e.chams) do
        if a then a.Color3 = col a.Visible = true end
    end
end

function updateSkeleton(e, char, c)
    if not Settings.Skeleton then
        hideSkel(e)
        return
    end
    e.skel = e.skel or {}
    local bones = char:FindFirstChild("UpperTorso") and SKEL_BONES_R15 or SKEL_BONES_R6
    for i, pair in ipairs(bones) do
        local s = e.skel[i]
        if not s then
            s = {
                line = newDrawing("Line", {
                    Thickness = 1.4,
                    Transparency = 1,
                    Visible = false,
                    Color = Color3.fromRGB(255, 255, 255),
                    ZIndex = 7,
                }),
            }
            e.skel[i] = s
        end
        local shown = false
        local p0 = char:FindFirstChild(pair[1])
        local p1 = char:FindFirstChild(pair[2])
        if p0 and p1 then
            local v0, on0 = Camera:WorldToViewportPoint(p0.Position)
            local v1, on1 = Camera:WorldToViewportPoint(p1.Position)
            if on0 and on1 then
                local a = Vector2.new(v0.X, v0.Y)
                local b = Vector2.new(v1.X, v1.Y)
                if s.line then
                    s.line.From = a
                    s.line.To = b
                    s.line.Color = Settings.SkeletonColor
                    s.line.Visible = true
                end
                shown = true
            end
        end
        if not shown then
            if s.line then s.line.Visible = false end
            if s.shadow then s.shadow.Visible = false end
        end
    end
    -- if the rig switched from R15 to R6, hide the extra bone lines
    for i = #bones + 1, #e.skel do
        local s = e.skel[i]
        if s then
            if s.line then s.line.Visible = false end
            if s.shadow then s.shadow.Visible = false end
        end
    end
end

function updateVisuals(plr, char, c, hrp, role)
    local e = ESP[plr] or createESP(plr)

    local rootPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
    if not onScreen then
        hideBox(e)
        hideText(e)
        return
    end

    local topP = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 2.9, 0))
    local botP = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.0, 0))
    local h = math.abs(topP.Y - botP.Y)
    if h < 6 then h = 6 end
    local w = h * 0.56
    local minX = rootPos.X - w / 2
    local minY = math.min(topP.Y, botP.Y)
    local maxX = minX + w
    local maxY = minY + h
    local cx = rootPos.X
    local sizeV = Vector2.new(w, h)
    local posV = Vector2.new(minX, minY)

    if Settings.Mode == "Box" then
        local inset = GuiService:GetGuiInset()
        e.boxFrame.Position = UDim2.fromOffset(minX, minY)
        e.boxFrame.Size = UDim2.fromOffset(w, h)

        local t = os.clock()
        local roleDark = c.bright:Lerp(Color3.fromRGB(0, 0, 0), 0.6)
        local mid = c.bright:Lerp(roleDark, 0.5)
        e.gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, c.bright),
            ColorSequenceKeypoint.new(0.5, mid),
            ColorSequenceKeypoint.new(1, roleDark),
        })
        e.gradient.Rotation = (t * 70) % 360
        e.gradient.Offset = Vector2.new(math.sin(t * 1.6) * 0.35, math.cos(t * 1.6) * 0.35)

        local lineCol = c.bright:Lerp(Color3.fromRGB(0, 0, 0), 0.75)
        e.stroke.Color = lineCol
        e.stroke.Thickness = 0.5

        local dPos = Vector2.new(minX, minY)
        -- thick accent outline removed per request; keep only the thin boxLine
        if e.boxAccent then
            e.boxAccent.Visible = false
        end
        if e.boxLine then
            e.boxLine.Size = sizeV
            e.boxLine.Position = dPos
            e.boxLine.Thickness = 0.5
            e.boxLine.Color = lineCol
            e.boxLine.Transparency = 1
            e.boxLine.ZIndex = 6
            e.boxLine.Visible = true
        end

        e.boxFrame.Visible = true
    else
        hideBox(e)
    end

    if Settings.Tracers then
        local vp = Camera.ViewportSize
        local fromV = Vector2.new(vp.X / 2, vp.Y)
        local toV = Vector2.new(rootPos.X, rootPos.Y)
        if e.tracer then
            e.tracer.From = fromV
            e.tracer.To = toV
            e.tracer.Thickness = 1
            e.tracer.Color = c.bright
            e.tracer.Transparency = 1
            e.tracer.Visible = true
        end
    else
        if e.tracer then e.tracer.Visible = false end
        if e.tracerShadow then e.tracerShadow.Visible = false end
    end

    updateSkeleton(e, char, c)

    if Settings.ShowName then
        e.nameLabel.Text = plr.Name
        e.nameLabel.TextColor3 = Color3.new(1, 1, 1)
        e.nameLabel.Position = UDim2.fromOffset(cx, minY - 3)
        e.nameLabel.Visible = true
        if Settings.ShowAvatar and e.avatar then
            local half = e.nameLabel.TextBounds.X / 2
            e.avatar.Position = UDim2.fromOffset(cx - half - 4, minY - 2)
            e.avatar.Visible = true
        elseif e.avatar then
            e.avatar.Visible = false
        end
    else
        e.nameLabel.Visible = false
        if e.avatar then e.avatar.Visible = false end
    end

    if Settings.ShowRole and role then
        e.roleLabel.Text = string.upper(role)
        e.roleLabel.TextColor3 = c.bright
        local roleY = minY - 3 - (Settings.ShowName and 16 or 0)
        e.roleLabel.Position = UDim2.fromOffset(cx, roleY)
        e.roleLabel.Visible = true
    else
        e.roleLabel.Visible = false
    end

    if Settings.ShowDistance then
        local d = 0
        local myChar = LocalPlayer.Character
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if myHrp then d = (myHrp.Position - hrp.Position).Magnitude end
        e.distLabel.Text = string.format("%dm", math.floor(d))
        e.distLabel.TextColor3 = Color3.new(1, 1, 1)
        e.distLabel.Position = UDim2.fromOffset(cx, maxY + 3)
        e.distLabel.Visible = true
    else
        e.distLabel.Visible = false
    end
end

local PlayerFX = { hat = nil, trail = nil, att0 = nil, att1 = nil }

function getMyChar()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not hrp then return nil end
    return char, hrp, head
end

function updateChinaHat()
    local char, hrp, head = getMyChar()
    if not Settings.ChinaHat or not char or not head then
        if PlayerFX.hat then pcall(function() PlayerFX.hat:Destroy() end) PlayerFX.hat = nil end
        return
    end
    local hat = PlayerFX.hat
    if not hat or not hat.Parent or hat.Parent ~= char then
        if hat then pcall(function() hat:Destroy() end) end
        hat = Instance.new("Part")
        hat.Name = "\0chinahat"
        hat.Anchored = false
        hat.CanCollide = false
        hat.CanQuery = false
        hat.CanTouch = false
        hat.Size = Vector3.new(3.2, 1.2, 3.2)
        hat.Material = Enum.Material.Neon
        hat.Transparency = 0.3
        hat.Color = Settings.ChinaHatColor
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.FileMesh
        mesh.MeshId = "rbxassetid://1033714"
        mesh.Scale = Vector3.new(1.65, 0.8, 1.65)
        mesh.Parent = hat
        hat.Parent = char
        local weld = Instance.new("Weld")
        weld.Part0 = head
        weld.Part1 = hat
        weld.C0 = CFrame.new(0, 0.9, 0)
        weld.Parent = hat
        PlayerFX.hat = hat
    end
    if hat.Color ~= Settings.ChinaHatColor then
        hat.Color = Settings.ChinaHatColor
    end
end

function updateTrail()
    local char, hrp = getMyChar()
    if not Settings.Trail or not char or not hrp then
        if PlayerFX.trail then PlayerFX.trail.Enabled = false end
        return
    end

    if not PlayerFX.att0 or PlayerFX.att0.Parent ~= hrp then
        local a0 = hrp:FindFirstChild("\0t0") or Instance.new("Attachment")
        a0.Name = "\0t0"
        a0.Position = Vector3.new(0, 2, 0)
        a0.Parent = hrp
        local a1 = hrp:FindFirstChild("\0t1") or Instance.new("Attachment")
        a1.Name = "\0t1"
        a1.Position = Vector3.new(0, -2, 0)
        a1.Parent = hrp
        PlayerFX.att0, PlayerFX.att1 = a0, a1
        if PlayerFX.trail then pcall(function() PlayerFX.trail:Destroy() end) PlayerFX.trail = nil end
    end

    local trail = PlayerFX.trail
    if not trail or trail.Parent ~= hrp then
        if trail then pcall(function() trail:Destroy() end) end
        trail = Instance.new("Trail")
        trail.Name = "\0trail"
        trail.Attachment0 = PlayerFX.att0
        trail.Attachment1 = PlayerFX.att1
        trail.Lifetime = 0.45
        trail.MinLength = 0
        trail.FaceCamera = false
        trail.LightEmission = 0
        trail.WidthScale = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 1),
        })
        trail.Transparency = NumberSequence.new(0)
        trail.Parent = hrp
        PlayerFX.trail = trail
    end
    if PlayerFX.lastTrailColor ~= Settings.TrailColor then
        trail.Color = ColorSequence.new(Settings.TrailColor)
        PlayerFX.lastTrailColor = Settings.TrailColor
    end
    trail.Enabled = true
end

function rebindPlayerFX()
    PlayerFX.hat = nil
    PlayerFX.trail = nil
    PlayerFX.att0 = nil
    PlayerFX.att1 = nil
    PlayerFX.lastTrailColor = nil
end

LocalPlayer.CharacterAdded:Connect(rebindPlayerFX)

local DropGuns = {}
local DROPGUN_COLOR = Color3.fromRGB(255, 220, 70)

function findMap()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:GetAttribute("MapID") ~= nil then
            return obj
        end
    end
    return nil
end

function getDropRec(obj)
    local r = DropGuns[obj]
    if not r then r = { chams = {} } DropGuns[obj] = r end
    return r
end

function destroyDropRec(obj)
    local r = DropGuns[obj]
    if not r then return end
    if r.hl then pcall(function() r.hl:Destroy() end) end
    if r.chams then for _, a in ipairs(r.chams) do pcall(function() a:Destroy() end) end end
    if r.box then pcall(function() r.box:Remove() end) end
    if r.boxFrame then pcall(function() r.boxFrame:Destroy() end) end
    DropGuns[obj] = nil
end

function clearDropGuns()
    for obj in pairs(DropGuns) do destroyDropRec(obj) end
end

function dropHighlight(obj, r)
    if not r.hl or not r.hl.Parent then
        if r.hl then pcall(function() r.hl:Destroy() end) end
        r.hl = Instance.new("Highlight")
        r.hl.Name = "\0dropgun"
        r.hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        r.hl.FillColor = DROPGUN_COLOR
        r.hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        r.hl.FillTransparency = 0
        r.hl.OutlineTransparency = 0
        pcall(function() r.hl.Parent = ChamsFolder end)
    end
    if r.hl.Adornee ~= obj then r.hl.Adornee = obj end
    r.hl.Enabled = true
end

function dropChams(obj, r)
    if not r.chams then r.chams = {} end
    if #r.chams == 0 then
        local parts = {}
        if obj:IsA("BasePart") then
            table.insert(parts, obj)
        else
            for _, p in ipairs(obj:GetDescendants()) do
                if p:IsA("BasePart") then table.insert(parts, p) end
            end
        end
        for _, p in ipairs(parts) do
            local a = Instance.new("BoxHandleAdornment")
            a.Name = "\0dgc"
            a.Adornee = p
            a.Size = p.Size + Vector3.new(0.1, 0.1, 0.1)
            a.AlwaysOnTop = true
            a.ZIndex = 0
            a.Transparency = 0.3
            a.Color3 = DROPGUN_COLOR
            pcall(function() a.Parent = ChamsFolder end)
            table.insert(r.chams, a)
        end
    end
    for _, a in ipairs(r.chams) do
        if a then a.Color3 = DROPGUN_COLOR a.Visible = true end
    end
end

function dropBox(obj, r)
    local part = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
    if not part then return end
    local pos, on = Camera:WorldToViewportPoint(part.Position)
    if not on then
        if r.boxFrame then r.boxFrame.Visible = false end
        if r.box then r.box.Visible = false end if r.boxFrame then r.boxFrame.Visible = false end
        return
    end
    if not r.boxFrame then
        r.boxFrame = Instance.new("Frame")
        r.boxFrame.Name = "gunbox"
        r.boxFrame.BackgroundColor3 = Color3.new(1, 1, 1)
        r.boxFrame.BackgroundTransparency = 0.4
        r.boxFrame.BorderSizePixel = 0
        r.boxFrame.Visible = false
        r.boxFrame.ZIndex = 2
        r.boxFrame.Parent = Holder

        r.gradient = Instance.new("UIGradient")
        r.gradient.Parent = r.boxFrame

        r.stroke = Instance.new("UIStroke")
        r.stroke.Color = DROPGUN_COLOR
        r.stroke.Thickness = 0.5
        r.stroke.Transparency = 0
        r.stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        r.stroke.Parent = r.boxFrame
    end
    local s = 16
    r.boxFrame.Position = UDim2.fromOffset(pos.X - s / 2, pos.Y - s / 2)
    r.boxFrame.Size = UDim2.fromOffset(s, s)

    local t = os.clock()
    local gunDark = DROPGUN_COLOR:Lerp(Color3.fromRGB(0, 0, 0), 0.6)
    local gunMid = DROPGUN_COLOR:Lerp(gunDark, 0.5)
    r.gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, DROPGUN_COLOR),
        ColorSequenceKeypoint.new(0.5, gunMid),
        ColorSequenceKeypoint.new(1, gunDark),
    })
    r.gradient.Rotation = (t * 70) % 360
    r.gradient.Offset = Vector2.new(math.sin(t * 1.6) * 0.35, math.cos(t * 1.6) * 0.35)

    r.stroke.Color = DROPGUN_COLOR:Lerp(Color3.fromRGB(0, 0, 0), 0.75)
    r.boxFrame.Visible = true
end

local _dropList = {}
local _dropScanTime = 0
function updateDropGun()
    if not Settings.DropGun then
        if next(DropGuns) then clearDropGuns() end
        _dropList = {}
        return
    end
    local mode = Settings.Mode
    if os.clock() - _dropScanTime >= 0.5 then
        _dropScanTime = os.clock()
        local map = findMap()
        local newList = {}
        local found = {}
        if map then
            for _, obj in ipairs(map:GetDescendants()) do
                if obj.Name == "GunDrop" and (obj:IsA("Model") or obj:IsA("BasePart")) then
                    table.insert(newList, obj)
                    found[obj] = true
                end
            end
        end
        _dropList = newList
        for obj in pairs(DropGuns) do
            if not found[obj] then destroyDropRec(obj) end
        end
    end
    local camPos = Camera.CFrame.Position
    local maxSq = MAX_DIST * MAX_DIST
    for _, obj in ipairs(_dropList) do
        if obj.Parent then
            local r = getDropRec(obj)
            local part = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
            local off = part and (camPos - part.Position) or nil
            local tooFar = (not part) or (off.X * off.X + off.Y * off.Y + off.Z * off.Z > maxSq)
            if tooFar then
                if r.hl then r.hl.Enabled = false end
                if r.box then r.box.Visible = false end if r.boxFrame then r.boxFrame.Visible = false end
                if r.chams then for _, a in ipairs(r.chams) do a.Visible = false end end
            elseif mode == "Chams" then
                if r.hl then r.hl.Enabled = false end
                if r.box then r.box.Visible = false end if r.boxFrame then r.boxFrame.Visible = false end
                dropChams(obj, r)
            elseif mode == "Box" then
                if r.hl then r.hl.Enabled = false end
                if r.chams then for _, a in ipairs(r.chams) do a.Visible = false end end
                dropBox(obj, r)
            else
                if r.chams then for _, a in ipairs(r.chams) do a.Visible = false end end
                if r.box then r.box.Visible = false end if r.boxFrame then r.boxFrame.Visible = false end
                dropHighlight(obj, r)
            end
        end
    end
end

local _fxFrame = 0
function espTick()
    _frame = _frame + 1
    refreshSelf()

    _fxFrame = _fxFrame + 1
    if _fxFrame >= 3 then
        _fxFrame = 0
        updateChinaHat()
        updateTrail()
    end

    -- gun/drop box must track the camera every frame or it lags behind
    updateDropGun()

    if not Settings.Enabled or not roundActive() then
        for plr in pairs(ESP) do
            local e = ESP[plr]
            hideBox(e)
            hideText(e)
            hideChams(e)
            disableHighlight(plr)
        end
        return
    end

    local camPos = Camera.CFrame.Position
    local maxSq = MAX_DIST * MAX_DIST
    local mode = Settings.Mode

    for _, plr in ipairs(Players:GetPlayers()) do
        local e = ESP[plr]
        if plr == LocalPlayer then
            if e then hideBox(e) hideText(e) hideChams(e) disableHighlight(plr) end
        else
            local data = getData(plr)
            local char = data and plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local valid = hrp and data.Dead ~= true
            local role = valid and resolveRole(plr, data) or nil

            if valid and role and shouldShow(role) then
                local off = camPos - hrp.Position
                if off.X * off.X + off.Y * off.Y + off.Z * off.Z <= maxSq then
                    local c = COLORS[role]
                    e = e or createESP(plr)

                    if mode == "Highlight" then
                        applyHighlight(plr, char, c)
                        hideChams(e)
                    elseif mode == "Chams" then
                        applyChams(plr, char, c)
                        disableHighlight(plr)
                    else
                        disableHighlight(plr)
                        hideChams(e)
                    end

                    updateVisuals(plr, char, c, hrp, role)
                else
                    if e then hideBox(e) hideText(e) hideChams(e) disableHighlight(plr) end
                end
            else
                if e then hideBox(e) hideText(e) hideChams(e) disableHighlight(plr) end
            end
        end
    end
end

RunService.RenderStepped:Connect(function()
    pcall(espTick)
end)

Players.PlayerRemoving:Connect(function(plr)
    destroyESP(plr)
    PlayerData[plr.Name] = nil
end)

function bindRespawn(plr)
    plr.CharacterAdded:Connect(function()
        local e = ESP[plr]
        if e then
            if e.highlight then pcall(function() e.highlight:Destroy() end) e.highlight = nil end
            clearChams(e)
        end
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then bindRespawn(plr) end
end
Players.PlayerAdded:Connect(bindRespawn)

local UIReg, UIRegSeen = {}, {}
function RegisterUI(kind, tabName, title, api, callback)
    if not title or not api then return end
    local key = kind .. "|" .. tostring(tabName) .. "|" .. tostring(title)
    if UIRegSeen[key] then
        local n = 2
        while UIRegSeen[key .. "#" .. n] do n = n + 1 end
        key = key .. "#" .. n
    end
    UIRegSeen[key] = true
    UIReg[#UIReg + 1] = { key = key, kind = kind, api = api, callback = callback }
end

local WindUI = {}
local _lurkWindow = nil

function WindUI:CreateWindow(cfg)
    cfg = cfg or {}
    local win = Lurk:CreateWindow({
        Name = cfg.Title or "Menu",
        Size = cfg.Size,
    })
    _lurkWindow = win

    local WindowShim = {}

    function WindowShim:Tab(tcfg)
        tcfg = tcfg or {}
        local tab = win:AddTab(tcfg.Title or "Tab")

        local TabShim = {}

        function TabShim:Toggle(c)
            c = c or {}
            local api = tab:AddToggle({ Name = c.Title, Default = c.Value, Callback = c.Callback })
            RegisterUI("Toggle", tcfg.Title, c.Title, api, c.Callback)
            return api
        end

        function TabShim:Dropdown(c)
            c = c or {}
            local api = tab:AddDropdown({
                Name = c.Title,
                Options = c.Values,
                Default = c.Value,
                Callback = c.Callback,
            })
            RegisterUI("Dropdown", tcfg.Title, c.Title, api, c.Callback)
            return {
                Refresh = function(_, newValues) api.SetOptions(newValues) end,
                Set = function(_, v) api.Set(v) end,
                Get = function(_) return api.Get() end,
            }
        end

        function TabShim:Slider(c)
            c = c or {}
            local v = c.Value or {}
            local api = tab:AddSlider({
                Name = c.Title,
                Min = v.Min,
                Max = v.Max,
                Default = v.Default,
                Step = c.Step,
                Callback = c.Callback,
            })
            RegisterUI("Slider", tcfg.Title, c.Title, api, c.Callback)
            return api
        end

        function TabShim:AddSlider(c)
            return tab:AddSlider(c)
        end

        function TabShim:Button(c)
            c = c or {}
            return tab:AddButton({ Name = c.Title, Callback = c.Callback })
        end

        function TabShim:Colorpicker(c)
            c = c or {}
            local api = tab:AddColorPicker({ Name = c.Title, Default = c.Default, Callback = c.Callback })
            RegisterUI("Color", tcfg.Title, c.Title, api, c.Callback)
            return api
        end

        function TabShim:Textbox(c)
            c = c or {}
            local api = tab:AddTextbox({ Name = c.Title, Default = c.Value, Placeholder = c.Placeholder, Callback = c.Callback })
            RegisterUI("Textbox", tcfg.Title, c.Title, api, c.Callback)
            return api
        end

        function TabShim:Section(c)
            c = c or {}
            return tab:AddSection(c.Title)
        end

        function TabShim:Paragraph(c)
            c = c or {}
            return tab:AddParagraph({ Title = c.Title, Text = c.Desc or c.Text })
        end

        return TabShim
    end

    function WindowShim:AddFloatingButton(c)
        return win:AddFloatingButton(c)
    end

    function WindowShim:AddFloatingToggle(c)
        return win:AddFloatingToggle(c)
    end

    function WindowShim:Notify(c)
        return win:Notify(c)
    end

    task.defer(function()
        pcall(function() win:Toggle(true) end)
    end)

    return WindowShim
end

function WindUI:Notify(c)
    if _lurkWindow then
        return _lurkWindow:Notify(c)
    end
end

local Window = WindUI:CreateWindow({
    Title = "Mindjorn Hub",
    Author = "v2.0",
    Folder = "MindjornHub",
    Icon = "solar:eye-bold",
    Size = UDim2.fromOffset(480, 340),
    NewElements = true,
    HideSearchBar = true,
})

local VisualsTab = Window:Tab({
    Title = "Visuals",
    Icon = "solar:eye-bold",
    IconShape = "Square",
    Border = true,
})

VisualsTab:Toggle({
    Title = "Enable ESP",
    Value = false,
    Callback = function(v) Settings.Enabled = v end,
})

VisualsTab:Dropdown({
    Title = "ESP Mode",
    Values = { "Highlight", "Chams", "Box" },
    Value = "Highlight",
    Callback = function(opt) Settings.Mode = opt end,
})

VisualsTab:Toggle({ Title = "Show Name", Value = true, Callback = function(v) Settings.ShowName = v end })
VisualsTab:Toggle({ Title = "Player Icon", Value = false, Callback = function(v) Settings.ShowAvatar = v end })
VisualsTab:Toggle({ Title = "Show Role", Value = false, Callback = function(v) Settings.ShowRole = v end })
VisualsTab:Toggle({ Title = "Skeleton", Value = false, Callback = function(v) Settings.Skeleton = v end })
VisualsTab:Colorpicker({
    Title = "Skeleton Color",
    Default = Settings.SkeletonColor,
    Transparency = 0,
    Locked = false,
    Callback = function(color) Settings.SkeletonColor = color end,
})
VisualsTab:Toggle({ Title = "Show Distance", Value = true, Callback = function(v) Settings.ShowDistance = v end })
VisualsTab:Toggle({ Title = "Tracers", Value = false, Callback = function(v) Settings.Tracers = v end })
VisualsTab:Toggle({ Title = "Player Click Menu", Value = false, Callback = function(v) Settings.ClickMenu = v end })

VisualsTab:Section({ Title = "Roles" })

VisualsTab:Toggle({
    Title = "Murderer",
    Value = false,
    Callback = function(v) Settings.Murderer = v end,
})

VisualsTab:Toggle({
    Title = "Sheriff / Hero",
    Value = false,
    Callback = function(v) Settings.Sheriff = v end,
})

VisualsTab:Toggle({
    Title = "Innocent",
    Value = false,
    Callback = function(v) Settings.Innocent = v end,
})

VisualsTab:Toggle({
    Title = "Notify My Role",
    Value = false,
    Callback = function(v) Settings.NotifyMyRole = v end,
})

VisualsTab:Section({ Title = "Map" })

VisualsTab:Toggle({
    Title = "X-Ray",
    Value = false,
    Callback = function(v) setXRay(v) end,
})

VisualsTab:Toggle({
    Title = "Drop Gun ESP",
    Value = false,
    Callback = function(v) Settings.DropGun = v end,
})

VisualsTab:Section({ Title = "Player" })

VisualsTab:Toggle({
    Title = "China Hat",
    Value = false,
    Callback = function(v) Settings.ChinaHat = v end,
})
VisualsTab:Colorpicker({
    Title = "China Hat Color",
    Default = Settings.ChinaHatColor,
    Transparency = 0,
    Locked = false,
    Callback = function(color) Settings.ChinaHatColor = color end,
})

VisualsTab:Toggle({
    Title = "Trail",
    Value = false,
    Callback = function(v) Settings.Trail = v end,
})
VisualsTab:Colorpicker({
    Title = "Trail Color",
    Default = Settings.TrailColor,
    Transparency = 0,
    Locked = false,
    Callback = function(color) Settings.TrailColor = color end,
})



local SelectedPlayer = nil
local Spectating = nil
local origCamSubject = nil
local notify
local flingPlayer
local flingAll
local startLoopFlingAll

function getPlayerByName(name)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name == name then return p end
    end
    return nil
end

function playerNames()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(list, p.Name)
        end
    end
    return list
end

function teleportTo(target)
    local me, myHrp = getMyChar()
    if not me or not myHrp then return end
    local tc = target.Character
    local thrp = tc and tc:FindFirstChild("HumanoidRootPart")
    if thrp then
        myHrp.CFrame = thrp.CFrame * CFrame.new(0, 0, 3)
    end
end

function startSpectate(target)
    local tc = target.Character
    local thum = tc and tc:FindFirstChildOfClass("Humanoid")
    if thum then
        if not origCamSubject then origCamSubject = Camera.CameraSubject end
        Camera.CameraSubject = thum
        Spectating = target
    end
end

function stopSpectate()
    local me = LocalPlayer.Character
    local h = me and me:FindFirstChildOfClass("Humanoid")
    if h then Camera.CameraSubject = h end
    origCamSubject = nil
    Spectating = nil
end

local PlayersTab = Window:Tab({
    Title = "Players",
    Icon = "solar:users-group-rounded-bold",
    IconShape = "Square",
    Border = true,
})

local playerDropdown = PlayersTab:Dropdown({
    Title = "Target",
    Values = playerNames(),
    Value = "",
    Callback = function(opt) SelectedPlayer = opt end,
})

PlayersTab:Button({
    Title = "Teleport",
    Callback = function()
        local t = SelectedPlayer and getPlayerByName(SelectedPlayer)
        if t then teleportTo(t) end
    end,
})

PlayersTab:Button({
    Title = "Spectate",
    Callback = function()
        local t = SelectedPlayer and getPlayerByName(SelectedPlayer)
        if t then startSpectate(t) end
    end,
})

PlayersTab:Button({
    Title = "Stop Spectate",
    Callback = function() stopSpectate() end,
})

PlayersTab:Button({
    Title = "Fling",
    Callback = function()
        local t = SelectedPlayer and getPlayerByName(SelectedPlayer)
        if not t then notify("Select a player first") return end
        flingPlayer(t)
    end,
})

PlayersTab:Button({
    Title = "Fling All",
    Callback = function() flingAll() end,
})

PlayersTab:Toggle({
    Title = "Loop Fling All",
    Value = false,
    Callback = function(v)
        Settings.LoopFlingAll = v
        if v then startLoopFlingAll() end
    end,
})


function refreshPlayerList()
    pcall(function() playerDropdown:Refresh(playerNames()) end)
end

Players.PlayerAdded:Connect(function() task.defer(refreshPlayerList) end)
Players.PlayerRemoving:Connect(function() task.defer(refreshPlayerList) end)

function notify(msg)
    pcall(function()
        WindUI:Notify({ Title = "Mindjorn Hub", Content = msg, Icon = "solar:danger-triangle-bold", Duration = 4 })
    end)
end

function getTorso(plr)
    local c = plr.Character
    if not c then return nil end
    return c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or c:FindFirstChild("HumanoidRootPart")
end

function isAlive(plr)
    local d = getData(plr)
    if not d then return false end
    if d.Dead == true then return false end
    local c = plr.Character
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

function findMurderer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local d = getData(p)
            if d and resolveRole(p, d) == "Murderer" and d.Dead ~= true then
                return p
            end
        end
    end
    return nil
end

function isSheriffRole(p)
    local d = getData(p)
    if not d or d.Dead == true then return false end
    local r = resolveRole(p, d)
    return r == "Sheriff" or r == "Hero"
end

function findSheriff()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isSheriffRole(p) then
            return p
        end
    end
    return nil
end

function findNearestSheriff()
    local me, myHrp = getMyChar()
    if not myHrp then return findSheriff() end
    local best, bestD = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isSheriffRole(p) then
            local t = getTorso(p)
            if t then
                local dd = (myHrp.Position - t.Position).Magnitude
                if dd < bestD then best, bestD = p, dd end
            end
        end
    end
    return best
end

-- === Announce Roles feature (Mindjorn Hub) ===
function sendChatMessage(msg)
    local sent = false
    pcall(function()
        local TextChatService = game:GetService("TextChatService")
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local channels = TextChatService:FindFirstChild("TextChannels")
            local general = channels and channels:FindFirstChild("RBXGeneral")
            if general then
                general:SendAsync(msg)
                sent = true
            end
        end
    end)
    if not sent then
        pcall(function()
            local events = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
            local say = events and events:FindFirstChild("SayMessageRequest")
            if say then
                say:FireServer(msg, "All")
                sent = true
            end
        end)
    end
    return sent
end

function announceRoles()
    local s = findSheriff()
    local m = findMurderer()
    local sName = s and s.Name or "?"
    local mName = m and m.Name or "?"
    sendChatMessage("sheriff is " .. sName .. " and the killer is " .. mName)
end

-- auto-announce once at the start of each round
do
    local announced = false
    task.spawn(function()
        while true do
            if roundActive() then
                if not announced then
                    announced = true
                    if Settings.AutoAnnounceRoles then
                        task.wait(1.5) -- give the server a moment to assign roles
                        pcall(announceRoles)
                    end
                end
            else
                announced = false
            end
            task.wait(0.5)
        end
    end)
end

function getKnifeEvent()
    local function scan(parent)
        if not parent then return nil end
        local knife = parent:FindFirstChild("Knife")
        if knife then
            local ev = knife:FindFirstChild("Events")
            if ev then return ev:FindFirstChild("KnifeStabbed") end
        end
        return nil
    end
    return scan(LocalPlayer.Character) or scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
end

local KnifeThrowCache
function getKnifeThrow()
    -- cached: avoid rescanning the tree on every single throw (saves precious ms)
    if KnifeThrowCache then
        local ok, valid = pcall(function() return KnifeThrowCache:IsDescendantOf(game) end)
        if ok and valid then return KnifeThrowCache end
        KnifeThrowCache = nil
    end
    local function scan(parent)
        if not parent then return nil end
        local knife = parent:FindFirstChild("Knife")
        if knife then
            local ev = knife:FindFirstChild("Events")
            if ev then return ev:FindFirstChild("KnifeThrown") end
        end
        return nil
    end
    KnifeThrowCache = scan(LocalPlayer.Character) or scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
    return KnifeThrowCache
end

local AutoThrowing = false
function throwKnifeAll()
    if AutoThrowing then return end
    refreshSelf()
    if Me.Role ~= "Murderer" then
        notify("You are not the murderer")
        return
    end
    if not roundActive() or Me.Dead then return end
    local ev = getKnifeThrow()
    if not ev then notify("Knife not found") return end
    AutoThrowing = true
    task.spawn(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if not roundActive() then break end
            refreshSelf()
            if Me.Dead then break end
            if p ~= LocalPlayer and isAlive(p) then
                local me, myHrp, head = getMyChar()
                local torso = getTorso(p)
                if myHrp and torso then
                    local origin = head and head.CFrame or myHrp.CFrame
                    local aim = CFrame.new(origin.Position, torso.Position)
                    pcall(function() ev:FireServer(aim, CFrame.new(torso.Position)) end)
                    task.wait(0.1)
                end
            end
        end
        AutoThrowing = false
    end)
end

function equipKnife()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    local knife = (char and char:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife"))
    if knife and hum and knife.Parent ~= char then
        pcall(function() hum:EquipTool(knife) end)
    end
end

function findNearestAlive()
    local me, myHrp = getMyChar()
    if not myHrp then return nil end
    local best, bestD = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlive(p) then
            local t = getTorso(p)
            if t then
                local dd = (myHrp.Position - t.Position).Magnitude
                if dd < bestD then best, bestD = p, dd end
            end
        end
    end
    return best
end

local KNIFE_PARTS = { "Head", "UpperTorso", "Torso", "HumanoidRootPart", "LowerTorso",
    "LeftUpperArm", "RightUpperArm", "LeftLowerLeg", "RightLowerLeg",
    "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
function visiblePart(fromPos, char)
    -- checks EVERY body part: if any part of the target is visible, we can throw
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character, char }
    for _, name in ipairs(KNIFE_PARTS) do
        local part = char:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            local res = Workspace:Raycast(fromPos, part.Position - fromPos, params)
            if not res then return part end
        end
    end
    return nil
end

function findNearestVisible()
    local me, myHrp, head = getMyChar()
    if not myHrp then return nil end
    local fromPos = (head and head.Position) or myHrp.Position
    local best, bestPart, bestD = nil, nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlive(p) and p.Character then
            local part = visiblePart(fromPos, p.Character)
            if part then
                local dd = (myHrp.Position - part.Position).Magnitude
                if dd < bestD then best, bestPart, bestD = p, part, dd end
            end
        end
    end
    return best, bestPart
end

function knifeAimPos(origin, part)
    -- lead the shot: aim where the target WILL be (velocity * flight time),
    -- not the stale position they were at when the button was pressed
    local vel = part.AssemblyLinearVelocity
    local hv = Vector3.new(vel.X, 0, vel.Z)
    if hv.Magnitude < 1 then hv = Vector3.new(0, 0, 0) end
    if hv.Magnitude > 40 then hv = hv.Unit * 40 end
    local dist = (part.Position - origin).Magnitude
    return part.Position + hv * (0.08 + dist * 0.0045)
end

function throwKnifeNearest()
    refreshSelf()
    if Me.Role ~= "Murderer" then
        notify("You are not the murderer")
        return
    end
    if not roundActive() or Me.Dead then return end
    equipKnife()
    local ev = getKnifeThrow()
    if not ev then notify("Knife not found") return end
    local target, part = findNearestVisible()
    if not target or not part then notify("No target in sight") return end
    local me, myHrp, head = getMyChar()
    if not myHrp then return end
    local origin = (head and head.Position) or myHrp.Position
    local aimPos = knifeAimPos(origin, part)
    pcall(function() ev:FireServer(CFrame.new(origin, aimPos), CFrame.new(aimPos)) end)
end

-- Auto Throw Knife: zero-delay reaction — runs EVERY frame (Heartbeat),
-- keeps the knife pre-equipped so the throw fires the instant a target is visible
local KnifeAuto = { last = 0, equipTick = 0 }
RunService.Heartbeat:Connect(function()
    if not Settings.AutoKnifeThrow then return end
    pcall(function()
        refreshSelf()
        if Me.Role ~= "Murderer" or Me.Dead or not roundActive() then return end

        -- pre-equip the knife BEFORE any target shows up, so no equip lag at throw time
        if os.clock() - KnifeAuto.equipTick > 0.25 then
            KnifeAuto.equipTick = os.clock()
            equipKnife()
        end

        if os.clock() - KnifeAuto.last < 0.12 then return end
        local target, part = findNearestVisible()
        if not target or not part then return end
        local me, myHrp, head = getMyChar()
        if not myHrp then return end
        if (myHrp.Position - part.Position).Magnitude > 150 then return end
        local ev = getKnifeThrow()
        if not ev then return end
        local origin = (head and head.Position) or myHrp.Position
        local aimPos = knifeAimPos(origin, part)
        ev:FireServer(CFrame.new(origin, aimPos), CFrame.new(aimPos))
        KnifeAuto.last = os.clock()
    end)
end)

local getKnifeTool, getKnifeToolNoEquip, findKillRemote, fireKnife
function killSheriff()
    refreshSelf()
    if Me.Role ~= "Murderer" then
        notify("You are not the murderer")
        return
    end
    if not roundActive() or Me.Dead then return end
    local knife = getKnifeTool()
    if not knife then notify("Knife not found") return end
    local remote = findKillRemote(knife)
    if not remote then notify("Kill remote not found") return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlive(p) and isSheriffRole(p) then
            local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if root then fireKnife(remote, root) end
        end
    end
end

local Stats = game:GetService("Stats")

local ShootRemote
function getShoot()
    local char = LocalPlayer.Character
    local gun = char and (char:FindFirstChild("Gun") or char:FindFirstChild("GunClient"))
    if ShootRemote and ShootRemote.Parent and gun and ShootRemote:IsDescendantOf(gun) then
        return ShootRemote
    end
    ShootRemote = nil
    if gun then
        local ev = gun:FindFirstChild("Shoot") or gun:FindFirstChild("ShootEvent")
        if ev and ev:IsA("RemoteEvent") then ShootRemote = ev return ev end
        for _, d in ipairs(gun:GetDescendants()) do
            if d:IsA("RemoteEvent") then ShootRemote = d return d end
        end
    end
    return nil
end

local cachedPing, pingTime = 0.05, 0
function getPing()
    local now = os.clock()
    if now - pingTime > 0.5 then
        pingTime = now
        pcall(function()
            cachedPing = math.clamp(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000, 0.01, 0.3)
        end)
    end
    return cachedPing
end

function bestHitPart(char)
    return char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        or char:FindFirstChild("Head")
end

function predictTarget(char, aimPart, t)
    local pos = aimPart.Position
    local vel = aimPart.AssemblyLinearVelocity
    local hum = char:FindFirstChildOfClass("Humanoid")

    -- ignore jitter and clamp insane velocities (flings / lag spikes) so
    -- prediction never throws the aim way off target
    local hv = Vector3.new(vel.X, 0, vel.Z)
    local hmag = hv.Magnitude
    if hmag < 1.5 then
        hv = Vector3.new(0, 0, 0)
    else
        if hmag > 60 then
            hv = hv.Unit * 60
            hmag = 60
        end
        -- steer prediction along movement INTENT: MoveDirection has none of
        -- the physics jitter (bumps, knockback wobble) that assembly
        -- velocity picks up, so the lead lands on the real walking path
        if hum then
            local md = hum.MoveDirection
            local mdh = Vector3.new(md.X, 0, md.Z)
            if mdh.Magnitude > 0.5 then
                local speed = hmag
                if hum.WalkSpeed > 0 then
                    speed = math.min(hmag, hum.WalkSpeed + 2)
                end
                hv = mdh.Unit * speed
            end
        end
    end

    local px = pos.X + hv.X * t
    local pz = pos.Z + hv.Z * t
    local py = pos.Y

    local state = hum and hum:GetState()
    local airborne = state == Enum.HumanoidStateType.Freefall
        or state == Enum.HumanoidStateType.Jumping

    if airborne then
        local g = workspace.Gravity
        local vy = math.clamp(vel.Y, -80, 80)
        py = pos.Y + vy * t - 0.5 * g * t * t
        if hum then
            local floorY = pos.Y
            pcall(function()
                local rp = RaycastParams.new()
                rp.FilterType = Enum.RaycastFilterType.Exclude
                rp.FilterDescendantsInstances = { char }
                local hit = workspace:Raycast(pos, Vector3.new(0, -50, 0), rp)
                if hit then floorY = hit.Position.Y + 3 end
            end)
            if py < floorY then py = floorY end
        end
    end

    return Vector3.new(px, py, pz)
end

function predictPosition(origin, p)
    local char = p.Character
    local aimPart = char and bestHitPart(char)
    if not aimPart then return nil end
    return predictTarget(char, aimPart, getPing())
end

function fireShoot(plr, throughWalls)
    local shoot = getShoot()
    if not shoot then return false end
    local char = plr.Character
    local aimPart = char and bestHitPart(char)
    if not aimPart then return false end
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return false end

    local origin, targetPos
    if throughWalls then
        -- through-walls: shot spawns right next to the target, so bullet
        -- flight time is ~0. Predict only ONE-WAY latency (ping/2) plus a
        -- small server-processing margin — full RTT overshoots a walking
        -- target by 1-2 studs and causes misses.
        local t = getPing() * 0.5 + 0.03
        targetPos = predictTarget(char, aimPart, t)

        local vel = aimPart.AssemblyLinearVelocity
        local hv = Vector3.new(vel.X, 0, vel.Z)
        if hv.Magnitude >= 1.5 then
            -- target is moving: spawn the shot AHEAD of them along their
            -- movement and fire backwards along the path. Any timing error
            -- then only shifts WHERE on the line they get hit — instead of
            -- making the bullet pass by their side.
            local unit = hv.Unit
            local dist = 5
            pcall(function()
                local rp = RaycastParams.new()
                rp.FilterType = Enum.RaycastFilterType.Exclude
                rp.FilterDescendantsInstances = { char, myChar }
                local hit = workspace:Raycast(targetPos, unit * (dist + 0.5), rp)
                if hit then
                    -- clamp INSIDE the free space: never past the wall, even
                    -- when the wall is closer than the old 1.5-stud minimum
                    dist = math.clamp((hit.Position - targetPos).Magnitude - 0.5, 0.75, 5)
                end
            end)
            origin = targetPos + unit * dist + Vector3.new(0, 0.2, 0)
        else
            -- stationary target: spawn close on our side of them
            local dir = myHrp.Position - targetPos
            local unit = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(0, 0, 1)
            origin = targetPos + unit * 2 + Vector3.new(0, 0.2, 0)
        end

        -- final line-of-fire check: if anything sits between the spawned
        -- origin and the target (thin wall, prop, doorframe), pull the
        -- origin to 1.2 studs in front of the target so the shot can't
        -- be eaten by geometry
        pcall(function()
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Exclude
            rp.FilterDescendantsInstances = { char, myChar }
            local dir = targetPos - origin
            if dir.Magnitude > 0.05 and workspace:Raycast(origin, dir, rp) then
                origin = targetPos - dir.Unit * 1.2 + Vector3.new(0, 0.2, 0)
            end
        end)
    else
        -- regular shot travels across the map: full ping keeps covering
        -- one-way latency + bullet travel time
        targetPos = predictTarget(char, aimPart, getPing())
        local head = myChar:FindFirstChild("Head")
        origin = (head and head.Position) or myHrp.Position
    end

    shoot:FireServer(CFrame.new(origin, targetPos), CFrame.new(targetPos))
    return true
end

function equipGun()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    local gun = (char and char:FindFirstChild("Gun")) or (bp and bp:FindFirstChild("Gun"))
    if gun and hum and gun.Parent ~= char then
        pcall(function() hum:EquipTool(gun) end)
    end
end

local KnifeKillRemote
function getKnifeTool()
    local char = LocalPlayer.Character
    if not char then return nil end
    local knife = char:FindFirstChild("Knife") or char:FindFirstChild("KnifeClient")
    if knife then return knife end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        local k = bp:FindFirstChild("Knife") or bp:FindFirstChild("KnifeClient")
        if k then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum:EquipTool(k) end) end
            task.wait(0.05)
            return char:FindFirstChild("Knife") or char:FindFirstChild("KnifeClient")
        end
    end
    return nil
end

-- Kill Aura variant: locate the knife WITHOUT equipping it.
-- (the kill remote lives inside the knife object even while it sits in the backpack,
--  so there's no need to constantly pull the knife out for the aura)
function getKnifeToolNoEquip()
    local char = LocalPlayer.Character
    if char then
        local knife = char:FindFirstChild("Knife") or char:FindFirstChild("KnifeClient")
        if knife then return knife end
    end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        local k = bp:FindFirstChild("Knife") or bp:FindFirstChild("KnifeClient")
        if k then return k end
    end
    return nil
end

function findKillRemote(knife)
    if not knife then return nil end
    if KnifeKillRemote then
        local ok = pcall(function() return KnifeKillRemote.ClassName end)
        if ok and KnifeKillRemote:IsDescendantOf(game) then return KnifeKillRemote end
        KnifeKillRemote = nil
    end
    for _, n in ipairs({ "HandleTouched", "Slash" }) do
        local ev = knife:FindFirstChild(n, true)
        if ev and (ev:IsA("RemoteEvent") or ev:IsA("RemoteFunction")) then KnifeKillRemote = ev return ev end
    end
    for _, d in ipairs(knife:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then KnifeKillRemote = d return d end
    end
    return nil
end

function fireKnife(remote, targetRoot)
    pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(targetRoot)
        else
            remote:InvokeServer(targetRoot)
        end
    end)
end

function lineClear(fromPos, targetChar)
    local part = targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso") or targetChar:FindFirstChild("HumanoidRootPart")
    if not part then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character }
    local dir = part.Position - fromPos
    local res = Workspace:Raycast(fromPos, dir, params)
    if not res then return true end
    return res.Instance and res.Instance:IsDescendantOf(targetChar)
end

function killAll()
    refreshSelf()
    if Me.Role ~= "Murderer" then
        notify("You are not the murderer")
        return
    end
    if not roundActive() or Me.Dead then return end
    local knife = getKnifeTool()
    if not knife then notify("Knife not found") return end
    local remote = findKillRemote(knife)
    if not remote then notify("Kill remote not found") return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlive(p) then
            local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if root then fireKnife(remote, root) end
        end
    end
end

function killMurder()
    refreshSelf()
    if not (Me.Role == "Sheriff" or Me.Role == "Hero") or Me.Dead then
        notify("You are not the sheriff")
        return
    end
    local m = findMurderer()
    if not m then notify("No murderer found") return end
    local torso = getTorso(m)
    local me, myHrp = getMyChar()
    if not torso or not myHrp then return end
    myHrp.CFrame = torso.CFrame * CFrame.new(0, 0, 10)
    equipGun()
    task.wait(0.06)
    fireShoot(m)
end

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local args = { ... }
    local method = getnamecallmethod()
    if Settings.SilentAim and method == "FireServer" and typeof(self) == "Instance" and self.Name == "Shoot" then
        local m = findMurderer()
        if m then
            local myChar = LocalPlayer.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myHrp then
                local aim = predictPosition(myHrp.Position, m)
                if aim then
                    args[1] = CFrame.new(myHrp.Position, aim)
                    args[2] = CFrame.new(aim)
                    return oldNamecall(self, unpack(args))
                end
            end
        end
    end
    return oldNamecall(self, ...)
end)

task.spawn(function()
    while true do
        task.wait(0.25)
        if Settings.KillAura then
            refreshSelf()
            if Me.Role == "Murderer" and roundActive() and not Me.Dead then
                local knife = getKnifeToolNoEquip()
                local remote = knife and findKillRemote(knife)
                local me, myHrp = getMyChar()
                if remote and myHrp then
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and isAlive(p) then
                            local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                            if root and (myHrp.Position - root.Position).Magnitude <= Settings.KillAuraRadius then
                                fireKnife(remote, root)
                            end
                        end
                    end
                end
            end
        end
    end
end)

local UIS_BTN = game:GetService("UserInputService")

function makeFloatingButton(cfg)
    cfg = cfg or {}
    local handle = Window:AddFloatingButton({
        Text = cfg.text,
        Size = cfg.w or cfg.h or 90,
        Position = cfg.pos or UDim2.new(0.5, -45, 0.62, 0),
        Callback = cfg.onClick,
    })
    return { gui = handle.Gui, btn = handle.Button, stroke = handle.Stroke, handle = handle }
end
local ShootObj
function makeShootButton()
    if ShootObj and ShootObj.gui.Parent then return end
    ShootObj = makeFloatingButton({
        id = "shootbtn",
        text = "SHOOT",
        w = Settings.ShootButtonSize,
        h = Settings.ShootButtonSize,
        radius = 18,
        pos = UDim2.new(0.5, -40, 0.68, 0),
        onClick = function()
            local m = findMurderer()
            if not m then notify("No murderer found") return end
            equipGun()
            local shoot
            for i = 1, 20 do
                shoot = getShoot()
                if shoot then break end
                task.wait(0.02)
            end
            if not shoot then notify("Shoot remote not found (equip gun)") return end
            fireShoot(m)
        end,
    })
end

function removeShootButton()
    if ShootObj then pcall(function() ShootObj.gui:Destroy() end) ShootObj = nil end
end

local ShootWHObj
function makeShootButtonWH()
    if ShootWHObj and ShootWHObj.gui.Parent then return end
    ShootWHObj = makeFloatingButton({
        id = "shootbtnwh",
        text = "SHOOT\nWALL",
        w = Settings.ShootButtonWHSize,
        h = Settings.ShootButtonWHSize,
        radius = 18,
        pos = UDim2.new(0.5, 60, 0.68, 0),
        onClick = function()
            local m = findMurderer()
            if not m then notify("No murderer found") return end
            equipGun()
            local shoot
            for i = 1, 20 do
                shoot = getShoot()
                if shoot then break end
                task.wait(0.02)
            end
            if not shoot then notify("Shoot remote not found (equip gun)") return end
            fireShoot(m, true)
        end,
    })
end
function removeShootButtonWH()
    if ShootWHObj then pcall(function() ShootWHObj.gui:Destroy() end) ShootWHObj = nil end
end

-- ============================================================
-- FLING  ::  single canonical implementation (working Lurk Fling / SkidFling logic, verbatim)
-- `flinging` is the shared guard other feature loops (Swim/Fly/FakeSpeed/PingLag/Spin/noclip) check.
-- ============================================================
local flinging = false

function getFlingRoot(char)
    return char and (
        char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("UpperTorso")
    )
end

function Fling(target)
    if flinging then return end
    if not target or not target:IsA("Player") then return end

    flinging = true

    local Character = LocalPlayer.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    local RootPart = getFlingRoot(Character)
    local TCharacter = target.Character

    if not (Character and Humanoid and RootPart and TCharacter) then
        flinging = false
        return
    end

    local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead = TCharacter:FindFirstChild("Head")

    if not THumanoid then
        flinging = false
        return
    end

    -- Pre-fling cleanup: strip foreign physics off our root and ensure the
    -- body can collide, otherwise our own huge velocity throws US into the sky.
    pcall(function()
        for _, o in ipairs(RootPart:GetChildren()) do
            if o:IsA("BodyVelocity") or o:IsA("BodyGyro") or o:IsA("BodyPosition")
                or o:IsA("BodyForce") or o:IsA("BodyThrust") or o:IsA("BodyAngularVelocity")
                or o:IsA("LinearVelocity") or o:IsA("AngularVelocity") or o:IsA("VectorForce")
                or o:IsA("AlignPosition") or o:IsA("AlignOrientation") then
                pcall(function() o:Destroy() end)
            end
        end
        Humanoid.PlatformStand = false
        for _, p in ipairs(Character:GetDescendants()) do
            if p:IsA("BasePart") then p.Anchored = false end
        end
        RootPart.CanCollide = true
    end)

    getgenv().OldPos = RootPart.CFrame
    getgenv().FPDH = workspace.FallenPartsDestroyHeight

    pcall(function()
        workspace.FallenPartsDestroyHeight = 0 / 0
    end)

    local BV = Instance.new("BodyVelocity")
    BV.Parent = RootPart
    BV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    BV.Velocity = Vector3.new(0, 0, 0)

    pcall(function()
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    end)

    local function FPos(BasePart, Pos, Ang)
        if not flinging then return end
        if not Character or not RootPart or not BasePart then return end

        local cf = CFrame.new(BasePart.Position) * Pos * Ang

        RootPart.CFrame = cf

        pcall(function()
            Character:SetPrimaryPartCFrame(cf)
        end)

        RootPart.Velocity = Vector3.new(9e7, 9e8, 9e7)
        RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
    end

    local function SFBasePart(BasePart)
        local Time = tick()
        local Angle = 0

        repeat
            if not BasePart or not BasePart.Parent then break end
            if not THumanoid or not THumanoid.Parent then break end

            if BasePart.Velocity.Magnitude < 50 then
                Angle += 100

                FPos(
                    BasePart,
                    CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25,
                    CFrame.Angles(math.rad(Angle), 0, 0)
                )

                task.wait()

                FPos(
                    BasePart,
                    CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25,
                    CFrame.Angles(math.rad(Angle), 0, 0)
                )

                task.wait()
            else
                FPos(
                    BasePart,
                    CFrame.new(0, 1.5, THumanoid.WalkSpeed),
                    CFrame.Angles(math.rad(90), 0, 0)
                )

                task.wait()

                FPos(
                    BasePart,
                    CFrame.new(0, -1.5, -THumanoid.WalkSpeed),
                    CFrame.Angles(0, 0, 0)
                )

                task.wait()
            end
        until tick() - Time > 1.8 or not flinging
    end

    if TRootPart then
        SFBasePart(TRootPart)
    elseif THead then
        SFBasePart(THead)
    end

    pcall(function()
        BV:Destroy()
    end)

    pcall(function()
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    end)

    pcall(function()
        workspace.CurrentCamera.CameraSubject = Humanoid
    end)

    if getgenv().OldPos then
        local start = tick()
        local backCF = getgenv().OldPos * CFrame.new(0, 0.5, 0)

        repeat
            -- strip any residual mover that could keep launching us
            pcall(function()
                for _, o in ipairs(RootPart:GetChildren()) do
                    if o:IsA("BodyMover") or o:IsA("LinearVelocity") or o:IsA("AngularVelocity")
                        or o:IsA("VectorForce") or o:IsA("AlignPosition") or o:IsA("AlignOrientation") then
                        pcall(function() o:Destroy() end)
                    end
                end
            end)

            RootPart.CFrame = backCF

            pcall(function()
                Character:SetPrimaryPartCFrame(backCF)
            end)

            pcall(function()
                Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end)

            for _, part in ipairs(Character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.Velocity = Vector3.new()
                    part.RotVelocity = Vector3.new()
                    part.AssemblyLinearVelocity = Vector3.new()
                    part.AssemblyAngularVelocity = Vector3.new()
                end
            end

            task.wait()
        until (RootPart.Position - getgenv().OldPos.Position).Magnitude < 8 or tick() - start > 6

        -- final snap to be safe
        pcall(function() RootPart.CFrame = backCF end)

        pcall(function()
            workspace.FallenPartsDestroyHeight = getgenv().FPDH or -500
        end)
    end

    flinging = false
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if flinging then
        flinging = false
    end
end)

-- All player-fling entry points route through the single Fling() above.
function flingPlayer(target)
    if target and target:IsA("Player") then Fling(target) end
end
function flingAll()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            Fling(plr)
        end
    end
end
function startLoopFlingAll()
    task.spawn(function()
        while Settings.LoopFlingAll do
            for _, plr in ipairs(Players:GetPlayers()) do
                if not Settings.LoopFlingAll then break end
                if plr ~= LocalPlayer then
                    Fling(plr)
                end
            end
            task.wait()
        end
    end)
end


local RolesTab = Window:Tab({
    Title = "Roles",
    Icon = "solar:gun-bold",
    IconShape = "Square",
    Border = true,
})

local ThrowKObj -- forward declaration: the floating button itself is created later

RolesTab:Section({ Title = "Murderer" })

RolesTab:Button({
    Title = "Kill All",
    Callback = function() killAll() end,
})

RolesTab:Button({
    Title = "Kill Sheriff",
    Callback = function() killSheriff() end,
})

RolesTab:Button({
    Title = "Fling Sheriff",
    Callback = function()
        local s = findSheriff()
        if not s then notify("No sheriff found") return end
        flingPlayer(s)
    end,
})

RolesTab:Toggle({
    Title = "Kill Aura",
    Value = false,
    Callback = function(v) Settings.KillAura = v end,
})

RolesTab:Slider({
    Title = "Kill Aura Radius",
    Step = 5,
    Value = { Min = 5, Max = 100, Default = 50 },
    Callback = function(v) Settings.KillAuraRadius = v end,
})

RolesTab:Toggle({
    Title = "Auto Throw Knife",
    Value = false,
    Callback = function(v) Settings.AutoKnifeThrow = v end,
})

local ThrowKShowTgl = RolesTab:Toggle({
    Title = "Throw Knife Button",
    Value = false,
    Callback = function(v)
        if ThrowKObj and ThrowKObj.gui then ThrowKObj.gui.Enabled = v end
    end,
})

RolesTab:Slider({
    Title = "Throw Knife Button Size",
    Step = 5,
    Value = { Min = 55, Max = 200, Default = 60 },
    Callback = function(v)
        Settings.ThrowKnifeButtonSize = v
        if ThrowKObj and ThrowKObj.handle and ThrowKObj.handle.SetSize then
            ThrowKObj.handle:SetSize(v)
        elseif ThrowKObj and ThrowKObj.btn then
            ThrowKObj.btn.Size = UDim2.fromOffset(v, v)
        end
    end,
})

RolesTab:Section({ Title = "Sheriff" })

RolesTab:Toggle({
    Title = "Lock Cam (Murderer)",
    Value = false,
    Callback = function(v) Settings.LockCam = v end,
})

RolesTab:Toggle({
    Title = "Silent Aim",
    Value = false,
    Callback = function(v) Settings.SilentAim = v end,
})

RolesTab:Button({
    Title = "Kill Murder",
    Callback = function() killMurder() end,
})

RolesTab:Button({
    Title = "Fling Murderer",
    Callback = function()
        local m = findMurderer()
        if not m then notify("No murderer found") return end
        flingPlayer(m)
    end,
})

RolesTab:Toggle({
    Title = "Delayed Shoot",
    Value = false,
    Callback = function(v) Settings.DelayedShoot = v end,
})

RolesTab:Toggle({
    Title = "Shoot Button",
    Value = false,
    Callback = function(v)
        Settings.ShootButton = v
        if v then makeShootButton() else removeShootButton() end
    end,
})

RolesTab:Slider({
    Title = "Shoot Button Size",
    Step = 5,
    Value = { Min = 55, Max = 200, Default = 80 },
    Callback = function(v)
        Settings.ShootButtonSize = v
        if ShootObj and ShootObj.btn then ShootObj.btn.Size = UDim2.fromOffset(v, v) end
    end,
})

RolesTab:Toggle({
    Title = "Shoot Button (Walls)",
    Value = false,
    Callback = function(v)
        Settings.ShootButtonWH = v
        if v then makeShootButtonWH() else removeShootButtonWH() end
    end,
})

RolesTab:Slider({
    Title = "Shoot (Walls) Button Size",
    Step = 5,
    Value = { Min = 55, Max = 200, Default = 80 },
    Callback = function(v)
        Settings.ShootButtonWHSize = v
        if ShootWHObj and ShootWHObj.btn then ShootWHObj.btn.Size = UDim2.fromOffset(v, v) end
    end,
})

local UIS = game:GetService("UserInputService")

function applySpeed()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = Settings.WalkSpeed end
end

function applyJump()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.UseJumpPower = true
        hum.JumpPower = Settings.JumpPower
    end
end

task.spawn(function()
    while true do
        task.wait(0.6)
        if Settings.WalkSpeed ~= 16 or Settings.JumpPower ~= 50 then
            pcall(function()
                if Settings.WalkSpeed ~= 16 then applySpeed() end
                if Settings.JumpPower ~= 50 then applyJump() end
            end)
        end
    end
end)

local noclipConn
function setNoclip(state)
    if state then
        if noclipConn then return end
        noclipConn = RunService.Stepped:Connect(function()
            if flinging then return end -- don't kill collisions mid-fling
            local char = LocalPlayer.Character
            if char then
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then
                        p.CanCollide = false
                    end
                end
            end
        end)
    else
        if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    end
end

UIS.JumpRequest:Connect(function()
    if Settings.InfJump then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

local _gunCache, _gunCacheTime = nil, 0
function findMapGun()
    if _gunCache and _gunCache.Parent then
        if os.clock() - _gunCacheTime < (Settings.AutoGrabGun and 0.15 or 1) then return _gunCache end
    end
    _gunCacheTime = os.clock()
    local ok, res = pcall(function()
        local map
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:GetAttribute("MapID") ~= nil then map = obj break end
        end
        if not map then return nil end
        for _, d in ipairs(map:GetDescendants()) do
            if d.Name == "GunDrop" or d.Name == "GunSpawn" then
                local part = d:IsA("BasePart") and d or d:FindFirstChildWhichIsA("BasePart")
                if part then return part end
            end
        end
        return nil
    end)
    _gunCache = ok and res or nil
    return _gunCache
end

function grabGun()
    local part = findMapGun()
    local me, myHrp = getMyChar()
    if not part or not myHrp then return end
    local touchOk = pcall(function()
        firetouchinterest(myHrp, part, 0)
        firetouchinterest(myHrp, part, 1)
    end)
    if not touchOk then
        local prompt = part:FindFirstChildWhichIsA("ProximityPrompt", true) or (part.Parent and part.Parent:FindFirstChildWhichIsA("ProximityPrompt", true))
        if prompt then pcall(function() fireproximityprompt(prompt) end) end
    end
end

local AG = { busy = false }
AG.try = function()
    if AG.busy or not Settings.AutoGrabGun then return end
    AG.busy = true
    task.spawn(function()
        -- Me is refreshed every frame by the main tick, no extra refreshSelf here
        if (Me.Role == "Sheriff" or Me.Role == "Innocent" or Me.Role == "Hero") and not Me.Dead and roundActive() then
            local me = LocalPlayer.Character
            local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
            local hasGun = me and (me:FindFirstChild("Gun") or (bp and bp:FindFirstChild("Gun")))
            if not hasGun then grabGun() end
        end
        AG.busy = false
    end)
end
task.spawn(function()
    while true do
        if Settings.AutoGrabGun then
            AG.try()
            task.wait(0.07)
        else
            task.wait(0.4)
        end
    end
end)
-- instant reaction: the moment a gun drop appears in the map, grab it
Workspace.DescendantAdded:Connect(function(d)
    if not Settings.AutoGrabGun then return end
    local n = d.Name
    if n == "GunDrop" or n == "GunSpawn" then
        _gunCache = nil
        task.defer(AG.try)
    end
end)

local GrabObj

local _lastDelayShot = 0
task.spawn(function()
    while true do
        task.wait(0.1)
        if Settings.DelayedShoot then
            refreshSelf()
            if (Me.Role == "Sheriff" or Me.Role == "Hero") and not Me.Dead and roundActive() then
                local m = findMurderer()
                if m and m.Character and isAlive(m) then
                    local me, myHrp, head = getMyChar()
                    local fromPos = (head and head.Position) or (myHrp and myHrp.Position)
                    if fromPos and lineClear(fromPos, m.Character) and os.clock() - _lastDelayShot > 0.25 then
                        equipGun()
                        if fireShoot(m) then _lastDelayShot = os.clock() end
                    end
                end
            end
        end
    end
end)

-- Antifling: neutralize other players' abnormal velocity/rotation/size/collision.
local AF_MAX_VELOCITY = 60
local AF_MAX_ANGULAR_VEL = 30
local _antiflingConn = nil
function setAntifling(state)
    if state then
        if _antiflingConn then return end
        _antiflingConn = RunService.RenderStepped:Connect(function()
            if not Settings.Antifling then return end
            local myChar = LocalPlayer.Character
            if not myChar then return end
            local myHum = myChar:FindFirstChildOfClass("Humanoid")
            local myRoot = myChar:FindFirstChild("HumanoidRootPart")
            if not (myHum and myRoot and myHum.Health > 0) then return end
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    local char = plr.Character
                    if char then
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            if hrp.Velocity.Magnitude > AF_MAX_VELOCITY then
                                hrp.Velocity = Vector3.zero
                            end
                            if hrp.RotVelocity.Magnitude > AF_MAX_ANGULAR_VEL then
                                hrp.RotVelocity = Vector3.zero
                            end
                            if hrp.Size.X > 5 or hrp.Size.Y > 5 or hrp.Size.Z > 5 then
                                hrp.Size = Vector3.new(2, 2, 1)
                            end
                            if hrp.CanCollide == false then
                                hrp.CanCollide = true
                            end
                        end
                    end
                end
            end
        end)
    else
        if _antiflingConn then
            _antiflingConn:Disconnect()
            _antiflingConn = nil
        end
    end
end

local _gunNotified = false
task.spawn(function()
    while true do
        task.wait(1)
        if Settings.NotifyGun then
            local part = findMapGun()
            if part and not _gunNotified then
                _gunNotified = true
                notify("Gun available on the map")
            elseif not part then
                _gunNotified = false
            end
        else
            _gunNotified = false
        end
    end
end)

local PlayerTab = Window:Tab({
    Title = "Player",
    Icon = "solar:running-bold",
    IconShape = "Square",
    Border = true,
})

PlayerTab:Slider({
    Title = "Walk Speed",
    Step = 1,
    Value = { Min = 16, Max = 100, Default = 16 },
    Callback = function(v) Settings.WalkSpeed = v applySpeed() end,
})

PlayerTab:Slider({
    Title = "Jump Power",
    Step = 5,
    Value = { Min = 50, Max = 200, Default = 50 },
    Callback = function(v) Settings.JumpPower = v applyJump() end,
})

PlayerTab:Toggle({
    Title = "Noclip",
    Value = false,
    Callback = function(v) Settings.Noclip = v setNoclip(v) end,
})

PlayerTab:Toggle({
    Title = "Inf Jump",
    Value = false,
    Callback = function(v) Settings.InfJump = v end,
})

PlayerTab:Toggle({
    Title = "Antifling",
    Value = false,
    Callback = function(v) Settings.Antifling = v setAntifling(v) end,
})

-- ==== Swimming ====
local Swim = { on = false, force = nil, att = nil }
Swim.cleanup = function()
    if Swim.force then pcall(function() Swim.force:Destroy() end) Swim.force = nil end
    if Swim.att then pcall(function() Swim.att:Destroy() end) Swim.att = nil end
    pcall(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end)
end
PlayerTab:Toggle({
    Title = "Swimming",
    Value = false,
    Callback = function(v)
        Swim.on = v
        Settings.SwimOn = v
        if not v then Swim.cleanup() end
    end,
})
RunService.RenderStepped:Connect(function()
    if not Swim.on or flinging then return end
    pcall(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end
        -- neutral buoyancy: a force cancels gravity so you float like in water
        if not Swim.force or Swim.force.Parent ~= hrp then
            if Swim.force then pcall(function() Swim.force:Destroy() end) end
            if Swim.att then pcall(function() Swim.att:Destroy() end) end
            local att = Instance.new("Attachment")
            att.Name = "\0swimatt"
            att.Parent = hrp
            local vf = Instance.new("VectorForce")
            vf.Name = "\0swim"
            vf.Attachment0 = att
            vf.RelativeTo = Enum.ActuatorRelativeTo.World
            vf.Force = Vector3.new(0, 0, 0)
            vf.Parent = hrp
            Swim.att = att
            Swim.force = vf
        end
        Swim.force.Force = Vector3.new(0, hrp.AssemblyMass * workspace.Gravity, 0)
        hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
        if hum:GetState() ~= Enum.HumanoidStateType.Swimming then
            hum:ChangeState(Enum.HumanoidStateType.Swimming)
        end
    end)
end)
LocalPlayer.CharacterAdded:Connect(function() Swim.force = nil Swim.att = nil end)
-- ==== /Swimming ====

-- ==== Gravity ====
Settings.GravityDefault = workspace.Gravity
PlayerTab:Slider({
    Title = "Gravity",
    Step = 2,
    Value = { Min = 0, Max = 400, Default = 196 },
    Callback = function(v)
        Settings.GravityCustom = true
        Settings.Gravity = v
        pcall(function() workspace.Gravity = v end)
    end,
})
PlayerTab:Button({
    Title = "Reset Gravity",
    Callback = function()
        Settings.GravityCustom = false
        pcall(function() workspace.Gravity = Settings.GravityDefault or 196.2 end)
        notify("Gravity reset to default")
    end,
})
RunService.Heartbeat:Connect(function()
    if not Settings.GravityCustom then return end
    pcall(function()
        if Settings.Gravity and math.abs(workspace.Gravity - Settings.Gravity) > 0.5 then
            workspace.Gravity = Settings.Gravity
        end
    end)
end)
-- ==== /Gravity ====

-- ==== Fly ====
local Fly = { enabled = false, speed = 60, bv = nil, slider = nil, toggle = nil }

Fly.set = function(v)
    Fly.enabled = v
    Settings.FlyOn = v
    if not v and Fly.bv then
        pcall(function() Fly.bv:Destroy() end)
        Fly.bv = nil
    end
end

Fly.toggle = PlayerTab:Toggle({
    Title = "Fly",
    Value = false,
    Callback = function(v)
        Fly.set(v)
        if v then
            if not Fly.slider and Fly.toggle and Fly.toggle.AddSlider then
                Fly.slider = Fly.toggle:AddSlider({
                    Name = "Fly Speed",
                    Min = 10, Max = 300, Step = 5,
                    Default = Fly.speed,
                    Callback = function(val) Fly.speed = val Settings.FlySpeed = val end,
                })
            end
        else
            if Fly.slider and Fly.slider.Destroy then pcall(function() Fly.slider.Destroy() end) end
            Fly.slider = nil
        end
    end,
})

RunService.RenderStepped:Connect(function()
    if not Fly.enabled or flinging then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local cam = workspace.CurrentCamera
    if not hum or not hrp or not cam then return end
    local bv = Fly.bv
    if not bv or bv.Parent ~= hrp then
        if bv then pcall(function() bv:Destroy() end) end
        bv = Instance.new("BodyVelocity")
        bv.Name = "\0fly"
        bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.Parent = hrp
        Fly.bv = bv
    end
    local move = hum.MoveDirection
    local vel = Vector3.new(0, 0, 0)
    if move.Magnitude > 0 then
        local look = cam.CFrame.LookVector
        local right = cam.CFrame.RightVector
        local flatL = Vector3.new(look.X, 0, look.Z)
        local flatR = Vector3.new(right.X, 0, right.Z)
        flatL = flatL.Magnitude > 0.001 and flatL.Unit or Vector3.new(0, 0, 0)
        flatR = flatR.Magnitude > 0.001 and flatR.Unit or Vector3.new(0, 0, 0)
        local f = move:Dot(flatL)
        local r = move:Dot(flatR)
        vel = look * f + right * r
        if vel.Magnitude > 0.001 then vel = vel.Unit * Fly.speed end
    end
    if hum.Jump then
        vel = Vector3.new(vel.X, Fly.speed * 0.85, vel.Z)
    end
    bv.Velocity = vel
end)
LocalPlayer.CharacterAdded:Connect(function() Fly.bv = nil end)
-- ==== /Fly ====

-- ==== Fake SpeedGlitch ====
local FakeSpeed = { enabled = false, value = 0, slider = nil, toggle = nil }
FakeSpeed.toggle = PlayerTab:Toggle({
    Title = "Fake SpeedGlitch",
    Value = false,
    Callback = function(v)
        FakeSpeed.enabled = v
        Settings.FakeSpeedOn = v
        if v then
            -- \u043f\u0440\u0438 \u0432\u043a\u043b\u044e\u0447\u0435\u043d\u0438\u0438 \u0441\u043d\u0438\u0437\u0443 \u043f\u043e\u044f\u0432\u043b\u044f\u0435\u0442\u0441\u044f \u0441\u043b\u0430\u0439\u0434\u0435\u0440 \u0440\u0435\u0433\u0443\u043b\u0438\u0440\u043e\u0432\u043a\u0438 \u0441\u043a\u043e\u0440\u043e\u0441\u0442\u0438
            if not FakeSpeed.slider and FakeSpeed.toggle and FakeSpeed.toggle.AddSlider then
                FakeSpeed.slider = FakeSpeed.toggle:AddSlider({
                    Name = "Speed",
                    Min = 0, Max = 200, Step = 1,
                    Default = FakeSpeed.value,
                    Callback = function(val) FakeSpeed.value = val Settings.FakeSpeedVal = val end,
                })
            end
        else
            if FakeSpeed.slider and FakeSpeed.slider.Destroy then
                pcall(function() FakeSpeed.slider.Destroy() end)
            end
            FakeSpeed.slider = nil
        end
    end,
})

RunService.RenderStepped:Connect(function()
    if not FakeSpeed.enabled or flinging then return end
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then return end
    -- \u0433\u043b\u0438\u0442\u0447 \u0441\u043a\u043e\u0440\u043e\u0441\u0442\u0438 \u0440\u0430\u0431\u043e\u0442\u0430\u0435\u0442 \u0432\u043e \u0432\u0440\u0435\u043c\u044f Freefall
    if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
        local moveDir = humanoid.MoveDirection
        if moveDir.Magnitude > 0 then
            root.Velocity = Vector3.new(
                moveDir.X * FakeSpeed.value,
                root.Velocity.Y,
                moveDir.Z * FakeSpeed.value
            )
        end
    end
end)
-- ==== /Fake SpeedGlitch ====

-- ==== FakeLag ====
-- FakeLag (Ping): mimics a real high-ping player. Movement is smooth for
-- random stretches, then a random-length lag spike hits: the character
-- freezes mid-motion and then rubber-bands (teleports) to where it should
-- be — exactly how laggy players look. Spike length jitters around the
-- configured ms value.
local PingLag = { on = false, ms = 200, t = 0, mode = "move", dur = 0, frozen = false, pend = Vector3.new(0, 0, 0), slider = nil, toggle = nil }
PingLag.unfreeze = function()
    PingLag.frozen = false
    PingLag.mode = "move"
    PingLag.dur = 0
    PingLag.t = 0
    PingLag.pend = Vector3.new(0, 0, 0)
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Anchored = false end
    end)
end
PingLag.toggle = PlayerTab:Toggle({
    Title = "FakeLag (Ping)",
    Value = false,
    Callback = function(v)
        PingLag.on = v
        PingLag.acc = 0
        if not v then PingLag.unfreeze() end
        if v then
            if not PingLag.slider and PingLag.toggle and PingLag.toggle.AddSlider then
                PingLag.slider = PingLag.toggle:AddSlider({
                    Name = "Lag (ms)",
                    Min = 50, Max = 1000, Step = 25,
                    Default = PingLag.ms,
                    Callback = function(val) PingLag.ms = val end,
                })
            end
        else
            if PingLag.slider and PingLag.slider.Destroy then pcall(function() PingLag.slider.Destroy() end) end
            PingLag.slider = nil
        end
    end,
})
RunService.Heartbeat:Connect(function(dt)
    if not PingLag.on or flinging then
        if PingLag.frozen then PingLag.unfreeze() end
        return
    end
    pcall(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        PingLag.t = PingLag.t + dt
        if PingLag.t >= PingLag.dur then
            PingLag.t = 0
            if PingLag.mode == "move" then
                -- lag spike begins: freeze, duration jitters around the ms value
                PingLag.mode = "freeze"
                PingLag.dur = (PingLag.ms / 1000) * (0.7 + math.random() * 0.8)
                PingLag.pend = Vector3.new(0, 0, 0)
                PingLag.frozen = true
                hrp.Anchored = true
            else
                -- spike ends: rubber-band catch-up to where we should be,
                -- then move smoothly for a random stretch
                PingLag.mode = "move"
                PingLag.dur = 0.25 + math.random() * 1.1
                PingLag.frozen = false
                hrp.Anchored = false
                if PingLag.pend.Magnitude > 0.05 then
                    hrp.CFrame = hrp.CFrame + PingLag.pend
                    PingLag.pend = Vector3.new(0, 0, 0)
                end
            end
        elseif PingLag.frozen and hum then
            -- remember the movement the player is trying to make during the
            -- spike, so the catch-up teleport lands where they "should" be
            PingLag.pend = PingLag.pend + hum.MoveDirection * hum.WalkSpeed * dt
        end
    end)
end)
LocalPlayer.CharacterAdded:Connect(function()
    PingLag.frozen = false
    PingLag.mode = "move"
    PingLag.dur = 0
    PingLag.t = 0
    PingLag.pend = Vector3.new(0, 0, 0)
end)
-- ==== /FakeLag ====

local EMOTES = {
    { Name = "Ninja Rest", ID = "rbxassetid://2431864798", Loop = true },
    { Name = "Floss", ID = "rbxassetid://2452938820", Loop = true },
    { Name = "Zen", ID = "rbxassetid://2431812646", Loop = true },
    { Name = "Dab", ID = "rbxassetid://2445521505", Loop = false },
    { Name = "Zombie", ID = "rbxassetid://2513692312", Loop = true },
    { Name = "Headless", ID = "rbxassetid://2513664073", Loop = false },
    { Name = "Sit", ID = "rbxassetid://2431845940", Loop = true },
}

local KeepOnWalk = false
local currentTrack = nil

function setAnimate(state)
    local char = LocalPlayer.Character
    local animate = char and char:FindFirstChild("Animate")
    if animate then pcall(function() animate.Disabled = state end) end
end

function stopAllTracks(humanoid, animator)
    local function killList(obj)
        local ok, tracks = pcall(function() return obj:GetPlayingAnimationTracks() end)
        if ok and tracks then
            for _, t in ipairs(tracks) do
                pcall(function() t:Stop(0) end)
            end
        end
    end
    if animator then killList(animator) end
    if humanoid then killList(humanoid) end
end

function stopEmote()
    if currentTrack then
        pcall(function() currentTrack:Stop() end)
        pcall(function() currentTrack:Destroy() end)
        currentTrack = nil
    end
    setAnimate(false)
end

function playEmote(emote)
    if currentTrack then
        pcall(function() currentTrack:Stop() end)
        pcall(function() currentTrack:Destroy() end)
        currentTrack = nil
    end
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid

    setAnimate(true)
    stopAllTracks(humanoid, animator)

    local anim = Instance.new("Animation")
    anim.AnimationId = emote.ID

    local success, track = pcall(function()
        return animator:LoadAnimation(anim)
    end)

    if success and track then
        track.Looped = emote.Loop
        pcall(function() track.Priority = Enum.AnimationPriority.Action4 end)
        track:Play()
        currentTrack = track
    end
end

function setupMovementStopping(char)
    local humanoid = char:WaitForChild("Humanoid")
    humanoid.Running:Connect(function(speed)
        if speed > 0.1 and currentTrack and not KeepOnWalk then
            stopEmote()
        end
    end)
end

if LocalPlayer.Character then
    task.spawn(setupMovementStopping, LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(function(char)
    currentTrack = nil
    task.spawn(setupMovementStopping, char)
end)

local EmotesTab = Window:Tab({
    Title = "Emotes",
    Icon = "solar:music-notes-bold",
    IconShape = "Square",
    Border = true,
})

EmotesTab:Toggle({
    Title = "Keep On Walk",
    Value = false,
    Callback = function(v) KeepOnWalk = v end,
})

EmotesTab:Section({ Title = "Emotes" })

for _, em in ipairs(EMOTES) do
    EmotesTab:Button({
        Title = em.Name,
        Callback = function() playEmote(em) end,
    })
end

EmotesTab:Button({
    Title = "Stop Emote",
    Callback = function() stopEmote() end,
})

-- ==== Fun functions (redistributed into Visuals / Player) ====
local Fun = {
    fov = 70,
    rainbow = false,
    rainbowOrig = nil,
    rainbowChar = nil,
}

VisualsTab:Slider({
    Title = "Camera FOV",
    Step = 1,
    Value = { Min = 40, Max = 120, Default = 70 },
    Callback = function(v) Fun.fov = v end,
})

PlayerTab:Toggle({
    Title = "Rainbow Body",
    Value = false,
    Callback = function(v)
        Fun.rainbow = v
        if not v and Fun.rainbowOrig and Fun.rainbowChar then
            pcall(function()
                for part, col in pairs(Fun.rainbowOrig) do
                    if part and part.Parent then part.Color = col end
                end
            end)
            Fun.rainbowOrig = nil
            Fun.rainbowChar = nil
        end
    end,
})

local FAKE_DEATH_EMOTE_IDS = { 93957913528389, 128669447776375, 138864094700166 }
function playFakeDeathEmote()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    -- catalog EMOTEs (asset type 61): played via the official emote API,
    -- works in every game and replicates to all players (FE) just like the emote wheel.
    -- The character is NOT locked: walking/jumping cancels it naturally,
    -- exactly like using a normal emote. A random one of the three is picked each press.
    local id = FAKE_DEATH_EMOTE_IDS[math.random(1, #FAKE_DEATH_EMOTE_IDS)]
    pcall(function()
        hum:PlayEmoteAndGetAnimTrackById(id)
    end)
end

PlayerTab:Button({
    Title = "Fake Death",
    Callback = function()
        playFakeDeathEmote()
    end,
})

-- ==== Emote Unlocker: кастомное "колесо эмоций" со всеми эмоциями каталога ====
do
    local HttpSvc = game:GetService("HttpService")
    local emGui, emList, emSearch, emPageLbl, emPrev, emNext, emStatus
    local emCursors, emPage, emNextCur, emKeyword, emBusy = { "" }, 1, nil, "", false

    local function emPlay(id)
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        pcall(function() hum:PlayEmoteAndGetAnimTrackById(id) end)
    end

    local function emFetch(keyword, cursor)
        local url = "https://catalog.roblox.com/v1/search/items/details?Category=12&Subcategory=39&Limit=30&SortType=2"
        if keyword and keyword ~= "" then
            url = url .. "&Keyword=" .. HttpSvc:UrlEncode(keyword)
        end
        if cursor and cursor ~= "" then
            url = url .. "&Cursor=" .. HttpSvc:UrlEncode(cursor)
        end
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if not ok or type(body) ~= "string" then return nil end
        local ok2, data = pcall(function() return HttpSvc:JSONDecode(body) end)
        if not ok2 or type(data) ~= "table" then return nil end
        return data
    end

    local function emRender(items)
        if not (emList and emList.Parent) then return end
        for _, ch in ipairs(emList:GetChildren()) do
            if ch:IsA("TextButton") then ch:Destroy() end
        end
        local n = 0
        for _, it in ipairs(items or {}) do
            if it.id then
                n = n + 1
                local b = Instance.new("TextButton")
                b.Size = UDim2.new(1, -6, 0, 30)
                b.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
                b.BorderSizePixel = 0
                b.AutoButtonColor = true
                b.Font = Enum.Font.Gotham
                b.TextSize = 13
                b.TextColor3 = Color3.fromRGB(220, 220, 220)
                b.TextXAlignment = Enum.TextXAlignment.Left
                b.Text = "  " .. tostring(it.name or it.id)
                b.LayoutOrder = n
                b.Parent = emList
                local c = Instance.new("UICorner")
                c.CornerRadius = UDim.new(0, 6)
                c.Parent = b
                local eid = it.id
                b.MouseButton1Click:Connect(function()
                    emPlay(eid)
                end)
            end
        end
        if emStatus then
            emStatus.Visible = (n == 0)
            if n == 0 then emStatus.Text = "Nothing found" end
        end
        if emPageLbl then emPageLbl.Text = "Page " .. tostring(emPage) end
        if emPrev then emPrev.TextTransparency = (emPage > 1) and 0 or 0.6 end
        if emNext then emNext.TextTransparency = emNextCur and 0 or 0.6 end
        emList.CanvasPosition = Vector2.new(0, 0)
    end

    local function emLoad(page)
        if emBusy then return end
        emBusy = true
        emPage = page
        if emStatus then
            emStatus.Text = "Loading..."
            emStatus.Visible = true
        end
        task.spawn(function()
            local data = emFetch(emKeyword, emCursors[page])
            emBusy = false
            if not (emGui and emGui.Parent) then return end
            if not data then
                if emStatus then emStatus.Text = "Failed to load emotes" emStatus.Visible = true end
                return
            end
            emNextCur = data.nextPageCursor
            if emNextCur then emCursors[page + 1] = emNextCur end
            emRender(data.data)
        end)
    end

    local function buildEmoteMenu()
        local parentGui
        pcall(function()
            parentGui = (gethui and gethui()) or game:GetService("CoreGui")
        end)

        emGui = Instance.new("ScreenGui")
        emGui.Name = "MindjornEmotes"
        emGui.ResetOnSpawn = false
        emGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        local okp = pcall(function() emGui.Parent = parentGui end)
        if not okp or not emGui.Parent then
            emGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end

        local frame = Instance.new("Frame")
        frame.Name = "Main"
        frame.Size = UDim2.fromOffset(300, 420)
        frame.Position = UDim2.new(0.5, -150, 0.5, -210)
        frame.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
        frame.BorderSizePixel = 0
        frame.Active = true
        frame.Parent = emGui
        local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0, 8) fc.Parent = frame
        local fs = Instance.new("UIStroke") fs.Color = Color3.fromRGB(60, 60, 60) fs.Parent = frame

        -- title bar (draggable)
        local title = Instance.new("TextLabel")
        title.BackgroundTransparency = 1
        title.Size = UDim2.new(1, -40, 0, 34)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 15
        title.TextColor3 = Color3.fromRGB(230, 230, 230)
        title.Text = "  Emotes"
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = frame

        local closeBtn = Instance.new("TextButton")
        closeBtn.AnchorPoint = Vector2.new(1, 0)
        closeBtn.Position = UDim2.new(1, -6, 0, 5)
        closeBtn.Size = UDim2.fromOffset(24, 24)
        closeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        closeBtn.BorderSizePixel = 0
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 13
        closeBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
        closeBtn.Text = "X"
        closeBtn.Parent = frame
        local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0, 6) cc.Parent = closeBtn
        closeBtn.MouseButton1Click:Connect(function()
            emGui.Enabled = false
        end)

        -- drag
        local UIS = game:GetService("UserInputService")
        local dragging, dragStart, startPos = false, nil, nil
        title.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = inp.Position
                startPos = frame.Position
                inp.Changed:Connect(function()
                    if inp.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        UIS.InputChanged:Connect(function(inp)
            if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
                local d = inp.Position - dragStart
                frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)

        -- search box
        emSearch = Instance.new("TextBox")
        emSearch.Position = UDim2.fromOffset(8, 38)
        emSearch.Size = UDim2.new(1, -16, 0, 28)
        emSearch.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
        emSearch.BorderSizePixel = 0
        emSearch.Font = Enum.Font.Gotham
        emSearch.TextSize = 13
        emSearch.TextColor3 = Color3.fromRGB(230, 230, 230)
        emSearch.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
        emSearch.PlaceholderText = "Search emotes..."
        emSearch.Text = ""
        emSearch.ClearTextOnFocus = false
        emSearch.Parent = frame
        local sc = Instance.new("UICorner") sc.CornerRadius = UDim.new(0, 6) sc.Parent = emSearch
        emSearch.FocusLost:Connect(function()
            emKeyword = emSearch.Text
            emCursors = { "" }
            emNextCur = nil
            emLoad(1)
        end)

        -- list
        emList = Instance.new("ScrollingFrame")
        emList.Position = UDim2.fromOffset(8, 74)
        emList.Size = UDim2.new(1, -16, 1, -116)
        emList.BackgroundTransparency = 1
        emList.BorderSizePixel = 0
        emList.CanvasSize = UDim2.new(0, 0, 0, 0)
        emList.AutomaticCanvasSize = Enum.AutomaticSize.Y
        emList.ScrollingDirection = Enum.ScrollingDirection.Y
        emList.ScrollBarThickness = 3
        emList.Parent = frame
        local ll = Instance.new("UIListLayout")
        ll.SortOrder = Enum.SortOrder.LayoutOrder
        ll.Padding = UDim.new(0, 4)
        ll.Parent = emList

        -- status label
        emStatus = Instance.new("TextLabel")
        emStatus.BackgroundTransparency = 1
        emStatus.Position = UDim2.fromOffset(8, 74)
        emStatus.Size = UDim2.new(1, -16, 0, 30)
        emStatus.Font = Enum.Font.Gotham
        emStatus.TextSize = 13
        emStatus.TextColor3 = Color3.fromRGB(150, 150, 150)
        emStatus.Text = "Loading..."
        emStatus.Visible = false
        emStatus.ZIndex = 5
        emStatus.Parent = frame

        -- bottom bar: prev / page / next
        emPrev = Instance.new("TextButton")
        emPrev.Position = UDim2.new(0, 8, 1, -34)
        emPrev.Size = UDim2.fromOffset(80, 26)
        emPrev.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
        emPrev.BorderSizePixel = 0
        emPrev.Font = Enum.Font.Gotham
        emPrev.TextSize = 13
        emPrev.TextColor3 = Color3.fromRGB(220, 220, 220)
        emPrev.Text = "< Prev"
        emPrev.Parent = frame
        local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(0, 6) pc.Parent = emPrev
        emPrev.MouseButton1Click:Connect(function()
            if emPage > 1 and not emBusy then emLoad(emPage - 1) end
        end)

        emNext = Instance.new("TextButton")
        emNext.AnchorPoint = Vector2.new(1, 0)
        emNext.Position = UDim2.new(1, -8, 1, -34)
        emNext.Size = UDim2.fromOffset(80, 26)
        emNext.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
        emNext.BorderSizePixel = 0
        emNext.Font = Enum.Font.Gotham
        emNext.TextSize = 13
        emNext.TextColor3 = Color3.fromRGB(220, 220, 220)
        emNext.Text = "Next >"
        emNext.Parent = frame
        local nc = Instance.new("UICorner") nc.CornerRadius = UDim.new(0, 6) nc.Parent = emNext
        emNext.MouseButton1Click:Connect(function()
            if emNextCur and not emBusy then emLoad(emPage + 1) end
        end)

        emPageLbl = Instance.new("TextLabel")
        emPageLbl.BackgroundTransparency = 1
        emPageLbl.Position = UDim2.new(0, 92, 1, -34)
        emPageLbl.Size = UDim2.new(1, -184, 0, 26)
        emPageLbl.Font = Enum.Font.Gotham
        emPageLbl.TextSize = 13
        emPageLbl.TextColor3 = Color3.fromRGB(170, 170, 170)
        emPageLbl.Text = "Page 1"
        emPageLbl.Parent = frame
    end

    function openEmoteMenu()
        if emGui and emGui.Parent then
            emGui.Enabled = not emGui.Enabled
            return
        end
        buildEmoteMenu()
        emLoad(1)
    end
end

RunService.Heartbeat:Connect(function(dt)
    -- FOV enforcement (only when changed from default)
    pcall(function()
        local cam = workspace.CurrentCamera
        if cam then
            if Fun.fov ~= 70 then
                if math.abs(cam.FieldOfView - Fun.fov) > 0.01 then cam.FieldOfView = Fun.fov end
            end
        end
    end)
    -- Rainbow body
    if Fun.rainbow then
        pcall(function()
            local char = LocalPlayer.Character
            if not char then return end
            if Fun.rainbowChar ~= char then
                Fun.rainbowChar = char
                Fun.rainbowOrig = {}
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        Fun.rainbowOrig[part] = part.Color
                    end
                end
            end
            local color = Color3.fromHSV((os.clock() * 0.35) % 1, 0.75, 1)
            for part in pairs(Fun.rainbowOrig) do
                if part and part.Parent then part.Color = color end
            end
        end)
    end
end)
-- ==== /Fun functions ====

function getRoleTarget(roleSet)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local d = getData(p)
            if d and d.Dead ~= true and roleSet[resolveRole(p, d)] then return p end
        end
    end
    return nil
end

local fbList = {}
function makeFB(id, text, pos, onClick)
    local obj = makeFloatingButton({ id = id, text = text, w = 60, h = 60, pos = pos, onClick = onClick })
    if obj and obj.gui then obj.gui.Enabled = false end
    fbList[#fbList + 1] = { obj = obj, id = id, name = (tostring(text or "Button")):gsub("\n", " ") }
    return obj
end
function makeFBToggle(id, onText, offText, pos, default, onChange)
    local handle = Window:AddFloatingToggle({
        Text = offText,
        OnText = onText,
        OffText = offText,
        Default = default or false,
        Size = 60,
        Position = pos or UDim2.new(0.5, -30, 0.62, 0),
        Callback = onChange,
    })
    local obj = { gui = handle.Gui, btn = handle.Button, stroke = handle.Stroke, handle = handle }
    if obj.gui then obj.gui.Enabled = false end
    fbList[#fbList + 1] = { obj = obj, id = id, name = (tostring(offText or "Button")):gsub("\n", " ") }
    return obj
end

local ButtonsTab = Window:Tab({ Title = "Buttons", Icon = "solar:gamepad-bold", IconShape = "Square", Border = true })

local resizeTargets = {}
local resizeEnabled = false

function showToggle(title, obj, tab)
    tab = tab or ButtonsTab
    local tgl = tab:Toggle({ Title = title, Value = false, Callback = function(v)
        if obj and obj.gui then obj.gui.Enabled = v end
    end })
    for _, e in ipairs(fbList) do
        if e.obj == obj then e.tgl = tgl end
    end
    if obj and obj.handle and tgl and tgl.AddSlider then
        local target = { tgl = tgl, obj = obj, name = title }
        resizeTargets[#resizeTargets + 1] = target
        if resizeEnabled then
            target.slider = tgl:AddSlider({
                Name = title .. " Size",
                Min = 40, Max = 200, Step = 5,
                Default = obj.handle:GetSize(),
                Callback = function(v) obj.handle:SetSize(v) end,
            })
        end
    end
    return tgl
end

ButtonsTab:Toggle({ Title = "Allow Resizing", Value = false, Callback = function(v)
    resizeEnabled = v
    for _, t in ipairs(resizeTargets) do
        if v then
            if not t.slider and t.tgl and t.tgl.AddSlider and t.obj and t.obj.handle then
                t.slider = t.tgl:AddSlider({
                    Name = t.name .. " Size",
                    Min = 40, Max = 200, Step = 5,
                    Default = t.obj.handle:GetSize(),
                    Callback = function(val) t.obj.handle:SetSize(val) end,
                })
            end
        else
            if t.slider and t.slider.Destroy then pcall(function() t.slider.Destroy() end) end
            t.slider = nil
        end
    end
end })

Settings.SpeedBoostBtn = false
local _boostCur = nil
local SpeedObj = makeFBToggle("\0fb_speed", "Speed\nON", "Speed\nOFF", UDim2.new(0, 30, 0.30, 0), false, function(on)
    Settings.SpeedBoostBtn = on
end)
RunService.Heartbeat:Connect(function(dt)
    pcall(function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if Settings.SpeedBoostBtn then
            if _boostCur == nil then _boostCur = math.max(hum.WalkSpeed, Settings.WalkSpeed or 16) end
            _boostCur = math.min(23, _boostCur + 60 * dt)
            hum.WalkSpeed = _boostCur
            if SpeedObj and SpeedObj.stroke then local p = (math.sin(os.clock()*6)+1)/2 SpeedObj.stroke.Color = Color3.fromRGB(80,160,255):Lerp(Color3.fromRGB(255,255,255), p) end
        elseif _boostCur ~= nil then
            hum.WalkSpeed = Settings.WalkSpeed or 16
            _boostCur = nil
        end
    end)
end)

Settings.SpinBtn = false
local SpinFX = { angle = 0, conn = nil, speed = 40 }
SpinFX.stop = function()
    if SpinFX.conn then SpinFX.conn:Disconnect() SpinFX.conn = nil end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    pcall(function()
        if hum then hum.AutoRotate = true end
        if hrp then
            local bg = hrp:FindFirstChild("\0spin")
            if bg then bg:Destroy() end
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end)
end
SpinFX.start = function()
    SpinFX.stop()
    SpinFX.angle = 0
    -- CFrame-driven spin: only the yaw is rotated each frame, no physics
    -- forces involved -> impossible to tip over, sink into the floor or
    -- lose movement control
    SpinFX.conn = RunService.RenderStepped:Connect(function(dt)
        if not Settings.SpinBtn or flinging then return end
        pcall(function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            if hum and hum.AutoRotate then hum.AutoRotate = false end
            SpinFX.angle = (SpinFX.angle + SpinFX.speed * math.min(dt, 0.1)) % (math.pi * 2)
            hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, SpinFX.angle, 0)
            -- kill residual angular momentum so physics never fights the spin
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end)
    end)
end
local SpinObj = makeFBToggle("\0fb_spin", "Spin\nON", "Spin\nOFF", UDim2.new(0, 30, 0.30, 80), false, function(on)
    Settings.SpinBtn = on
    if on then SpinFX.start() else SpinFX.stop() end
end)
RunService.Heartbeat:Connect(function()
    if not Settings.SpinBtn then return end
    pcall(function()
        if SpinObj and SpinObj.stroke then
            local p = (math.sin(os.clock() * 6) + 1) / 2
            SpinObj.stroke.Color = Color3.fromRGB(180, 80, 255):Lerp(Color3.fromRGB(255, 255, 255), p)
        end
    end)
end)

local FlingMObj = makeFB("\0fb_flingm", "Fling M", UDim2.new(0, 30, 0.30, 160), function()
    local t = getRoleTarget({ Murderer = true })
    if t then flingPlayer(t) else notify("No Murderer") end
end)

local FlingSObj = makeFB("\0fb_flings", "Fling S", UDim2.new(0, 30, 0.30, 240), function()
    local t = getRoleTarget({ Sheriff = true, Hero = true })
    if t then flingPlayer(t) else notify("No Sheriff/Hero") end
end)

ThrowKObj = makeFB("\0fb_throwk", "Throw\nKnife", UDim2.new(0, 30, 0.30, 400), function()
    throwKnifeNearest()
end)

GrabObj = makeFB("\0fb_grab", "Grab\nGun", UDim2.new(0, 30, 0.30, 320), function()
    grabGun()
end)
task.spawn(function()
    while GrabObj and GrabObj.btn and GrabObj.btn.Parent do
        local part = findMapGun()
        if GrabObj and GrabObj.btn then
            GrabObj.btn.Text = part and "Grab\nGun" or "No\nGun"
        end
        task.wait(1)
    end
end)

RolesTab:Section({ Title = "Innocent" })

RolesTab:Toggle({
    Title = "Auto Grab Gun",
    Value = false,
    Callback = function(v) Settings.AutoGrabGun = v end,
})

RolesTab:Toggle({
    Title = "Notify Gun Available",
    Value = false,
    Callback = function(v) Settings.NotifyGun = v end,
})

RolesTab:Slider({
    Title = "Grab Button Size",
    Step = 5,
    Value = { Min = 55, Max = 200, Default = 70 },
    Callback = function(v)
        Settings.GrabButtonSize = v
        if GrabObj and GrabObj.btn then GrabObj.btn.Size = UDim2.fromOffset(v, v) end
    end,
})

showToggle("Grab Gun", GrabObj, RolesTab)

RolesTab:Toggle({
    Title = "Auto Announce Roles",
    Value = false,
    Callback = function(v) Settings.AutoAnnounceRoles = v end,
})

RolesTab:Button({
    Title = "Announce Roles",
    Callback = function() announceRoles() end,
})
-- "Throw Knife Button" toggle lives in the Murderer section (created earlier);
-- hook it into the resize system here, same as showToggle would do
if ThrowKObj and ThrowKObj.handle and ThrowKShowTgl and ThrowKShowTgl.AddSlider then
    resizeTargets[#resizeTargets + 1] = { tgl = ThrowKShowTgl, obj = ThrowKObj, name = "Throw Knife Button" }
end

ButtonsTab:Section({ Title = "Show / Hide" })
showToggle("Speed Boost", SpeedObj)
showToggle("Spin", SpinObj)
showToggle("Fling Murderer", FlingMObj)
showToggle("Fling Sheriff/Hero", FlingSObj)

ButtonsTab:Section({ Title = "Animation Buttons" })
for i, em in ipairs(EMOTES) do
    local obj = makeFB("\0fb_em" .. i, em.Name, UDim2.new(0, 110, 0.30, (i - 1) * 80), function()
        playEmote(em)
    end)
    showToggle(em.Name, obj)
end

-- ==== Custom Buttons Constructor ====
ButtonsTab:Section({ Title = "Custom Buttons" })

local CustomButtonActions = {
    { Name = "Grab Gun", Run = function() grabGun() end },
    { Name = "Fling Murderer", Run = function()
        local t = getRoleTarget({ Murderer = true })
        if t then flingPlayer(t) else notify("No Murderer") end
    end },
    { Name = "Fling Sheriff/Hero", Run = function()
        local t = getRoleTarget({ Sheriff = true, Hero = true })
        if t then flingPlayer(t) else notify("No Sheriff/Hero") end
    end },
    { Name = "Kill All", Run = function() killAll() end },
    { Name = "Kill Murderer", Run = function() killMurder() end },
    { Name = "Kill Sheriff", Run = function() killSheriff() end },
    { Name = "Throw Knife Nearest", Run = function() throwKnifeNearest() end },
    { Name = "Throw Knife All", Run = function() throwKnifeAll() end },
    { Name = "Fake Death", Run = function() playFakeDeathEmote() end },
    { Name = "Stop Emote", Run = function() stopEmote() end },
}

local CustomToggleActions = {
    { Name = "Noclip", Set = function(v) Settings.Noclip = v setNoclip(v) end },
    { Name = "Inf Jump", Set = function(v) Settings.InfJump = v end },
    { Name = "Antifling", Set = function(v) Settings.Antifling = v setAntifling(v) end },
    { Name = "Kill Aura", Set = function(v) Settings.KillAura = v end },
    { Name = "Silent Aim", Set = function(v) Settings.SilentAim = v end },
    { Name = "Auto Grab Gun", Set = function(v) Settings.AutoGrabGun = v end },
    { Name = "Auto Knife Throw", Set = function(v) Settings.AutoKnifeThrow = v end },
    { Name = "Speed Boost", Set = function(v) Settings.SpeedBoostBtn = v end },
    { Name = "Spin", Set = function(v) Settings.SpinBtn = v if v then SpinFX.start() else SpinFX.stop() end end },
    { Name = "Fly", Set = function(v) Fly.set(v) end },
    { Name = "Lock Cam (Sheriff)", Set = function(v) Settings.LockCam = v end },
    { Name = "Fake SpeedGlitch", Set = function(v) FakeSpeed.enabled = v Settings.FakeSpeedOn = v end },
}

local Custom = { type = "Button", func = nil, count = 0, dropdown = nil }
Custom.namesFor = function(kind)
    local list = (kind == "Toggle") and CustomToggleActions or CustomButtonActions
    local names = {}
    for _, a in ipairs(list) do names[#names + 1] = a.Name end
    return names
end

Custom.findAction = function(kind, name)
    local list = (kind == "Toggle") and CustomToggleActions or CustomButtonActions
    for _, a in ipairs(list) do
        if a.Name == name then return a end
    end
end

Custom.func = CustomButtonActions[1].Name

ButtonsTab:Dropdown({
    Title = "Type",
    Values = { "Button", "Toggle" },
    Value = "Button",
    Callback = function(v)
        Custom.type = v
        Custom.func = Custom.namesFor(v)[1]
        if Custom.dropdown then
            pcall(function()
                Custom.dropdown:Refresh(Custom.namesFor(v))
                Custom.dropdown:Set(Custom.func)
            end)
        end
    end,
})

Custom.dropdown = ButtonsTab:Dropdown({
    Title = "Function",
    Values = Custom.namesFor("Button"),
    Value = Custom.func,
    Callback = function(v) Custom.func = v end,
})

do -- config system scope (keeps main-chunk locals under Lua's 200 limit)

local CustomCreated = {}

local function createCustomButton(kind, funcName, posOverride, sizeOverride, visible)
    local action = Custom.findAction(kind, funcName)
    if not action then return nil end
    Custom.count = Custom.count + 1
    local pos = posOverride or UDim2.new(0, 190, 0.30, (Custom.count - 1) * 80)
    local obj
    if kind == "Toggle" then
        obj = makeFBToggle("\0fb_custom" .. Custom.count, action.Name .. "\nON", action.Name .. "\nOFF", pos, false, function(on)
            pcall(action.Set, on)
        end)
    else
        obj = makeFB("\0fb_custom" .. Custom.count, action.Name, pos, function()
            pcall(action.Run)
        end)
    end
    showToggle(action.Name .. " #" .. Custom.count, obj)
    if sizeOverride and obj and obj.handle and obj.handle.SetSize then
        pcall(function() obj.handle:SetSize(sizeOverride) end)
    end
    local vis = (visible ~= false)
    if obj and obj.gui then obj.gui.Enabled = vis end
    for _, e in ipairs(fbList) do
        if e.obj == obj and e.tgl then pcall(function() e.tgl.Set(vis) end) end
    end
    CustomCreated[#CustomCreated + 1] = { kind = kind, func = funcName, obj = obj }
    return obj
end

ButtonsTab:Button({
    Title = "Create",
    Callback = function()
        local obj = createCustomButton(Custom.type, Custom.func, nil, nil, true)
        if obj then
            notify("Created: " .. tostring(Custom.func) .. " (" .. tostring(Custom.type) .. ")")
        else
            notify("Select a function first")
        end
    end,
})
-- ==== /Custom Buttons Constructor ====

-- ==== Settings Tab: Config System ====
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "solar:settings-bold", IconShape = "Square", Border = true })

local HttpS = game:GetService("HttpService")
local CFG_FOLDER = "MindjornHub"
local CFG_SUB = CFG_FOLDER .. "/configs"
local AUTOLOAD_FILE = CFG_FOLDER .. "/autoload.txt"

local canFiles = (type(writefile) == "function") and (type(readfile) == "function") and (type(isfile) == "function")

local function ensureFolders()
    if type(makefolder) == "function" and type(isfolder) == "function" then
        if not isfolder(CFG_FOLDER) then pcall(makefolder, CFG_FOLDER) end
        if not isfolder(CFG_SUB) then pcall(makefolder, CFG_SUB) end
    end
end

local function sanitizeName(n)
    n = tostring(n or ""):gsub("[^%w_%- ]", "")
    n = n:gsub("^%s+", ""):gsub("%s+$", "")
    return n
end

local function cfgPath(name) return CFG_SUB .. "/" .. name .. ".json" end
local function cfgKey(id) return (tostring(id):gsub("%z", "")) end

local function serU(u) return { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset } end
local function deserU(t) return UDim2.new(t[1] or 0, t[2] or 0, t[3] or 0, t[4] or 0) end

local UIExcludeKeys = {
    ["Textbox|Settings|Config Name"] = true,
    ["Dropdown|Settings|Saved Configs"] = true,
    ["Dropdown|Settings|Language"] = true,
}

local function encodeVal(v)
    if typeof(v) == "Color3" then return { c3 = { v.R, v.G, v.B } } end
    local t = type(v)
    if t == "number" or t == "string" or t == "boolean" then return v end
    return nil
end

local function decodeVal(v)
    if type(v) == "table" and type(v.c3) == "table" then
        return Color3.new(tonumber(v.c3[1]) or 0, tonumber(v.c3[2]) or 0, tonumber(v.c3[3]) or 0)
    end
    return v
end

local function snapshotEntry(e)
    local o = e.obj
    if not (o and o.btn) then return nil end
    local rec = { visible = (o.gui and o.gui.Enabled) == true }
    pcall(function() rec.pos = serU(o.btn.Position) end)
    if o.handle and o.handle.GetSize then
        pcall(function() rec.size = o.handle:GetSize() end)
    end
    return rec
end

local function isCustomObj(obj)
    for _, c in ipairs(CustomCreated) do
        if c.obj == obj then return true end
    end
    return false
end

local function buildConfig()
    local cfg = { version = 1, buttons = {}, custom = {}, shoot = {} }
    for _, e in ipairs(fbList) do
        if e.id and not isCustomObj(e.obj) then
            local rec = snapshotEntry(e)
            if rec then cfg.buttons[cfgKey(e.id)] = rec end
        end
    end
    for _, c in ipairs(CustomCreated) do
        for _, e in ipairs(fbList) do
            if e.obj == c.obj then
                local rec = snapshotEntry(e)
                if rec then
                    rec.kind = c.kind
                    rec.func = c.func
                    cfg.custom[#cfg.custom + 1] = rec
                end
                break
            end
        end
    end
    cfg.shoot.size = Settings.ShootButtonSize
    cfg.shoot.whSize = Settings.ShootButtonWHSize
    if ShootObj and ShootObj.btn then pcall(function() cfg.shoot.pos = serU(ShootObj.btn.Position) end) end
    if ShootWHObj and ShootWHObj.btn then pcall(function() cfg.shoot.whPos = serU(ShootWHObj.btn.Position) end) end
    cfg.ui = {}
    for _, r in ipairs(UIReg) do
        if not UIExcludeKeys[r.key] and not r.key:find("#%d+$") then
            local ok, v = pcall(function() return r.api.Get() end)
            if ok and v ~= nil then
                local ev = encodeVal(v)
                if ev ~= nil then cfg.ui[r.key] = ev end
            end
        end
    end
    return cfg
end

local function applyRec(e, rec)
    local o = e.obj
    if not o then return end
    if rec.size and o.handle and o.handle.SetSize then
        pcall(function() o.handle:SetSize(rec.size) end)
    end
    if rec.pos then
        if o.handle and o.handle.SetPosition then
            pcall(function() o.handle:SetPosition(deserU(rec.pos)) end)
        elseif o.btn then
            pcall(function() o.btn.Position = deserU(rec.pos) end)
        end
    end
    local vis = rec.visible == true
    if o.gui then o.gui.Enabled = vis end
    if e.tgl then pcall(function() e.tgl.Set(vis) end) end
end

local function removeCustomButtons()
    for _, c in ipairs(CustomCreated) do
        for idx = #fbList, 1, -1 do
            local e = fbList[idx]
            if e.obj == c.obj then
                if e.tgl then
                    pcall(function()
                        if e.tgl.Container then
                            e.tgl.Container:Destroy()
                        elseif e.tgl.Row then
                            e.tgl.Row:Destroy()
                        end
                    end)
                end
                table.remove(fbList, idx)
            end
        end
        for idx = #resizeTargets, 1, -1 do
            if resizeTargets[idx].obj == c.obj then table.remove(resizeTargets, idx) end
        end
        if c.obj and c.obj.gui then pcall(function() c.obj.gui:Destroy() end) end
    end
    CustomCreated = {}
    Custom.count = 0
end

local function applyConfig(cfg)
    if type(cfg) ~= "table" then return false end
    if type(cfg.ui) == "table" then
        for _, r in ipairs(UIReg) do
            local raw = cfg.ui[r.key]
            if raw ~= nil and not UIExcludeKeys[r.key] then
                local v = decodeVal(raw)
                pcall(function() if r.api.Set then r.api.Set(v) end end)
                if r.callback then pcall(r.callback, v) end
            end
        end
    end
    if type(cfg.buttons) == "table" then
        for _, e in ipairs(fbList) do
            if e.id and not isCustomObj(e.obj) then
                local rec = cfg.buttons[cfgKey(e.id)]
                if type(rec) == "table" then applyRec(e, rec) end
            end
        end
    end
    if type(cfg.custom) == "table" then
        removeCustomButtons()
        for _, rec in ipairs(cfg.custom) do
            if type(rec) == "table" and rec.func then
                createCustomButton(rec.kind or "Button", rec.func, rec.pos and deserU(rec.pos) or nil, rec.size, rec.visible == true)
            end
        end
    end
    if type(cfg.shoot) == "table" then
        if tonumber(cfg.shoot.size) then Settings.ShootButtonSize = tonumber(cfg.shoot.size) end
        if tonumber(cfg.shoot.whSize) then Settings.ShootButtonWHSize = tonumber(cfg.shoot.whSize) end
        if ShootObj and ShootObj.handle then
            pcall(function() ShootObj.handle:SetSize(Settings.ShootButtonSize) end)
            if cfg.shoot.pos then pcall(function() ShootObj.handle:SetPosition(deserU(cfg.shoot.pos)) end) end
        end
        if ShootWHObj and ShootWHObj.handle then
            pcall(function() ShootWHObj.handle:SetSize(Settings.ShootButtonWHSize) end)
            if cfg.shoot.whPos then pcall(function() ShootWHObj.handle:SetPosition(deserU(cfg.shoot.whPos)) end) end
        end
    end
    return true
end

local function listConfigs()
    local out = {}
    if type(listfiles) == "function" and type(isfolder) == "function" and isfolder(CFG_SUB) then
        local ok, files = pcall(listfiles, CFG_SUB)
        if ok and type(files) == "table" then
            for _, f in ipairs(files) do
                local name = tostring(f):match("([^/\\]+)%.json$")
                if name then out[#out + 1] = name end
            end
        end
    end
    table.sort(out)
    return out
end

local function saveConfig(name)
    if not canFiles then notify("Your executor has no file functions") return end
    name = sanitizeName(name)
    if name == "" then notify("Enter a config name first") return end
    ensureFolders()
    local ok, json = pcall(function() return HttpS:JSONEncode(buildConfig()) end)
    if not ok then notify("Failed to encode config") return end
    local ok2 = pcall(writefile, cfgPath(name), json)
    if ok2 then notify("Saved config: " .. name) else notify("Failed to write config file") end
end

local function loadConfig(name)
    if not canFiles then notify("Your executor has no file functions") return end
    name = sanitizeName(name)
    if name == "" then notify("Select a config first") return end
    local path = cfgPath(name)
    local okf, exists = pcall(isfile, path)
    if not okf or not exists then notify("Config not found: " .. name) return end
    local okr, raw = pcall(readfile, path)
    if not okr then notify("Failed to read config") return end
    local okd, cfg = pcall(function() return HttpS:JSONDecode(raw) end)
    if not okd then notify("Config file is corrupted") return end
    if applyConfig(cfg) then notify("Loaded config: " .. name) end
end

local ConfigUI = { name = "", selected = nil }

SettingsTab:Section({ Title = "Configs" })

SettingsTab:Textbox({
    Title = "Config Name",
    Placeholder = "my config",
    Value = "",
    Callback = function(text) ConfigUI.name = text end,
})

SettingsTab:Button({
    Title = "Save Config",
    Callback = function() saveConfig(ConfigUI.name) end,
})

local cfgStartList = listConfigs()
ConfigUI.selected = cfgStartList[1]
local cfgDropdown = SettingsTab:Dropdown({
    Title = "Saved Configs",
    Values = cfgStartList,
    Value = ConfigUI.selected,
    Callback = function(v) ConfigUI.selected = v end,
})

local function refreshCfgList()
    local list = listConfigs()
    pcall(function()
        cfgDropdown:Refresh(list)
        if list[1] and not table.find(list, ConfigUI.selected) then
            ConfigUI.selected = list[1]
            cfgDropdown:Set(ConfigUI.selected)
        end
    end)
end

SettingsTab:Button({
    Title = "Refresh List",
    Callback = refreshCfgList,
})

SettingsTab:Button({
    Title = "Load Selected",
    Callback = function() loadConfig(ConfigUI.selected) end,
})

SettingsTab:Button({
    Title = "Delete Selected",
    Callback = function()
        if not canFiles or type(delfile) ~= "function" then notify("Your executor has no file functions") return end
        local name = sanitizeName(ConfigUI.selected)
        if name == "" then notify("Select a config first") return end
        local ok = pcall(delfile, cfgPath(name))
        if ok then
            notify("Deleted config: " .. name)
            refreshCfgList()
        else
            notify("Failed to delete config")
        end
    end,
})

SettingsTab:Section({ Title = "Auto Load" })

SettingsTab:Button({
    Title = "Set Selected as Auto Load",
    Callback = function()
        if not canFiles then notify("Your executor has no file functions") return end
        local name = sanitizeName(ConfigUI.selected)
        if name == "" then notify("Select a config first") return end
        ensureFolders()
        local ok = pcall(writefile, AUTOLOAD_FILE, name)
        if ok then notify("Auto load set: " .. name) else notify("Failed to set auto load") end
    end,
})

SettingsTab:Button({
    Title = "Clear Auto Load",
    Callback = function()
        if type(delfile) == "function" and type(isfile) == "function" then
            pcall(function() if isfile(AUTOLOAD_FILE) then delfile(AUTOLOAD_FILE) end end)
        end
        notify("Auto load cleared")
    end,
})

SettingsTab:Section({ Title = "Language" })

-- ==================================================================
-- Ссылка на файл переводов (translations.json)
-- ==================================================================
local TRANSLATIONS_URL = "https://pastebin.com/raw/JU0DsBPh"

local LANG_FILE = CFG_FOLDER .. "/lang.txt"
local TR_CACHE = CFG_FOLDER .. "/translations.json"

local LANGS = {
    { code = "en", label = "\u{1F1FA}\u{1F1F8} English (US)" },
    { code = "ru", label = "\u{1F1F7}\u{1F1FA} Русский" },
    { code = "es", label = "\u{1F1EA}\u{1F1F8} Español" },
    { code = "de", label = "\u{1F1E9}\u{1F1EA} Deutsch" },
}

local Translations = nil
local curCode = "en"

local function loadTranslations(forceDownload)
    if Translations and not forceDownload then return Translations end
    local raw = nil
    if not forceDownload and canFiles then
        local ok, ex = pcall(isfile, TR_CACHE)
        if ok and ex then
            local okr, v = pcall(readfile, TR_CACHE)
            if okr and type(v) == "string" and #v > 2 then raw = v end
        end
    end
    if not raw then
        local okh, body = pcall(function() return game:HttpGet(TRANSLATIONS_URL) end)
        if okh and type(body) == "string" and #body > 2 then
            raw = body
            if canFiles then
                ensureFolders()
                pcall(writefile, TR_CACHE, raw)
            end
        end
    end
    if not raw then notify("Failed to load translations") return nil end
    local okd, tbl = pcall(function() return HttpS:JSONDecode(raw) end)
    if not okd or type(tbl) ~= "table" then notify("Translations file is corrupted") return nil end
    Translations = tbl
    return Translations
end

local LangOriginals = setmetatable({}, { __mode = "k" })
local LangSetTexts = setmetatable({}, { __mode = "k" })
local langTextConns = setmetatable({}, { __mode = "k" })
local LangOrigPh = setmetatable({}, { __mode = "k" })
local LangSetPh = setmetatable({}, { __mode = "k" })
local langConn = nil
local langSweepId = 0
local currentDict = nil

local function langRoot()
    return _lurkWindow and _lurkWindow.ScreenGui or nil
end

local function lookupTr(raw)
    if type(raw) ~= "string" or raw == "" then return nil end
    -- 1) точное совпадение
    local tr = currentDict[raw]
    if tr then return tr end
    -- 2) без крайних пробелов (дропдауны рисуют текст с отступом "  ")
    local pre, core, post = raw:match("^(%s*)(.-)(%s*)$")
    if core and core ~= "" and core ~= raw then
        tr = currentDict[core]
        if tr then return pre .. tr .. post end
    end
    -- 3) шаблон "Префикс: значение" (уведомления вида 'Saved config: имя')
    local base = core or raw
    local head, tail = base:match("^(.-:%s)(.+)$")
    if head then
        local trh = currentDict[head]
        if trh then return (pre or "") .. trh .. tail .. (post or "") end
    end
    return nil
end

local function translateInstance(d)
    if not currentDict then return end
    local isText = d:IsA("TextLabel") or d:IsA("TextButton")
    local isBox = d:IsA("TextBox")
    if not (isText or isBox) then return end
    if isText then
        local cur = d.Text
        if LangSetTexts[d] ~= cur then
            local tr = lookupTr(cur)
            if tr then
                LangOriginals[d] = cur
                LangSetTexts[d] = tr
                d.Text = tr
            end
        end
        -- следим за сменой текста скриптом (тумблеры, дропдауны и т.п.)
        if not langTextConns[d] then
            langTextConns[d] = d:GetPropertyChangedSignal("Text"):Connect(function()
                if not currentDict then return end
                if LangSetTexts[d] == d.Text then return end
                task.defer(function()
                    pcall(translateInstance, d)
                end)
            end)
        end
    end
    if isBox then
        local ph = d.PlaceholderText
        if ph and ph ~= "" and LangSetPh[d] ~= ph then
            local tr = lookupTr(ph)
            if tr then
                LangOrigPh[d] = ph
                LangSetPh[d] = tr
                d.PlaceholderText = tr
            end
        end
    end
end

local function resetTexts()
    if langConn then langConn:Disconnect() langConn = nil end
    langSweepId = langSweepId + 1
    for inst, conn in pairs(langTextConns) do
        pcall(function() conn:Disconnect() end)
        langTextConns[inst] = nil
    end
    for inst, orig in pairs(LangOriginals) do
        pcall(function() inst.Text = orig end)
        LangOriginals[inst] = nil
        LangSetTexts[inst] = nil
    end
    for inst, orig in pairs(LangOrigPh) do
        pcall(function() inst.PlaceholderText = orig end)
        LangOrigPh[inst] = nil
        LangSetPh[inst] = nil
    end
    currentDict = nil
end

local function sweepAll()
    local root = langRoot()
    if not root then return end
    for _, d in ipairs(root:GetDescendants()) do
        pcall(translateInstance, d)
    end
end

local function applyDict(dict)
    resetTexts()
    if not dict then return end
    currentDict = dict
    sweepAll()
    local root2 = langRoot()
    if root2 then
        langConn = root2.DescendantAdded:Connect(function(d)
            task.defer(function() pcall(translateInstance, d) end)
        end)
    end
    -- страховочный обход раз в 2 сек: ловит всё, что могло проскочить
    langSweepId = langSweepId + 1
    local myId = langSweepId
    task.spawn(function()
        while currentDict and langSweepId == myId do
            pcall(sweepAll)
            task.wait(2)
        end
    end)
end

local function setLanguage(code, save)
    if code == "en" then
        applyDict(nil)
    else
        local t = loadTranslations(false)
        local dict = t and t[code]
        if not dict then notify("No translation found for: " .. tostring(code)) return end
        applyDict(dict)
    end
    curCode = code
    if save and canFiles then
        ensureFolders()
        pcall(writefile, LANG_FILE, code)
    end
end

local langValues, labelToCode = {}, {}
for _, l in ipairs(LANGS) do
    langValues[#langValues + 1] = l.label
    labelToCode[l.label] = l.code
end

local savedCode = "en"
if canFiles then
    local okE, existsL = pcall(isfile, LANG_FILE)
    if okE and existsL then
        local okr, v = pcall(readfile, LANG_FILE)
        if okr then
            v = tostring(v):gsub("%s+", "")
            for _, l in ipairs(LANGS) do
                if l.code == v then savedCode = v end
            end
        end
    end
end

local savedLabel = langValues[1]
for _, l in ipairs(LANGS) do
    if l.code == savedCode then savedLabel = l.label end
end

SettingsTab:Dropdown({
    Title = "Language",
    Values = langValues,
    Value = savedLabel,
    Callback = function(v)
        setLanguage(labelToCode[v] or "en", true)
    end,
})

SettingsTab:Button({
    Title = "Update Translations",
    Callback = function()
        Translations = nil
        if type(delfile) == "function" and type(isfile) == "function" then
            pcall(function() if isfile(TR_CACHE) then delfile(TR_CACHE) end end)
        end
        if loadTranslations(true) then
            notify("Translations updated")
            if curCode ~= "en" then setLanguage(curCode, false) end
        end
    end,
})

-- перевод уведомлений: оборачиваем notify, чтобы переводились и они
if type(notify) == "function" then
    local origNotify = notify
    notify = function(msg, ...)
        if currentDict and type(msg) == "string" then
            local trmsg = lookupTr(msg)
            if trmsg then msg = trmsg end
        end
        return origNotify(msg, ...)
    end
end

if savedCode ~= "en" then
    task.delay(0.4, function() setLanguage(savedCode, false) end)
end

if canFiles then
    task.delay(0.6, function()
        local ok, exists = pcall(isfile, AUTOLOAD_FILE)
        if ok and exists then
            local okr, name = pcall(readfile, AUTOLOAD_FILE)
            if okr and name and sanitizeName(name) ~= "" then
                loadConfig(sanitizeName(name))
            end
        end
    end)
end

end -- /config system scope
-- ==== /Settings Tab: Config System ====

function arrangeFloating()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local pad = 8
    local gap = 10
    local startX = 30
    local startY = math.floor(vp.Y * 0.18)
    local x = startX
    local y = startY
    local colWidth = 0
    for _, entry in ipairs(fbList) do
        local o = entry.obj
        local b = o and o.btn
        if b then
            local bw = b.AbsoluteSize.X
            local bh = b.AbsoluteSize.Y
            if bw <= 0 then bw = b.Size.X.Offset end
            if bh <= 0 then bh = b.Size.Y.Offset end
            if bw <= 0 then bw = 60 end
            if bh <= 0 then bh = 60 end
            if y + bh > vp.Y - pad and y > startY then
                x = x + colWidth + gap
                y = startY
                colWidth = 0
            end
            b.Position = UDim2.fromOffset(x, y)
            y = y + bh + gap
            if bw > colWidth then colWidth = bw end
            if o.handle and o.handle.Clamp then o.handle.Clamp() end
        end
    end
end
task.defer(arrangeFloating)
task.delay(0.2, arrangeFloating)
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        task.defer(arrangeFloating)
    end)
end

Settings.LockCam = false
RunService.RenderStepped:Connect(function()
    if not Settings.LockCam then return end
    pcall(function()
        if Me.Role ~= "Sheriff" and Me.Role ~= "Hero" then return end
        local m = getRoleTarget({ Murderer = true })
        if not m then return end
        local ch = m.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if hrp then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, hrp.Position)
        end
    end)
end)

WindUI:Notify({
    Title = "Mindjorn Hub",
    Content = "Mindjorn Hub loaded.",
    Icon = "solar:check-circle-bold",
    Duration = 4,
})

function buildPlayerTag(plr, e)
    local btn = Instance.new("TextButton")
    btn.Name = "\0tagbtn"
    btn.Size = UDim2.fromOffset(34, 34)
    btn.AnchorPoint = Vector2.new(0.5, 0.5)
    btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    btn.BackgroundTransparency = 0.1
    btn.AutoButtonColor = false
    btn.Text = "\226\128\162\226\128\162\226\128\162"
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 16
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Visible = false
    btn.ZIndex = 50
    btn.Parent = Holder
    local bcorner = Instance.new("UICorner")
    bcorner.CornerRadius = UDim.new(0, 6)
    bcorner.Parent = btn
    local bstroke = Instance.new("UIStroke")
    bstroke.Thickness = 1.5
    bstroke.Color = Color3.fromRGB(255, 255, 255)
    bstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    bstroke.Parent = btn
    e.tagStroke = bstroke

    local menu = Instance.new("Frame")
    menu.Name = "\0tagmenu"
    menu.Size = UDim2.fromOffset(140, 34)
    menu.AnchorPoint = Vector2.new(0.5, 0)
    menu.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    menu.BackgroundTransparency = 0.1
    menu.BorderSizePixel = 0
    menu.Visible = false
    menu.ClipsDescendants = true
    menu.ZIndex = 51
    menu.Parent = Holder
    local mcorner = Instance.new("UICorner")
    mcorner.CornerRadius = UDim.new(0, 6)
    mcorner.Parent = menu
    local mstroke = Instance.new("UIStroke")
    mstroke.Thickness = 1.5
    mstroke.Color = Color3.fromRGB(255, 255, 255)
    mstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    mstroke.Parent = menu
    e.tagMenuStroke = mstroke
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 4)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Parent = menu
    local mpad = Instance.new("UIPadding")
    mpad.PaddingLeft = UDim.new(0, 4)
    mpad.PaddingRight = UDim.new(0, 4)
    mpad.Parent = menu

    local function mkBtn(txt)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.5, -4, 1, -6)
        b.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        b.AutoButtonColor = true
        b.Text = txt
        b.Font = Enum.Font.GothamSemibold
        b.TextSize = 13
        b.TextColor3 = Color3.new(1, 1, 1)
        b.ZIndex = 52
        b.Parent = menu
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 5)
        c.Parent = b
        return b
    end
    local tpBtn = mkBtn("Tp to")
    local flingBtn = mkBtn("Fling")
    e.tagInner = { tpBtn, flingBtn }

    e.tagOpen = false
    e.tagAnim = 0

    btn.Activated:Connect(function()
        e.tagOpen = not e.tagOpen
    end)
    tpBtn.Activated:Connect(function()
        e.tagOpen = false
        teleportTo(plr)
    end)
    flingBtn.Activated:Connect(function()
        e.tagOpen = false
        flingPlayer(plr)
    end)

    e.tagBtn = btn
    e.tagMenu = menu
end

function hideAllTags()
    for _, e in pairs(ESP) do
        if e.tagBtn then e.tagBtn.Visible = false end
        if e.tagMenu then e.tagMenu.Visible = false end
        e.tagOpen = false
        e.tagAnim = 0
    end
end

local TAG_BASE = 34
local TAG_REF_DIST = 40

function updatePlayerTags(dt)
    if not Settings.Enabled or not Settings.ClickMenu or not roundActive() then
        hideAllTags()
        return
    end
    dt = dt or 0.016
    local camPos = Camera.CFrame.Position
    local maxSq = MAX_DIST * MAX_DIST
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local e = ESP[plr]
            local data = getData(plr)
            local char = data and plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local valid = hrp and data.Dead ~= true
            local role = valid and resolveRole(plr, data) or nil
            local show = false
            local screenPos, dist
            if valid and role and shouldShow(role) then
                local off = camPos - hrp.Position
                local d2 = off.X * off.X + off.Y * off.Y + off.Z * off.Z
                if d2 <= maxSq then
                    local sp, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    if onScreen then
                        show = true
                        screenPos = sp
                        dist = math.sqrt(d2)
                    end
                end
            end
            if show then
                e = e or createESP(plr)
                if not e.tagBtn then buildPlayerTag(plr, e) end

                -- distance-based size: shrinks as the player gets farther, clamped
                local scale = TAG_REF_DIST / math.max(dist, 1)
                local btnSize = math.clamp(TAG_BASE * scale, 16, 40)
                local bx, by = screenPos.X, screenPos.Y

                e.tagBtn.Size = UDim2.fromOffset(btnSize, btnSize)
                e.tagBtn.Position = UDim2.fromOffset(bx, by)
                e.tagBtn.TextSize = math.clamp(math.floor(btnSize * 0.5 + 0.5), 9, 18)
                e.tagBtn.Visible = true

                local col = COLORS[role] and COLORS[role].bright or Color3.fromRGB(255, 255, 255)
                if e.tagStroke then e.tagStroke.Color = col end
                if e.tagMenuStroke then e.tagMenuStroke.Color = col end

                -- animate open/close (ease-out), menu grows out of the button
                local target = e.tagOpen and 1 or 0
                e.tagAnim = e.tagAnim + (target - e.tagAnim) * math.clamp(dt * 14, 0, 1)
                if target == 0 and e.tagAnim < 0.02 then e.tagAnim = 0 end

                local menu = e.tagMenu
                if e.tagAnim > 0.01 then
                    local a = e.tagAnim
                    local ea = 1 - (1 - a) * (1 - a)
                    local fullW = math.clamp(btnSize * 3.6, 84, 150)
                    local fullH = math.clamp(btnSize * 0.95, 22, 36)
                    menu.Visible = true
                    menu.Size = UDim2.fromOffset(fullW * ea, fullH * ea)
                    menu.Position = UDim2.fromOffset(bx, by + btnSize * 0.5 + 4)
                    menu.BackgroundTransparency = 0.1 + (1 - ea) * 0.9
                    if e.tagMenuStroke then e.tagMenuStroke.Transparency = 1 - ea end
                    for _, ib in ipairs(e.tagInner or {}) do
                        ib.TextTransparency = 1 - ea
                        ib.BackgroundTransparency = 1 - ea
                        ib.TextSize = math.clamp(math.floor(fullH * 0.4 + 0.5), 9, 14)
                    end
                else
                    menu.Visible = false
                end
            else
                if e then
                    if e.tagBtn then e.tagBtn.Visible = false end
                    if e.tagMenu then e.tagMenu.Visible = false end
                    e.tagOpen = false
                    e.tagAnim = 0
                end
            end
        end
    end
end

RunService.RenderStepped:Connect(function(dt)
    pcall(function() updatePlayerTags(dt) end)
end)

--==================================================================--
--  SCREEN STRETCH: stretched resolution like in other games. The
--  camera matrix is scaled AFTER Roblox positions the camera each
--  frame, so the whole world stretches.
--==================================================================--

local Stretch = {
    Enabled = false,
    X = 1.25,
    Y = 1,
}

RunService:BindToRenderStep("\0mjstretch", Enum.RenderPriority.Camera.Value + 1, function()
    if not Stretch.Enabled then return end
    local sx, sy = Stretch.X, Stretch.Y
    if sx == 1 and sy == 1 then return end
    Camera.CFrame = Camera.CFrame * CFrame.new(0, 0, 0, 1 / sx, 0, 0, 0, 1 / sy, 0, 0, 0, 1)
end)

VisualsTab:Section({ Title = "Screen" })
VisualsTab:Toggle({ Title = "Screen Stretch", Value = false, Callback = function(v) Stretch.Enabled = v end })
VisualsTab:Slider({ Title = "Stretch Horizontal", Value = { Min = 0.6, Max = 2, Default = 1.25 }, Step = 0.05, Callback = function(v) Stretch.X = v end })
VisualsTab:Slider({ Title = "Stretch Vertical", Value = { Min = 0.6, Max = 2, Default = 1 }, Step = 0.05, Callback = function(v) Stretch.Y = v end })

--==================================================================--
--  FRIEND LINKS: Beam instances between friends' root parts. Beams
--  are rendered by the engine and follow characters automatically,
--  so they never lag behind and cost zero Lua work per frame.
--==================================================================--

local FriendLinks = {
    Enabled = false,
    Color = Color3.fromRGB(100, 210, 255),
}

local friendCache = {}
local friendBeams = {}
local friendScanBusy = false

local function friendPairKey(a, b)
    local x, y = a.UserId, b.UserId
    if x > y then x, y = y, x end
    return tostring(x) .. ":" .. tostring(y)
end

local function friendAttachment(hrp)
    local att = hrp:FindFirstChild("\0mjfriend")
    if not att then
        att = Instance.new("Attachment")
        att.Name = "\0mjfriend"
        att.Parent = hrp
    end
    return att
end

local function clearFriendBeams()
    for key, beam in pairs(friendBeams) do
        pcall(function() beam:Destroy() end)
        friendBeams[key] = nil
    end
end

local function scanFriends()
    if friendScanBusy then return end
    friendScanBusy = true
    task.spawn(function()
        local list = Players:GetPlayers()
        for i = 1, #list - 1 do
            for j = i + 1, #list do
                local a, b = list[i], list[j]
                if a.Parent and b.Parent then
                    local key = friendPairKey(a, b)
                    if friendCache[key] == nil then
                        local ok, v = pcall(function() return a:IsFriendsWith(b.UserId) end)
                        friendCache[key] = ok and v or false
                        task.wait(0.03)
                    end
                end
            end
        end
        friendScanBusy = false
    end)
end

-- slow maintenance loop: (re)builds beams once a second; the beams
-- themselves track characters natively with no per-frame updates
task.spawn(function()
    while true do
        task.wait(1)
        if FriendLinks.Enabled then
            pcall(function()
                local list = Players:GetPlayers()
                for i = 1, #list - 1 do
                    for j = i + 1, #list do
                        local a, b = list[i], list[j]
                        local key = friendPairKey(a, b)
                        if friendCache[key] then
                            local ar = a.Character and a.Character:FindFirstChild("HumanoidRootPart")
                            local br = b.Character and b.Character:FindFirstChild("HumanoidRootPart")
                            local beam = friendBeams[key]
                            if ar and br then
                                local stale = not beam or not beam.Parent
                                    or not beam.Attachment0 or beam.Attachment0.Parent ~= ar
                                    or not beam.Attachment1 or beam.Attachment1.Parent ~= br
                                if stale then
                                    if beam then pcall(function() beam:Destroy() end) end
                                    beam = Instance.new("Beam")
                                    beam.Name = "\0mjfriendbeam"
                                    beam.Attachment0 = friendAttachment(ar)
                                    beam.Attachment1 = friendAttachment(br)
                                    beam.FaceCamera = true
                                    beam.Width0 = 0.12
                                    beam.Width1 = 0.12
                                    beam.LightEmission = 1
                                    beam.LightInfluence = 0
                                    beam.Transparency = NumberSequence.new(0.25)
                                    beam.Parent = ar
                                    friendBeams[key] = beam
                                end
                                beam.Color = ColorSequence.new(FriendLinks.Color)
                                beam.Enabled = true
                            elseif beam then
                                beam.Enabled = false
                            end
                        end
                    end
                end
            end)
        elseif next(friendBeams) then
            clearFriendBeams()
        end
    end
end)

Players.PlayerAdded:Connect(function()
    if FriendLinks.Enabled then scanFriends() end
end)
Players.PlayerRemoving:Connect(function(plr)
    local id = tostring(plr.UserId)
    for key, beam in pairs(friendBeams) do
        if string.find(key, id, 1, true) then
            pcall(function() beam:Destroy() end)
            friendBeams[key] = nil
        end
    end
end)

PlayersTab:Section({ Title = "Friends" })
PlayersTab:Toggle({ Title = "Friend Links", Value = false, Callback = function(v)
    FriendLinks.Enabled = v
    if v then scanFriends() else clearFriendBeams() end
end })
PlayersTab:Colorpicker({ Title = "Friend Link Color", Default = FriendLinks.Color, Transparency = 0, Locked = false, Callback = function(v) FriendLinks.Color = v end })

--==================================================================--
--  AUTOFARM
--==================================================================--

local AutoFarmTab = Window:Tab({
    Title = "AutoFarm",
    Icon = "solar:dollar-minimalistic-bold",
    IconShape = "Square",
    Border = true,
})

do
    local TweenService = game:GetService("TweenService")
    local VirtualUser = game:GetService("VirtualUser")
    local FarmPlayerGui = LocalPlayer:WaitForChild("PlayerGui")

    local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    local GameplayRemotes = RemotesFolder and RemotesFolder:FindFirstChild("Gameplay")

    local TWEEN_SPEED = 20
    local COIN_DETECTION_RANGE = 200
    local HOVER_HEIGHT = 2.5
    local CLOSE_RANGE = 12
    local MIN_SEGMENT_TIME = 0.05

    local PICKUP_RADIUS = 4.0
    local PICKUP_GRACE = 0.35
    local SWITCH_MARGIN = 0.80
    local RETARGET_MOVE = 1.5
    local STUCK_TIME = 1.0
    local STUCK_PROGRESS = 1.0
    local BLACKLIST_TIME = 3.0
    local MAX_FAILS = 2
    local VISIBLE_LIMIT = 0.95

    local RENDER_STEP_NAME = "MJ_FarmApplyTween"

    local Destroyed = false

    local CanTouchSupported = false
    do
        local probe = Instance.new("Part")
        local ok = pcall(function() return probe.CanTouch end)
        CanTouchSupported = ok
        probe:Destroy()
    end

    local IsAutoMoveEnabled = false
    local PauseReason = nil

    local TotalCoinsCollected = 0
    local IsBagFull = false
    local Alive = false
    local SessionStart = nil
    local SessionSeconds = 0

    local ServerRole = ""
    local CurrentMapName = ""
    local ActiveMap = nil
    local RoundEnded = false

    pcall(function() RunService:UnbindFromRenderStep(RENDER_STEP_NAME) end)

    local afkConn = nil

    local function setAntiAfk(on)
        if on then
            if afkConn then return end
            afkConn = LocalPlayer.Idled:Connect(function()
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end)
        elseif afkConn then
            pcall(function() afkConn:Disconnect() end)
            afkConn = nil
        end
    end

    local PAUSE_TEXT = {
        round = "paused - round not running",
        bag   = "paused - bag full",
        dead  = "paused - character dead",
        coins = "paused - no coins",
    }

    local StatsBox = nil
    local lastStatsText = ""

    local function fmtTime(sec)
        sec = math.floor(sec)
        local h = math.floor(sec / 3600)
        local m = math.floor((sec % 3600) / 60)
        local s = sec % 60
        if h > 0 then return ("%dh %dm %ds"):format(h, m, s) end
        if m > 0 then return ("%dm %ds"):format(m, s) end
        return ("%ds"):format(s)
    end

    local function RefreshStatusUI(nearby)
        if Destroyed or not StatsBox then return end
        local status
        if not IsAutoMoveEnabled then
            status = "disabled"
        elseif PauseReason then
            status = PAUSE_TEXT[PauseReason] or "paused"
        else
            status = "farming"
        end
        local uptime = SessionSeconds
        if IsAutoMoveEnabled and SessionStart then
            uptime = SessionSeconds + (os.clock() - SessionStart)
        end
        local txt = ("Status: %s\nCollected: %d\nCoins nearby: %d\nUptime: %s")
            :format(status, TotalCoinsCollected, nearby or 0, fmtTime(uptime))
        if txt ~= lastStatsText then
            lastStatsText = txt
            pcall(function() StatsBox.SetText(txt) end)
        end
    end

    local function GetLobby()
        return Workspace:FindFirstChild("Lobby")
    end

    local function GetCharParts()
        local char = LocalPlayer.Character
        if not char or not char.Parent then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not hum or not root then return nil end
        return char, hum, root
    end

    local function IsAliveFarm()
        local char, hum, root = GetCharParts()
        if not char then return false end
        local lobby = GetLobby()
        if lobby and char:IsDescendantOf(lobby) then return false end
        if hum.Health <= 0 then return false end
        if hum:GetState() == Enum.HumanoidStateType.Dead then return false end
        if not root.Parent then return false end
        return true
    end

    local Tick

    local function RequestTick()
        if Destroyed or not Tick then return end
        pcall(Tick)
    end

    local CoinParts = {}
    local CoinVisuals = {}
    local CoinBaseVisible = {}
    local CoinBaseTouch = {}
    local CoinSignals = {}
    local Blacklist = {}
    local FailCount = {}
    local Consumed = {}
    local coinConns = {}
    local TrackedContainer = nil

    local CurrentTarget = nil
    local TargetLostFlag = false

    local function CoinPart(coin)
        if coin:IsA("BasePart") then return coin end
        if coin:IsA("Model") then
            return coin.PrimaryPart or coin:FindFirstChildWhichIsA("BasePart")
        end
        return nil
    end

    local function CollectVisuals(coin)
        local parts = {}
        if coin:IsA("BasePart") then
            table.insert(parts, coin)
        else
            for _, d in ipairs(coin:GetDescendants()) do
                if d:IsA("BasePart") then table.insert(parts, d) end
            end
        end
        return parts
    end

    local function AnyVisible(coin)
        local parts = CoinVisuals[coin]
        if not parts then return false end
        local found = false
        for i = #parts, 1, -1 do
            local p = parts[i]
            if not p.Parent then
                table.remove(parts, i)
            elseif p.Transparency < VISIBLE_LIMIT then
                found = true
            end
        end
        return found
    end

    local function HasTouch(part)
        if part:FindFirstChildOfClass("TouchTransmitter") then return true end
        if part:FindFirstChild("TouchInterest") then return true end
        return false
    end

    local function ClearCoin(coin)
        local conns = CoinSignals[coin]
        if conns then
            for _, c in ipairs(conns) do
                pcall(function() c:Disconnect() end)
            end
            CoinSignals[coin] = nil
        end
        CoinParts[coin] = nil
        CoinVisuals[coin] = nil
        CoinBaseVisible[coin] = nil
        CoinBaseTouch[coin] = nil
        Blacklist[coin] = nil
    end

    local function DropCoin(coin, permanent)
        ClearCoin(coin)
        if permanent then
            Consumed[coin] = true
            FailCount[coin] = nil
        end
        if CurrentTarget == coin then
            CurrentTarget = nil
            TargetLostFlag = true
        end
    end

    local function RegisterCoin(coin)
        if Destroyed or not coin or not coin.Parent then return end
        if coin.Parent ~= TrackedContainer then return end
        if Consumed[coin] then return end
        local part = CoinPart(coin)
        if not part then return end

        CoinParts[coin] = part
        CoinVisuals[coin] = CollectVisuals(coin)
        CoinBaseVisible[coin] = AnyVisible(coin)
        CoinBaseTouch[coin] = HasTouch(part)

        if not CoinSignals[coin] then
            local conns = {}
            table.insert(conns, part:GetPropertyChangedSignal("Transparency"):Connect(function()
                RequestTick()
            end))
            if CanTouchSupported then
                table.insert(conns, part:GetPropertyChangedSignal("CanTouch"):Connect(function()
                    RequestTick()
                end))
            end
            table.insert(conns, coin.AncestryChanged:Connect(function()
                if coin.Parent ~= TrackedContainer then
                    DropCoin(coin, true)
                    RequestTick()
                end
            end))
            CoinSignals[coin] = conns
        end
    end

    local function CoinGone(coin, part)
        if not part.Parent then return true end
        if coin.Parent ~= TrackedContainer then return true end
        if coin:GetAttribute("Collected") == true then return true end
        if coin:GetAttribute("Taken") == true then return true end
        if CanTouchSupported and part.CanTouch == false then return true end
        if CoinBaseVisible[coin] and not AnyVisible(coin) then return true end
        if CoinBaseTouch[coin] and not HasTouch(part) then return true end
        return false
    end

    local function CoinValid(coin, now)
        if Consumed[coin] then return nil end
        local part = CoinParts[coin]
        if not part then return nil end
        if CoinGone(coin, part) then
            DropCoin(coin, true)
            return nil
        end
        local ban = Blacklist[coin]
        if ban then
            if ban > now then return nil end
            Blacklist[coin] = nil
        end
        return part
    end

    local function FailCoin(coin, now)
        local n = (FailCount[coin] or 0) + 1
        FailCount[coin] = n
        if n >= MAX_FAILS then
            DropCoin(coin, true)
        else
            Blacklist[coin] = now + BLACKLIST_TIME
            if CurrentTarget == coin then
                CurrentTarget = nil
                TargetLostFlag = true
            end
        end
    end

    local function FindBestCoin(rootPos, now)
        local best, bestDist, nearby = nil, math.huge, 0
        for coin in pairs(CoinParts) do
            local part = CoinValid(coin, now)
            if part then
                local d = (part.Position - rootPos).Magnitude
                if d <= COIN_DETECTION_RANGE then
                    nearby += 1
                    if d < bestDist then
                        best, bestDist = coin, d
                    end
                end
            end
        end
        return best, bestDist, nearby
    end

    local function TrackContainer(container)
        if TrackedContainer == container then return end
        for _, c in ipairs(coinConns) do c:Disconnect() end
        coinConns = {}
        for coin in pairs(CoinSignals) do ClearCoin(coin) end
        table.clear(CoinParts)
        table.clear(CoinVisuals)
        table.clear(CoinBaseVisible)
        table.clear(CoinBaseTouch)
        table.clear(CoinSignals)
        table.clear(Blacklist)
        table.clear(FailCount)
        table.clear(Consumed)
        CurrentTarget = nil
        TargetLostFlag = true
        TrackedContainer = container
        if not container then return end

        for _, coin in ipairs(container:GetChildren()) do RegisterCoin(coin) end

        table.insert(coinConns, container.ChildAdded:Connect(function(coin)
            Consumed[coin] = nil
            FailCount[coin] = nil
            RegisterCoin(coin)
            RequestTick()
            task.defer(function()
                RegisterCoin(coin)
                RequestTick()
            end)
        end))

        table.insert(coinConns, container.ChildRemoved:Connect(function(coin)
            DropCoin(coin, true)
            RequestTick()
        end))

        table.insert(coinConns, container.DescendantRemoving:Connect(function()
            task.defer(RequestTick)
        end))
    end

    local BagCoinLast = {}
    local FullLabels = {}
    local bagConns = {}
    local BoundCoinBags = nil

    local function RecomputeBagFull()
        local full = false
        for label in pairs(FullLabels) do
            if label.Parent then
                if label.Visible then full = true end
            else
                FullLabels[label] = nil
            end
        end
        IsBagFull = full
    end

    local function ApplyCoinsText(label, text)
        local val = tonumber((tostring(text):gsub("%D", "")))
        if not val then return end
        local prev = BagCoinLast[label] or 0
        if val > prev then
            TotalCoinsCollected += (val - prev)
        end
        BagCoinLast[label] = val
    end

    local function UnbindBagGui()
        for _, c in ipairs(bagConns) do c:Disconnect() end
        bagConns = {}
        table.clear(FullLabels)
        BoundCoinBags = nil
    end

    local function BindBagGui()
        if Destroyed then return false end

        local mainGui = FarmPlayerGui:FindFirstChild("MainGUI")
        local gameGui = mainGui and mainGui:FindFirstChild("Game")
        if not gameGui then
            UnbindBagGui()
            return false
        end
        local coinBags = gameGui:FindFirstChild("CoinBags", true)
        if not coinBags then
            UnbindBagGui()
            return false
        end
        if BoundCoinBags == coinBags and coinBags.Parent then return true end

        UnbindBagGui()
        BoundCoinBags = coinBags

        local container = coinBags:FindFirstChild("Container") or coinBags
        local targets = {}
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("GuiObject") then table.insert(targets, child) end
        end
        if #targets == 0 then targets = { container } end

        for _, holder in ipairs(targets) do
            local coinsLabel = holder:FindFirstChild("Coins", true)
            if coinsLabel and coinsLabel:IsA("TextLabel") then
                BagCoinLast[coinsLabel] = tonumber((coinsLabel.Text:gsub("%D", ""))) or 0
                table.insert(bagConns, coinsLabel:GetPropertyChangedSignal("Text"):Connect(function()
                    ApplyCoinsText(coinsLabel, coinsLabel.Text)
                    RequestTick()
                end))
            end

            local fullLabel = holder:FindFirstChild("Full", true) or holder:FindFirstChild("FullBagNotification", true)
            if fullLabel and fullLabel:IsA("GuiObject") then
                FullLabels[fullLabel] = true
                table.insert(bagConns, fullLabel:GetPropertyChangedSignal("Visible"):Connect(function()
                    RecomputeBagFull()
                    RequestTick()
                end))
            end
        end

        RecomputeBagFull()
        return #bagConns > 0
    end

    local function DetermineExactRole()
        if ServerRole ~= "" and ServerRole ~= "Lobby" then return ServerRole end
        local mainGui = FarmPlayerGui:FindFirstChild("MainGUI")
        local gameGui = mainGui and mainGui:FindFirstChild("Game")
        if gameGui then
            local roleSelector = gameGui:FindFirstChild("RoleSelector", true)
            if roleSelector then
                local label = roleSelector:FindFirstChild("Role", true)
                if label and label:IsA("TextLabel") and label.Text ~= "" then return label.Text end
            end
        end
        local char = LocalPlayer.Character
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if char then
            if char:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife")) then
                return "Murderer"
            elseif char:FindFirstChild("Gun") or (backpack and backpack:FindFirstChild("Gun")) then
                return "Sheriff"
            end
        end
        return "Innocent"
    end

    local function DetectMap()
        for _, child in ipairs(Workspace:GetChildren()) do
            if child:IsA("Model") and child.Name ~= "Lobby" and child.Name ~= "PetContainer"
                and not Players:GetPlayerFromCharacter(child) then
                if child:FindFirstChild("CoinContainer") or child:FindFirstChild("Spawns") then
                    return child
                end
            end
        end
        return nil
    end

    local mapConns = {}

    local function ClearMapConns()
        for _, c in ipairs(mapConns) do c:Disconnect() end
        mapConns = {}
    end

    local function RefreshMap()
        if Destroyed then return end
        local map = DetectMap()
        if map == ActiveMap then
            if map and TrackedContainer == nil then
                local cc = map:FindFirstChild("CoinContainer")
                if cc then
                    TrackContainer(cc)
                    RequestTick()
                end
            end
            return
        end

        ClearMapConns()
        ActiveMap = map

        if map then
            RoundEnded = false
            if map.Name ~= CurrentMapName then
                CurrentMapName = map.Name
                table.clear(BagCoinLast)
                IsBagFull = false
                BoundCoinBags = nil
                BindBagGui()
            end
            local cc = map:FindFirstChild("CoinContainer")
            TrackContainer(cc)
            if not cc then
                table.insert(mapConns, map.ChildAdded:Connect(function(ch)
                    if ch.Name == "CoinContainer" then
                        TrackContainer(ch)
                        RequestTick()
                    end
                end))
            end
        else
            RoundEnded = true
            CurrentMapName = ""
            IsBagFull = false
            ServerRole = ""
            table.clear(BagCoinLast)
            TrackContainer(nil)
        end

        RequestTick()
    end

    local function IsRoundActive()
        if RoundEnded then return false end
        if not ActiveMap or not ActiveMap.Parent then return false end
        return true
    end

    Workspace.ChildAdded:Connect(function()
        task.defer(function()
            RefreshMap()
            RequestTick()
        end)
    end)

    Workspace.ChildRemoved:Connect(function(child)
        if child == ActiveMap then
            RefreshMap()
            RequestTick()
        else
            task.defer(RefreshMap)
        end
    end)

    FarmPlayerGui.ChildAdded:Connect(function(child)
        if child.Name == "MainGUI" then
            task.defer(function()
                BoundCoinBags = nil
                BindBagGui()
                RequestTick()
            end)
        end
    end)

    local MoveProxy = Instance.new("CFrameValue")
    local activeTween = nil
    local applyingMovement = false
    local movementEngaged = false
    local preparedCharacter = nil

    local tweenAimPos = nil
    local tweenEndsAt = 0
    local pickupSince = nil
    local stuckSince, stuckDist = nil, nil

    RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value - 1, function()
        if Destroyed or not applyingMovement then return end
        local char, hum, root = GetCharParts()
        if not char then return end
        root.CFrame = MoveProxy.Value
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)

    local function PrepareCharacter()
        local char = LocalPlayer.Character
        if not char or preparedCharacter == char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CanCollide = false
                p.Massless = true
            end
        end
        preparedCharacter = char
    end

    local function EngageMovement()
        local char, hum, root = GetCharParts()
        if not char then return false end
        PrepareCharacter()
        if not movementEngaged then
            movementEngaged = true
            hum.AutoRotate = false
            hum.PlatformStand = true
            hum:ChangeState(Enum.HumanoidStateType.Physics)
            MoveProxy.Value = root.CFrame
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        applyingMovement = true
        return true
    end

    local function ReleaseMovement()
        applyingMovement = false
        if activeTween then
            activeTween:Cancel()
            activeTween = nil
        end
        tweenAimPos = nil
        pickupSince, stuckSince, stuckDist = nil, nil, nil
        if not movementEngaged then return end
        movementEngaged = false
        local char, hum, root = GetCharParts()
        if not char then return end
        hum.PlatformStand = false
        hum.AutoRotate = true
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end

    local function PauseFarm(reason)
        PauseReason = reason
        CurrentTarget = nil
        if movementEngaged or applyingMovement or activeTween then
            ReleaseMovement()
        end
    end

    local function StopMovement()
        PauseReason = nil
        CurrentTarget = nil
        ReleaseMovement()
    end

    local function StartTween(targetPos)
        local char, hum, root = GetCharParts()
        if not char then return false end
        if activeTween then
            activeTween:Cancel()
            activeTween = nil
        end

        local startCF = root.CFrame
        local dist = (targetPos - startCF.Position).Magnitude
        local duration = math.max(dist / TWEEN_SPEED, MIN_SEGMENT_TIME)

        local flat = Vector3.new(targetPos.X - startCF.Position.X, 0, targetPos.Z - startCF.Position.Z)
        local finalCF
        if flat.Magnitude > 0.05 then
            finalCF = CFrame.lookAt(targetPos, targetPos + flat.Unit)
        else
            finalCF = startCF.Rotation + targetPos
        end

        MoveProxy.Value = startCF
        activeTween = TweenService:Create(
            MoveProxy,
            TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
            { Value = finalCF }
        )
        activeTween:Play()
        tweenAimPos = targetPos
        tweenEndsAt = os.clock() + duration
        return true
    end

    local function TickBody()
        if Destroyed then return 0 end

        if not IsAutoMoveEnabled then
            if movementEngaged or PauseReason then StopMovement() end
            return 0
        end

        if not IsRoundActive() or not TrackedContainer then
            PauseFarm("round")
            return 0
        end

        Alive = IsAliveFarm()
        if not Alive then
            PauseFarm("dead")
            return 0
        end

        if IsBagFull then
            PauseFarm("bag")
            return 0
        end

        local char, hum, root = GetCharParts()
        if not char then
            PauseFarm("dead")
            return 0
        end

        local now = os.clock()
        local rootPos = root.Position

        local targetPart = CurrentTarget and CoinValid(CurrentTarget, now) or nil
        if not targetPart then
            CurrentTarget = nil
            pickupSince, stuckSince, stuckDist = nil, nil, nil
        end

        local best, bestDist, nearby = FindBestCoin(rootPos, now)

        if not best then
            PauseFarm("coins")
            return 0
        end

        PauseReason = nil

        local needRetarget = false
        if not CurrentTarget then
            needRetarget = true
            TargetLostFlag = false
        elseif TargetLostFlag then
            TargetLostFlag = false
            needRetarget = true
        elseif best ~= CurrentTarget then
            local curDist = (targetPart.Position - rootPos).Magnitude
            if bestDist < curDist * SWITCH_MARGIN then needRetarget = true end
        end

        if needRetarget then
            CurrentTarget = best
            targetPart = CoinParts[best]
            if not targetPart then
                CurrentTarget = nil
                return nearby
            end
            tweenAimPos = nil
            pickupSince = nil
            stuckSince, stuckDist = now, (targetPart.Position - rootPos).Magnitude
        end

        if not targetPart then return nearby end

        local coinPos = targetPart.Position
        local dist = (coinPos - rootPos).Magnitude

        if dist <= PICKUP_RADIUS then
            pickupSince = pickupSince or now
            if now - pickupSince >= PICKUP_GRACE then
                FailCoin(CurrentTarget, now)
                pickupSince = nil
            end
            return nearby
        else
            pickupSince = nil
        end

        if not EngageMovement() then return nearby end

        if stuckSince and stuckDist then
            if stuckDist - dist >= STUCK_PROGRESS then
                stuckSince, stuckDist = now, dist
            elseif now - stuckSince >= STUCK_TIME then
                FailCoin(CurrentTarget, now)
                return nearby
            end
        else
            stuckSince, stuckDist = now, dist
        end

        local aim = (dist <= CLOSE_RANGE) and coinPos or (coinPos + Vector3.new(0, HOVER_HEIGHT, 0))

        local needTween = (activeTween == nil)
            or (tweenAimPos == nil)
            or (now >= tweenEndsAt)
            or ((aim - tweenAimPos).Magnitude > RETARGET_MOVE)

        if needTween then StartTween(aim) end

        return nearby
    end

    local inTick = false

    Tick = function()
        if inTick or Destroyed then return end
        inTick = true
        local ok, res = pcall(TickBody)
        inTick = false
        if ok then
            RefreshStatusUI(res or 0)
        else
            RefreshStatusUI(0)
        end
    end

    local driverSignal = RunService.Heartbeat
    local okSignal, preSim = pcall(function() return RunService.PreSimulation end)
    if okSignal and typeof(preSim) == "RBXScriptSignal" then
        driverSignal = preSim
    else
        local okStepped, stepped = pcall(function() return RunService.Stepped end)
        if okStepped and typeof(stepped) == "RBXScriptSignal" then
            driverSignal = stepped
        end
    end

    driverSignal:Connect(function()
        Tick()
    end)

    local humConn = nil

    local function BindCharacter(char)
        if Destroyed then return end
        preparedCharacter = nil
        movementEngaged = false
        applyingMovement = false
        if activeTween then
            activeTween:Cancel()
            activeTween = nil
        end
        CurrentTarget = nil
        tweenAimPos = nil
        pickupSince, stuckSince, stuckDist = nil, nil, nil

        if humConn then
            humConn:Disconnect()
            humConn = nil
        end

        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            humConn = hum.Died:Connect(function()
                Alive = false
                PauseFarm("dead")
                RequestTick()
            end)
        end

        Alive = IsAliveFarm()
        RequestTick()
    end

    LocalPlayer.CharacterAdded:Connect(function(char)
        task.defer(BindCharacter, char)
    end)

    if LocalPlayer.Character then
        task.defer(BindCharacter, LocalPlayer.Character)
    end

    if GameplayRemotes then
        local roleEvent = GameplayRemotes:FindFirstChild("RoleSelect")
            or GameplayRemotes:FindFirstChild("ShowRoleSelect")
            or GameplayRemotes:FindFirstChild("ShowRoleSelectNew")
        if roleEvent and roleEvent:IsA("RemoteEvent") then
            roleEvent.OnClientEvent:Connect(function(roleData)
                local roleName = type(roleData) == "string" and roleData
                    or (type(roleData) == "table" and (roleData.Role or roleData[1]))
                    or "Innocent"
                ServerRole = tostring(roleName)
                RoundEnded = false
                RefreshMap()
                RequestTick()
            end)
        end

        for _, name in ipairs({ "GameOver", "VictoryScreen", "RoundEndFade" }) do
            local rem = GameplayRemotes:FindFirstChild(name)
            if rem and rem:IsA("RemoteEvent") then
                rem.OnClientEvent:Connect(function()
                    RoundEnded = true
                    PauseFarm("round")
                    RequestTick()
                end)
            end
        end

        local coinEvent = GameplayRemotes:FindFirstChild("CoinCollected")
            or GameplayRemotes:FindFirstChild("CollectCoin")
            or GameplayRemotes:FindFirstChild("PickupCoin")
        if coinEvent and coinEvent:IsA("RemoteEvent") then
            coinEvent.OnClientEvent:Connect(function(data)
                if typeof(data) == "Instance" then
                    DropCoin(data, true)
                end
                RequestTick()
            end)
        end

        local killEvent = GameplayRemotes:FindFirstChild("KillEvent")
        if killEvent and killEvent:IsA("RemoteEvent") then
            killEvent.OnClientEvent:Connect(function(victim)
                local isMe = false
                if victim == LocalPlayer then
                    isMe = true
                elseif typeof(victim) == "Instance" and victim.Name == LocalPlayer.Name then
                    isMe = true
                elseif type(victim) == "string" and victim == LocalPlayer.Name then
                    isMe = true
                end
                if isMe then
                    Alive = false
                    PauseFarm("dead")
                    RequestTick()
                end
            end)
        end
    end

    task.spawn(function()
        while not Destroyed do
            pcall(function()
                RefreshMap()
                if not BoundCoinBags or not BoundCoinBags.Parent then
                    BoundCoinBags = nil
                    BindBagGui()
                end
                RecomputeBagFull()
                if ServerRole == "" then ServerRole = DetermineExactRole() end
                Alive = IsAliveFarm()
                if TrackedContainer then
                    for _, coin in ipairs(TrackedContainer:GetChildren()) do
                        if not CoinParts[coin] and not Consumed[coin] then RegisterCoin(coin) end
                    end
                end
            end)
            task.wait(0.25)
        end
    end)

    task.spawn(function()
        while not Destroyed do
            task.wait(1)
            if IsAutoMoveEnabled then RefreshStatusUI(nil) end
        end
    end)

    AutoFarmTab:Section({ Title = "Coin Farm" })

    AutoFarmTab:Toggle({
        Title = "AutoFarm Coins",
        Value = false,
        Callback = function(v)
            IsAutoMoveEnabled = v
            if v then
                SessionStart = os.clock()
                setAntiAfk(true)
                PauseReason = nil
                RefreshMap()
                RequestTick()
            else
                if SessionStart then
                    SessionSeconds += (os.clock() - SessionStart)
                    SessionStart = nil
                end
                setAntiAfk(false)
                StopMovement()
                RefreshStatusUI(0)
            end
        end,
    })

    AutoFarmTab:Section({ Title = "Stats" })

    StatsBox = AutoFarmTab:Paragraph({
        Title = "Session",
        Desc = "Status: disabled\nCollected: 0\nCoins nearby: 0\nUptime: 0s",
    })

    AutoFarmTab:Button({
        Title = "Reset Stats",
        Callback = function()
            TotalCoinsCollected = 0
            SessionSeconds = 0
            if IsAutoMoveEnabled then SessionStart = os.clock() end
            lastStatsText = ""
            RefreshStatusUI(0)
        end,
    })

    BindBagGui()
    RefreshMap()
    RefreshStatusUI(0)
end

--==================================================================--
--  ROLE NOTIFY: fires once whenever our role changes at round start
--==================================================================--

task.spawn(function()
    local lastRole = nil
    while true do
        task.wait(0.5)
        if Settings.NotifyMyRole then
            pcall(function()
                refreshSelf()
                local r = Me.Role
                if r ~= lastRole then
                    lastRole = r
                    if r and not Me.Dead then
                        notify("Your role: " .. string.upper(tostring(r)))
                    end
                end
            end)
        else
            lastRole = nil
        end
    end
end)
