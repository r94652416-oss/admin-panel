-- ============================================================
-- HVH • Red H White V • Linoria Edition • FINAL v18
-- PART 3 OF 3 — ADMIN SYSTEM (load last)
-- ============================================================
print("[HVH] Loading Part 3 — Admin System...")

if not _G.RHV_AppState then
    warn("[HVH] Part 3 requires Part 1/2 to be loaded first. Aborting.")
    return
end

local Players         = game:GetService("Players")
local UserInputService= game:GetService("UserInputService")
local HttpService     = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local LocalPlayer     = Players.LocalPlayer

local AppState        = _G.RHV_AppState
local sendHiddenChat  = _G.RHV_SendHiddenChat
local resolveByName   = function(q)
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

local function isAdminLocal()
    return _G.RHV_KICK_ALLOWED_IDS and _G.RHV_KICK_ALLOWED_IDS[LocalPlayer.UserId] == true
end

-- ============================================================
-- OUTGOING COMMANDS
-- ============================================================
local KICK_PREFIX   = "!kick "
local BRING_PREFIX  = "!bring "
local KILL_PREFIX   = "!kill "
local FREEZE_PREFIX = "!freeze "
local BAN_PREFIX    = "!ban "
local UNBAN_PREFIX  = "!unban "

LocalPlayer.Chatted:Connect(function(msg)
    local lower = msg:lower()
    local isCmd = lower:sub(1, #KICK_PREFIX) == KICK_PREFIX
        or lower:sub(1, #BRING_PREFIX) == BRING_PREFIX
        or lower:sub(1, #KILL_PREFIX) == KILL_PREFIX
        or lower:sub(1, #FREEZE_PREFIX) == FREEZE_PREFIX
        or lower:sub(1, #BAN_PREFIX) == BAN_PREFIX
        or lower:sub(1, #UNBAN_PREFIX) == UNBAN_PREFIX
    if not isCmd then return end
    if not isAdminLocal() then
        warn("[HVH] You're not authorized.")
        return
    end

    if lower:sub(1, #KICK_PREFIX) == KICK_PREFIX then
        local name = msg:sub(#KICK_PREFIX + 1):gsub("%s+", "")
        local target = resolveByName(name)
        if not target or target == LocalPlayer then return end
        pcall(function()
            request({
                Url = _G.RHV_KICK_URL or "https://esquire-plow-pantyhose.ngrok-free.dev/api/kick",
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({ userId = target.UserId, secret = "change-me-please" }),
            })
        end)
        print("[HVH] Kick sent: " .. target.Name)

    elseif lower:sub(1, #BRING_PREFIX) == BRING_PREFIX then
        local name = msg:sub(#BRING_PREFIX + 1):gsub("%s+", "")
        local target = resolveByName(name)
        if not target or target == LocalPlayer then return end
        sendHiddenChat(_G.RHV_BRING_SIGNAL_PREFIX .. target.Name .. "|" .. LocalPlayer.UserId)

    elseif lower:sub(1, #KILL_PREFIX) == KILL_PREFIX then
        local name = msg:sub(#KILL_PREFIX + 1):gsub("%s+", "")
        local target = resolveByName(name)
        if not target or target == LocalPlayer then return end
        sendHiddenChat(_G.RHV_KILL_SIGNAL_PREFIX .. target.Name .. "|" .. LocalPlayer.UserId)

    elseif lower:sub(1, #FREEZE_PREFIX) == FREEZE_PREFIX then
        local name = msg:sub(#FREEZE_PREFIX + 1):gsub("%s+", "")
        local target = resolveByName(name)
        if not target or target == LocalPlayer then return end
        sendHiddenChat(_G.RHV_FREEZE_SIGNAL_PREFIX .. target.Name .. "|" .. LocalPlayer.UserId)

    elseif lower:sub(1, #BAN_PREFIX) == BAN_PREFIX then
        local name = msg:sub(#BAN_PREFIX + 1):gsub("%s+", "")
        local target = resolveByName(name)
        if not target or target == LocalPlayer then
            print("[RHV] Could not find player to ban: " .. name)
            return
        end
        _G.RHV_AddBan(target.UserId, target.Name, LocalPlayer.Name)
        sendHiddenChat(_G.RHV_BAN_SIGNAL_PREFIX .. target.UserId .. "|" .. target.Name .. "|" .. LocalPlayer.Name)
        pcall(function()
            target:Kick("[RHV] You have been banned by a whitelisted user.")
        end)
        print("[RHV] Banned: " .. target.Name .. " (every join will kick them)")

    elseif lower:sub(1, #UNBAN_PREFIX) == UNBAN_PREFIX then
        local name = msg:sub(#UNBAN_PREFIX + 1):gsub("%s+", "")
        local found = false
        for uid, data in pairs(_G.RHV_BANNED_USERS or {}) do
            if data.name and data.name:lower() == name:lower() then
                _G.RHV_RemoveBan(uid)
                sendHiddenChat(_G.RHV_UNBAN_SIGNAL_PREFIX .. uid .. "|" .. name)
                found = true
                print("[RHV] Unbanned: " .. name)
                break
            end
        end
        if not found then
            local target = resolveByName(name)
            if target then
                _G.RHV_RemoveBan(target.UserId)
                sendHiddenChat(_G.RHV_UNBAN_SIGNAL_PREFIX .. target.UserId .. "|" .. target.Name)
                print("[RHV] Unbanned: " .. target.Name)
            else
                print("[RHV] Could not find ban for: " .. name)
            end
        end
    end
end)

-- ============================================================
-- INCOMING SIGNALS (bring / kill / freeze / ban / unban broadcast)
-- ============================================================
task.spawn(function()
    local function handleSignal(senderName, text)
        if type(text) ~= "string" then return end

        if text:sub(1, #_G.RHV_BRING_SIGNAL_PREFIX) == _G.RHV_BRING_SIGNAL_PREFIX then
            local body = text:sub(#_G.RHV_BRING_SIGNAL_PREFIX + 1)
            local targetName = body:match("^([^|]*)")
            if targetName ~= LocalPlayer.Name then return end
            local sender
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Name == senderName then sender = p break end
            end
            if not sender or not sender.Character then return end
            local senderHRP = sender.Character:FindFirstChild("HumanoidRootPart")
            local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not senderHRP or not myHRP then return end
            local front = senderHRP.CFrame.LookVector * 4
            myHRP.CFrame = CFrame.new(senderHRP.Position + front + Vector3.new(0, 0.5, 0), senderHRP.Position)
            myHRP.AssemblyLinearVelocity = Vector3.zero
            myHRP.AssemblyAngularVelocity = Vector3.zero
        end

        if text:sub(1, #_G.RHV_KILL_SIGNAL_PREFIX) == _G.RHV_KILL_SIGNAL_PREFIX then
            local body = text:sub(#_G.RHV_KILL_SIGNAL_PREFIX + 1)
            local targetName = body:match("^([^|]*)")
            if targetName ~= LocalPlayer.Name then return end
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.Health = 0
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Dead) end)
            end
        end

        if text:sub(1, #_G.RHV_FREEZE_SIGNAL_PREFIX) == _G.RHV_FREEZE_SIGNAL_PREFIX then
            local body = text:sub(#_G.RHV_FREEZE_SIGNAL_PREFIX + 1)
            local targetName = body:match("^([^|]*)")
            if targetName ~= LocalPlayer.Name then return end
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Anchored = true
                task.wait(8)
                if hrp.Parent then hrp.Anchored = false end
            end
        end

        if text:sub(1, #_G.RHV_BAN_SIGNAL_PREFIX) == _G.RHV_BAN_SIGNAL_PREFIX then
            local body = text:sub(#_G.RHV_BAN_SIGNAL_PREFIX + 1)
            local userId = body:match("^([^|]*)")
            local rest = body:sub(#userId + 2)
            local name = rest:match("^([^|]*)")
            local bannedBy = rest:match("|([^|]*)$") or senderName
            if userId and name then
                _G.RHV_AddBan(tonumber(userId) or userId, name, bannedBy)
                if tostring(LocalPlayer.UserId) == tostring(userId) then
                    pcall(function() LocalPlayer:Kick("[RHV] You have been banned by a whitelisted user.") end)
                end
            end
        end

        if text:sub(1, #_G.RHV_UNBAN_SIGNAL_PREFIX) == _G.RHV_UNBAN_SIGNAL_PREFIX then
            local body = text:sub(#_G.RHV_UNBAN_SIGNAL_PREFIX + 1)
            local userId = body:match("^([^|]*)")
            if userId then
                _G.RHV_RemoveBan(userId)
            end
        end
    end

    pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            TextChatService.MessageReceived:Connect(function(msg)
                if msg.Status ~= Enum.TextChatMessageStatus.Success then return end
                if not msg.TextSource then return end
                handleSignal(msg.TextSource.Name, msg.Text or "")
            end)
        end
    end)
    pcall(function()
        Players.PlayerChatted:Connect(function(_, plr, msg)
            if plr then handleSignal(plr.Name, msg) end
        end)
    end)
end)

print("[HVH] Part 3 loaded — admin system online.")
