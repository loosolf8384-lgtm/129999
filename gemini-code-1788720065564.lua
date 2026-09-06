-- =============================================================================
-- DRONEFRONT ESP SUITE (Optimized Lua Script for Roblox)
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

-- Список дронов в игре (включая управляемые игроками и ботами)
local DroneList = {
	["shahed-136 white"] = true, ["shahed-136 black"] = true, ["gerbera"] = true,
	["fp1"] = true, ["shahed 238"] = true, ["italmas"] = true,
	["molniy"] = true, ["flamingo"] = true, ["kalibr"] = true,
	["geran5"] = true, ["fpv"] = true, ["interceptor"] = true,
	["romaska"] = true, ["newfpv"] = true
}

-- Проверка дрона
local function isDrone(object)
	if object:IsA("Model") and object.Name then
		return DroneList[string.lower(object.Name)] ~= nil
	end
	return false
end

-- Получение цвета команды игрока
local function getTeamColor(player)
	if player.Team and player.TeamColor then
		return player.TeamColor.Color
	end
	return Color3.fromRGB(255, 255, 255)
end

-- Поиск основной части дрона
local function getDronePart(drone)
	if drone.PrimaryPart and not drone.PrimaryPart:IsA("VehicleSeat") then
		return drone.PrimaryPart
	end
	for _, part in ipairs(drone:GetDescendants()) do
		if part:IsA("BasePart") and not part:IsA("VehicleSeat") then
			return part
		end
	end
	return nil
end

-- Определение пилота дрона (игрок или бот)
local function getDronePilot(drone)
	local seat = drone:FindFirstChildOfClass("VehicleSeat") or drone:FindFirstChild("VehicleSeat", true)
	if seat and seat.Occupant then
		local char = seat.Occupant.Parent
		if char then
			return Players:GetPlayerFromCharacter(char)
		end
	end
	return nil
end

-- Оптимизированный цикл подсветки (выполняется реже, чтобы исключить лаги)
task.spawn(function()
	while true do
		task.wait(0.25)
		
		-- 1. Подсветка игроков
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
		
		-- 2. Подсветка дронов (игрок + боты)
		if Settings.DronesEnabled then
			for _, obj in ipairs(Workspace:GetChildren()) do
				if isDrone(obj) then
					local dronePart = getDronePart(obj)
					if dronePart then
						local highlight = obj:FindFirstChild("Dronefront_DroneESP")
						local billboard = obj:FindFirstChild("Dronefront_DroneText")
						
						local pilot = getDronePilot(obj)
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
								billboard.Size = UDim2.new(0, 220, 0, 40)
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
							local pilotText = pilot and (" [" .. pilot.Name .. "]") or " [Bot]"
							billboard.Label.Text = "🛸 " .. string.upper(obj.Name) .. pilotText .. " | " .. distance .. "m"
							billboard.Label.TextColor3 = droneColor
						elseif billboard then
							billboard:Destroy()
						end
					end
				end
			end
		else
			for _, obj in ipairs(Workspace:GetChildren()) do
				if isDrone(obj) then
					local h = obj:FindFirstChild("Dronefront_DroneESP")
					local b = obj:FindFirstChild("Dronefront_DroneText")
					if h then h:Destroy() end
					if b then b:Destroy() end
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
	Subtitle = "Players & Drones Tracker",
	Theme = { mode = "dark", acrylic = false }
})

-- Вкладка Игроков
local PlayersPage = Window:CreatePage({ Name = "Игроки", Title = "Игроки" })
local PlayersSection = PlayersPage:CreateSection({ Title = "Подсветка игроков", Description = "Включение отображения пехоты сквозь стены." })

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
local DronesSection = DronesPage:CreateSection({ Title = "Подсветка дронов", Description = "Отображение дронов игроков и ботов." })

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
	Content = "Скрипт успешно запущен!",
	Duration = 4
})