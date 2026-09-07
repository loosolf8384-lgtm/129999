--// Dronefront ESP — Optimized
--// Оптимизированный ESP дронов + предупреждение о приближении
--// Без отображения ников, имен и дистанции над дроном

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

--==================================================
-- UI
--==================================================

local MaterialUI = loadstring(
    game:HttpGet("https://raw.githubusercontent.com/xdbobr-jpg/roblox/refs/heads/main/MaterialUI.lua")
)()

--==================================================
-- SETTINGS
--==================================================

local Settings = {
    PlayersEnabled = false,
    PlayersTransparency = 0.5,

    DronesEnabled = false,
    DronesTransparency = 0.3,
    DroneColor = Color3.fromRGB(255, 115, 0),

    -- Отображение расстояния
    DistanceEnabled = false,

    -- Предупреждение о приближении к дрону
    ProximityWarning = false,

    -- Максимально до 200
    WarningDistance = 200,

    -- Как часто обновлять ESP
    ESPUpdateInterval = 0.5,

    -- Как часто проверять приближение
    ProximityCheckInterval = 0.15,
}

--==================================================
-- CACHE
--==================================================

local DroneCache = {}
local PlayerCache = {}

local LastESPUpdate = 0
local LastProximityCheck = 0

--==================================================
-- HELPERS
--==================================================

local DroneKeywords = {
    "shahed",
    "geran",
    "gerber",
    "fpv",
    "drone",
    "italmas",
    "molniy",
    "flamingo",
    "kalibr",
    "interceptor",
    "romaska",
    "uav",
    "missile",
    "loitering",
}

local function nameContainsDroneKeyword(name)
    name = string.lower(name)

    for _, keyword in ipairs(DroneKeywords) do
        if string.find(name, keyword, 1, true) then
            return true
        end
    end

    return false
end

local function isDroneModel(obj)
    if not obj:IsA("Model") then
        return false
    end

    if nameContainsDroneKeyword(obj.Name) then
        return true
    end

    -- Дополнительная проверка по атрибутам
    if obj:GetAttribute("IsDrone") == true then
        return true
    end

    if obj:GetAttribute("Drone") == true then
        return true
    end

    if obj:GetAttribute("IsFPV") == true then
        return true
    end

    -- Проверяем наличие сиденья только внутри модели
    for _, child in ipairs(obj:GetChildren()) do
        if child:IsA("VehicleSeat") or child:IsA("Seat") then
            return true
        end
    end

    return false
end

--==================================================
-- DRONE PART
--==================================================

local function findDronePart(model)
    if not model or not model.Parent then
        return nil
    end

    if model.PrimaryPart then
        return model.PrimaryPart
    end

    -- Сначала проверяем прямых детей
    for _, child in ipairs(model:GetChildren()) do
        if child:IsA("BasePart") then
            return child
        end
    end

    -- Только если не нашли — один раз ищем глубже
    for _, child in ipairs(model:GetDescendants()) do
        if child:IsA("BasePart") then
            return child
        end
    end

    return nil
end

--==================================================
-- PILOT
--==================================================

local function getPilot(model)
    if not model or not model.Parent then
        return nil
    end

    -- Сначала ищем Seat / VehicleSeat
    for _, child in ipairs(model:GetDescendants()) do
        if child:IsA("VehicleSeat") or child:IsA("Seat") then
            local humanoid = child.Occupant

            if humanoid then
                local character = humanoid.Parent

                if character then
                    return Players:GetPlayerFromCharacter(character)
                end
            end
        end
    end

    -- Дополнительная проверка ObjectValue
    for _, child in ipairs(model:GetDescendants()) do
        if child:IsA("ObjectValue") then
            local value = child.Value

            if value and value:IsA("Player") then
                return value
            end

            if value and value:IsA("Model") then
                local player = Players:GetPlayerFromCharacter(value)

                if player then
                    return player
                end
            end
        end
    end

    return nil
end

--==================================================
-- HIGHLIGHT
--==================================================

local function removeESP(model)
    if not model then
        return
    end

    local highlight = model:FindFirstChild("_DronefrontHighlight")

    if highlight then
        highlight:Destroy()
    end

    local billboard = model:FindFirstChild("_DronefrontDistance")

    if billboard then
        billboard:Destroy()
    end
end

local function createDroneESP(model, part)
    if not model or not model.Parent then
        return
    end

    if not Settings.DronesEnabled then
        removeESP(model)
        return
    end

    local highlight = model:FindFirstChild("_DronefrontHighlight")

    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = "_DronefrontHighlight"
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = model
    end

    highlight.FillColor = Settings.DroneColor
    highlight.OutlineColor = Settings.DroneColor

    highlight.FillTransparency = Settings.DronesTransparency
    highlight.OutlineTransparency = math.clamp(
        Settings.DronesTransparency - 0.15,
        0,
        1
    )

    --==================================================
    -- DISTANCE BILLBOARD
    --==================================================

    if Settings.DistanceEnabled and part then
        local billboard = model:FindFirstChild("_DronefrontDistance")

        if not billboard then
            billboard = Instance.new("BillboardGui")
            billboard.Name = "_DronefrontDistance"
            billboard.Size = UDim2.fromOffset(120, 30)
            billboard.StudsOffset = Vector3.new(0, 3, 0)
            billboard.AlwaysOnTop = true
            billboard.Parent = model

            local text = Instance.new("TextLabel")
            text.Name = "Distance"
            text.Size = UDim2.fromScale(1, 1)
            text.BackgroundTransparency = 1
            text.TextScaled = true
            text.TextStrokeTransparency = 0.25
            text.Parent = billboard
        end

        local text = billboard:FindFirstChild("Distance")

        if text then
            local root = LocalPlayer.Character
                and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

            if root then
                local distance = (root.Position - part.Position).Magnitude
                text.Text = string.format("%d m", distance)
            end
        end
    else
        local billboard = model:FindFirstChild("_DronefrontDistance")

        if billboard then
            billboard:Destroy()
        end
    end
end

--==================================================
-- PLAYER ESP
--==================================================

local function createPlayerESP(player)
    if player == LocalPlayer then
        return
    end

    local character = player.Character

    if not character then
        return
    end

    if not Settings.PlayersEnabled then
        local highlight = character:FindFirstChild("_DronefrontPlayerHighlight")

        if highlight then
            highlight:Destroy()
        end

        return
    end

    local highlight = character:FindFirstChild("_DronefrontPlayerHighlight")

    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = "_DronefrontPlayerHighlight"
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillColor = Color3.fromRGB(255, 70, 70)
        highlight.OutlineColor = Color3.fromRGB(255, 70, 70)
        highlight.Parent = character
    end

    highlight.FillTransparency = Settings.PlayersTransparency
    highlight.OutlineTransparency = 0
end

--==================================================
-- DRONE CACHE
--==================================================

local function registerDrone(model)
    if not model then
        return
    end

    if not isDroneModel(model) then
        return
    end

    if DroneCache[model] then
        return
    end

    local part = findDronePart(model)

    DroneCache[model] = {
        Model = model,
        Part = part,
        Pilot = nil,
        LastPilotCheck = 0,
    }
end

local function unregisterDrone(model)
    if DroneCache[model] then
        removeESP(model)
        DroneCache[model] = nil
    end
end

--==================================================
-- INITIAL SCAN
--==================================================

for _, obj in ipairs(Workspace:GetDescendants()) do
    if obj:IsA("Model") then
        registerDrone(obj)
    end
end

--==================================================
-- NEW OBJECTS
--==================================================

Workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Model") then
        task.defer(function()
            registerDrone(obj)
        end)
    end
end)

Workspace.DescendantRemoving:Connect(function(obj)
    if DroneCache[obj] then
        unregisterDrone(obj)
    end
end)

--==================================================
-- CHARACTER EVENTS
--==================================================

local function setupPlayer(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.2)

        if Settings.PlayersEnabled then
            createPlayerESP(player)
        end
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player)
    PlayerCache[player] = nil
end)

--==================================================
-- PROXIMITY WARNING
--==================================================

local function checkDroneProximity()
    if not Settings.ProximityWarning then
        return
    end

    local character = LocalPlayer.Character

    if not character then
        return
    end

    local root = character:FindFirstChild("HumanoidRootPart")

    if not root then
        return
    end

    local closestDistance = math.huge
    local closestDrone = nil

    for model, data in pairs(DroneCache) do
        if model.Parent and data.Part and data.Part.Parent then

            local distance =
                (root.Position - data.Part.Position).Magnitude

            if distance <= Settings.WarningDistance
                and distance < closestDistance then

                closestDistance = distance
                closestDrone = model
            end
        end
    end

    if closestDrone then
        -- Подсветка ближайшего дрона
        local highlight =
            closestDrone:FindFirstChild("_DronefrontHighlight")

        if highlight then
            highlight.OutlineTransparency = 0
        end
    end
end

--==================================================
-- CLEANUP
--==================================================

local function cleanupAll()
    for model in pairs(DroneCache) do
        removeESP(model)
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            local highlight =
                player.Character:FindFirstChild(
                    "_DronefrontPlayerHighlight"
                )

            if highlight then
                highlight:Destroy()
            end
        end
    end
end

--==================================================
-- MAIN LOOP
--==================================================

RunService.Heartbeat:Connect(function()
    local now = os.clock()

    --------------------------------------------------
    -- ESP UPDATE
    --------------------------------------------------

    if now - LastESPUpdate >= Settings.ESPUpdateInterval then
        LastESPUpdate = now

        --------------------------------------------------
        -- PLAYERS
        --------------------------------------------------

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                createPlayerESP(player)
            end
        end

        --------------------------------------------------
        -- DRONES
        --------------------------------------------------

        for model, data in pairs(DroneCache) do

            if not model.Parent then
                DroneCache[model] = nil
                continue
            end

            --------------------------------------------------
            -- Обновляем Part только если старый исчез
            --------------------------------------------------

            if not data.Part or not data.Part.Parent then
                data.Part = findDronePart(model)
            end

            --------------------------------------------------
            -- Пилота проверяем редко, а не каждый кадр
            --------------------------------------------------

            if now - data.LastPilotCheck >= 0.5 then
                data.LastPilotCheck = now
                data.Pilot = getPilot(model)
            end

            createDroneESP(model, data.Part)
        end
    end

    --------------------------------------------------
    -- PROXIMITY
    --------------------------------------------------

    if now - LastProximityCheck >= Settings.ProximityCheckInterval then
        LastProximityCheck = now

        checkDroneProximity()
    end
end)

--==================================================
-- GUI
--==================================================

local Window = MaterialUI:CreateWindow({
    Name = "DronefrontESP",
    Title = "Dronefront ESP",
    Theme = {
        mode = "dark",
        acrylic = false
    },
    ConfigSettings = {
        SaveCurrentState = true,
        FolderName = "Dronefront",
        FileName = "Settings.json"
    },
    ToggleUIKeybind = Enum.KeyCode.RightShift
})

--==================================================
-- PAGE: ESP
--==================================================

local ESPPage = Window:CreatePage({
    Name = "ESP",
    Title = "ESP"
})

--==================================================
-- PLAYERS
--==================================================

local PlayersSection = ESPPage:CreateSection({
    Name = "PlayersSection",
    Title = "Игроки"
})

PlayersSection:CreateToggle({
    Name = "PlayersEnabled",
    Title = "Подсветка игроков",
    Default = Settings.PlayersEnabled,

    Callback = function(value)
        Settings.PlayersEnabled = value

        if not value then
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then
                    local highlight =
                        player.Character:FindFirstChild(
                            "_DronefrontPlayerHighlight"
                        )

                    if highlight then
                        highlight:Destroy()
                    end
                end
            end
        end
    end
})

PlayersSection:CreateSlider({
    Name = "PlayersTransparency",
    Title = "Прозрачность игроков",
    Min = 0,
    Max = 1,
    Step = 0.05,
    Default = Settings.PlayersTransparency,

    Callback = function(value)
        Settings.PlayersTransparency = value
    end
})

--==================================================
-- DRONES
--==================================================

local DronesSection = ESPPage:CreateSection({
    Name = "DronesSection",
    Title = "Дроны"
})

DronesSection:CreateToggle({
    Name = "DronesEnabled",
    Title = "Подсветка дронов",
    Default = Settings.DronesEnabled,

    Callback = function(value)
        Settings.DronesEnabled = value

        if not value then
            for model in pairs(DroneCache) do
                removeESP(model)
            end
        end
    end
})

DronesSection:CreateToggle({
    Name = "DistanceEnabled",
    Title = "Показывать расстояние",
    Default = Settings.DistanceEnabled,

    Callback = function(value)
        Settings.DistanceEnabled = value
    end
})

DronesSection:CreateColorPicker({
    Name = "DroneColor",
    Title = "Цвет дронов",
    Default = Settings.DroneColor,

    Callback = function(value)
        if typeof(value) == "Color3" then
            Settings.DroneColor = value
        end
    end
})

DronesSection:CreateSlider({
    Name = "DronesTransparency",
    Title = "Прозрачность дронов",
    Min = 0,
    Max = 1,
    Step = 0.05,
    Default = Settings.DronesTransparency,

    Callback = function(value)
        Settings.DronesTransparency = value
    end
})

--==================================================
-- PROXIMITY
--==================================================

local WarningSection = ESPPage:CreateSection({
    Name = "WarningSection",
    Title = "Приближение"
})

WarningSection:CreateToggle({
    Name = "ProximityWarning",
    Title = "Предупреждение о приближении",
    Default = Settings.ProximityWarning,

    Callback = function(value)
        Settings.ProximityWarning = value
    end
})

WarningSection:CreateSlider({
    Name = "WarningDistance",
    Title = "Дистанция предупреждения",
    Min = 2,
    Max = 200,
    Step = 1,
    Default = Settings.WarningDistance,

    Callback = function(value)
        Settings.WarningDistance = value
    end
})

--==================================================
-- PERFORMANCE
--==================================================

local PerformanceSection = ESPPage:CreateSection({
    Name = "PerformanceSection",
    Title = "Производительность"
})

PerformanceSection:CreateSlider({
    Name = "ESPUpdateInterval",
    Title = "Интервал обновления ESP",
    Min = 0.2,
    Max = 2,
    Step = 0.1,
    Default = Settings.ESPUpdateInterval,

    Callback = function(value)
        Settings.ESPUpdateInterval = value
    end
})

--==================================================
-- INFO
--==================================================

local InfoSection = ESPPage:CreateSection({
    Name = "InfoSection",
    Title = "Информация"
})

InfoSection:CreateLabel({
    Title = "RightShift — показать / скрыть меню",
    Style = "bodyMedium"
})

InfoSection:CreateLabel({
    Title = "Дистанция предупреждения: до 200 м",
    Style = "bodyMedium"
})

print("[Dronefront ESP] Optimized version loaded")
print("[Dronefront ESP] Drones cached:", #DroneCache)