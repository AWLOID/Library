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
    Crosshair = false,
}

local MAX_DIST = 1000

local BASE = {
    Murderer = Color3.fromRGB(255, 90, 90),
    Sheriff = Color3.fromRGB(110, 160, 255),
    Hero = Color3.fromRGB(255, 220, 110),
    Innocent = Color3.fromRGB(120, 230, 140),
}

local function makeRole(base)
    return {
        bright = base,
        dark = base:Lerp(Color3.fromRGB(0, 0, 0), 0.78),
        outline = base:Lerp(Color3.fromRGB(255, 255, 255), 0.15),
    }
end

local COLORS = {}
local function rebuildColors()
    for role, base in pairs(BASE) do
        COLORS[role] = makeRole(base)
    end
end
rebuildColors()

local function getgui()
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
local function getRoundModule()
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
local function liveData()
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

local function getData(plr)
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

local function roundActive()
    local live = liveData()
    return live ~= nil and next(live) ~= nil
end

local Me = { Role = nil, Dead = false, InLobby = false, Alive = false }

local function holdsGun(plr)
    local ok, res = pcall(function()
        local char = plr.Character
        if char and char:FindFirstChild("Gun") then return true end
        local bp = plr:FindFirstChildOfClass("Backpack")
        if bp and bp:FindFirstChild("Gun") then return true end
        return false
    end)
    return ok and res
end

local function resolveRole(plr, data)
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

local function refreshSelf()
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

local function shouldShow(role)
    if role == "Murderer" then return Settings.Murderer end
    if role == "Sheriff" then return Settings.Sheriff end
    if role == "Hero" then return Settings.Sheriff end
    if role == "Innocent" then return Settings.Innocent end
    return false
end

local function shimmer(c)
    local t = (math.sin(os.clock() * 3) + 1) / 2
    return c.dark:Lerp(c.bright, t)
end

local ESP = {}

local function newDrawing(class, props)
    local ok, obj = pcall(function() return Drawing.new(class) end)
    if not ok or not obj then return nil end
    for k, v in pairs(props) do
        pcall(function() obj[k] = v end)
    end
    return obj
end

local function createESP(plr)
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
    e.stroke.Thickness = 1.2
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
    e.tracerShadow = newDrawing("Line", {
        Thickness = 3,
        Transparency = 0.5,
        Visible = false,
        Color = Color3.fromRGB(0, 0, 0),
        ZIndex = 2,
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

    e.chams = {}
    e.chamsChar = nil
    ESP[plr] = e
    return e
end

local function hideBox(e)
    if e.boxFrame then e.boxFrame.Visible = false end
    if e.boxLine then e.boxLine.Visible = false end
    if e.boxAccent then e.boxAccent.Visible = false end
    if e.tracer then e.tracer.Visible = false end
    if e.tracerShadow then e.tracerShadow.Visible = false end
end

local function hideText(e)
    if e.nameLabel then e.nameLabel.Visible = false end
    if e.distLabel then e.distLabel.Visible = false end
end

local function disableHighlight(plr)
    local e = ESP[plr]
    if e and e.highlight then e.highlight.Enabled = false end
end

local function hideChams(e)
    if e.chams then
        for _, a in ipairs(e.chams) do
            if a then a.Visible = false end
        end
    end
end

local function clearChams(e)
    if e.chams then
        for _, a in ipairs(e.chams) do pcall(function() a:Destroy() end) end
    end
    e.chams = {}
    e.chamsChar = nil
end

local function destroyESP(plr)
    local e = ESP[plr]
    if not e then return end
    if e.boxFrame then pcall(function() e.boxFrame:Destroy() end) end
    if e.boxLine then pcall(function() e.boxLine:Remove() end) end
    if e.boxAccent then pcall(function() e.boxAccent:Remove() end) end
    if e.tracer then pcall(function() e.tracer:Remove() end) end
    if e.tracerShadow then pcall(function() e.tracerShadow:Remove() end) end
    if e.nameLabel then pcall(function() e.nameLabel:Destroy() end) end
    if e.distLabel then pcall(function() e.distLabel:Destroy() end) end
    if e.highlight then pcall(function() e.highlight:Destroy() end) end
    if e.tagBtn then pcall(function() e.tagBtn:Destroy() end) end
    if e.tagMenu then pcall(function() e.tagMenu:Destroy() end) end
    clearChams(e)
    ESP[plr] = nil
end

local function getHighlight(plr, char)
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

local function applyHighlight(plr, char, c)
    local hl = getHighlight(plr, char)
    if hl.Adornee ~= char then hl.Adornee = char end
    local col = c.bright
    if hl.FillColor ~= col then hl.FillColor = col end
    if hl.OutlineColor ~= c.outline then hl.OutlineColor = c.outline end
    if hl.FillTransparency ~= 0.4 then hl.FillTransparency = 0.4 end
    if hl.OutlineTransparency ~= 0 then hl.OutlineTransparency = 0 end
    if not hl.Enabled then hl.Enabled = true end
end

local function applyChams(plr, char, c)
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

local function updateVisuals(plr, char, c, hrp)
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
        e.stroke.Thickness = 1

        local dPos = Vector2.new(minX + inset.X, minY + inset.Y)
        if e.boxAccent then
            e.boxAccent.Size = sizeV
            e.boxAccent.Position = dPos
            e.boxAccent.Thickness = 3
            e.boxAccent.Color = Color3.fromRGB(0, 0, 0)
            e.boxAccent.Transparency = 0.6
            e.boxAccent.ZIndex = 4
            e.boxAccent.Visible = true
        end
        if e.boxLine then
            e.boxLine.Size = sizeV
            e.boxLine.Position = dPos
            e.boxLine.Thickness = 1
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
        if e.tracerShadow then
            e.tracerShadow.From = fromV
            e.tracerShadow.To = toV
            e.tracerShadow.Thickness = 3
            e.tracerShadow.Color = Color3.fromRGB(0, 0, 0)
            e.tracerShadow.Transparency = 0.5
            e.tracerShadow.Visible = true
        end
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

    if Settings.ShowName then
        e.nameLabel.Text = plr.Name
        e.nameLabel.TextColor3 = Color3.new(1, 1, 1)
        e.nameLabel.Position = UDim2.fromOffset(cx, minY - 3)
        e.nameLabel.Visible = true
    else
        e.nameLabel.Visible = false
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

local function getMyChar()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not hrp then return nil end
    return char, hrp, head
end

local function updateChinaHat()
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

local function updateTrail()
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

local function rebindPlayerFX()
    PlayerFX.hat = nil
    PlayerFX.trail = nil
    PlayerFX.att0 = nil
    PlayerFX.att1 = nil
    PlayerFX.lastTrailColor = nil
end

LocalPlayer.CharacterAdded:Connect(rebindPlayerFX)

local DropGuns = {}
local DROPGUN_COLOR = Color3.fromRGB(255, 220, 70)

local function findMap()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:GetAttribute("MapID") ~= nil then
            return obj
        end
    end
    return nil
end

local function getDropRec(obj)
    local r = DropGuns[obj]
    if not r then r = { chams = {} } DropGuns[obj] = r end
    return r
end

local function destroyDropRec(obj)
    local r = DropGuns[obj]
    if not r then return end
    if r.hl then pcall(function() r.hl:Destroy() end) end
    if r.chams then for _, a in ipairs(r.chams) do pcall(function() a:Destroy() end) end end
    if r.box then pcall(function() r.box:Remove() end) end
    DropGuns[obj] = nil
end

local function clearDropGuns()
    for obj in pairs(DropGuns) do destroyDropRec(obj) end
end

local function dropHighlight(obj, r)
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

local function dropChams(obj, r)
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

local function dropBox(obj, r)
    local part = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
    if not part then return end
    local pos, on = Camera:WorldToViewportPoint(part.Position)
    if not on then
        if r.box then r.box.Visible = false end
        return
    end
    if not r.box then
        r.box = newDrawing("Square", { Thickness = 1.5, Filled = false, Transparency = 1, Color = DROPGUN_COLOR, ZIndex = 6 })
    end
    if r.box then
        local inset = GuiService:GetGuiInset()
        local s = 16
        r.box.Size = Vector2.new(s, s)
        r.box.Position = Vector2.new(pos.X - s / 2 + inset.X, pos.Y - s / 2 + inset.Y)
        r.box.Color = DROPGUN_COLOR
        r.box.Thickness = 1.5
        r.box.Visible = true
    end
end

local _dropList = {}
local _dropScanTime = 0
local function updateDropGun()
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
    for _, obj in ipairs(_dropList) do
        if obj.Parent then
            local r = getDropRec(obj)
            if mode == "Chams" then
                if r.hl then r.hl.Enabled = false end
                if r.box then r.box.Visible = false end
                dropChams(obj, r)
            elseif mode == "Box" then
                if r.hl then r.hl.Enabled = false end
                if r.chams then for _, a in ipairs(r.chams) do a.Visible = false end end
                dropBox(obj, r)
            else
                if r.chams then for _, a in ipairs(r.chams) do a.Visible = false end end
                if r.box then r.box.Visible = false end
                dropHighlight(obj, r)
            end
        end
    end
end

local _fxFrame = 0
local function tick()
    _frame = _frame + 1
    refreshSelf()

    _fxFrame = _fxFrame + 1
    if _fxFrame >= 3 then
        _fxFrame = 0
        updateChinaHat()
        updateTrail()
        updateDropGun()
    end

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

                    updateVisuals(plr, char, c, hrp)
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
    pcall(tick)
end)

Players.PlayerRemoving:Connect(function(plr)
    destroyESP(plr)
    PlayerData[plr.Name] = nil
end)

local function bindRespawn(plr)
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
            return tab:AddToggle({ Name = c.Title, Default = c.Value, Callback = c.Callback })
        end

        function TabShim:Dropdown(c)
            c = c or {}
            local api = tab:AddDropdown({
                Name = c.Title,
                Options = c.Values,
                Default = c.Value,
                Callback = c.Callback,
            })
            return {
                Refresh = function(_, newValues) api.SetOptions(newValues) end,
                Set = function(_, v) api.Set(v) end,
                Get = function(_) return api.Get() end,
            }
        end

        function TabShim:Slider(c)
            c = c or {}
            local v = c.Value or {}
            return tab:AddSlider({
                Name = c.Title,
                Min = v.Min,
                Max = v.Max,
                Default = v.Default,
                Step = c.Step,
                Callback = c.Callback,
            })
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
            return tab:AddColorPicker({ Name = c.Title, Default = c.Default, Callback = c.Callback })
        end

        function TabShim:Section(c)
            c = c or {}
            return tab:AddSection(c.Title)
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

VisualsTab:Section({ Title = "Map" })

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

local function getPlayerByName(name)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name == name then return p end
    end
    return nil
end

local function playerNames()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(list, p.Name)
        end
    end
    return list
end

local function teleportTo(target)
    local me, myHrp = getMyChar()
    if not me or not myHrp then return end
    local tc = target.Character
    local thrp = tc and tc:FindFirstChild("HumanoidRootPart")
    if thrp then
        myHrp.CFrame = thrp.CFrame * CFrame.new(0, 0, 3)
    end
end

local function startSpectate(target)
    local tc = target.Character
    local thum = tc and tc:FindFirstChildOfClass("Humanoid")
    if thum then
        if not origCamSubject then origCamSubject = Camera.CameraSubject end
        Camera.CameraSubject = thum
        Spectating = target
    end
end

local function stopSpectate()
    local me = LocalPlayer.Character
    local h = me and me:FindFirstChildOfClass("Humanoid")
    if h then Camera.CameraSubject = h end
    origCamSubject = nil
    Spectating = nil
end

local function flingTarget(target)
    local me, myHrp = getMyChar()
    local tc = target.Character
    local thrp = tc and tc:FindFirstChild("HumanoidRootPart")
    if not myHrp or not thrp then return end
    local v = Instance.new("BodyVelocity")
    v.MaxForce = Vector3.new(1, 1, 1) * 1e9
    v.Velocity = Vector3.new(0, 0, 0)
    v.Parent = myHrp
    local conn
    local count = 0
    conn = RunService.Heartbeat:Connect(function()
        count = count + 1
        myHrp.CFrame = thrp.CFrame
        myHrp.Velocity = Vector3.new(9999, 9999, 9999)
        if count > 6 then
            conn:Disconnect()
            pcall(function() v:Destroy() end)
        end
    end)
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

local function refreshPlayerList()
    pcall(function() playerDropdown:Refresh(playerNames()) end)
end

Players.PlayerAdded:Connect(function() task.defer(refreshPlayerList) end)
Players.PlayerRemoving:Connect(function() task.defer(refreshPlayerList) end)

function notify(msg)
    pcall(function()
        WindUI:Notify({ Title = "Mindjorn Hub", Content = msg, Icon = "solar:danger-triangle-bold", Duration = 4 })
    end)
end

local function getTorso(plr)
    local c = plr.Character
    if not c then return nil end
    return c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or c:FindFirstChild("HumanoidRootPart")
end

local function isAlive(plr)
    local d = getData(plr)
    if not d then return false end
    if d.Dead == true then return false end
    local c = plr.Character
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

local function findMurderer()
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

local function isSheriffRole(p)
    local d = getData(p)
    if not d or d.Dead == true then return false end
    local r = resolveRole(p, d)
    return r == "Sheriff" or r == "Hero"
end

local function findSheriff()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isSheriffRole(p) then
            return p
        end
    end
    return nil
end

local function findNearestSheriff()
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

local function getKnifeEvent()
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

local function getKnifeThrow()
    local function scan(parent)
        if not parent then return nil end
        local knife = parent:FindFirstChild("Knife")
        if knife then
            local ev = knife:FindFirstChild("Events")
            if ev then return ev:FindFirstChild("KnifeThrown") end
        end
        return nil
    end
    return scan(LocalPlayer.Character) or scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
end

local AutoThrowing = false
local function throwKnifeAll()
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
                    task.wait(0.35)
                end
            end
        end
        AutoThrowing = false
    end)
end

local function equipKnife()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    local knife = (char and char:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife"))
    if knife and hum and knife.Parent ~= char then
        pcall(function() hum:EquipTool(knife) end)
    end
end

local function findNearestAlive()
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

local function findNearestVisible()
    local me, myHrp, head = getMyChar()
    if not myHrp then return nil end
    local fromPos = (head and head.Position) or myHrp.Position
    local best, bestD = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlive(p) and p.Character then
            local t = getTorso(p)
            if t and lineClear(fromPos, p.Character) then
                local dd = (myHrp.Position - t.Position).Magnitude
                if dd < bestD then best, bestD = p, dd end
            end
        end
    end
    return best
end

local function throwKnifeNearest()
    refreshSelf()
    if Me.Role ~= "Murderer" then
        notify("You are not the murderer")
        return
    end
    if not roundActive() or Me.Dead then return end
    equipKnife()
    local ev = getKnifeThrow()
    if not ev then notify("Knife not found") return end
    local target = findNearestVisible()
    if not target then return end
    local me, myHrp, head = getMyChar()
    local torso = getTorso(target)
    if not myHrp or not torso then return end
    local origin = (head and head.Position) or myHrp.Position
    local aim = CFrame.new(origin, torso.Position)
    pcall(function() ev:FireServer(aim, CFrame.new(torso.Position)) end)
end

local function killSheriff()
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
local function getShoot()
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
local function getPing()
    local now = os.clock()
    if now - pingTime > 0.5 then
        pingTime = now
        pcall(function()
            cachedPing = math.clamp(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000, 0.01, 0.3)
        end)
    end
    return cachedPing
end

local function bestHitPart(char)
    return char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        or char:FindFirstChild("Head")
end

local function predictTarget(char, aimPart, t)
    local pos = aimPart.Position
    local vel = aimPart.AssemblyLinearVelocity

    local px = pos.X + vel.X * t
    local pz = pos.Z + vel.Z * t
    local py = pos.Y

    local hum = char:FindFirstChildOfClass("Humanoid")
    local state = hum and hum:GetState()
    local airborne = state == Enum.HumanoidStateType.Freefall
        or state == Enum.HumanoidStateType.Jumping

    if airborne then
        local g = workspace.Gravity
        py = pos.Y + vel.Y * t - 0.5 * g * t * t
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

local function predictPosition(origin, p)
    local char = p.Character
    local aimPart = char and bestHitPart(char)
    if not aimPart then return nil end
    return predictTarget(char, aimPart, getPing())
end

local function fireShoot(plr, throughWalls)
    local shoot = getShoot()
    if not shoot then return false end
    local char = plr.Character
    local aimPart = char and bestHitPart(char)
    if not aimPart then return false end
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return false end

    local targetPos = predictTarget(char, aimPart, getPing())

    local origin
    if throughWalls then
        local dir = myHrp.Position - targetPos
        origin = targetPos + (dir.Magnitude > 0.1 and dir.Unit or Vector3.zAxis) * 2
    else
        local head = myChar:FindFirstChild("Head")
        origin = (head and head.Position) or myHrp.Position
    end

    shoot:FireServer(CFrame.new(origin, targetPos), CFrame.new(targetPos))
    return true
end

local function equipGun()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    local gun = (char and char:FindFirstChild("Gun")) or (bp and bp:FindFirstChild("Gun"))
    if gun and hum and gun.Parent ~= char then
        pcall(function() hum:EquipTool(gun) end)
    end
end

local KnifeKillRemote
local function getKnifeTool()
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

local function findKillRemote(knife)
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

local function fireKnife(remote, targetRoot)
    pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(targetRoot)
        else
            remote:InvokeServer(targetRoot)
        end
    end)
end

local function lineClear(fromPos, targetChar)
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

local function killAll()
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

local function killMurder()
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
                local knife = getKnifeTool()
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

local function makeFloatingButton(cfg)
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
local function makeShootButton()
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

local function removeShootButton()
    if ShootObj then pcall(function() ShootObj.gui:Destroy() end) ShootObj = nil end
end

local ShootWHObj
local function makeShootButtonWH()
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
local function removeShootButtonWH()
    if ShootWHObj then pcall(function() ShootWHObj.gui:Destroy() end) ShootWHObj = nil end
end

local flinging = false
function flingPlayer(target)
    task.spawn(function()
        if flinging then return end
        if not target then return end
        flinging = true

        local Character = LocalPlayer.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        local RootPart = Character and (Character:FindFirstChild("HumanoidRootPart") or Character:FindFirstChild("Torso") or Character:FindFirstChild("UpperTorso"))
        local TCharacter = target.Character

        if not (Character and Humanoid and RootPart and TCharacter) then
            flinging = false
            notify("No character")
            return
        end

        local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
        local TRootPart = THumanoid and THumanoid.RootPart
        local THead = TCharacter:FindFirstChild("Head")

        if not THumanoid then
            flinging = false
            notify("Target died")
            return
        end

        local OldPos = RootPart.CFrame
        local FPDH = Workspace.FallenPartsDestroyHeight
        pcall(function() Workspace.FallenPartsDestroyHeight = 0/0 end)

        local BV = Instance.new("BodyVelocity")
        BV.Parent = RootPart
        BV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        BV.Velocity = Vector3.new(0, 0, 0)

        pcall(function() Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end)

        local function FPos(BasePart, Pos, Ang)
            if not flinging then return end
            if not Character or not RootPart or not BasePart then return end
            local cf = CFrame.new(BasePart.Position) * Pos * Ang
            RootPart.CFrame = cf
            pcall(function() Character:SetPrimaryPartCFrame(cf) end)
            RootPart.Velocity = Vector3.new(9e7, 9e8, 9e7)
            RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
        end

        local function SFBasePart(BasePart)
            local Time = os.clock()
            local Angle = 0
            repeat
                if not BasePart or not BasePart.Parent then break end
                if not THumanoid or not THumanoid.Parent then break end
                if BasePart.Velocity.Magnitude < 50 then
                    Angle = Angle + 100
                    FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()
                else
                    FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))
                    task.wait()
                end
            until os.clock() - Time > 1.8 or not flinging
        end

        if TRootPart then
            SFBasePart(TRootPart)
        elseif THead then
            SFBasePart(THead)
        end

        pcall(function() BV:Destroy() end)
        pcall(function() Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end)
        pcall(function() Workspace.CurrentCamera.CameraSubject = Humanoid end)

        local startT = os.clock()
        repeat
            RootPart.CFrame = OldPos * CFrame.new(0, 0.5, 0)
            pcall(function() Character:SetPrimaryPartCFrame(OldPos * CFrame.new(0, 0.5, 0)) end)
            pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            for _, part in ipairs(Character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.Velocity = Vector3.new()
                    part.RotVelocity = Vector3.new()
                end
            end
            task.wait()
        until (RootPart.Position - OldPos.Position).Magnitude < 30 or os.clock() - startT > 2

        pcall(function() Workspace.FallenPartsDestroyHeight = FPDH or -500 end)
        flinging = false
    end)
end

function flingAll()
    task.spawn(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and isAlive(p) then
                flingPlayer(p)
                repeat task.wait(0.1) until not flinging
                task.wait(0.2)
            end
        end
    end)
end

local loopFlingRunning = false
function startLoopFlingAll()
    if loopFlingRunning then return end
    loopFlingRunning = true
    task.spawn(function()
        while Settings.LoopFlingAll do
            for _, p in ipairs(Players:GetPlayers()) do
                if not Settings.LoopFlingAll then break end
                if p ~= LocalPlayer and p.Character and isAlive(p) then
                    flingPlayer(p)
                    repeat task.wait(0.1) until (not flinging) or (not Settings.LoopFlingAll)
                    task.wait(0.12)
                end
            end
            task.wait(0.15)
        end
        loopFlingRunning = false
    end)
end

local RolesTab = Window:Tab({
    Title = "Roles",
    Icon = "solar:gun-bold",
    IconShape = "Square",
    Border = true,
})

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

RolesTab:Toggle({
    Title = "Delayed Shoot",
    Value = false,
    Callback = function(v) Settings.DelayedShoot = v end,
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

local function applySpeed()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = Settings.WalkSpeed end
end

local function applyJump()
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
local function setNoclip(state)
    if state then
        if noclipConn then return end
        noclipConn = RunService.Stepped:Connect(function()
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
local function findMapGun()
    if _gunCache and _gunCache.Parent then
        if os.clock() - _gunCacheTime < 1 then return _gunCache end
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

local function grabGun()
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

task.spawn(function()
    while true do
        task.wait(1)
        if Settings.AutoGrabGun then
            refreshSelf()
            if (Me.Role == "Sheriff" or Me.Role == "Innocent" or Me.Role == "Hero") and not Me.Dead and roundActive() then
                local me, myHrp = getMyChar()
                local hasGun = me and (me:FindFirstChild("Gun") or (LocalPlayer:FindFirstChildOfClass("Backpack") and LocalPlayer:FindFirstChildOfClass("Backpack"):FindFirstChild("Gun")))
                if not hasGun then grabGun() end
            end
        end
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

local antiflingConn
local function setAntifling(state)
    if state then
        if antiflingConn then return end
        antiflingConn = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local v = hrp.AssemblyLinearVelocity
                if v.Magnitude > 130 then
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                end
                local av = hrp.AssemblyAngularVelocity
                if av.Magnitude > 25 then
                    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end
                pcall(function()
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 1, 1)
                            part.Massless = false
                        end
                    end
                end)
            end
        end)
    else
        if antiflingConn then antiflingConn:Disconnect() antiflingConn = nil end
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

local CrosshairGui, CrosshairConn
local function makeCrosshair()
    if CrosshairGui and CrosshairGui.Parent then return end
    CrosshairGui = Instance.new("ScreenGui")
    CrosshairGui.Name = "\0cc"
    CrosshairGui.ResetOnSpawn = false
    CrosshairGui.IgnoreGuiInset = true
    CrosshairGui.DisplayOrder = 999999
    pcall(function() CrosshairGui.Parent = getgui() end)

    local label = Instance.new("TextLabel")
    label.Parent = CrosshairGui
    label.BackgroundTransparency = 1
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Position = UDim2.new(0.5, 0, 0.5, 0)
    label.Size = UDim2.new(0, 40, 0, 40)
    label.Text = "卐"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.Code
    label.TextStrokeTransparency = 0.3
    label.ZIndex = 9999

    local r = 0
    CrosshairConn = RunService.RenderStepped:Connect(function(dt)
        if not label or not label.Parent then return end
        r = (r + 25 * math.min(dt, 0.05)) % 360
        label.Rotation = r
    end)
end

local function removeCrosshair()
    if CrosshairConn then CrosshairConn:Disconnect() CrosshairConn = nil end
    if CrosshairGui then pcall(function() CrosshairGui:Destroy() end) CrosshairGui = nil end
end

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

PlayerTab:Toggle({
    Title = "Svastika Crosshair",
    Value = false,
    Callback = function(v)
        Settings.Crosshair = v
        if v then makeCrosshair() else removeCrosshair() end
    end,
})

-- ==== Fake SpeedGlitch ====
local FakeSpeedEnabled = false
local FakeSpeedValue = 0 -- \u0437\u043d\u0430\u0447\u0435\u043d\u0438\u0435 \u0441\u043a\u043e\u0440\u043e\u0441\u0442\u0438, \u043a\u043e\u0442\u043e\u0440\u043e\u0435 \u0441\u0442\u0430\u0432\u0438\u0442\u0441\u044f \u0432\u043e \u0432\u0440\u0435\u043c\u044f Freefall
local fakeSpeedSlider = nil
local fakeSpeedToggle
fakeSpeedToggle = PlayerTab:Toggle({
    Title = "Fake SpeedGlitch",
    Value = false,
    Callback = function(v)
        FakeSpeedEnabled = v
        if v then
            -- \u043f\u0440\u0438 \u0432\u043a\u043b\u044e\u0447\u0435\u043d\u0438\u0438 \u0441\u043d\u0438\u0437\u0443 \u043f\u043e\u044f\u0432\u043b\u044f\u0435\u0442\u0441\u044f \u0441\u043b\u0430\u0439\u0434\u0435\u0440 \u0440\u0435\u0433\u0443\u043b\u0438\u0440\u043e\u0432\u043a\u0438 \u0441\u043a\u043e\u0440\u043e\u0441\u0442\u0438
            if not fakeSpeedSlider and fakeSpeedToggle and fakeSpeedToggle.AddSlider then
                fakeSpeedSlider = fakeSpeedToggle:AddSlider({
                    Name = "Speed",
                    Min = 0, Max = 200, Step = 1,
                    Default = FakeSpeedValue,
                    Callback = function(val) FakeSpeedValue = val end,
                })
            end
        else
            if fakeSpeedSlider and fakeSpeedSlider.Destroy then
                pcall(function() fakeSpeedSlider.Destroy() end)
            end
            fakeSpeedSlider = nil
        end
    end,
})

RunService.RenderStepped:Connect(function()
    if not FakeSpeedEnabled then return end
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
                moveDir.X * FakeSpeedValue,
                root.Velocity.Y,
                moveDir.Z * FakeSpeedValue
            )
        end
    end
end)
-- ==== /Fake SpeedGlitch ====

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

local function setAnimate(state)
    local char = LocalPlayer.Character
    local animate = char and char:FindFirstChild("Animate")
    if animate then pcall(function() animate.Disabled = state end) end
end

local function stopAllTracks(humanoid, animator)
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

local function stopEmote()
    if currentTrack then
        pcall(function() currentTrack:Stop() end)
        pcall(function() currentTrack:Destroy() end)
        currentTrack = nil
    end
    setAnimate(false)
end

local function playEmote(emote)
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

local function setupMovementStopping(char)
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

local function getRoleTarget(roleSet)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local d = getData(p)
            if d and d.Dead ~= true and roleSet[resolveRole(p, d)] then return p end
        end
    end
    return nil
end

local fbList = {}
local function makeFB(id, text, pos, onClick)
    local obj = makeFloatingButton({ id = id, text = text, w = 60, h = 60, pos = pos, onClick = onClick })
    if obj and obj.gui then obj.gui.Enabled = false end
    fbList[#fbList + 1] = { obj = obj, name = (tostring(text or "Button")):gsub("\n", " ") }
    return obj
end
local function makeFBToggle(id, onText, offText, pos, default, onChange)
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
    fbList[#fbList + 1] = { obj = obj, name = (tostring(offText or "Button")):gsub("\n", " ") }
    return obj
end

local ButtonsTab = Window:Tab({ Title = "Buttons", Icon = "solar:gamepad-bold", IconShape = "Square", Border = true })

local resizeTargets = {}
local resizeEnabled = false

local function showToggle(title, obj, tab)
    tab = tab or ButtonsTab
    local tgl = tab:Toggle({ Title = title, Value = false, Callback = function(v)
        if obj and obj.gui then obj.gui.Enabled = v end
    end })
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
local SPIN_SPEED = 25
local function stopSpin()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bg = hrp:FindFirstChild("\0spin")
    if bg then bg:Destroy() end
    pcall(function() hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0) end)
end
local SpinObj = makeFBToggle("\0fb_spin", "Spin\nON", "Spin\nOFF", UDim2.new(0, 30, 0.30, 80), false, function(on)
    Settings.SpinBtn = on
    if not on then stopSpin() end
end)
RunService.Heartbeat:Connect(function()
    if not Settings.SpinBtn then return end
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        hrp.AssemblyAngularVelocity = Vector3.new(0, SPIN_SPEED, 0)
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
    { Name = "Spin", Set = function(v) Settings.SpinBtn = v if not v then stopSpin() end end },
    { Name = "Crosshair", Set = function(v) Settings.Crosshair = v if v then makeCrosshair() else removeCrosshair() end end },
    { Name = "Lock Cam (Sheriff)", Set = function(v) Settings.LockCam = v end },
    { Name = "Fake SpeedGlitch", Set = function(v) FakeSpeedEnabled = v end },
}

local function customNamesFor(kind)
    local list = (kind == "Toggle") and CustomToggleActions or CustomButtonActions
    local names = {}
    for _, a in ipairs(list) do names[#names + 1] = a.Name end
    return names
end

local function findCustomAction(kind, name)
    local list = (kind == "Toggle") and CustomToggleActions or CustomButtonActions
    for _, a in ipairs(list) do
        if a.Name == name then return a end
    end
end

local customType = "Button"
local customFunc = CustomButtonActions[1].Name
local customCount = 0
local customFuncDropdown

ButtonsTab:Dropdown({
    Title = "Type",
    Values = { "Button", "Toggle" },
    Value = "Button",
    Callback = function(v)
        customType = v
        customFunc = customNamesFor(v)[1]
        if customFuncDropdown then
            pcall(function()
                customFuncDropdown:Refresh(customNamesFor(v))
                customFuncDropdown:Set(customFunc)
            end)
        end
    end,
})

customFuncDropdown = ButtonsTab:Dropdown({
    Title = "Function",
    Values = customNamesFor("Button"),
    Value = customFunc,
    Callback = function(v) customFunc = v end,
})

ButtonsTab:Button({
    Title = "Create",
    Callback = function()
        local action = findCustomAction(customType, customFunc)
        if not action then
            notify("Select a function first")
            return
        end
        customCount = customCount + 1
        local pos = UDim2.new(0, 190, 0.30, (customCount - 1) * 80)
        local obj
        if customType == "Toggle" then
            obj = makeFBToggle("\0fb_custom" .. customCount, action.Name .. "\nON", action.Name .. "\nOFF", pos, false, function(on)
                pcall(action.Set, on)
            end)
        else
            obj = makeFB("\0fb_custom" .. customCount, action.Name, pos, function()
                pcall(action.Run)
            end)
        end
        showToggle(action.Name .. " #" .. customCount, obj)
        if obj and obj.gui then obj.gui.Enabled = true end
        notify("Created: " .. action.Name .. " (" .. customType .. ")")
    end,
})
-- ==== /Custom Buttons Constructor ====

local function arrangeFloating()
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

local function buildPlayerTag(plr, e)
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

local function hideAllTags()
    for _, e in pairs(ESP) do
        if e.tagBtn then e.tagBtn.Visible = false end
        if e.tagMenu then e.tagMenu.Visible = false end
        e.tagOpen = false
        e.tagAnim = 0
    end
end

local TAG_BASE = 34
local TAG_REF_DIST = 40

local function updatePlayerTags(dt)
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
