-- =============================================================================
-- DRONEFRONT ESP - OPTIMIZED
-- Только Highlight, без текста и дистанции
-- =============================================================================

-- Загрузка Material3 UI
local Material3 = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/xdbobr-jpg/roblox/refs/heads/main/MaterialUI.lua"
))()

-- =============================================================================
-- НАСТРОЙКИ
-- =============================================================================

local Settings = {
    PlayersEnabled = false,
    PlayersTransparency = 0.5,

    DronesEnabled = false,
    DronesTransparency = 0.3,
    DroneColor = Color3.fromRGB(255, 115, 0),

    -- Как часто проверять состояние уже найденных дронов
    ActiveCheckInterval = 0.5
}

-- =============================================================================
-- СЕРВИСЫ
-- =============================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- =============================================================================
-- КОНСТАНТЫ
-- =============================================================================

local PLAYER_HIGHLIGHT_NAME = "Dronefront_PlayerESP"
local DRONE_HIGHLIGHT_NAME = "Dronefront_DroneESP"

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

-- =============================================================================
-- КЭШ
-- =============================================================================

local DroneCache = {}
local PlayerCache = {}

-- =============================================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- =============================================================================

local function getTeamColor(player)
    if player and player.Team and player.TeamColor then
        return player.TeamColor.Color
    end

    return Color3.fromRGB(255, 255, 255)
end


-- Быстрая проверка имени модели
local function hasDroneName(name)
    name = string.lower(name)

    for _, keyword in ipairs(DroneKeywords) do
        if string.find(name, keyword, 1, true) then
            return true
        end
    end

    return false
end


-- Проверяем, является ли объект потенциальным дроном
local function isDroneModel(obj)
    if not obj:IsA("Model") then
        return false
    end

    -- Сначала дешёвая проверка имени
    if hasDroneName(obj.Name) then
        return true
    end

    -- Затем проверяем только непосредственные объекты,
    -- вместо полного GetDescendants()
    if obj:FindFirstChildOfClass("VehicleSeat")
        or obj:FindFirstChildOfClass("Seat") then

        return true
    end

    return false
end


-- =============================================================================
-- ОПРЕДЕЛЕНИЕ АКТИВНОГО ДРОНА
-- =============================================================================

local function getPilot(drone)
    -- Сначала проверяем Seat / VehicleSeat
    local seat =
        drone:FindFirstChildOfClass("VehicleSeat")
        or drone:FindFirstChildOfClass("Seat")

    if seat and seat.Occupant then
        local character = seat.Occupant.Parent

        if character then
            return Players:GetPlayerFromCharacter(character)
        end
    end

    -- Проверяем ObjectValue только среди непосредственных детей
    for _, child in ipairs(drone:GetChildren()) do
        if child:IsA("ObjectValue")
            and child.Value
            and child.Value:IsA("Player") then

            return child.Value
        end

        if child:IsA("StringValue")
            and child.Value ~= "" then

            local player = Players:FindFirstChild(child.Value)

            if player then
                return player
            end
        end
    end

    return nil
end


-- Проверка атрибутов активности
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
        local value = drone:GetAttribute(attributeName)

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


-- Главная проверка:
-- true = дрон действительно активен
local function isActiveDrone(drone)
    if not drone
        or not drone.Parent
        or not drone:IsDescendantOf(Workspace) then

        return false
    end

    -- Если игра явно сообщает состояние через Attribute —
    -- используем его.
    local attributeState = getActiveAttribute(drone)

    if attributeState ~= nil then
        return attributeState
    end

    -- Если есть оператор — дрон активен
    if getPilot(drone) then
        return true
    end

    -- Если у модели есть PrimaryPart / BasePart,
    -- считаем её существующим активным объектом,
    -- но НЕ подсвечиваем шаблоны вне Workspace.
    return true
end


-- =============================================================================
-- HIGHLIGHT ДРОНА
-- =============================================================================

local function removeDroneHighlight(drone)
    if not drone then
        return
    end

    local highlight = drone:FindFirstChild(DRONE_HIGHLIGHT_NAME)

    if highlight then
        highlight:Destroy()
    end
end


local function createDroneHighlight(drone)
    if not Settings.DronesEnabled then
        return
    end

    if not isActiveDrone(drone) then
        removeDroneHighlight(drone)
        return
    end

    local highlight = drone:FindFirstChild(DRONE_HIGHLIGHT_NAME)

    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = DRONE_HIGHLIGHT_NAME
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = drone
    end

    local pilot = getPilot(drone)

    if pilot then
        highlight.FillColor = getTeamColor(pilot)
    else
        highlight.FillColor = Settings.DroneColor
    end

    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = Settings.DronesTransparency
    highlight.OutlineTransparency = 0
end


-- =============================================================================
-- КЭШ ДРОНОВ
-- =============================================================================

local function registerDrone(obj)
    if not isDroneModel(obj) then
        return
    end

    if DroneCache[obj] then
        return
    end

    DroneCache[obj] = true

    if Settings.DronesEnabled then
        createDroneHighlight(obj)
    end
end


local function unregisterDrone(obj)
    if not DroneCache[obj] then
        return
    end

    removeDroneHighlight(obj)
    DroneCache[obj] = nil
end


-- =============================================================================
-- ПЕРВИЧНЫЙ ПОИСК
-- Выполняется ОДИН РАЗ
-- =============================================================================

task.spawn(function()

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and isDroneModel(obj) then
            registerDrone(obj)
        end
    end

end)


-- =============================================================================
-- ОТСЛЕЖИВАНИЕ НОВЫХ ДРОНОВ
-- =============================================================================

Workspace.DescendantAdded:Connect(function(obj)

    -- Проверяем только новые Model
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


-- =============================================================================
-- ПРОВЕРКА АКТИВНОСТИ
-- =============================================================================

task.spawn(function()

    while true do

        task.wait(Settings.ActiveCheckInterval)

        if not Settings.DronesEnabled then
            continue
        end

        for drone in pairs(DroneCache) do

            if not drone
                or not drone.Parent
                or not drone:IsDescendantOf(Workspace) then

                unregisterDrone(drone)

            else
                createDroneHighlight(drone)
            end

        end

    end

end)


-- =============================================================================
-- ПОДСВЕТКА ИГРОКОВ
-- =============================================================================

local function updatePlayerHighlight(player)

    if player == LocalPlayer then
        return
    end

    local character = player.Character

    if not character then
        return
    end

    local highlight = character:FindFirstChild(PLAYER_HIGHLIGHT_NAME)

    if not Settings.PlayersEnabled then

        if highlight then
            highlight:Destroy()
        end

        return
    end

    if not highlight then

        highlight = Instance.new("Highlight")
        highlight.Name = PLAYER_HIGHLIGHT_NAME
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = character

    end

    highlight.FillColor = getTeamColor(player)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = Settings.PlayersTransparency
    highlight.OutlineTransparency = 0
end


local function setupPlayer(player)

    if player == LocalPlayer then
        return
    end

    PlayerCache[player] = true

    player.CharacterAdded:Connect(function(character)

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
            player.Character:FindFirstChild(PLAYER_HIGHLIGHT_NAME)

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


-- =============================================================================
-- GUI
-- =============================================================================

local Window = Material3.CreateWindow({
    Name = "DronefrontESP",
    Title = "Dronefront ESP",
    Subtitle = "Optimized ESP",
    Theme = {
        mode = "dark",
        acrylic = false
    }
})


-- =============================================================================
-- ИГРОКИ
-- =============================================================================

local PlayersPage = Window:CreatePage({
    Name = "Игроки",
    Title = "Игроки"
})

local PlayersSection = PlayersPage:CreateSection({
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
    Title = "Прозрачность заливки",
    Min = 0,
    Max = 1,
    Step = 0.1,
    Default = 0.5,

    Callback = function(value)

        Settings.PlayersTransparency = value

        if Settings.PlayersEnabled then

            for player in pairs(PlayerCache) do

                local character = player.Character

                if character then

                    local highlight =
                        character:FindFirstChild(PLAYER_HIGHLIGHT_NAME)

                    if highlight then
                        highlight.FillTransparency = value
                    end

                end

            end

        end

    end
})


-- =============================================================================
-- ДРОНЫ
-- =============================================================================

local DronesPage = Window:CreatePage({
    Name = "Дроны",
    Title = "Дроны"
})

local DronesSection = DronesPage:CreateSection({
    Title = "Подсветка дронов",
    Description = "Только активные дроны. Без названий и дистанции."
})


DronesSection:CreateToggle({
    Title = "Включить подсветку дронов",
    Default = false,

    Callback = function(value)

        Settings.DronesEnabled = value

        for drone in pairs(DroneCache) do

            if value then
                createDroneHighlight(drone)
            else
                removeDroneHighlight(drone)
            end

        end

    end
})


DronesSection:CreateColorPicker({
    Title = "Цвет дронов",
    Default = Color3.fromRGB(255, 115, 0),

    Callback = function(color)

        Settings.DroneColor = color

        if Settings.DronesEnabled then

            for drone in pairs(DroneCache) do

                local highlight =
                    drone:FindFirstChild(DRONE_HIGHLIGHT_NAME)

                if highlight and not getPilot(drone) then
                    highlight.FillColor = color
                end

            end

        end

    end
})


DronesSection:CreateSlider({
    Title = "Прозрачность заливки",
    Min = 0,
    Max = 1,
    Step = 0.1,
    Default = 0.3,

    Callback = function(value)

        Settings.DronesTransparency = value

        if Settings.DronesEnabled then

            for drone in pairs(DroneCache) do

                local highlight =
                    drone:FindFirstChild(DRONE_HIGHLIGHT_NAME)

                if highlight then
                    highlight.FillTransparency = value
                end

            end

        end

    end
})


Window:Notify({
    Content = "Оптимизированный ESP загружен",
    Duration = 3
})