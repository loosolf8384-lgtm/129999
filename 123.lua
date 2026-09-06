-- =============================================================================
-- BASE ENGINE: Gemini Suite (Dronefront Optimized ESP)
-- DEVELOPER/AI: Gemini
-- YEAR: 2026
-- =============================================================================

-- Загрузка Material3 UI библиотеки
local Material3 = loadstring(game:HttpGet("https://raw.githubusercontent.com/xdbobr-jpg/roblox/refs/heads/main/MaterialUI.lua"))()

-- Глобальная таблица настроек скрипта (только подсветка игроков и дронов)
local Cheats_Settings = {
	PlayersEnabled = false,
	PlayersTextEnabled = true,
	PlayersFillTrans = 0.5,
	PlayersOutlineTrans = 0,
	
	DronesEnabled = false,
	DronesTextEnabled = true,
	DronesFillTrans = 0.3,
	DronesOutlineTrans = 0,
	DroneColor = Color3.fromRGB(255, 115, 0),
}

-- Сервисы Roblox
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Camera = Workspace.CurrentCamera

-- Список отслеживаемых моделей дронов (управляются игроками и ботами)
local TargetDronesList = {
	["shahed-136 white"] = true, ["shahed-136 black"] = true, ["gerbera"] = true,
	["fp1"] = true, ["shahed 238"] = true, ["italmas"] = true,
	["molniy"] = true, ["flamingo"] = true, ["kalibr"] = true,
	["geran5"] = true, ["fpv"] = true, ["interceptor"] = true,
	["romaska"] = true, ["newfpv"] = true
}

-- Таблица локализации (Языковые пакеты)
local Localization = {
	ru = {
		Title = "Dronefront ESP Suite", Subtitle = "Оптимизированная версия",
		PlayersPage = "Игроки ESP", PTitle = "Подсветка Пехоты", PDesc = "Отображение игроков сквозь стены.",
		EnableP = "Включить ВХ на Игроков", PText = "Показывать Ники и Дистанцию", PTrans = "Прозрачность заливки",
		
		DronesPage = "Дроны ESP", DTitle = "Подсветка Дронов", DDesc = "Отображение воздушных дронов (игроки и боты) сквозь стены.",
		EnableD = "Включить ВХ на Дроны", DText = "Показывать Названия и Дистанцию", DColor = "Дефолтный цвет дрона", DTrans = "Прозрачность заливки",
		Notify = "Скрипт успешно загружен!"
	},
	en = {
		Title = "Dronefront ESP Suite", Subtitle = "Optimized Build",
		PlayersPage = "Players ESP", PTitle = "Infantry ESP", PDesc = "Display players through walls.",
		EnableP = "Enable Player ESP", PText = "Show Names & Distance", PTrans = "Fill Transparency",
		
		DronesPage = "Drones ESP", DTitle = "Drone ESP", DDesc = "Display aerial drones (players and bots) through walls.",
		EnableD = "Enable Drone ESP", DText = "Show Drone Names & Distance", DColor = "Fallback Drone Color", DTrans = "Fill Transparency",
		Notify = "Script loaded successfully!"
	}
}

-- Вспомогательные функции
local function isTargetDrone(object)
	if object:IsA("Model") and object.Name then
		return TargetDronesList[string.lower(object.Name)] ~= nil
	end
	return false
end

local function getPlayerColor(player)
	if player.Team and player.TeamColor then
		return player.TeamColor.Color
	end
	return Color3.fromRGB(255, 255, 255)
end

local function getValidDronePart(droneModel)
	if droneModel.PrimaryPart and not droneModel.PrimaryPart:IsA("VehicleSeat") then
		return droneModel.PrimaryPart
	end
	local bodyNames = {"base", "main", "body", "chassis", "hull", "part"}
	for _, name in ipairs(bodyNames) do
		local found = droneModel:FindFirstChild(name, true)
		if found and found:IsA("BasePart") and not found:IsA("VehicleSeat") then
			return found
		end
	end
	for _, child in ipairs(droneModel:GetDescendants()) do
		if child:IsA("BasePart") and not child:IsA("VehicleSeat") then
			return child
		end
	end
	return nil
end

local function getDronePilot(droneModel)
	local seat = droneModel:FindFirstChildOfClass("VehicleSeat") or droneModel:FindFirstChild("VehicleSeat", true)
	if seat and seat.Occupant then
		local char = seat.Occupant.Parent
		if char then
			return Players:GetPlayerFromCharacter(char)
		end
	end
	return nil
end

-- Оптимизированный цикл отрисовки ESP (без лагов, с распределением нагрузки)
task.spawn(function()
	while true do
		task.wait(0.2) -- Увеличенный интервал для исключения просадок FPS
		
		-- 1. Обработка Игроков
		if Cheats_Settings.PlayersEnabled then
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and player.Character then
					local char = player.Character
					local highlight = char:FindFirstChild("Gemini_HighlightESP")
					local bbgui = char:FindFirstChild("Gemini_TextESP")
					
					if not highlight then
						highlight = Instance.new("Highlight", char)
						highlight.Name = "Gemini_HighlightESP"
						highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					end
					highlight.FillColor = getPlayerColor(player)
					highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
					highlight.FillTransparency = Cheats_Settings.PlayersFillTrans
					highlight.OutlineTransparency = Cheats_Settings.PlayersOutlineTrans
					
					if Cheats_Settings.PlayersTextEnabled then
						if not bbgui then
							bbgui = Instance.new("BillboardGui", char)
							bbgui.Name = "Gemini_TextESP"
							bbgui.AlwaysOnTop = true
							bbgui.Size = UDim2.new(0, 200, 0, 50)
							bbgui.StudsOffset = Vector3.new(0, 3, 0)
							local label = Instance.new("TextLabel", bbgui)
							label.Name = "ESPText"
							label.Size = UDim2.new(1, 0, 1, 0)
							label.BackgroundTransparency = 1
							label.TextStrokeTransparency = 0
							label.Font = Enum.Font.SourceSansBold
							label.TextSize = 14
						end
						local targetPart = char:FindFirstChild("Head") or char.PrimaryPart
						if targetPart then
							bbgui.Adornee = targetPart
							local dist = math.round((Camera.CFrame.Position - targetPart.Position).Magnitude)
							bbgui.ESPText.Text = player.Name .. " [" .. tostring(dist) .. "m]"
							bbgui.ESPText.TextColor3 = getPlayerColor(player)
						end
					elseif bbgui then
						bbgui:Destroy()
					end
				end
			end
		else
			-- Очистка при выключении
			for _, player in ipairs(Players:GetPlayers()) do
				if player.Character then
					local h = player.Character:FindFirstChild("Gemini_HighlightESP")
					local b = player.Character:FindFirstChild("Gemini_TextESP")
					if h then h:Destroy() end
					if b then b:Destroy() end
				end
			end
		end
		
		-- 2. Обработка Дронов (Игрок + Боты)
		if Cheats_Settings.DronesEnabled then
			for _, obj in ipairs(Workspace:GetChildren()) do
				if isTargetDrone(obj) then
					local dronePart = getValidDronePart(obj)
					if dronePart then
						local highlight = obj:FindFirstChild("Gemini_HighlightESP")
						local bbgui = obj:FindFirstChild("Gemini_TextESP")
						
						local dynamicColor = Cheats_Settings.DroneColor
						local pilot = getDronePilot(obj)
						if pilot then 
							dynamicColor = getPlayerColor(pilot) 
						end
						
						if not highlight then
							highlight = Instance.new("Highlight", obj)
							highlight.Name = "Gemini_HighlightESP"
							highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						end
						highlight.FillColor = dynamicColor
						highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
						highlight.FillTransparency = Cheats_Settings.DronesFillTrans
						highlight.OutlineTransparency = Cheats_Settings.DronesOutlineTrans
						
						if Cheats_Settings.DronesTextEnabled then
							if not bbgui then
								bbgui = Instance.new("BillboardGui", obj)
								bbgui.Name = "Gemini_TextESP"
								bbgui.AlwaysOnTop = true
								bbgui.Size = UDim2.new(0, 250, 0, 50)
								bbgui.StudsOffset = Vector3.new(0, 3, 0)
								local label = Instance.new("TextLabel", bbgui)
								label.Name = "ESPText"
								label.Size = UDim2.new(1, 0, 1, 0)
								label.BackgroundTransparency = 1
								label.TextStrokeTransparency = 0
								label.Font = Enum.Font.RobotoMono
								label.TextSize = 13
							end
							bbgui.Adornee = dronePart
							local dist = math.round((Camera.CFrame.Position - dronePart.Position).Magnitude)
							local ownerTag = pilot and (" [" .. pilot.Name .. "]") or " [Bot]"
							bbgui.ESPText.Text = "🛸 " .. string.upper(obj.Name) .. ownerTag .. " | " .. tostring(dist) .. "m"
							bbgui.ESPText.TextColor3 = dynamicColor
						elseif bbgui then
							bbgui:Destroy()
						end
					end
				end
			end
		else
			-- Очистка при выключении
			for _, obj in ipairs(Workspace:GetChildren()) do
				if isTargetDrone(obj) then
					local h = obj:FindFirstChild("Gemini_HighlightESP")
					local b = obj:FindFirstChild("Gemini_TextESP")
					if h then h:Destroy() end
					if b then b:Destroy() end
				end
			end
		end
	end
end)

-- =============================================================================
-- ИНИЦИАЛИЗАЦИЯ ИНТЕРФЕЙСА (ВЫБОР ЯЗЫКА)
-- =============================================================================

local langWindow = Material3.CreateWindow({
	Name = "GeminiInit",
	Title = "Dronefront Setup",
	Subtitle = "Select Language / Выберите язык",
	Theme = { mode = "dark", acrylic = false }
})

local langPage = langWindow:CreatePage({ Name = "Language", Title = "Language / Язык" })
local langSection = langPage:CreateSection({ Title = "Setup Wizard", Description = "Please choose your preferred language." })

local function BuildMainMenu(ln)
	langWindow:Destroy()
	
	local window = Material3.CreateWindow({
		Name = "DronefrontESP",
		Title = ln.Title,
		Subtitle = ln.Subtitle,
		Theme = { mode = "dark", acrylic = false },
	})

	-- ВКЛАДКА 1: ИГРОКИ ESP
	local playersPage = window:CreatePage({ Name = ln.PlayersPage, Title = ln.PlayersPage })
	local pSection = playersPage:CreateSection({ Title = ln.PTitle, Description = ln.PDesc })

	pSection:CreateToggle({
		Title = ln.EnableP,
		Default = false,
		Callback = function(value) Cheats_Settings.PlayersEnabled = value end
	})

	pSection:CreateToggle({
		Title = ln.PText,
		Default = true,
		Callback = function(value) Cheats_Settings.PlayersTextEnabled = value end
	})

	pSection:CreateSlider({
		Title = ln.PTrans,
		Min = 0, Max = 1, Step = 0.1, Default = 0.5,
		Callback = function(value) Cheats_Settings.PlayersFillTrans = value end
	})

	-- ВКЛАДКА 2: ДРОНЫ ESP
	local dronesPage = window:CreatePage({ Name = ln.DronesPage, Title = ln.DronesPage })
	local dSection = dronesPage:CreateSection({ Title = ln.DTitle, Description = ln.DDesc })

	dSection:Create