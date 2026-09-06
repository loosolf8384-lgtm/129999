-- =============================================================================
-- DRONEFRONT ESP SUITE (Advanced Deep Scan & Remote Tracking)
-- =============================================================================

-- Загрузка Material3 UI библиотеки
local Material3 = loadstring(game:HttpGet("https://raw.githubusercontent.com/xdbobr-jpg/roblox/refs/heads/main/MaterialUI.lua"))()

-- Настройки функций
local Settings = {
	PlayersEnabled = false,
	PlayersText = true,
	PlayersTransparency = 0.5,
	
	DronesEnabled = false,
	DronesText = true,
	DronesTransparency = 0.3,
	DroneColor = Color3.fromRGB(255, 115, 0)
}

-- Сервисы
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

-- Расширенный список папок и контейнеров для поиска дронов в Dronefront
local DroneContainers = {
	Workspace,
}

-- Инициализация дополнительных папок, если они есть в игре
task.spawn(function()
	pcall(function()
		for _, child in ipairs(Workspace:GetChildren()) do
			if child:IsA("Folder") or child:IsA("Model") then
				local nameLower = string.lower(child.Name)
				if nameLower:find("drone") or nameLower:find("uav") or nameLower:find("missile") or nameLower:find("spawn") or nameLower:find("team") or nameLower:find("vehicle") or nameLower:find("entity") then
					table.insert(DroneContainers, child)
				end
			end
		end
	end)
end)

-- Проверка объекта на принадлежность к дронам (по именам или содержимому)
local function isDroneModel(obj)
	if not obj:IsA("Model") then return false end
	local name = string.lower(obj.Name)
	
	-- Проверяем ключевые слова дронов в Dronefront
	if name:find("shahed") or name:find("gerber") or name:find("fpv") or name:find("drone") or 
	   name:find("italmas") or name:find("molniy") or name:find("flamingo") or name:find("kalibr") or 
	   name:find("geran") or name:find("interceptor") or name:find("romaska") or name:find("uav") or 
	   name:find("missile") or name:find("loitering") then
		return true
	end
	
	-- Если у модели есть сиденье или мотор/пропеллер, считаем объектом беспилотника
	if obj:FindFirstChildOfClass("VehicleSeat") or obj:FindFirstChildOfClass("Seat") then
		return true
	end
	
	return false
end

-- Получение цвета команды игрока
local function getTeamColor(player)
	if player and player.Team and player.TeamColor then
		return player.TeamColor.Color
	end
	return Color3.fromRGB(255, 255, 255)
end

-- Поиск основной детали дрона
local function getDronePart(drone)
	if drone.PrimaryPart and not drone.PrimaryPart:IsA("VehicleSeat") and not drone.PrimaryPart:IsA("Seat") then
		return drone.PrimaryPart
	end
	for _, part in ipairs(drone:GetDescendants()) do
		if part:IsA("BasePart") and not part:IsA("VehicleSeat") and not part:IsA("Seat") then
			return part
		end
	end
	return drone:FindFirstChildWhichIsA("BasePart")
end

-- Поиск удаленного оператора/пилота (если игрок сидит на базе или управляет удаленно)
local function getActivePilot(drone)
	-- 1. Проверяем стандартное сиденье внутри дрона
	local seat = drone:FindFirstChildOfClass("VehicleSeat") or drone:FindFirstChildOfClass("Seat") or drone:FindFirstChild("VehicleSeat", true)
	if seat and seat.Occupant then
		local char = seat.Occupant.Parent
		if char then
			local player = Players:GetPlayerFromCharacter(char)
			if player then return player end
		end	
	end
	
	-- 2. Проверяем кастомные атрибуты или वैल्यू (Value) связи с игроком (для удаленного управления с базы)
	for _, desc in ipairs(drone:GetDescendants()) do
		if desc:IsA("ObjectValue") and desc.Value and desc.Value:IsA("Player") then
			return desc.Value
		elseif desc:IsA("StringValue") and desc.Value ~= "" then
			local foundPlayer = Players:FindFirstChild(desc.Value)
			if foundPlayer then return foundPlayer end
		end
	end
	
	return nil
end

-- Сканирование всех возможных мест появления дронов
local function getAllDrones()
	local drones = {}
	local checked = {}
	
	for _, container in ipairs(DroneContainers) do
		if container and container.Parent then
			-- Проверяем прямое содержимое и потомков первого уровня для максимальной скорости
			for _, obj in ipairs(container:GetChildren()) do
				if not checked[obj] then
					checked[obj] = true
					if isDroneModel(obj) then
						table.insert(drones, obj)
					end
				end
			end
			-- Глубокий поиск для вложенных папок баз
			for _, obj in ipairs(container:GetDescendants()) do
				if not checked[obj] and obj:IsA("Model") then
					checked[obj] = true
					if isDroneModel(obj) then
						table.insert(drones, obj)
					end
				end
			end
		end
	end
	
	return drones
end

-- Основной оптимизированный цикл отрисовки (работает плавно и без лагов)
task.spawn(function()
	while true do
		task.wait(0.2)
		
		-- 1. Подсветка игроков (пехота / операторы на базе)
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
							billboard.Label.Text = player.Name .. " (Оператор) [" .. distance .. "m]"
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
		
		-- 2. Подсветка дронов (включая управляемые удаленно с базы и ботов)
		if Settings.DronesEnabled then
			local activeDrones = getAllDrones()
			for _, obj in ipairs(activeDrones) do
				local dronePart = getDronePart(obj)
				if dronePart then
					local highlight = obj:FindFirstChild("Dronefront_DroneESP")
					local billboard = obj:FindFirstChild("Dronefront_DroneText")
					
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
					
					if Settings.DronesText then
						if not billboard then
							billboard = Instance.new("BillboardGui", obj)
							billboard.Name = "Dronefront_DroneText"
							billboard.AlwaysOnTop = true
							billboard.Size = UDim2.new(0, 240, 0, 40)
							billboard.StudsOffset = Vector3.new(0, 3, 0)
							
							local textLabel = Instance.new("TextLabel", billboard)
							textLabel.Name = "Label"
							textLabel.Size = UDim2.new(1, 0, 1, 0)
							textLabel.BackgroundTransparency = 1
							textLabel.TextStrokeTransparency = 0
							textLabel.Font = Enum.Font.RobotoMono
							textLabel.TextSize = 13
						end
						
						billboard.Adornee = dronePart
						local distance = math.round((Camera.CFrame.Position - dronePart.Position).Magnitude)
						local controlTag = pilot and (" [Пилот: " .. pilot.Name .. "]") or " [Бот/Удаленно]"
						billboard.Label.Text = "🛸 " .. string.upper(obj.Name) .. controlTag .. " | " .. distance .. "m"
						billboard.Label.TextColor3 = droneColor
					elseif billboard then
						billboard:Destroy()
					end
				end
			end
		else
			-- Очистка при выключении
			for _, container in ipairs(DroneContainers) do
				if container and container.Parent then
					for _, obj in ipairs(container:GetDescendants()) do
						if obj:IsA("Model") then
							local h = obj:FindFirstChild("Dronefront_DroneESP")
							local b = obj:FindFirstChild("Dronefront_DroneText")
							if h then h:Destroy() end
							if b then b:Destroy() end
						end
					end
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
	Subtitle = "Players & Drones Tracker (Pro)",
	Theme = { mode = "dark", acrylic = false }
})

-- Вкладка Игроков
local PlayersPage = Window:CreatePage({ Name = "Игроки", Title = "Игроки" })
local PlayersSection = PlayersPage:CreateSection({ Title = "Подсветка игроков", Description = "Отображение пехоты и операторов на базе." })

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
local DronesSection = DronesPage:CreateSection({ Title = "Подсветка дронов", Description = "Отображение дронов, ботов и техники удаленного управления." })

DronesSection:CreateToggle({
	Title = "Включить ВХ на дроны",
	Default = false,
	Callback = function(value)
		Settings.DronesEnabled = value
	end
})

DronesSection:CreateToggle({
	Title = "Показывать название и пилота",
	Default = true,
	Callback = function(value)
		Settings.DronesText = value
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
	Content = "Скрипт обновлен: добавлено сканирование удаленных дронов!",
	Duration = 4
})