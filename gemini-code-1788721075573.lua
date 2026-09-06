-- =============================================================================
-- DRONEFRONT ESP SUITE (Ultra-Optimized & Clean)
-- =============================================================================

-- Загрузка Material3 UI библиотеки
local Material3 = loadstring(game:HttpGet("https://raw.githubusercontent.com/xdbobr-jpg/roblox/refs/heads/main/MaterialUI.lua"))()

-- Настройки функций
local Settings = {
	PlayersEnabled = false,
	PlayersText = true,
	PlayersTransparency = 0.5,
	
	DronesEnabled = false,
	DronesTransparency = 0.3,
	DroneColor = Color3.fromRGB(255, 115, 0)
}

-- Сервисы
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

-- Кэш для дронов, чтобы не нагружать процессор постоянным сканированием
local DroneCache = {}
local LastCacheUpdate = 0

-- Получение цвета команды игрока
local function getTeamColor(player)
	if player and player.Team and player.TeamColor then
		return player.TeamColor.Color
	end
	return Color3.fromRGB(255, 255, 255)
end

-- Быстрая проверка модели на принадлежность к дронам
local function isDroneModel(obj)
	if not obj:IsA("Model") then return false end
	local name = string.lower(obj.Name)
	return name:find("shahed") or name:find("gerber") or name:find("fpv") or name:find("drone") or 
	       name:find("italmas") or name:find("molniy") or name:find("flamingo") or name:find("kalibr") or 
	       name:find("geran") or name:find("interceptor") or name:find("romaska") or name:find("uav") or 
	       name:find("missile") or name:find("loitering") or obj:FindFirstChildOfClass("VehicleSeat")
end

-- Поиск пилота (учитывает удаленное управление с базы)
local function getActivePilot(drone)
	local seat = drone:FindFirstChildOfClass("VehicleSeat") or drone:FindFirstChildOfClass("Seat")
	if seat and seat.Occupant then
		local char = seat.Occupant.Parent
		if char then
			local player = Players:GetPlayerFromCharacter(char)
			if player then return player end
		end	
	end
	
	for _, desc in ipairs(drone:GetGetChildren and drone:GetChildren() or {}) do
		if desc:IsA("ObjectValue") and desc.Value and desc.Value:IsA("Player") then
			return desc.Value
		end
	end
	return nil
end

-- Функция обновления кэша дронов (работает раз в 2 секунды, чтобы не лагало)
local function updateDroneCache()
	local currentTime = tick()
	if currentTime - LastCacheUpdate < 2 then return DroneCache end
	LastCacheUpdate = currentTime
	
	table.clear(DroneCache)
	for _, obj in ipairs(Workspace:GetChildren()) do
		if isDroneModel(obj) then
			table.insert(DroneCache, obj)
		else
			-- Проверяем папки первого уровня (если дроны хранятся внутри папок)
			if obj:IsA("Folder") or obj:IsA("Model") then
				for _, subObj in ipairs(obj:GetChildren()) do
					if isDroneModel(subObj) then
						table.insert(DroneCache, subObj)
					end
				end
			end
		end
	end
	return DroneCache
end

-- Оптимизированный фоновый поток
task.spawn(function()
	while true do
		task.wait(0.4) -- Увеличенный интервал для полной плавности игры
		
		-- 1. Обработка Игроков
		if Settings.PlayersEnabled then
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and player.Character then
					local char = player.Character
					local highlight = char:FindFirstChild("Dronefront_PlayerESP")
					local billboard = char:FindFirstChild("Dronefront_PlayerText")
					
					if not highlight then
						highlight = Instance.new("Highlight", char)
						highlight.Name = "Dronefront_PlayerESP"
						highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					end
					
					highlight.FillColor = getTeamColor(player)
					highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
					highlight.FillTransparency = Settings.PlayersTransparency
					
					if Settings.PlayersText then
						if not billboard then
							billboard = Instance.new("BillboardGui", char)
							billboard.Name = "Dronefront_PlayerText"
							billboard.AlwaysOnTop = true
							billboard.Size = UDim2.new(0, 200, 0, 40)
							billboard.StudsOffset = Vector3.new(0, 3, 0)
							
							local textLabel = Instance.new("TextLabel", billboard)
							textLabel.Name = "Label"
							textLabel.Size = UDim2.new(1, 0, 1, 0)
							textLabel.BackgroundTransparency = 1
							textLabel.TextStrokeTransparency = 0
							textLabel.Font = Enum.Font.SourceSansBold
							textLabel.TextSize = 14
						end
						
						local head = char:FindFirstChild("Head") or char.PrimaryPart
						if head then
							billboard.Adornee = head
							local distance = math.round((Camera.CFrame.Position - head.Position).Magnitude)
							billboard.Label.Text = player.Name .. " [" .. distance .. "m]"
							billboard.Label.TextColor3 = getTeamColor(player)
						end
					elseif billboard then
						billboard:Destroy()
					end
				end
			end
		else
			for _, player in ipairs(Players:GetPlayers()) do
				if player.Character then
					local h = player.Character:FindFirstChild("Dronefront_PlayerESP")
					local b = player.Character:FindFirstChild("Dronefront_PlayerText")
					if h then h:Destroy() end
					if b then b:Destroy() end
				end
			end
		end
		
		-- 2. Обработка Дронов (БЕЗ ТЕКСТА, только подсветка)
		if Settings.DronesEnabled then
			local drones = updateDroneCache()
			for _, obj in ipairs(drones) do
				if obj and obj.Parent then
					local highlight = obj:FindFirstChild("Dronefront_DroneESP")
					local pilot = getActivePilot(obj)
					local droneColor = pilot and getTeamColor(pilot) or Settings.DroneColor
					
					if not highlight then
						highlight = Instance.new("Highlight", obj)
						highlight.Name = "Dronefront_DroneESP"
						highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					end
					
					highlight.FillColor = droneColor
					highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
					highlight.FillTransparency = Settings.DronesTransparency
				end
			end
		else
			-- Очистка подсветки дронов при выключении
			for _, obj in ipairs(DroneCache) do
				if obj then
					local h = obj:FindFirstChild("Dronefront_DroneESP")
					if h then h:Destroy() end
				end
			end
		end
	end
end)

-- =============================================================================
-- ГРАФИЧЕСКИЙ ИНТЕРФЕЙС (GUI)
-- =============================================================================

local Window = Material3.CreateWindow({
	Name = "DronefrontESP",
	Title = "Dronefront ESP Suite",
	Subtitle = "Optimized Edition",
	Theme = { mode = "dark", acrylic = false }
})

-- Вкладка Игроков
local PlayersPage = Window:CreatePage({ Name = "Игроки", Title = "Игроки" })
local PlayersSection = PlayersPage:CreateSection({ Title = "Подсветка игроков", Description = "Отображение пехоты сквозь стены." })

PlayersSection:CreateToggle({
	Title = "Включить ВХ на игроков",
	Default = false,
	Callback = function(value)
		Settings.PlayersEnabled = value
	end
})

PlayersSection:CreateToggle({
	Title = "Показывать ник и дистанцию",
	Default = true,
	Callback = function(value)
		Settings.PlayersText = value
	end
})

PlayersSection:CreateSlider({
	Title = "Прозрачность заливки",
	Min = 0, Max = 1, Step = 0.1, Default = 0.5,
	Callback = function(value)
		Settings.PlayersTransparency = value
	end
})

-- Вкладка Дронов
local DronesPage = Window:CreatePage({ Name = "Дроны", Title = "Дроны" })
local DronesSection = DronesPage:CreateSection({ Title = "Подсветка дронов", Description = "Отображение дронов и удаленной техники без лишнего текста." })

DronesSection:CreateToggle({
	Title = "Включить ВХ на дроны",
	Default = false,
	Callback = function(value)
		Settings.DronesEnabled = value
	end
})

DronesSection:CreateColorPicker({
	Title = "Цвет дронов (по умолчанию)",
	Default = Color3.fromRGB(255, 115, 0),
	Callback = function(color)
		Settings.DroneColor = color
	end
})

DronesSection:CreateSlider({
	Title = "Прозрачность заливки дронов",
	Min = 0, Max = 1, Step = 0.1, Default = 0.3,
	Callback = function(value)
		Settings.DronesTransparency = value
	end
})

Window:Notify({
	Content = "Оптимизированный скрипт загружен без лагов!",
	Duration = 4
})