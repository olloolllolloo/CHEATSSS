
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MorphCheat_Final_Neon"
ScreenGui.Parent = player:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true

local COLORS = {
    MainBG = Color3.fromRGB(10, 10, 12),
    SideBG = Color3.fromRGB(18, 18, 22),
    Accent = Color3.fromRGB(0, 255, 255),
    Inactive = Color3.fromRGB(30, 30, 35),
    Text = Color3.fromRGB(255, 255, 255),
    RowDark = Color3.fromRGB(15, 15, 18),
    RowLight = Color3.fromRGB(28, 28, 35),
}

local function GetRowColor(order)
    return (order % 2 == 0) and COLORS.RowDark or COLORS.RowLight
end

local States = {
    InfJump = false, NoClip = false, TeleportClick = false, AntiAFK = false,
    ESP = false, ESPColorIndex = 1, NameESP = false, NameESPColorIndex = 1, HealthESP = false,
    ShowNotifications = true, TapToIdentify = false, Light = false, FollowTP = false,
    ObjectHighlighter = false, HighlightColorIndex = 1,
    -- Joke features
    Spin = false, SpinAxisX = false, SpinAxisY = false, SpinAxisZ = false,
    BAF = false, Combo = false,
    -- Disturb features
    Fling = false, FlingPower = 10000
}

local ESP_COLORS = {Color3.fromRGB(0, 255, 255), Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0), Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 0, 255)}
local NAME_ESP_COLORS = {Color3.fromRGB(0, 255, 255), Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0), Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 0, 255)}
local HIGHLIGHT_COLORS = {Color3.fromRGB(0, 255, 255), Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0), Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 0, 255), Color3.fromRGB(255, 165, 0), Color3.fromRGB(128, 0, 255)}

local originalLightingSettings = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    Ambient = Lighting.Ambient,
    ColorShift_Top = Lighting.ColorShift_Top,
    ColorShift_Bottom = Lighting.ColorShift_Bottom,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    ExposureCompensation = Lighting.ExposureCompensation,
    GlobalShadows = Lighting.GlobalShadows,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart
}

local camera = workspace.CurrentCamera
local followedPlayer = nil
local originalCameraSubject = nil
local cameraConnection = nil

local selectedFollowPlayer = nil
local followTpConnection = nil
local savedPosition = nil

local healthBillboards = {}
local nameBillboards = {}

local activeDropdowns = {}

-- Joke features variables
local spinConnection = nil
local bafConnection = nil
local comboConnection = nil
local bafDirection = 1
local bafTimer = 0

-- Disturb (Fling) variables
local flingThread = nil

-- Fling detection decal
if not ReplicatedStorage:FindFirstChild("juisdfj0i32i0eidsuf0iok") then
    local detection = Instance.new("Decal")
    detection.Name = "juisdfj0i32i0eidsuf0iok"
    detection.Parent = ReplicatedStorage
end

local function CloseAllDropdowns()
    for _, dropdown in pairs(activeDropdowns) do
        if dropdown and dropdown.container and dropdown.container.Visible then
            dropdown.container.Visible = false
        end
    end
end

local function Notify(text, color)
    if not States.ShowNotifications then return end
    color = color or COLORS.Accent
    local notif = Instance.new("Frame", ScreenGui)
    notif.Size = UDim2.new(0, 140, 0, 22)
    notif.Position = UDim2.new(0.5, -70, 0, 60)
    notif.BackgroundColor3 = COLORS.MainBG
    notif.BackgroundTransparency = 0.2
    Instance.new("UICorner", notif).CornerRadius = UDim.new(0, 5)
    local stroke = Instance.new("UIStroke", notif)
    stroke.Color = color
    stroke.Thickness = 1.2
    
    local label = Instance.new("TextLabel", notif)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.Font = "Gotham"
    label.TextSize = 9
    label.TextScaled = true
    
    notif:TweenPosition(UDim2.new(0.5, -70, 0, 30), "Out", "Quart", 0.25, true)
    task.wait(1.5)
    notif:TweenPosition(UDim2.new(0.5, -70, 0, -30), "Out", "Quart", 0.25, true)
    task.wait(0.25)
    notif:Destroy()
end

local function setupTapToIdentify()
    local mouse = player:GetMouse()
    mouse.Button1Down:Connect(function()
        if States.TapToIdentify then
            local target = mouse.Target
            if target then
                Notify("Object: " .. target.Name .. " (" .. target.ClassName .. ")", COLORS.Accent)
            end
        end
    end)
end

local antiAFKConnection = nil
local antiAFKLoop = nil

local function startAntiAFK()
    local VirtualUser = game:GetService("VirtualUser")
    if antiAFKConnection then antiAFKConnection:Disconnect() end
    if antiAFKLoop then task.cancel(antiAFKLoop) end
    
    antiAFKConnection = game:GetService("Players").LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
    
    antiAFKLoop = task.spawn(function()
        while States.AntiAFK and task.wait(50) do
            if States.AntiAFK then
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end
        end
    end)
end

local function setupTeleportClick()
    local mouse = player:GetMouse()
    mouse.Button1Down:Connect(function()
        if States.TeleportClick and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            player.Character.HumanoidRootPart.CFrame = CFrame.new(mouse.Hit.p)
            Notify("Teleported to point!", COLORS.Accent)
        end
    end)
end

local function teleportToObject(objectName)
    if not objectName or objectName == "" then
        Notify("Enter object name!", COLORS.Accent)
        return
    end
    
    local allObjects = {}
    local function searchObjects(container)
        for _, obj in pairs(container:GetChildren()) do
            if obj:IsA("BasePart") or obj:IsA("Model") then
                table.insert(allObjects, obj)
            end
            if #obj:GetChildren() > 0 then
                searchObjects(obj)
            end
        end
    end
    
    searchObjects(Workspace)
    
    local bestMatch = nil
    local bestDistance = math.huge
    local searchLower = string.lower(objectName)
    
    for _, obj in pairs(allObjects) do
        local objNameLower = string.lower(obj.Name)
        if objNameLower:find(searchLower) or searchLower:find(objNameLower) then
            local pos = obj:IsA("Model") and obj:FindFirstChild("HumanoidRootPart") and obj.HumanoidRootPart.Position or 
                       (obj:IsA("BasePart") and obj.Position or nil)
            if pos then
                local distance = (player.Character and player.Character:FindFirstChild("HumanoidRootPart") and 
                                 (player.Character.HumanoidRootPart.Position - pos).Magnitude) or 0
                if distance < bestDistance then
                    bestMatch = obj
                    bestDistance = distance
                end
            end
        end
    end
    
    if bestMatch and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local targetPos = bestMatch:IsA("Model") and bestMatch:FindFirstChild("HumanoidRootPart") and bestMatch.HumanoidRootPart.Position or
                         (bestMatch:IsA("BasePart") and bestMatch.Position or nil)
        if targetPos then
            player.Character.HumanoidRootPart.CFrame = CFrame.new(targetPos)
            Notify("Teleported to: " .. bestMatch.Name, COLORS.Accent)
        else
            Notify("Failed to get object position!", COLORS.Accent)
        end
    else
        Notify("Object not found: " .. objectName, COLORS.Accent)
    end
end

local function teleportToCoordinates(x, y, z)
    if not x or not y or not z then
        Notify("Enter all three coordinates!", COLORS.Accent)
        return
    end
    
    local numX = tonumber(x)
    local numY = tonumber(y)
    local numZ = tonumber(z)
    
    if numX and numY and numZ then
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            player.Character.HumanoidRootPart.CFrame = CFrame.new(numX, numY, numZ)
            Notify("Teleported to: " .. numX .. ", " .. numY .. ", " .. numZ, COLORS.Accent)
        end
    else
        Notify("Invalid coordinates!", COLORS.Accent)
    end
end

local function teleportToPlayer(targetPlayer)
    if not targetPlayer then
        Notify("Select a player!", COLORS.Accent)
        return
    end
    
    if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local targetPos = targetPlayer.Character.HumanoidRootPart.Position
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            player.Character.HumanoidRootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 2, 0))
            Notify("Teleported to: " .. targetPlayer.Name, COLORS.Accent)
        end
    else
        Notify("Player not found or not in game!", COLORS.Accent)
    end
end

local function setLighting(enabled)
    if enabled then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.Ambient = Color3.fromRGB(180, 180, 180)
        Lighting.ColorShift_Top = Color3.fromRGB(255, 255, 255)
        Lighting.ColorShift_Bottom = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)
        Lighting.ExposureCompensation = 1
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1000
        Lighting.FogStart = 0
        Notify("Light ON", COLORS.Accent)
    else
        Lighting.Brightness = originalLightingSettings.Brightness
        Lighting.ClockTime = originalLightingSettings.ClockTime
        Lighting.Ambient = originalLightingSettings.Ambient
        Lighting.ColorShift_Top = originalLightingSettings.ColorShift_Top
        Lighting.ColorShift_Bottom = originalLightingSettings.ColorShift_Bottom
        Lighting.OutdoorAmbient = originalLightingSettings.OutdoorAmbient
        Lighting.ExposureCompensation = originalLightingSettings.ExposureCompensation
        Lighting.GlobalShadows = originalLightingSettings.GlobalShadows
        Lighting.FogEnd = originalLightingSettings.FogEnd
        Lighting.FogStart = originalLightingSettings.FogStart
        Notify("Light OFF", COLORS.Accent)
    end
end

local function startFollowTP(playerToFollow)
    if followTpConnection then followTpConnection:Disconnect() end
    if not playerToFollow then return end
    followTpConnection = RunService.RenderStepped:Connect(function()
        if States.FollowTP and playerToFollow and playerToFollow.Character and playerToFollow.Character:FindFirstChild("HumanoidRootPart") then
            local targetPos = playerToFollow.Character.HumanoidRootPart.Position
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                player.Character.HumanoidRootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 2, 0))
            end
        end
    end)
end

local function stopFollowTP()
    if followTpConnection then
        followTpConnection:Disconnect()
        followTpConnection = nil
    end
end

local function startCameraFollow(targetPlayer)
    if cameraConnection then cameraConnection:Disconnect() end
    
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        Notify("Player not found or not in game!", COLORS.Accent)
        return false
    end
    
    if not originalCameraSubject then
        originalCameraSubject = camera.CameraSubject
    end
    
    followedPlayer = targetPlayer
    
    camera.CameraSubject = targetPlayer.Character.Humanoid
    camera.CameraType = Enum.CameraType.Custom
    
    cameraConnection = RunService.RenderStepped:Connect(function()
        if followedPlayer and followedPlayer.Character and followedPlayer.Character:FindFirstChild("HumanoidRootPart") then
            if camera.CameraSubject ~= followedPlayer.Character.Humanoid then
                camera.CameraSubject = followedPlayer.Character.Humanoid
            end
        else
            stopCameraFollow()
            Notify("Camera follow stopped - player left!", COLORS.Accent)
        end
    end)
    
    Notify("Camera now follows: " .. targetPlayer.Name, COLORS.Accent)
    return true
end

local function stopCameraFollow()
    if cameraConnection then
        cameraConnection:Disconnect()
        cameraConnection = nil
    end
    
    followedPlayer = nil
    
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        camera.CameraSubject = player.Character.Humanoid
    end
    camera.CameraType = Enum.CameraType.Custom
    
    Notify("Camera returned to you!", COLORS.Accent)
end

local function updateHealthESP()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("Head") then
            local head = p.Character.Head
            local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
            local bb = healthBillboards[p]
            
            if States.HealthESP and humanoid then
                local healthPercent = humanoid.Health / humanoid.MaxHealth
                local healthColor = Color3.fromRGB(255 - (255 * healthPercent), 255 * healthPercent, 0)
                
                if not bb or not bb.Parent then
                    bb = Instance.new("BillboardGui")
                    bb.Name = "HealthESP_BB"
                    bb.Size = UDim2.new(0, 60, 0, 15)
                    bb.Adornee = head
                    bb.AlwaysOnTop = true
                    bb.StudsOffset = Vector3.new(0, 2, 0)
                    
                    local healthBarBg = Instance.new("Frame", bb)
                    healthBarBg.Size = UDim2.new(1, 0, 1, 0)
                    healthBarBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                    healthBarBg.BackgroundTransparency = 0.5
                    Instance.new("UICorner", healthBarBg).CornerRadius = UDim.new(0, 2)
                    
                    local healthBar = Instance.new("Frame", healthBarBg)
                    healthBar.Name = "HealthBar"
                    healthBar.Size = UDim2.new(healthPercent, 0, 1, 0)
                    healthBar.BackgroundColor3 = healthColor
                    Instance.new("UICorner", healthBar).CornerRadius = UDim.new(0, 2)
                    
                    local healthText = Instance.new("TextLabel", bb)
                    healthText.Name = "HealthText"
                    healthText.Size = UDim2.new(1, 0, 1, 0)
                    healthText.BackgroundTransparency = 1
                    healthText.Text = math.floor(humanoid.Health) .. "/" .. humanoid.MaxHealth
                    healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
                    healthText.TextSize = 7
                    healthText.Font = Enum.Font.GothamBold
                    
                    bb.Parent = head
                    healthBillboards[p] = bb
                else
                    local healthBar = bb:FindFirstChild("HealthBarBg") and bb.HealthBarBg:FindFirstChild("HealthBar")
                    local healthText = bb:FindFirstChild("HealthText")
                    if healthBar then
                        healthBar.Size = UDim2.new(healthPercent, 0, 1, 0)
                        healthBar.BackgroundColor3 = healthColor
                    end
                    if healthText then
                        healthText.Text = math.floor(humanoid.Health) .. "/" .. humanoid.MaxHealth
                    end
                end
            else
                if bb then
                    bb:Destroy()
                    healthBillboards[p] = nil
                end
            end
        end
    end
end

local function updateNameESP()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("Head") then
            local head = p.Character.Head
            local bb = nameBillboards[p]
            if States.NameESP then
                if not bb or not bb.Parent then
                    bb = Instance.new("BillboardGui")
                    bb.Name = "NameESP_BB"
                    bb.Size = UDim2.new(0, 80, 0, 16)
                    bb.Adornee = head
                    bb.AlwaysOnTop = true
                    bb.StudsOffset = Vector3.new(0, 1.8, 0)
                    local text = Instance.new("TextLabel", bb)
                    text.Size = UDim2.new(1, 0, 1, 0)
                    text.BackgroundTransparency = 1
                    text.Text = p.Name
                    text.TextColor3 = NAME_ESP_COLORS[States.NameESPColorIndex]
                    text.Font = Enum.Font.GothamBold
                    text.TextSize = 8
                    bb.Parent = head
                    nameBillboards[p] = bb
                end
            else
                if bb then
                    bb:Destroy()
                    nameBillboards[p] = nil
                end
            end
        end
    end
end

-- ================= OBJECT HIGHLIGHTER SYSTEM =================
local highlightedObjects = {}
local objectHighlightConnection = nil
local highlightSearchTerm = ""

local function clearObjectHighlights()
    for obj, highlight in pairs(highlightedObjects) do
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end
    highlightedObjects = {}
end

local function findAndHighlightObjects(searchTerm)
    clearObjectHighlights()
    
    if not States.ObjectHighlighter or searchTerm == "" then
        return
    end
    
    local searchLower = string.lower(searchTerm)
    local allParts = {}
    
    local function searchForParts(container)
        for _, obj in pairs(container:GetChildren()) do
            if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
                table.insert(allParts, obj)
            elseif obj:IsA("Model") then
                searchForParts(obj)
            end
        end
    end
    
    searchForParts(Workspace)
    
    local highlightedCount = 0
    
    for _, part in pairs(allParts) do
        local partNameLower = string.lower(part.Name)
        if partNameLower:find(searchLower) then
            local highlight = Instance.new("Highlight")
            highlight.Name = "ObjectHighlighter"
            highlight.Adornee = part
            highlight.FillColor = HIGHLIGHT_COLORS[States.HighlightColorIndex]
            highlight.FillTransparency = 0.3
            highlight.OutlineColor = HIGHLIGHT_COLORS[States.HighlightColorIndex]
            highlight.OutlineTransparency = 0
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Parent = part
            
            highlightedObjects[part] = highlight
            highlightedCount = highlightedCount + 1
        end
    end
    
    if highlightedCount > 0 then
        Notify("Highlighted " .. highlightedCount .. " objects matching '" .. searchTerm .. "'", COLORS.Accent)
    else
        Notify("No objects found matching '" .. searchTerm .. "'", Color3.fromRGB(255, 100, 100))
    end
end

local function startObjectHighlighter(searchTerm)
    if objectHighlightConnection then
        objectHighlightConnection:Disconnect()
        objectHighlightConnection = nil
    end
    
    findAndHighlightObjects(searchTerm)
    
    objectHighlightConnection = Workspace.DescendantAdded:Connect(function(descendant)
        if States.ObjectHighlighter and highlightSearchTerm ~= "" then
            if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
                local searchLower = string.lower(highlightSearchTerm)
                local nameLower = string.lower(descendant.Name)
                if nameLower:find(searchLower) then
                    local highlight = Instance.new("Highlight")
                    highlight.Name = "ObjectHighlighter"
                    highlight.Adornee = descendant
                    highlight.FillColor = HIGHLIGHT_COLORS[States.HighlightColorIndex]
                    highlight.FillTransparency = 0.3
                    highlight.OutlineColor = HIGHLIGHT_COLORS[States.HighlightColorIndex]
                    highlight.OutlineTransparency = 0
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.Parent = descendant
                    highlightedObjects[descendant] = highlight
                end
            end
        end
    end)
end

local function stopObjectHighlighter()
    if objectHighlightConnection then
        objectHighlightConnection:Disconnect()
        objectHighlightConnection = nil
    end
    clearObjectHighlights()
end

local function updateHighlighterColor()
    if States.ObjectHighlighter then
        for obj, highlight in pairs(highlightedObjects) do
            if highlight and highlight.Parent then
                highlight.FillColor = HIGHLIGHT_COLORS[States.HighlightColorIndex]
                highlight.OutlineColor = HIGHLIGHT_COLORS[States.HighlightColorIndex]
            end
        end
    end
end

-- ================= JOKE FEATURES =================

local function startSpin()
    if spinConnection then spinConnection:Disconnect() end
    
    if not States.Spin then return end
    
    if not States.SpinAxisX and not States.SpinAxisY and not States.SpinAxisZ then
        Notify("Select at least one axis for spin!", COLORS.Accent)
        States.Spin = false
        return
    end
    
    spinConnection = RunService.RenderStepped:Connect(function(deltaTime)
        if not States.Spin or not player.Character then
            return
        end
        
        local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end
        
        local rotationSpeed = 720
        local rotationDelta = rotationSpeed * deltaTime
        
        local cframe = rootPart.CFrame
        local angles = Vector3.new(0, 0, 0)
        
        if States.SpinAxisX then angles = angles + Vector3.new(rotationDelta, 0, 0) end
        if States.SpinAxisY then angles = angles + Vector3.new(0, rotationDelta, 0) end
        if States.SpinAxisZ then angles = angles + Vector3.new(0, 0, rotationDelta) end
        
        local newCFrame = cframe
        if angles.X ~= 0 then newCFrame = newCFrame * CFrame.Angles(math.rad(angles.X), 0, 0) end
        if angles.Y ~= 0 then newCFrame = newCFrame * CFrame.Angles(0, math.rad(angles.Y), 0) end
        if angles.Z ~= 0 then newCFrame = newCFrame * CFrame.Angles(0, 0, math.rad(angles.Z)) end
        
        rootPart.CFrame = newCFrame
    end)
end

local function stopSpin()
    if spinConnection then
        spinConnection:Disconnect()
        spinConnection = nil
    end
end

local function startBAF()
    if bafConnection then bafConnection:Disconnect() end
    
    if not States.BAF then return end
    
    bafDirection = 1
    bafTimer = 0
    
    bafConnection = RunService.RenderStepped:Connect(function(deltaTime)
        if not States.BAF or not player.Character then
            return
        end
        
        local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end
        
        local cycleTime = 0.1
        local moveDistance = 2
        
        bafTimer = bafTimer + deltaTime
        if bafTimer >= cycleTime then
            bafTimer = bafTimer - cycleTime
            bafDirection = bafDirection * -1
        end
        
        local t = bafTimer / cycleTime
        local offset = moveDistance * (bafDirection == 1 and t or (1 - t))
        
        local currentPos = rootPart.Position
        local forwardVector = rootPart.CFrame.LookVector
        local newPos = currentPos + forwardVector * offset
        
        rootPart.CFrame = CFrame.new(newPos) * rootPart.CFrame.Rotation
    end)
end

local function stopBAF()
    if bafConnection then
        bafConnection:Disconnect()
        bafConnection = nil
    end
end

local function startCombo()
    if comboConnection then comboConnection:Disconnect() end
    
    if not States.Combo then return end
    
    if not States.SpinAxisX and not States.SpinAxisY and not States.SpinAxisZ then
        Notify("Select at least one axis for combo spin!", COLORS.Accent)
        States.Combo = false
        return
    end
    
    bafDirection = 1
    bafTimer = 0
    
    comboConnection = RunService.RenderStepped:Connect(function(deltaTime)
        if not States.Combo or not player.Character then
            return
        end
        
        local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end
        
        local rotationSpeed = 720
        local rotationDelta = rotationSpeed * deltaTime
        
        local cframe = rootPart.CFrame
        local angles = Vector3.new(0, 0, 0)
        
        if States.SpinAxisX then angles = angles + Vector3.new(rotationDelta, 0, 0) end
        if States.SpinAxisY then angles = angles + Vector3.new(0, rotationDelta, 0) end
        if States.SpinAxisZ then angles = angles + Vector3.new(0, 0, rotationDelta) end
        
        local newCFrame = cframe
        if angles.X ~= 0 then newCFrame = newCFrame * CFrame.Angles(math.rad(angles.X), 0, 0) end
        if angles.Y ~= 0 then newCFrame = newCFrame * CFrame.Angles(0, math.rad(angles.Y), 0) end
        if angles.Z ~= 0 then newCFrame = newCFrame * CFrame.Angles(0, 0, math.rad(angles.Z)) end
        
        local cycleTime = 0.1
        local moveDistance = 2
        
        bafTimer = bafTimer + deltaTime
        if bafTimer >= cycleTime then
            bafTimer = bafTimer - cycleTime
            bafDirection = bafDirection * -1
        end
        
        local t = bafTimer / cycleTime
        local offset = moveDistance * (bafDirection == 1 and t or (1 - t))
        
        local forwardVector = newCFrame.LookVector
        local newPos = rootPart.Position + forwardVector * offset
        
        rootPart.CFrame = CFrame.new(newPos) * newCFrame.Rotation
    end)
end

local function stopCombo()
    if comboConnection then
        comboConnection:Disconnect()
        comboConnection = nil
    end
end

local function stopAllJokeFeatures()
    States.Spin = false
    States.BAF = false
    States.Combo = false
    stopSpin()
    stopBAF()
    stopCombo()
end

-- ================= DISTURB (FLING) FEATURES =================

local function flingLoop()
    local hrp, c, vel, movel = nil, nil, nil, 0.1
    
    while States.Fling do
        RunService.Heartbeat:Wait()
        
        if States.Fling then
            while States.Fling and not (c and c.Parent and hrp and hrp.Parent) do
                RunService.Heartbeat:Wait()
                c = player.Character
                hrp = c and c:FindFirstChild("HumanoidRootPart")
            end
            
            if States.Fling and c and c.Parent and hrp and hrp.Parent then
                vel = hrp.Velocity
                hrp.Velocity = vel * States.FlingPower + Vector3.new(0, States.FlingPower, 0)
                RunService.RenderStepped:Wait()
                
                if c and c.Parent and hrp and hrp.Parent then
                    hrp.Velocity = vel
                end
                
                RunService.Stepped:Wait()
                
                if c and c.Parent and hrp and hrp.Parent then
                    hrp.Velocity = vel + Vector3.new(0, movel, 0)
                    movel = movel * -1
                end
            end
        end
    end
end

local function startFling()
    if flingThread then
        States.Fling = false
        task.cancel(flingThread)
        flingThread = nil
    end
    
    States.Fling = true
    flingThread = task.spawn(flingLoop)
    Notify("Fling ON - Power: " .. States.FlingPower, COLORS.Accent)
end

local function stopFling()
    States.Fling = false
    if flingThread then
        task.cancel(flingThread)
        flingThread = nil
    end
    
    -- === FIX: Сброс скорости при выключении ===
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.Velocity = Vector3.new(0, 0, 0)  -- Полный сброс скорости
        -- Дополнительно: сброс угловой скорости
        hrp.RotVelocity = Vector3.new(0, 0, 0)
    end
    -- ========================================
    
    Notify("Fling OFF", COLORS.Accent)
end

local function makeDraggable(obj, parent)
    local dragging, dragStart, startPos
    obj.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = parent.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            parent.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local OpenBtn = Instance.new("TextButton", ScreenGui)
OpenBtn.Size = UDim2.new(0, 32, 0, 32)
OpenBtn.Position = UDim2.new(0, 12, 0.5, -16)
OpenBtn.BackgroundColor3 = COLORS.MainBG
OpenBtn.Text = "M"
OpenBtn.TextColor3 = COLORS.Accent
OpenBtn.Font = Enum.Font.GothamBold
OpenBtn.TextSize = 18
OpenBtn.AutoButtonColor = false
Instance.new("UICorner", OpenBtn).CornerRadius = UDim.new(0, 8)

local OpenBtnStroke = Instance.new("UIStroke", OpenBtn)
OpenBtnStroke.Color = COLORS.Accent
OpenBtnStroke.Thickness = 1.5
OpenBtnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

makeDraggable(OpenBtn, OpenBtn)

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 0, 0, 0)
MainFrame.Position = UDim2.new(0.5, -130, 0.5, -140)
MainFrame.BackgroundColor3 = COLORS.MainBG
MainFrame.Visible = false
MainFrame.ClipsDescendants = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local MainFrameStroke = Instance.new("UIStroke", MainFrame)
MainFrameStroke.Color = COLORS.Accent
MainFrameStroke.Thickness = 1.2
MainFrameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local Header = Instance.new("Frame", MainFrame)
Header.Size = UDim2.new(1, 0, 0, 24)
Header.BackgroundTransparency = 1
makeDraggable(Header, MainFrame)

local Title = Instance.new("TextLabel", Header)
Title.Text = "MORPH CHEAT"
Title.Size = UDim2.new(1, -60, 1, 0)
Title.Position = UDim2.new(0, 8, 0, 0)
Title.BackgroundTransparency = 1
Title.TextColor3 = COLORS.Accent
Title.Font = "GothamBold"
Title.TextSize = 10
Title.TextXAlignment = "Left"

local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Size = UDim2.new(0, 22, 0, 22)
CloseBtn.Position = UDim2.new(1, -26, 0, 1)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "x"
CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
CloseBtn.TextSize = 14

local MinBtn = Instance.new("TextButton", Header)
MinBtn.Size = UDim2.new(0, 22, 0, 22)
MinBtn.Position = UDim2.new(1, -48, 0, 1)
MinBtn.BackgroundTransparency = 1
MinBtn.Text = "-"
MinBtn.TextColor3 = COLORS.Text
MinBtn.TextSize = 14

local Sidebar = Instance.new("Frame", MainFrame)
Sidebar.Size = UDim2.new(0, 65, 1, -32)
Sidebar.Position = UDim2.new(0, 6, 0, 28)
Sidebar.BackgroundColor3 = COLORS.SideBG
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 8)

local SidebarLayout = Instance.new("UIListLayout", Sidebar)
SidebarLayout.Padding = UDim.new(0, 4)
SidebarLayout.HorizontalAlignment = "Center"

local Content = Instance.new("Frame", MainFrame)
Content.Size = UDim2.new(1, -80, 1, -32)
Content.Position = UDim2.new(0, 72, 0, 28)
Content.BackgroundTransparency = 1

local Pages = {}
local TabBtns = {}

local function CreatePage(name, order)
    local scrollFrame = Instance.new("ScrollingFrame", Content)
    scrollFrame.Size = UDim2.new(1, -4, 1, -4)
    scrollFrame.Position = UDim2.new(0, 0, 0, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 3
    scrollFrame.ScrollBarImageColor3 = COLORS.Accent
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.Visible = (order == 1)
    scrollFrame.ZIndex = 1
    
    local listLayout = Instance.new("UIListLayout", scrollFrame)
    listLayout.Padding = UDim.new(0, 4)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local function updateCanvas()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 8)
    end
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
    task.wait()
    updateCanvas()
    
    Pages[name] = scrollFrame
    
    local btn = Instance.new("TextButton", Sidebar)
    btn.Size = UDim2.new(0.85, 0, 0, 26)
    btn.BackgroundColor3 = (order == 1) and Color3.fromRGB(30, 60, 65) or COLORS.Inactive
    btn.Text = name
    btn.TextColor3 = COLORS.Text
    btn.Font = "GothamSemibold"
    btn.TextSize = 9
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    TabBtns[name] = btn
    
    btn.MouseButton1Click:Connect(function()
        CloseAllDropdowns()
        for n, pg in pairs(Pages) do
            pg.Visible = (n == name)
            TabBtns[n].BackgroundColor3 = (n == name) and Color3.fromRGB(30, 60, 65) or COLORS.Inactive
        end
    end)
end

CreatePage("Player", 1)
CreatePage("Visual", 2)
CreatePage("Tools", 3)
CreatePage("Global", 4)
CreatePage("Joke", 5)
CreatePage("Disturb", 6)

local function CreateToggle(parent, text, key, order, colorVar, colorIndexVar, colorList)
    local bgColor = GetRowColor(order)
    
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, 0, 0, 26)
    frame.BackgroundColor3 = bgColor
    frame.BackgroundTransparency = 0
    frame.LayoutOrder = order
    frame.ZIndex = 1
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 3)
    
    local label = Instance.new("TextLabel", frame)
    label.Text = text
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Position = UDim2.new(0, 6, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = COLORS.Text
    label.Font = "Gotham"
    label.TextSize = 9
    label.TextXAlignment = "Left"
    label.ZIndex = 1
    
    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(0, 24, 0, 13)
    btn.Position = UDim2.new(1, -70, 0.5, -6.5)
    btn.BackgroundColor3 = COLORS.Inactive
    btn.Text = ""
    btn.ZIndex = 1
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
    
    local circle = Instance.new("Frame", btn)
    circle.Size = UDim2.new(0, 9, 0, 9)
    circle.Position = UDim2.new(0, 2, 0.5, -4.5)
    circle.BackgroundColor3 = COLORS.Text
    circle.ZIndex = 1
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
    
    local colorBox = Instance.new("TextButton", frame)
    colorBox.Size = UDim2.new(0, 16, 0, 16)
    colorBox.Position = UDim2.new(1, -38, 0.15, 0)
    colorBox.BackgroundColor3 = colorList and colorList[1] or COLORS.Accent
    colorBox.Text = ""
    colorBox.Visible = (colorVar ~= nil)
    colorBox.ZIndex = 1
    Instance.new("UICorner", colorBox).CornerRadius = UDim.new(0, 3)
    
    if colorVar and colorList then
        colorBox.MouseButton1Click:Connect(function()
            States[colorIndexVar] = (States[colorIndexVar] % #colorList) + 1
            colorBox.BackgroundColor3 = colorList[States[colorIndexVar]]
            Notify(text .. " color changed!", COLORS.Accent)
            if key == "ObjectHighlighter" and States.ObjectHighlighter then
                updateHighlighterColor()
            end
        end)
    end
    
    local function update()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = States[key] and COLORS.Accent or COLORS.Inactive}):Play()
        TweenService:Create(circle, TweenInfo.new(0.2), {Position = States[key] and UDim2.new(1, -13, 0.5, -4.5) or UDim2.new(0, 2, 0.5, -4.5)}):Play()
    end
    
    btn.MouseButton1Click:Connect(function()
        States[key] = not States[key]
        update()
        
        if key == "Spin" then
            if States.Spin then
                if not States.SpinAxisX and not States.SpinAxisY and not States.SpinAxisZ then
                    Notify("Select at least one axis for spin!", COLORS.Accent)
                    States.Spin = false
                    update()
                    return
                end
                if States.BAF then
                    States.BAF = false
                    stopBAF()
                end
                if States.Combo then
                    States.Combo = false
                    stopCombo()
                end
                if States.Fling then
                    States.Fling = false
                    stopFling()
                end
                startSpin()
                Notify(text .. " ON - Spinning!", COLORS.Accent)
            else
                stopSpin()
                Notify(text .. " OFF", COLORS.Accent)
            end
        elseif key == "BAF" then
            if States.BAF then
                if States.Spin then
                    States.Spin = false
                    stopSpin()
                end
                if States.Combo then
                    States.Combo = false
                    stopCombo()
                end
                if States.Fling then
                    States.Fling = false
                    stopFling()
                end
                startBAF()
                Notify(text .. " ON - Back and Forth!", COLORS.Accent)
            else
                stopBAF()
                Notify(text .. " OFF", COLORS.Accent)
            end
        elseif key == "Combo" then
            if States.Combo then
                if not States.SpinAxisX and not States.SpinAxisY and not States.SpinAxisZ then
                    Notify("Select at least one axis for combo spin!", COLORS.Accent)
                    States.Combo = false
                    update()
                    return
                end
                if States.Spin then
                    States.Spin = false
                    stopSpin()
                end
                if States.BAF then
                    States.BAF = false
                    stopBAF()
                end
                if States.Fling then
                    States.Fling = false
                    stopFling()
                end
                startCombo()
                Notify(text .. " ON - Spinning + Back and Forth!", COLORS.Accent)
            else
                stopCombo()
                Notify(text .. " OFF", COLORS.Accent)
            end
        elseif key == "Fling" then
            if States.Fling then
                if States.Spin then
                    States.Spin = false
                    stopSpin()
                end
                if States.BAF then
                    States.BAF = false
                    stopBAF()
                end
                if States.Combo then
                    States.Combo = false
                    stopCombo()
                end
                startFling()
            else
                stopFling()
            end
        elseif key == "AntiAFK" and States.AntiAFK then
            startAntiAFK()
        elseif key == "Light" then
            setLighting(States.Light)
        elseif key == "FollowTP" then
            if States.FollowTP and selectedFollowPlayer then
                startFollowTP(selectedFollowPlayer)
                Notify("Follow TP: Following " .. selectedFollowPlayer.Name, COLORS.Accent)
            elseif not States.FollowTP then
                stopFollowTP()
                Notify("Follow TP: Stopped", COLORS.Accent)
            end
        elseif key == "ObjectHighlighter" then
            if States.ObjectHighlighter and highlightSearchTerm ~= "" then
                startObjectHighlighter(highlightSearchTerm)
            else
                stopObjectHighlighter()
            end
            Notify(text .. (States[key] and " ON" or " OFF"), COLORS.Accent)
        else
            Notify(text .. (States[key] and " ON" or " OFF"), COLORS.Accent)
        end
    end)
    
    return update, colorBox
end

local function CreateAxisToggle(parent, text, key, order)
    local bgColor = GetRowColor(order)
    
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, 0, 0, 26)
    frame.BackgroundColor3 = bgColor
    frame.BackgroundTransparency = 0
    frame.LayoutOrder = order
    frame.ZIndex = 1
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 3)
    
    local label = Instance.new("TextLabel", frame)
    label.Text = text
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Position = UDim2.new(0, 6, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = COLORS.Text
    label.Font = "Gotham"
    label.TextSize = 9
    label.TextXAlignment = "Left"
    label.ZIndex = 1
    
    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(0, 24, 0, 13)
    btn.Position = UDim2.new(1, -12, 0.5, -6.5)
    btn.BackgroundColor3 = COLORS.Inactive
    btn.Text = ""
    btn.ZIndex = 1
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
    
    local circle = Instance.new("Frame", btn)
    circle.Size = UDim2.new(0, 9, 0, 9)
    circle.Position = UDim2.new(0, 2, 0.5, -4.5)
    circle.BackgroundColor3 = COLORS.Text
    circle.ZIndex = 1
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
    
    local function update()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = States[key] and COLORS.Accent or COLORS.Inactive}):Play()
        TweenService:Create(circle, TweenInfo.new(0.2), {Position = States[key] and UDim2.new(1, -13, 0.5, -4.5) or UDim2.new(0, 2, 0.5, -4.5)}):Play()
    end
    
    btn.MouseButton1Click:Connect(function()
        States[key] = not States[key]
        update()
        
        if States.Spin and key ~= "Spin" then
            if not States.SpinAxisX and not States.SpinAxisY and not States.SpinAxisZ then
                States.Spin = false
                stopSpin()
                Notify("Spin stopped - no axes selected!", COLORS.Accent)
                for _, child in pairs(Pages.Joke:GetChildren()) do
                    if child:IsA("Frame") and child:FindFirstChildOfClass("TextLabel") and child:FindFirstChildOfClass("TextLabel").Text == "Spin" then
                        local spinBtn = child:FindFirstChildOfClass("TextButton")
                        if spinBtn then
                            TweenService:Create(spinBtn, TweenInfo.new(0.2), {BackgroundColor3 = COLORS.Inactive}):Play()
                            local spinCircle = spinBtn:FindFirstChildOfClass("Frame")
                            if spinCircle then
                                TweenService:Create(spinCircle, TweenInfo.new(0.2), {Position = UDim2.new(0, 2, 0.5, -4.5)}):Play()
                            end
                        end
                        break
                    end
                end
            end
        end
        
        if States.Combo and key ~= "Combo" then
            if not States.SpinAxisX and not States.SpinAxisY and not States.SpinAxisZ then
                States.Combo = false
                stopCombo()
                Notify("Combo stopped - no axes selected!", COLORS.Accent)
                for _, child in pairs(Pages.Joke:GetChildren()) do
                    if child:IsA("Frame") and child:FindFirstChildOfClass("TextLabel") and child:FindFirstChildOfClass("TextLabel").Text == "Combo" then
                        local comboBtn = child:FindFirstChildOfClass("TextButton")
                        if comboBtn then
                            TweenService:Create(comboBtn, TweenInfo.new(0.2), {BackgroundColor3 = COLORS.Inactive}):Play()
                            local comboCircle = comboBtn:FindFirstChildOfClass("Frame")
                            if comboCircle then
                                TweenService:Create(comboCircle, TweenInfo.new(0.2), {Position = UDim2.new(0, 2, 0.5, -4.5)}):Play()
                            end
                        end
                        break
                    end
                end
            end
        end
        
        Notify(text .. (States[key] and " ON" or " OFF"), COLORS.Accent)
    end)
    
    return update
end

local function CreateButton(parent, text, order, callback)
    local bgColor = GetRowColor(order)
    
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, 0, 0, 26)
    btn.BackgroundColor3 = bgColor
    btn.Text = text
    btn.TextColor3 = COLORS.Accent
    btn.Font = "GothamBold"
    btn.TextSize = 9
    btn.LayoutOrder = order
    btn.ZIndex = 1
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
    
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function CreateInputRow(parent, labelText, placeholder, defaultValue, order, callback)
    local bgColor = GetRowColor(order)
    
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, 0, 0, 40)
    frame.BackgroundColor3 = bgColor
    frame.BackgroundTransparency = 0
    frame.LayoutOrder = order
    frame.ZIndex = 1
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 3)
    
    local label = Instance.new("TextLabel", frame)
    label.Text = labelText
    label.Size = UDim2.new(1, 0, 0, 14)
    label.Position = UDim2.new(0, 6, 0, 3)
    label.BackgroundTransparency = 1
    label.TextColor3 = COLORS.Text
    label.Font = "Gotham"
    label.TextSize = 8
    label.TextXAlignment = "Left"
    label.ZIndex = 1
    
    local input = Instance.new("TextBox", frame)
    input.Size = UDim2.new(1, -12, 0, 20)
    input.Position = UDim2.new(0, 6, 0, 18)
    input.BackgroundColor3 = COLORS.SideBG
    input.PlaceholderText = placeholder
    input.Text = defaultValue or ""
    input.TextColor3 = COLORS.Text
    input.TextSize = 9
    input.ZIndex = 1
    Instance.new("UICorner", input).CornerRadius = UDim.new(0, 3)
    
    if callback then
        input.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                callback(input.Text)
            end
        end)
    end
    
    return input
end

local function CreateDropdown(parent, labelText, order, onSelect)
    local bgColor = GetRowColor(order)
    
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, 0, 0, 44)
    frame.BackgroundColor3 = bgColor
    frame.BackgroundTransparency = 0
    frame.LayoutOrder = order
    frame.ZIndex = 10
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 3)
    
    local label = Instance.new("TextLabel", frame)
    label.Text = labelText
    label.Size = UDim2.new(1, -8, 0, 14)
    label.Position = UDim2.new(0, 6, 0, 3)
    label.BackgroundTransparency = 1
    label.TextColor3 = COLORS.Text
    label.Font = "Gotham"
    label.TextSize = 8
    label.TextXAlignment = "Left"
    label.ZIndex = 10
    
    local button = Instance.new("TextButton", frame)
    button.Size = UDim2.new(1, -12, 0, 20)
    button.Position = UDim2.new(0, 6, 0, 20)
    button.BackgroundColor3 = COLORS.SideBG
    button.Text = "Select player"
    button.TextColor3 = COLORS.Text
    button.Font = "Gotham"
    button.TextSize = 9
    button.ZIndex = 10
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 3)
    
    local listContainer = Instance.new("Frame", ScreenGui)
    listContainer.Size = UDim2.new(0, 150, 0, 0)
    listContainer.Position = UDim2.new(0, 0, 0, 0)
    listContainer.BackgroundColor3 = COLORS.SideBG
    listContainer.BorderSizePixel = 0
    listContainer.Visible = false
    listContainer.ZIndex = 100
    Instance.new("UICorner", listContainer).CornerRadius = UDim.new(0, 5)
    
    local listScroll = Instance.new("ScrollingFrame", listContainer)
    listScroll.Size = UDim2.new(1, 0, 1, -4)
    listScroll.Position = UDim2.new(0, 0, 0, 2)
    listScroll.BackgroundTransparency = 1
    listScroll.BorderSizePixel = 0
    listScroll.ScrollBarThickness = 3
    listScroll.ScrollBarImageColor3 = COLORS.Accent
    listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    listScroll.ZIndex = 100
    
    local listLayout = Instance.new("UIListLayout", listScroll)
    listLayout.Padding = UDim.new(0, 2)
    
    local dropdownData = {button = button, frame = frame, container = listContainer}
    table.insert(activeDropdowns, dropdownData)
    
    local function updateList()
        for _, v in pairs(listScroll:GetChildren()) do
            if v:IsA("TextButton") then v:Destroy() end
        end
        
        local players = {}
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player then
                table.insert(players, p.Name)
            end
        end
        
        if #players == 0 then
            table.insert(players, "No players")
        end
        
        for _, name in pairs(players) do
            local btn = Instance.new("TextButton", listScroll)
            btn.Size = UDim2.new(1, -4, 0, 22)
            btn.Position = UDim2.new(0, 2, 0, 0)
            btn.Text = name
            btn.BackgroundColor3 = COLORS.Inactive
            btn.TextColor3 = COLORS.Text
            btn.Font = "Gotham"
            btn.TextSize = 9
            btn.ZIndex = 100
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
            
            if name ~= "No players" then
                btn.MouseButton1Click:Connect(function()
                    button.Text = name
                    listContainer.Visible = false
                    if onSelect then
                        for _, p in pairs(Players:GetPlayers()) do
                            if p.Name == name then
                                onSelect(p)
                                break
                            end
                        end
                    end
                end)
            end
        end
        
        task.wait()
        local contentHeight = #players * 24 + 4
        listScroll.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
        local listHeight = math.min(contentHeight, 130)
        listContainer.Size = UDim2.new(0, 150, 0, listHeight)
    end
    
    button.MouseButton1Click:Connect(function()
        CloseAllDropdowns()
        updateList()
        local absPos = button.AbsolutePosition
        listContainer.Position = UDim2.new(0, absPos.X, 0, absPos.Y + button.AbsoluteSize.Y)
        listContainer.Visible = true
        
        local function closeOnClick(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local mousePos = Vector2.new(input.Position.X, input.Position.Y)
                if not (mousePos.X >= absPos.X and mousePos.X <= absPos.X + button.AbsoluteSize.X and
                        mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + button.AbsoluteSize.Y) then
                    if listContainer.Visible then
                        listContainer.Visible = false
                        UserInputService.InputBegan:Disconnect(closeOnClick)
                    end
                end
            end
        end
        UserInputService.InputBegan:Connect(closeOnClick)
    end)
    
    return dropdownData
end

-- ============ PLAYER TAB ============
local rowOrder = 1

local u1, _ = CreateToggle(Pages.Player, "Inf Jump", "InfJump", rowOrder); rowOrder = rowOrder + 1
local u2, _ = CreateToggle(Pages.Player, "No Clip", "NoClip", rowOrder); rowOrder = rowOrder + 1
local u3, _ = CreateToggle(Pages.Player, "TP on Click", "TeleportClick", rowOrder); rowOrder = rowOrder + 1
local u4, _ = CreateToggle(Pages.Player, "Anti AFK", "AntiAFK", rowOrder); rowOrder = rowOrder + 1

local speedInput = CreateInputRow(Pages.Player, "Player Speed", "Speed value", "16", rowOrder, function(value)
    local newSpeed = tonumber(value) or 16
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid.WalkSpeed = newSpeed
        Notify("Speed: " .. newSpeed, COLORS.Accent)
    end
end)
rowOrder = rowOrder + 1

local objectInput = CreateInputRow(Pages.Player, "TP to Object", "Object name", "", rowOrder, nil)
rowOrder = rowOrder + 1

local tpObjectBtn = CreateButton(Pages.Player, "Teleport to Object", rowOrder, function()
    teleportToObject(objectInput.Text)
end)
rowOrder = rowOrder + 1

local CoordsFrame = Instance.new("Frame", Pages.Player)
CoordsFrame.Size = UDim2.new(1, 0, 0, 68)
CoordsFrame.BackgroundColor3 = GetRowColor(rowOrder)
CoordsFrame.BackgroundTransparency = 0
CoordsFrame.LayoutOrder = rowOrder; rowOrder = rowOrder + 1
Instance.new("UICorner", CoordsFrame).CornerRadius = UDim.new(0, 3)

local CoordsLabel = Instance.new("TextLabel", CoordsFrame)
CoordsLabel.Text = "TP to XYZ"
CoordsLabel.Size = UDim2.new(1, -8, 0, 14)
CoordsLabel.Position = UDim2.new(0, 6, 0, 3)
CoordsLabel.BackgroundTransparency = 1
CoordsLabel.TextColor3 = COLORS.Text
CoordsLabel.Font = "Gotham"
CoordsLabel.TextSize = 8
CoordsLabel.TextXAlignment = "Left"

local CoordX = Instance.new("TextBox", CoordsFrame)
CoordX.Size = UDim2.new(0.3, -3, 0, 20)
CoordX.Position = UDim2.new(0, 6, 0, 18)
CoordX.BackgroundColor3 = COLORS.SideBG
CoordX.PlaceholderText = "X"
CoordX.Text = ""
CoordX.TextColor3 = COLORS.Text
CoordX.TextSize = 9
Instance.new("UICorner", CoordX).CornerRadius = UDim.new(0, 3)

local CoordY = Instance.new("TextBox", CoordsFrame)
CoordY.Size = UDim2.new(0.3, -3, 0, 20)
CoordY.Position = UDim2.new(0.35, 3, 0, 18)
CoordY.BackgroundColor3 = COLORS.SideBG
CoordY.PlaceholderText = "Y"
CoordY.Text = ""
CoordY.TextColor3 = COLORS.Text
CoordY.TextSize = 9
Instance.new("UICorner", CoordY).CornerRadius = UDim.new(0, 3)

local CoordZ = Instance.new("TextBox", CoordsFrame)
CoordZ.Size = UDim2.new(0.3, -3, 0, 20)
CoordZ.Position = UDim2.new(0.7, 0, 0, 18)
CoordZ.BackgroundColor3 = COLORS.SideBG
CoordZ.PlaceholderText = "Z"
CoordZ.Text = ""
CoordZ.TextColor3 = COLORS.Text
CoordZ.TextSize = 9
Instance.new("UICorner", CoordZ).CornerRadius = UDim.new(0, 3)

local CoordTPBtn = Instance.new("TextButton", CoordsFrame)
CoordTPBtn.Size = UDim2.new(1, -12, 0, 20)
CoordTPBtn.Position = UDim2.new(0, 6, 0, 44)
CoordTPBtn.BackgroundColor3 = COLORS.Accent
CoordTPBtn.Text = "TP"
CoordTPBtn.TextColor3 = COLORS.MainBG
CoordTPBtn.Font = "GothamBold"
CoordTPBtn.TextSize = 9
Instance.new("UICorner", CoordTPBtn).CornerRadius = UDim.new(0, 3)

CoordTPBtn.MouseButton1Click:Connect(function()
    teleportToCoordinates(CoordX.Text, CoordY.Text, CoordZ.Text)
end)

local tpToPlayerDropdown = CreateDropdown(Pages.Player, "TP to Player", rowOrder, function(selected)
    teleportToPlayer(selected)
end)
rowOrder = rowOrder + 1

local followTPDropdown = CreateDropdown(Pages.Player, "Follow TP to Player", rowOrder, function(selected)
    selectedFollowPlayer = selected
    if States.FollowTP then
        startFollowTP(selected)
        Notify("Follow TP: Following " .. selected.Name, COLORS.Accent)
    end
end)
rowOrder = rowOrder + 1

local u5, _ = CreateToggle(Pages.Player, "Follow TP Active", "FollowTP", rowOrder)
rowOrder = rowOrder + 1

local cameraDropdown = CreateDropdown(Pages.Player, "Camera to Player", rowOrder, function(selected)
    startCameraFollow(selected)
end)
rowOrder = rowOrder + 1

local returnCameraBtn = CreateButton(Pages.Player, "Return Camera", rowOrder, function()
    stopCameraFollow()
end)
rowOrder = rowOrder + 1

-- ============ VISUAL TAB ============
rowOrder = 1
local v1, espColorBox = CreateToggle(Pages.Visual, "Player ESP", "ESP", rowOrder, true, "ESPColorIndex", ESP_COLORS); rowOrder = rowOrder + 1
local v2, nameColorBox = CreateToggle(Pages.Visual, "Name ESP", "NameESP", rowOrder, true, "NameESPColorIndex", NAME_ESP_COLORS); rowOrder = rowOrder + 1
local v3, _ = CreateToggle(Pages.Visual, "Health ESP", "HealthESP", rowOrder); rowOrder = rowOrder + 1

local objectHighlightInput = CreateInputRow(Pages.Visual, "Object Name to Highlight", "e.g. Door, Chest, Key", "", rowOrder, function(value)
    highlightSearchTerm = value
    if States.ObjectHighlighter and highlightSearchTerm ~= "" then
        startObjectHighlighter(highlightSearchTerm)
    elseif States.ObjectHighlighter and highlightSearchTerm == "" then
        stopObjectHighlighter()
    end
end)
rowOrder = rowOrder + 1

local v4, highlightColorBox = CreateToggle(Pages.Visual, "Object Highlighter", "ObjectHighlighter", rowOrder, true, "HighlightColorIndex", HIGHLIGHT_COLORS)
rowOrder = rowOrder + 1

-- ============ TOOLS TAB ============
rowOrder = 1
local t1, _ = CreateToggle(Pages.Tools, "Show Notifications", "ShowNotifications", rowOrder); rowOrder = rowOrder + 1
local t2, _ = CreateToggle(Pages.Tools, "Tap to Identify Object", "TapToIdentify", rowOrder); rowOrder = rowOrder + 1
local t3, _ = CreateToggle(Pages.Tools, "Light", "Light", rowOrder); rowOrder = rowOrder + 1

-- ============ GLOBAL TAB ============
rowOrder = 1
local resetBtn = CreateButton(Pages.Global, "RESET ALL DATA", rowOrder, function()
    for k, v in pairs(States) do
        if k ~= "ESPColorIndex" and k ~= "NameESPColorIndex" and k ~= "HighlightColorIndex" and
           k ~= "SpinAxisX" and k ~= "SpinAxisY" and k ~= "SpinAxisZ" and k ~= "FlingPower" then
            States[k] = false
        end
    end
    States.ShowNotifications = true
    States.FlingPower = 10000
    v1(); v2(); v3(); v4(); t1(); t2(); t3()
    u1(); u2(); u3(); u4(); u5()
    if speedInput then speedInput.Text = "16" end
    if objectHighlightInput then objectHighlightInput.Text = "" end
    highlightSearchTerm = ""
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid.WalkSpeed = 16
    end
    if espColorBox then espColorBox.BackgroundColor3 = ESP_COLORS[1] end
    if nameColorBox then nameColorBox.BackgroundColor3 = NAME_ESP_COLORS[1] end
    if highlightColorBox then highlightColorBox.BackgroundColor3 = HIGHLIGHT_COLORS[1] end
    States.ESPColorIndex = 1
    States.NameESPColorIndex = 1
    States.HighlightColorIndex = 1
    setLighting(false)
    stopFollowTP()
    stopCameraFollow()
    stopObjectHighlighter()
    stopAllJokeFeatures()
    stopFling()
    selectedFollowPlayer = nil
    Notify("All settings reset!", COLORS.Accent)
end)
rowOrder = rowOrder + 1

-- ============ JOKE TAB ============
rowOrder = 1

local axisXUpdate = CreateAxisToggle(Pages.Joke, "Spin Axis X", "SpinAxisX", rowOrder); rowOrder = rowOrder + 1
local axisYUpdate = CreateAxisToggle(Pages.Joke, "Spin Axis Y", "SpinAxisY", rowOrder); rowOrder = rowOrder + 1
local axisZUpdate = CreateAxisToggle(Pages.Joke, "Spin Axis Z", "SpinAxisZ", rowOrder); rowOrder = rowOrder + 1

local sepFrame = Instance.new("Frame", Pages.Joke)
sepFrame.Size = UDim2.new(1, -12, 0, 1)
sepFrame.Position = UDim2.new(0, 6, 0, 0)
sepFrame.BackgroundColor3 = COLORS.Accent
sepFrame.BackgroundTransparency = 0.5
sepFrame.LayoutOrder = rowOrder; rowOrder = rowOrder + 1

local joke1, _ = CreateToggle(Pages.Joke, "Spin", "Spin", rowOrder); rowOrder = rowOrder + 1
local joke2, _ = CreateToggle(Pages.Joke, "BAF (Back and Forth)", "BAF", rowOrder); rowOrder = rowOrder + 1
local joke3, _ = CreateToggle(Pages.Joke, "Combo (Spin + BAF)", "Combo", rowOrder); rowOrder = rowOrder + 1

local stopJokeBtn = CreateButton(Pages.Joke, "STOP ALL JOKE FEATURES", rowOrder, function()
    stopAllJokeFeatures()
    joke1()
    joke2()
    joke3()
    Notify("All joke features stopped!", COLORS.Accent)
end)
rowOrder = rowOrder + 1

-- ============ DISTURB (FLING) TAB ============
rowOrder = 1

local flingToggle, _ = CreateToggle(Pages.Disturb, "Fling", "Fling", rowOrder)
rowOrder = rowOrder + 1

local flingPowerInput = CreateInputRow(Pages.Disturb, "Fling Power", "5000 - 55000", "10000", rowOrder, function(value)
    local power = tonumber(value)
    if power then
        power = math.clamp(power, 5000, 55000)
        States.FlingPower = power
        flingPowerInput.Text = tostring(power)
        Notify("Fling Power: " .. power, COLORS.Accent)
    else
        flingPowerInput.Text = tostring(States.FlingPower)
    end
end)
rowOrder = rowOrder + 1

local stopFlingBtn = CreateButton(Pages.Disturb, "STOP FLING", rowOrder, function()
    if States.Fling then
        States.Fling = false
        stopFling()
        flingToggle()
    end
    Notify("Fling stopped!", COLORS.Accent)
end)
rowOrder = rowOrder + 1

-- ============ INITIALIZATION & RUN LOOP ============

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function() task.wait(0.5) end)
end)

Players.PlayerRemoving:Connect(function(p)
    if nameBillboards[p] then nameBillboards[p]:Destroy() end
    if healthBillboards[p] then healthBillboards[p]:Destroy() end
    if followedPlayer == p then stopCameraFollow() end
end)

RunService.RenderStepped:Connect(function()
    if States.NoClip and player.Character then
        for _, v in pairs(player.Character:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end
    
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local highlight = p.Character:FindFirstChild("MorphESP")
            if States.ESP then
                if not highlight then
                    highlight = Instance.new("Highlight", p.Character)
                    highlight.Name = "MorphESP"
                end
                highlight.FillColor = ESP_COLORS[States.ESPColorIndex]
                highlight.OutlineTransparency = 1
                highlight.FillTransparency = 0.2
                highlight.DepthMode = "AlwaysOnTop"
            elseif highlight then
                highlight:Destroy()
            end
        end
    end
    
    updateNameESP()
    updateHealthESP()
end)

UserInputService.JumpRequest:Connect(function()
    if States.InfJump and player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid:ChangeState("Jumping")
    end
end)

setupTeleportClick()
setupTapToIdentify()
if States.AntiAFK then startAntiAFK() end

local function toggleGui(open)
    if open then
        MainFrame.Visible = true
        OpenBtn.Visible = false
        MainFrame:TweenSize(UDim2.new(0, 260, 0, 280), "Out", "Quart", 0.2, true)
    else
        CloseAllDropdowns()
        MainFrame:TweenSize(UDim2.new(0, 0, 0, 0), "In", "Quart", 0.2, true, function()
            MainFrame.Visible = false
            OpenBtn.Visible = true
        end)
    end
end

OpenBtn.MouseButton1Click:Connect(function() toggleGui(true) end)
MinBtn.MouseButton1Click:Connect(function() toggleGui(false) end)

CloseBtn.MouseButton1Click:Connect(function()
    local oldNotifyState = States.ShowNotifications
    States.ShowNotifications = false
    
    Lighting.Brightness = originalLightingSettings.Brightness
    Lighting.ClockTime = originalLightingSettings.ClockTime
    Lighting.Ambient = originalLightingSettings.Ambient
    Lighting.ColorShift_Top = originalLightingSettings.ColorShift_Top
    Lighting.ColorShift_Bottom = originalLightingSettings.ColorShift_Bottom
    Lighting.OutdoorAmbient = originalLightingSettings.OutdoorAmbient
    Lighting.ExposureCompensation = originalLightingSettings.ExposureCompensation
    Lighting.GlobalShadows = originalLightingSettings.GlobalShadows
    Lighting.FogEnd = originalLightingSettings.FogEnd
    Lighting.FogStart = originalLightingSettings.FogStart
    
    States.InfJump = false
    States.NoClip = false
    States.TeleportClick = false
    States.AntiAFK = false
    States.ESP = false
    States.NameESP = false
    States.HealthESP = false
    States.Light = false
    States.FollowTP = false
    States.TapToIdentify = false
    States.ObjectHighlighter = false
    States.ShowNotifications = oldNotifyState
    States.Fling = false
    
    stopAllJokeFeatures()
    stopFling()
    
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid.WalkSpeed = 16
    end
    
    stopFollowTP()
    stopCameraFollow()
    stopObjectHighlighter()
    
    if antiAFKConnection then antiAFKConnection:Disconnect() end
    if antiAFKLoop then task.cancel(antiAFKLoop) end
    
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local highlight = p.Character:FindFirstChild("MorphESP")
            if highlight then highlight:Destroy() end
        end
    end
    
    for _, bb in pairs(nameBillboards) do
        if bb then bb:Destroy() end
    end
    for _, bb in pairs(healthBillboards) do
        if bb then bb:Destroy() end
    end
    
    CloseAllDropdowns()
    ScreenGui:Destroy()
end)
