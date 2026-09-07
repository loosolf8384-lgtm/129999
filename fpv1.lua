-- =============================================================================
-- DRONEFRONT ESP - OPTIMIZED + DISTANCE + FPV AUTO DETONATION
-- Только Highlight + опциональное расстояние
-- =============================================================================

-- ============================================================================
-- MATERIAL3 UI
-- ============================================================================

local Material3 = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/xdbobr-jpg/roblox/refs/heads/main/MaterialUI.lua"
))()

-- ============================================================================
-- НАСТРОЙКИ
-- ============================================================================

local Settings = {

    -- Игроки
    PlayersEnabled = false,
    PlayersTransparency = 0.5,

    -- Дроны
    DronesEnabled = false,
    DronesTransparency = 0.3,
    DroneColor = Color3.fromRGB(255, 115, 0),

    -- Расстояние
    DistanceEnabled = false,

    -- FPV автоподрыв
    AutoDetonate = false,

    -- Расстояние, при котором нажимается R
    DetonationDistance = 8,

    -- Частота проверки
    ActiveCheckInterval = 0.15,

    -- Защита от многократного нажатия R
    DetonationCooldown = 0.8
}

-- ============================================================================
-- СЕРВИСЫ
-- ============================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- VirtualInputManager используется для имитации нажатия R
local VirtualInputManager = game:GetService("VirtualInputManager")

-- ============================================================================
-- НАЗВАНИЯ ESP
-- ============================================================================

local PLAYER_HIGHLIGHT_NAME = "Dronefront_PlayerESP"
local DRONE_HIGHLIGHT_NAME = "Dronefront_DroneESP"
local DRONE_DISTANCE_NAME = "Dronefront_Distance"

-- ============================================================================
-- КЭШ
-- ============================================================================

local DroneCache = {}
local PlayerCache = {}

-- ============================================================================
-- СПИСОК ДРОНОВ
-- ============================================================================

local DroneKeywords = {
    "shahed",
    "gerber",
    "fpv",
    "drone",
    "italmas",
    "molniy",
    "flamingo",
    "kalibr",
    "geran",
    "interceptor",
    "romaska",
    "uav",
    "missile",
    "loitering"
}

-- ============================================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ============================================================================

local function getTeamColor(player)

    if player and player.Team and player.TeamColor then
        return player.TeamColor.Color
    end

    return Color3.fromRGB(255, 255, 255)
end


local function hasDroneName(name)

    name = string.lower(name)

    for _, keyword in ipairs(DroneKeywords) do

        if string.find(name, keyword, 1, true) then
            return true
        end

    end

    return false
end


-- ============================================================================
-- ОПРЕДЕЛЕНИЕ ДРОНА
-- ============================================================================

local function isDroneModel(obj)

    if not obj:IsA("Model") then
        return false
    end

    -- Самая быстрая проверка
    if hasDroneName(obj.Name) then
        return true
    end

    -- Проверяем сиденье
    if obj:FindFirstChildOfClass("VehicleSeat")
        or obj:FindFirstChildOfClass("Seat") then

        return true
    end

    return false
end


-- ============================================================================
-- ПОЛУЧЕНИЕ ОСНОВНОЙ ДЕТАЛИ ДРОНА
-- ============================================================================

local function getDronePart(drone)

    if drone.PrimaryPart
        and drone.PrimaryPart:IsA("BasePart") then

        return drone.PrimaryPart
    end

    -- Не используем GetDescendants() постоянно.
    -- Ищем среди непосредственных детей.
    for _, child in ipairs(drone:GetChildren()) do

        if child:IsA("BasePart") then
            return child
        end

    end

    -- Редкий fallback
    local part = drone:FindFirstChildWhichIsA(
        "BasePart",
        true
    )

    return part
end


-- ============================================================================
-- ОПРЕДЕЛЕНИЕ ПИЛОТА
-- ============================================================================

local function getPilot(drone)

    -- 1. VehicleSeat
    local seat =
        drone:FindFirstChildOfClass("VehicleSeat")
        or drone:FindFirstChildOfClass("Seat")

    if seat and seat.Occupant then

        local character = seat.Occupant.Parent

        if character then

            local player =
                Players:GetPlayerFromCharacter(character)

            if player then
                return player
            end

        end

    end


    -- 2. ObjectValue / StringValue
    for _, child in ipairs(drone:GetChildren()) do

        if child:IsA("ObjectValue")
            and child.Value
            and child.Value:IsA("Player") then

            return child.Value
        end


        if child:IsA("StringValue")
            and child.Value ~= "" then

            local player =
                Players:FindFirstChild(child.Value)

            if player then
                return player
            end

        end

    end


    -- 3. Атрибуты
    local possibleAttributes = {
        "Pilot",
        "Player",
        "Owner",
        "Operator",
        "Controller"
    }

    for _, attributeName in ipairs(possibleAttributes) do

        local value =
            drone:GetAttribute(attributeName)

        if typeof(value) == "string"
            and value ~= "" then

            local player =
                Players:FindFirstChild(value)

            if player then
                return player
            end

        end

    end

    return nil
end


-- ============================================================================
-- ПРОВЕРКА АКТИВНОСТИ
-- ============================================================================

local function getActiveAttribute(drone)

    local attributes = {
        "Active",
        "IsActive",
        "Enabled",
        "IsEnabled",
        "Deployed",
        "DeployedState"
    }

    for _, attributeName in ipairs(attributes) do

        local value =
            drone:GetAttribute(attributeName)

        if value ~= nil then

            if typeof(value) == "boolean" then
                return value
            end

            if typeof(value) == "number" then
                return value ~= 0
            end

        end

    end

    return nil
end


local function isActiveDrone(drone)

    if not drone
        or not drone.Parent
        or not drone:IsDescendantOf(Workspace) then

        return false
    end

    -- Если игра предоставляет состояние через Attribute
    local attributeState =
        getActiveAttribute(drone)

    if attributeState ~= nil then
        return attributeState
    end

    -- Если дрон управляется игроком
    if getPilot(drone) then
        return true
    end

    -- В отсутствие отдельного признака активности
    -- считаем существующую модель активной.
    return true
end


-- ============================================================================
-- DISTANCE GUI
-- ============================================================================

local function removeDistance(drone)

    local gui =
        drone:FindFirstChild(DRONE_DISTANCE_NAME)

    if gui then
        gui:Destroy()
    end
end


local function createDistance(drone, part)

    if not Settings.DistanceEnabled then

        removeDistance(drone)

        return
    end

    if not part then
        return
    end

    local billboard =
        drone:FindFirstChild(DRONE_DISTANCE_NAME)

    if not billboard then

        billboard = Instance.new("BillboardGui")

        billboard.Name =
            DRONE_DISTANCE_NAME

        billboard.AlwaysOnTop = true

        billboard.Size =
            UDim2.new(0, 100, 0, 30)

        billboard.StudsOffset =
            Vector3.new(0, 2.5, 0)

        billboard.Parent = drone


        local label =
            Instance.new("TextLabel")

        label.Name = "Distance"

        label.Size =
            UDim2.new(1, 0, 1, 0)

        label.BackgroundTransparency = 1

        label.TextStrokeTransparency = 0

        label.Font =
            Enum.Font.SourceSansBold

        label.TextSize = 16

        label.TextColor3 =
            Color3.fromRGB(255, 255, 255)

        label.Parent = billboard

    end

    billboard.Adornee = part

    local camera =
        Workspace.CurrentCamera

    if camera then

        local distance =
            math.floor(
                (camera.CFrame.Position - part.Position).Magnitude
            )

        billboard.Distance.Text =
            tostring(distance) .. " m"

    end
end


-- ============================================================================
-- HIGHLIGHT ДРОНА
-- ============================================================================

local function removeDroneHighlight(drone)

    local highlight =
        drone:FindFirstChild(DRONE_HIGHLIGHT_NAME)

    if highlight then
        highlight:Destroy()
    end

    removeDistance(drone)
end


local function updateDroneHighlight(drone)

    if not Settings.DronesEnabled then

        removeDroneHighlight(drone)

        return
    end


    if not isActiveDrone(drone) then

        removeDroneHighlight(drone)

        return
    end


    local part =
        getDronePart(drone)

    if not part then
        return
    end


    local highlight =
        drone:FindFirstChild(DRONE_HIGHLIGHT_NAME)


    if not highlight then

        highlight =
            Instance.new("Highlight")

        highlight.Name =
            DRONE_HIGHLIGHT_NAME

        highlight.DepthMode =
            Enum.HighlightDepthMode.AlwaysOnTop

        highlight.Parent = drone

    end


    local pilot =
        getPilot(drone)


    if pilot then

        highlight.FillColor =
            getTeamColor(pilot)

    else

        highlight.FillColor =
            Settings.DroneColor

    end


    highlight.OutlineColor =
        Color3.fromRGB(255, 255, 255)

    highlight.FillTransparency =
        Settings.DronesTransparency

    highlight.OutlineTransparency = 0


    -- Расстояние
    createDistance(drone, part)
end


-- ============================================================================
-- РЕГИСТРАЦИЯ ДРОНОВ
-- ============================================================================

local function registerDrone(obj)

    if not isDroneModel(obj) then
        return
    end

    if DroneCache[obj] then
        return
    end

    DroneCache[obj] = true

    if Settings.DronesEnabled then
        updateDroneHighlight(obj)
    end
end


local function unregisterDrone(obj)

    if not DroneCache[obj] then
        return
    end

    removeDroneHighlight(obj)

    DroneCache[obj] = nil
end


-- ============================================================================
-- ПЕРВИЧНОЕ СКАНИРОВАНИЕ
-- ============================================================================

task.spawn(function()

    for _, obj in ipairs(Workspace:GetDescendants()) do

        if obj:IsA("Model")
            and isDroneModel(obj) then

            registerDrone(obj)

        end

    end

end)


-- ============================================================================
-- НОВЫЕ ОБЪЕКТЫ
-- ============================================================================

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


-- ============================================================================
-- ПОСЛЕДНИЙ ДРОН, КОТОРЫЙ БЫЛ ПОД УПРАВЛЕНИЕМ
-- ============================================================================

local CurrentControlledDrone = nil

local LastDetonation = 0


-- ============================================================================
-- ОПРЕДЕЛЕНИЕ FPV, КОТОРЫМ УПРАВЛЯЕТ LOCALPLAYER
-- ============================================================================

local function getControlledFPV()

    for drone in pairs(DroneCache) do

        if drone
            and drone.Parent
            and drone:IsDescendantOf(Workspace) then

            local pilot =
                getPilot(drone)

            -- Ключевая проверка:
            -- автоподрыв возможен ТОЛЬКО если пилот = LocalPlayer
            if pilot == LocalPlayer then

                local name =
                    string.lower(drone.Name)

                -- Ищем именно FPV
                if string.find(name, "fpv", 1, true)
                    or drone:GetAttribute("FPV") == true
                    or drone:GetAttribute("IsFPV") == true then

                    return drone
                end

            end

        end

    end

    return nil
end


-- ============================================================================
-- НАЖАТИЕ R
-- ============================================================================

local function pressR()

    local success =
        pcall(function()

            VirtualInputManager:SendKeyEvent(
                true,
                Enum.KeyCode.R,
                false,
                game
            )

            task.wait(0.03)

            VirtualInputManager:SendKeyEvent(
                false,
                Enum.KeyCode.R,
                false,
                game
            )

        end)

    return success
end


-- ============================================================================
-- АВТОПОДРЫВ
-- ============================================================================

local function processAutoDetonation()

    if not Settings.AutoDetonate then
        return
    end


    -- Находим именно FPV LocalPlayer
    local fpv =
        getControlledFPV()


    -- Никакого FPV под управлением LocalPlayer =
    -- НИЧЕГО НЕ ДЕЛАЕМ
    if not fpv then

        CurrentControlledDrone = nil

        return
    end


    CurrentControlledDrone = fpv


    local fpvPart =
        getDronePart(fpv)

    if not fpvPart then
        return
    end


    -- Ищем ближайший АКТИВНЫЙ объект,
    -- кроме самого управляемого FPV
    local nearestDistance = math.huge


    for drone in pairs(DroneCache) do

        if drone ~= fpv
            and drone.Parent
            and isActiveDrone(drone) then

            local targetPart =
                getDronePart(drone)

            if targetPart then

                local distance =
                    (fpvPart.Position - targetPart.Position).Magnitude

                if distance < nearestDistance then
                    nearestDistance = distance
                end

            end

        end

    end


    -- Если ближайшая цель достаточно близко
    if nearestDistance <= Settings.DetonationDistance then

        local now =
            os.clock()


        -- Защита от спама R
        if now - LastDetonation >=
            Settings.DetonationCooldown then

            LastDetonation = now

            pressR()

        end

    end

end


-- ============================================================================
-- ОСНОВНОЙ ЦИКЛ
-- ============================================================================

task.spawn(function()

    while true do

        task.wait(Settings.ActiveCheckInterval)


        -- Обновляем ESP
        for drone in pairs(DroneCache) do

            if not drone
                or not drone.Parent
                or not drone:IsDescendantOf(Workspace) then

                unregisterDrone(drone)

            else

                if Settings.DronesEnabled then
                    updateDroneHighlight(drone)
                end

            end

        end


        -- Автоподрыв
        processAutoDetonation()

    end

end)


-- ============================================================================
-- PLAYERS ESP
-- ============================================================================

local function updatePlayerHighlight(player)

    if player == LocalPlayer then
        return
    end


    local character =
        player.Character

    if not character then
        return
    end


    local highlight =
        character:FindFirstChild(
            PLAYER_HIGHLIGHT_NAME
        )


    if not Settings.PlayersEnabled then

        if highlight then
            highlight:Destroy()
        end

        return
    end


    if not highlight then

        highlight =
            Instance.new("Highlight")

        highlight.Name =
            PLAYER_HIGHLIGHT_NAME

        highlight.DepthMode =
            Enum.HighlightDepthMode.AlwaysOnTop

        highlight.Parent =
            character

    end


    highlight.FillColor =
        getTeamColor(player)

    highlight.OutlineColor =
        Color3.fromRGB(255, 255, 255)

    highlight.FillTransparency =
        Settings.PlayersTransparency

    highlight.OutlineTransparency = 0
end


local function setupPlayer(player)

    if player == LocalPlayer then
        return
    end


    PlayerCache[player] = true


    player.CharacterAdded:Connect(function()

        task.wait(0.1)

        if Settings.PlayersEnabled then
            updatePlayerHighlight(player)
        end

    end)


    if player.Character then
        updatePlayerHighlight(player)
    end

end


local function removePlayer(player)

    PlayerCache[player] = nil


    if player.Character then

        local highlight =
            player.Character:FindFirstChild(
                PLAYER_HIGHLIGHT_NAME
            )

        if highlight then
            highlight:Destroy()
        end

    end

end


for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end


Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(removePlayer)


-- ============================================================================
-- GUI
-- ============================================================================

local Window = Material3.CreateWindow({

    Name = "DronefrontESP",

    Title = "Dronefront ESP",

    Subtitle = "Optimized ESP",

    Theme = {
        mode = "dark",
        acrylic = false
    }

})


-- ============================================================================
-- PLAYERS
-- ============================================================================

local PlayersPage =
    Window:CreatePage({
        Name = "Игроки",
        Title = "Игроки"
    })


local PlayersSection =
    PlayersPage:CreateSection({
        Title = "Подсветка игроков",
        Description = "Только визуальная подсветка."
    })


PlayersSection:CreateToggle({

    Title = "Включить подсветку игроков",

    Default = false,

    Callback = function(value)

        Settings.PlayersEnabled = value


        for player in pairs(PlayerCache) do
            updatePlayerHighlight(player)
        end

    end

})


PlayersSection:CreateSlider({

    Title = "Прозрачность игроков",

    Min = 0,

    Max = 1,

    Step = 0.1,

    Default = 0.5,

    Callback = function(value)

        Settings.PlayersTransparency = value


        if Settings.PlayersEnabled then

            for player in pairs(PlayerCache) do

                local character =
                    player.Character

                if character then

                    local highlight =
                        character:FindFirstChild(
                            PLAYER_HIGHLIGHT_NAME
                        )

                    if highlight then
                        highlight.FillTransparency = value
                    end

                end

            end

        end

    end

})


-- ============================================================================
-- DRONES
-- ============================================================================

local DronesPage =
    Window:CreatePage({
        Name = "Дроны",
        Title = "Дроны"
    })


local DronesSection =
    DronesPage:CreateSection({

        Title = "Подсветка дронов",

        Description =
            "Активные дроны без названий и имён."

    })


DronesSection:CreateToggle({

    Title = "Включить подсветку дронов",

    Default = false,

    Callback = function(value)

        Settings.DronesEnabled = value


        for drone in pairs(DroneCache) do

            if value then
                updateDroneHighlight(drone)
            else
                removeDroneHighlight(drone)
            end

        end

    end

})


-- ============================================================================
-- DISTANCE
-- ============================================================================

DronesSection:CreateToggle({

    Title = "Показывать расстояние",

    Default = false,

    Callback = function(value)

        Settings.DistanceEnabled = value


        for drone in pairs(DroneCache) do

            if Settings.DronesEnabled
                and value then

                local part =
                    getDronePart(drone)

                if part then
                    createDistance(drone, part)
                end

            else

                removeDistance(drone)

            end

        end

    end

})


-- ============================================================================
-- COLOR
-- ============================================================================

DronesSection:CreateColorPicker({

    Title = "Цвет дронов",

    Default =
        Color3.fromRGB(255, 115, 0),

    Callback = function(color)

        Settings.DroneColor = color


        if Settings.DronesEnabled then

            for drone in pairs(DroneCache) do

                local highlight =
                    drone:FindFirstChild(
                        DRONE_HIGHLIGHT_NAME
                    )


                if highlight
                    and not getPilot(drone) then

                    highlight.FillColor =
                        color

                end

            end

        end

    end

})


-- ============================================================================
-- TRANSPARENCY
-- ============================================================================

DronesSection:CreateSlider({

    Title = "Прозрачность дронов",

    Min = 0,

    Max = 1,

    Step = 0.1,

    Default = 0.3,

    Callback = function(value)

        Settings.DronesTransparency = value


        if Settings.DronesEnabled then

            for drone in pairs(DroneCache) do

                local highlight =
                    drone:FindFirstChild(
                        DRONE_HIGHLIGHT_NAME
                    )

                if highlight then
                    highlight.FillTransparency =
                        value
                end

            end

        end

    end

})


-- ============================================================================
-- FPV AUTO DETONATION
-- ============================================================================

local FPVSection =
    DronesPage:CreateSection({

        Title = "FPV",

        Description =
            "Автоматическое нажатие R при приближении к цели."

    })


FPVSection:CreateToggle({

    Title = "Автоподрыв FPV",

    Default = false,

    Callback = function(value)

        Settings.AutoDetonate = value

        -- Сбрасываем состояние
        if not value then
            CurrentControlledDrone = nil
        end

    end

})


-- ============================================================================
-- DETONATION DISTANCE
-- ============================================================================

FPVSection:CreateSlider({

    Title = "Дистанция автоподрыва",

    Min = 2,

    Max = 20,

    Step = 1,

    Default = 8,

    Callback = function(value)

        Settings.DetonationDistance = value

    end

})


-- ============================================================================
-- УВЕДОМЛЕНИЕ
-- ============================================================================

Window:Notify({

    Content =
        "ESP загружен: Highlight + расстояние + FPV",

    Duration = 4

})