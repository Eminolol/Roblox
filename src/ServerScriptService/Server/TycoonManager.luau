--!strict
-- TycoonManager.luau
-- Constructor y gestor físico del Tycoon de 3 pisos: Cintas, Droppers, Upgraders Láser y Botones.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TycoonConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TycoonConfig"))
local DataStoreManager = require(script.Parent:FindFirstChild("DataStoreManager") or script.Parent:WaitForChild("DataStoreManager"))

local TycoonManager = {}

-- Constantes de diseño
local BASE_ORIGIN = Vector3.new(30, 0.5, 0)
local FLOOR_HEIGHT = 16
local CONVEYOR_SPEED = 18

type ActiveDropper = {
	Model: Model,
	Interval: number,
	BaseValue: number,
	AccentColor: Color3,
	TierName: string,
	Running: boolean,
}

local activeDroppers: { [string]: ActiveDropper } = {}
local activeButtons: { [string]: Model } = {}
local tycoonModel: Model

--------------------------------------------------------------------
-- FUNCIONES DE UTILIDAD (SFX y VFX)
--------------------------------------------------------------------
local function playSound(soundId: string?, parent: Instance, volume: number?): Sound?
	if not TycoonConfig.EnableSounds or not soundId or soundId == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.8
	sound.RollOffMaxDistance = 90
	sound.RollOffMinDistance = 12
	sound.Parent = parent
	pcall(function()
		sound:Play()
	end)
	Debris:AddItem(sound, 3)
	return sound
end

local function createNeonPart(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = false -- Decoraciones de neón no bloquean el paso del jugador
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Parent = parent
	return part
end

local function spawnBurstParticles(position: Vector3, color: Color3)
	local emitterPart = Instance.new("Part")
	emitterPart.Size = Vector3.new(0.5, 0.5, 0.5)
	emitterPart.Position = position
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.Transparency = 1
	emitterPart.Parent = workspace

	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = ColorSequence.new(color, Color3.fromRGB(255, 255, 255))
	burst.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0)})
	burst.Speed = NumberRange.new(9, 18)
	burst.Lifetime = NumberRange.new(0.4, 0.8)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Parent = emitterPart
	burst:Emit(35)

	Debris:AddItem(emitterPart, 1.2)
end

local function showFloatingText(position: Vector3, text: string, color: Color3)
	local bill = Instance.new("BillboardGui")
	bill.Size = UDim2.new(0, 150, 0, 50)
	bill.StudsOffset = Vector3.new(0, 1, 0)
	bill.AlwaysOnTop = true

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = bill

	local anchor = Instance.new("Part")
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.Anchored = true
	anchor.Position = position + Vector3.new(math.random(-1, 1), 1, math.random(-1, 1))
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Parent = workspace
	bill.Parent = anchor

	local tween = TweenService:Create(
		bill,
		TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffset = Vector3.new(0, 5, 0) }
	)
	tween:Play()

	task.delay(1.1, function()
		anchor:Destroy()
	end)
end

--------------------------------------------------------------------
-- CINTAS TRANSPORTADORAS Y COLECTORES DE VENTA
--------------------------------------------------------------------
local function createConveyorSystem(floorNum: number, position: Vector3): (Part, Part)
	local conveyorModel = Instance.new("Model")
	conveyorModel.Name = "Conveyor_Floor" .. floorNum
	conveyorModel.Parent = tycoonModel

	-- Cinta
	local conv = Instance.new("Part")
	conv.Name = "Belt"
	conv.Size = Vector3.new(6.4, 1.2, 26)
	conv.Position = position + Vector3.new(0, 1.1, 0)
	conv.Anchored = true
	conv.Material = Enum.Material.DiamondPlate
	conv.Color = Color3.fromRGB(20, 22, 26)
	conv.Friction = 0.95
	conv.Parent = conveyorModel

	conv.AssemblyLinearVelocity = Vector3.new(0, 0, CONVEYOR_SPEED)
	RunService.Heartbeat:Connect(function()
		if conv and conv.Parent then
			conv.AssemblyLinearVelocity = Vector3.new(0, 0, CONVEYOR_SPEED)
		end
	end)

	-- Barandillas con luces
	local function makeRail(offsetX: number)
		local rail = Instance.new("Part")
		rail.Size = Vector3.new(0.6, 2.4, 26)
		rail.Position = conv.Position + Vector3.new(offsetX, 0.6, 0)
		rail.Anchored = true
		rail.Material = Enum.Material.Metal
		rail.Color = Color3.fromRGB(45, 49, 58)
		rail.Parent = conveyorModel

		createNeonPart("RailLight", Vector3.new(0.2, 0.4, 26), rail.Position + Vector3.new(offsetX > 0 and -0.25 or 0.25, 0.8, 0), Color3.fromRGB(0, 240, 255), conveyorModel)
	end
	makeRail(-3.4)
	makeRail(3.4)

	-- Recolector / Desintegrador de Venta al final (+Z)
	local collector = Instance.new("Part")
	collector.Name = "Collector_Floor" .. floorNum
	collector.Size = Vector3.new(7.2, 1.4, 5.5)
	collector.Position = conv.Position + Vector3.new(0, 0.1, 15.5)
	collector.Anchored = true
	collector.Material = Enum.Material.Neon
	collector.Color = Color3.fromRGB(0, 255, 160)
	collector.Parent = conveyorModel

	-- Cartel de venta
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 160, 0, 45)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.Parent = collector

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "VENTA PISO " .. floorNum
	label.TextColor3 = Color3.fromRGB(85, 239, 196)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui

	-- Lógica de cobro
	collector.Touched:Connect(function(hit)
		if hit:GetAttribute("IsTycoonOre") == true then
			hit:SetAttribute("IsTycoonOre", false)

			local val = hit:GetAttribute("Value") or 10
			local tierName = hit:GetAttribute("TierName") or "Mineral"
			local oreColor = hit.Color

			-- Sonido y efectos
			playSound(TycoonConfig.Sounds.Sell, collector, 0.8)
			spawnBurstParticles(collector.Position + Vector3.new(0, 2, 0), oreColor)
			showFloatingText(collector.Position, "+$" .. tostring(val) .. " (" .. tierName .. ")", oreColor)

			-- Sumar dinero a los jugadores
			for _, player in ipairs(Players:GetPlayers()) do
				DataStoreManager.AddMoney(player, val)
			end

			-- Desintegrar y destruir
			local tween = TweenService:Create(
				hit,
				TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1 }
			)
			tween:Play()
			tween.Completed:Connect(function()
				hit:Destroy()
			end)
		end
	end)

	return conv, collector
end

--------------------------------------------------------------------
-- CONSTRUCCIÓN DE DROPPER
--------------------------------------------------------------------
local function buildDropper(item: TycoonConfig.TycoonItem, conveyorPart: Part, offsetZ: number)
	if activeDroppers[item.Id] then
		return
	end

	local dropperModel = Instance.new("Model")
	dropperModel.Name = item.Id
	dropperModel.Parent = tycoonModel

	local accent = item.AccentColor or Color3.fromRGB(0, 200, 255)
	local headPos = conveyorPart.Position + Vector3.new(0, 7.5, offsetZ)

	-- Pilar
	local pilar = Instance.new("Part")
	pilar.Size = Vector3.new(2, 9, 2)
	pilar.Position = headPos + Vector3.new(0, -3.5, -3)
	pilar.Anchored = true
	pilar.Material = Enum.Material.Metal
	pilar.Color = Color3.fromRGB(36, 40, 48)
	pilar.Parent = dropperModel

	-- Anillos de energía
	for i = 1, 3 do
		createNeonPart("Ring", Vector3.new(2.4, 0.35, 2.4), pilar.Position + Vector3.new(0, (i - 2) * 2.5, 0), accent, dropperModel)
	end

	-- Cabezal Neón
	local head = createNeonPart("Head", Vector3.new(3.8, 1.8, 3.8), headPos, accent, dropperModel)

	-- Boquilla
	local nozzle = Instance.new("Part")
	nozzle.Size = Vector3.new(2.4, 0.8, 2.4)
	nozzle.Position = head.Position - Vector3.new(0, 1.2, 0)
	nozzle.Anchored = true
	nozzle.Material = Enum.Material.Metal
	nozzle.Color = Color3.fromRGB(20, 20, 25)
	nozzle.Parent = dropperModel

	-- Holograma con nombre
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 180, 0, 45)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = item.Name
	label.TextColor3 = accent
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui

	local dropperData: ActiveDropper = {
		Model = dropperModel,
		Interval = item.Interval or 2,
		BaseValue = item.BaseValue or 15,
		AccentColor = accent,
		TierName = item.Name,
		Running = true,
	}
	activeDroppers[item.Id] = dropperData

	-- Bucle de dropeo autónomo
	task.spawn(function()
		while dropperData.Running and dropperModel.Parent do
			task.wait(dropperData.Interval)

			if not nozzle or not nozzle.Parent then
				break
			end

			-- Flash visual en el cabezal neón al producir mineral
			head.Color = Color3.fromRGB(255, 255, 255)

			TweenService:Create(
				head,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Color = accent }
			):Play()

			-- Crear el mineral
			local ore = Instance.new("Part")
			ore.Name = "Ore_" .. item.Id
			ore.Size = Vector3.new(1.8, 1.8, 1.8)
			ore.Position = nozzle.Position - Vector3.new(0, 1.2, 0)
			ore.Material = Enum.Material.Neon
			ore.Color = accent
			ore.Shape = Enum.PartType.Block
			ore.CanCollide = true
			ore.Anchored = false
			ore.CustomPhysicalProperties = PhysicalProperties.new(1.3, 0.35, 0.2, 1, 1)

			ore:SetAttribute("IsTycoonOre", true)
			ore:SetAttribute("Value", dropperData.BaseValue)
			ore:SetAttribute("TierName", dropperData.TierName)

			-- Aura de chispas
			local sparks = Instance.new("ParticleEmitter")
			sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			sparks.Color = ColorSequence.new(accent, Color3.fromRGB(255, 255, 255))
			sparks.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0)})
			sparks.Rate = 14
			sparks.Speed = NumberRange.new(1.5, 3)
			sparks.Lifetime = NumberRange.new(0.4, 0.8)
			sparks.Parent = ore

			ore.Parent = tycoonModel
			Debris:AddItem(ore, 26)
		end
	end)
end

--------------------------------------------------------------------
-- CONSTRUCCIÓN DE UPGRADERS LÁSER
--------------------------------------------------------------------
local function buildUpgrader(item: TycoonConfig.TycoonItem, conveyorPart: Part, offsetZ: number)
	local model = Instance.new("Model")
	model.Name = item.Id
	model.Parent = tycoonModel

	local laserColor = item.LaserColor or Color3.fromRGB(0, 255, 200)
	local archPos = conveyorPart.Position + Vector3.new(0, 4.2, offsetZ)

	-- Postes del arco
	local postL = Instance.new("Part")
	postL.Size = Vector3.new(1.2, 8, 1.2)
	postL.Position = archPos + Vector3.new(-3.6, 0, 0)
	postL.Anchored = true
	postL.Material = Enum.Material.Metal
	postL.Color = Color3.fromRGB(36, 40, 48)
	postL.Parent = model

	local postR = Instance.new("Part")
	postR.Size = Vector3.new(1.2, 8, 1.2)
	postR.Position = archPos + Vector3.new(3.6, 0, 0)
	postR.Anchored = true
	postR.Material = Enum.Material.Metal
	postR.Color = Color3.fromRGB(36, 40, 48)
	postR.Parent = model

	local topBeam = createNeonPart("TopBeam", Vector3.new(8.4, 1.2, 1.2), archPos + Vector3.new(0, 4, 0), laserColor, model)

	-- Láser / Campo de escaneo
	local laser = Instance.new("Part")
	laser.Name = "LaserSensor"
	laser.Size = Vector3.new(6.4, 7, 0.4)
	laser.Position = archPos
	laser.Anchored = true
	laser.CanCollide = false
	laser.Material = Enum.Material.ForceField
	laser.Color = laserColor
	laser.Transparency = 0.35
	laser.Parent = model

	-- Cartel informativo
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 170, 0, 40)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = topBeam

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = item.Name .. " (" .. tostring(item.Multiplier or 1.5) .. "x)"
	label.TextColor3 = laserColor
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui

	-- Lógica del escáner multiplicador
	local multiplier = item.Multiplier or 1.5
	local upgraderTag = "Upgraded_" .. item.Id

	laser.Touched:Connect(function(hit)
		if hit:GetAttribute("IsTycoonOre") == true and not hit:GetAttribute(upgraderTag) then
			hit:SetAttribute(upgraderTag, true)

			local currentVal = hit:GetAttribute("Value") or 10
			local newVal = math.floor(currentVal * multiplier)
			hit:SetAttribute("Value", newVal)

			-- Efecto visual: cambiar color del mineral hacia el color del láser
			hit.Color = laserColor
			playSound(TycoonConfig.Sounds.LaserUpgrade, laser, 0.6)
			spawnBurstParticles(hit.Position, laserColor)
			showFloatingText(hit.Position, "x" .. tostring(multiplier) .. "!", laserColor)
		end
	end)
end

--------------------------------------------------------------------
-- CONSTRUCCIÓN DE ESTRUCTURAS, PAREDES Y ESCALERAS
--------------------------------------------------------------------
local function buildStructure(item: TycoonConfig.TycoonItem)
	local model = Instance.new("Model")
	model.Name = item.Id
	model.Parent = tycoonModel

	if item.Id == "Walls_Floor1" then
		-- Paredes y ventanas Piso 1
		local wallBack = Instance.new("Part")
		wallBack.Size = Vector3.new(24, FLOOR_HEIGHT, 1)
		wallBack.Position = BASE_ORIGIN + Vector3.new(0, FLOOR_HEIGHT / 2, -19)
		wallBack.Anchored = true
		wallBack.Material = Enum.Material.Metal
		wallBack.Color = Color3.fromRGB(30, 32, 38)
		wallBack.Parent = model

		local wallLeft = Instance.new("Part")
		wallLeft.Size = Vector3.new(1, FLOOR_HEIGHT, 38)
		wallLeft.Position = BASE_ORIGIN + Vector3.new(-12, FLOOR_HEIGHT / 2, 0)
		wallLeft.Anchored = true
		wallLeft.Material = Enum.Material.Glass
		wallLeft.Color = Color3.fromRGB(20, 40, 60)
		wallLeft.Transparency = 0.4
		wallLeft.Parent = model

		createNeonPart("NeonWallTrim", Vector3.new(1, 0.4, 38), BASE_ORIGIN + Vector3.new(-12, FLOOR_HEIGHT, 0), Color3.fromRGB(0, 240, 255), model)

	elseif item.Id == "Stairs_Floor2" then
		-- Escalera conectando Piso 1 con Piso 2 por el lateral derecho
		local stepCount = 20
		local startPos = BASE_ORIGIN + Vector3.new(9, 0, 8)
		local endPos = BASE_ORIGIN + Vector3.new(9, FLOOR_HEIGHT, -6)

		for i = 1, stepCount do
			local alpha = i / stepCount
			local stepPos = startPos:Lerp(endPos, alpha)
			local step = Instance.new("Part")
			step.Size = Vector3.new(4.5, 0.8, 1.4)
			step.Position = stepPos
			step.Anchored = true
			step.Material = Enum.Material.DiamondPlate
			step.Color = Color3.fromRGB(40, 45, 55)
			step.Parent = model

			createNeonPart("StepGlow", Vector3.new(4.6, 0.2, 0.2), stepPos + Vector3.new(0, 0.4, 0.6), Color3.fromRGB(0, 255, 180), model)
		end

		-- Plataforma de descanso superior para poder pararse arriba con total comodidad
		local landing = Instance.new("Part")
		landing.Name = "Landing_Floor2"
		landing.Size = Vector3.new(5.5, 1.2, 6)
		landing.Position = BASE_ORIGIN + Vector3.new(9, FLOOR_HEIGHT, -9)
		landing.Anchored = true
		landing.Material = Enum.Material.DiamondPlate
		landing.Color = Color3.fromRGB(40, 45, 55)
		landing.Parent = model

	elseif item.Id == "Floor2_Base" then
		-- Suelo del Piso 2 con HUECO DE ESCALERA despejado (evita chocar con la cabeza al subir)
		-- Sección izquierda y central (cinta y droppers)
		local floorLeft = Instance.new("Part")
		floorLeft.Name = "Floor2_Left"
		floorLeft.Size = Vector3.new(16, 1.2, 38)
		floorLeft.Position = BASE_ORIGIN + Vector3.new(-4, FLOOR_HEIGHT, 0)
		floorLeft.Anchored = true
		floorLeft.Material = Enum.Material.DiamondPlate
		floorLeft.Color = Color3.fromRGB(28, 30, 36)
		floorLeft.Parent = model

		-- Sección derecha frontal (frente al hueco de escalera)
		local floorRightFront = Instance.new("Part")
		floorRightFront.Name = "Floor2_RightFront"
		floorRightFront.Size = Vector3.new(8, 1.2, 14)
		floorRightFront.Position = BASE_ORIGIN + Vector3.new(8, FLOOR_HEIGHT, 12)
		floorRightFront.Anchored = true
		floorRightFront.Material = Enum.Material.DiamondPlate
		floorRightFront.Color = Color3.fromRGB(28, 30, 36)
		floorRightFront.Parent = model

		-- Sección derecha trasera (detrás del hueco de escalera)
		local floorRightBack = Instance.new("Part")
		floorRightBack.Name = "Floor2_RightBack"
		floorRightBack.Size = Vector3.new(8, 1.2, 10)
		floorRightBack.Position = BASE_ORIGIN + Vector3.new(8, FLOOR_HEIGHT, -14)
		floorRightBack.Anchored = true
		floorRightBack.Material = Enum.Material.DiamondPlate
		floorRightBack.Color = Color3.fromRGB(28, 30, 36)
		floorRightBack.Parent = model

		-- Bordes neón decorativos exteriores (tiras finas perimetrales sin colisión, hueco de escalera 100% libre)
		createNeonPart("TrimF2_Left", Vector3.new(0.5, 0.3, 38), BASE_ORIGIN + Vector3.new(-12, FLOOR_HEIGHT + 0.6, 0), Color3.fromRGB(160, 32, 240), model)
		createNeonPart("TrimF2_Back", Vector3.new(24, 0.3, 0.5), BASE_ORIGIN + Vector3.new(0, FLOOR_HEIGHT + 0.6, -19), Color3.fromRGB(160, 32, 240), model)
		createNeonPart("TrimF2_Front", Vector3.new(24, 0.3, 0.5), BASE_ORIGIN + Vector3.new(0, FLOOR_HEIGHT + 0.6, 19), Color3.fromRGB(160, 32, 240), model)

		-- Cinta y colector Piso 2
		createConveyorSystem(2, BASE_ORIGIN + Vector3.new(0, FLOOR_HEIGHT, 0))

	elseif item.Id == "Stairs_Floor3" then
		-- Escalera hacia Piso 3 por el lateral izquierdo
		local stepCount = 20
		local startPos = BASE_ORIGIN + Vector3.new(-9, FLOOR_HEIGHT, -6)
		local endPos = BASE_ORIGIN + Vector3.new(-9, FLOOR_HEIGHT * 2, 8)

		for i = 1, stepCount do
			local alpha = i / stepCount
			local stepPos = startPos:Lerp(endPos, alpha)
			local step = Instance.new("Part")
			step.Size = Vector3.new(4.5, 0.8, 1.4)
			step.Position = stepPos
			step.Anchored = true
			step.Material = Enum.Material.DiamondPlate
			step.Color = Color3.fromRGB(45, 35, 55)
			step.Parent = model

			createNeonPart("StepGlow3", Vector3.new(4.6, 0.2, 0.2), stepPos + Vector3.new(0, 0.4, -0.6), Color3.fromRGB(255, 100, 255), model)
		end

		local landing3 = Instance.new("Part")
		landing3.Name = "Landing_Floor3"
		landing3.Size = Vector3.new(5.5, 1.2, 6)
		landing3.Position = BASE_ORIGIN + Vector3.new(-9, FLOOR_HEIGHT * 2, 11)
		landing3.Anchored = true
		landing3.Material = Enum.Material.DiamondPlate
		landing3.Color = Color3.fromRGB(45, 35, 55)
		landing3.Parent = model

	elseif item.Id == "Floor3_Base" then
		-- Suelo del Piso 3 con hueco para la escalera izquierda
		local floorRight = Instance.new("Part")
		floorRight.Name = "Floor3_Right"
		floorRight.Size = Vector3.new(16, 1.4, 40)
		floorRight.Position = BASE_ORIGIN + Vector3.new(4, FLOOR_HEIGHT * 2, 0)
		floorRight.Anchored = true
		floorRight.Material = Enum.Material.DiamondPlate
		floorRight.Color = Color3.fromRGB(22, 24, 30)
		floorRight.Parent = model

		local floorLeftFront = Instance.new("Part")
		floorLeftFront.Name = "Floor3_LeftFront"
		floorLeftFront.Size = Vector3.new(8, 1.4, 14)
		floorLeftFront.Position = BASE_ORIGIN + Vector3.new(-8, FLOOR_HEIGHT * 2, -13)
		floorLeftFront.Anchored = true
		floorLeftFront.Material = Enum.Material.DiamondPlate
		floorLeftFront.Color = Color3.fromRGB(22, 24, 30)
		floorLeftFront.Parent = model

		local floorLeftBack = Instance.new("Part")
		floorLeftBack.Name = "Floor3_LeftBack"
		floorLeftBack.Size = Vector3.new(8, 1.4, 10)
		floorLeftBack.Position = BASE_ORIGIN + Vector3.new(-8, FLOOR_HEIGHT * 2, 15)
		floorLeftBack.Anchored = true
		floorLeftBack.Material = Enum.Material.DiamondPlate
		floorLeftBack.Color = Color3.fromRGB(22, 24, 30)
		floorLeftBack.Parent = model

		-- Bordes neón decorativos dorados en el perímetro (sin colisión, hueco de escalera libre)
		createNeonPart("TrimF3_Right", Vector3.new(0.5, 0.4, 40), BASE_ORIGIN + Vector3.new(12, FLOOR_HEIGHT * 2 + 0.7, 0), Color3.fromRGB(255, 215, 0), model)
		createNeonPart("TrimF3_Back", Vector3.new(24, 0.4, 0.5), BASE_ORIGIN + Vector3.new(0, FLOOR_HEIGHT * 2 + 0.7, -20), Color3.fromRGB(255, 215, 0), model)
		createNeonPart("TrimF3_Front", Vector3.new(24, 0.4, 0.5), BASE_ORIGIN + Vector3.new(0, FLOOR_HEIGHT * 2 + 0.7, 20), Color3.fromRGB(255, 215, 0), model)
		createConveyorSystem(3, BASE_ORIGIN + Vector3.new(0, FLOOR_HEIGHT * 2, 0))

	elseif item.Id == "Floor3_Beacon" then
		-- Faro de Energía Estelar (Monumento Final)
		local beaconCenter = BASE_ORIGIN + Vector3.new(0, FLOOR_HEIGHT * 2 + 1, 0)

		local beaconPillar = createNeonPart("BeaconCore", Vector3.new(4, 12, 4), beaconCenter + Vector3.new(0, 6, 0), Color3.fromRGB(255, 230, 0), model)

		local beam = Instance.new("Part")
		beam.Name = "SkyBeam"
		beam.Size = Vector3.new(2, 200, 2)
		beam.Position = beaconCenter + Vector3.new(0, 106, 0)
		beam.Anchored = true
		beam.CanCollide = false
		beam.Material = Enum.Material.Neon
		beam.Color = Color3.fromRGB(255, 255, 100)
		beam.Transparency = 0.25
		beam.Parent = model

		-- Partículas estelares
		local stars = Instance.new("ParticleEmitter")
		stars.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		stars.Color = ColorSequence.new(Color3.fromRGB(255, 230, 0), Color3.fromRGB(255, 255, 255))
		stars.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.8), NumberSequenceKeypoint.new(1, 0)})
		stars.Rate = 50
		stars.Speed = NumberRange.new(15, 30)
		stars.SpreadAngle = Vector2.new(180, 180)
		stars.Parent = beaconPillar
	end
end

--------------------------------------------------------------------
-- GESTOR DE BOTONES DE COMPRA EN EL SUELO
--------------------------------------------------------------------
local function getButtonPlacement(item: TycoonConfig.TycoonItem): Vector3
	-- Posicionamiento exacto y alcanzable para cada botón
	if item.Id == "Floor2_Base" then
		-- Justo en la plataforma de aterrizaje al subir la escalera del Piso 1
		return BASE_ORIGIN + Vector3.new(9, FLOOR_HEIGHT + 1.2, -9)
	elseif item.Id == "Floor3_Base" then
		-- En la plataforma de aterrizaje al subir la escalera hacia el Piso 3
		return BASE_ORIGIN + Vector3.new(-9, FLOOR_HEIGHT * 2 + 1.2, 11)
	elseif item.Id == "Floor3_Beacon" then
		return BASE_ORIGIN + Vector3.new(0, FLOOR_HEIGHT * 2 + 1.2, 14)
	end

	local floorY = (item.Floor - 1) * FLOOR_HEIGHT + 1.2
	local sideX = (item.Floor == 1) and 7.5 or ((item.Floor == 2) and 7.5 or -7.5)

	if item.Type == "Dropper" then
		local offsetZ = (item.Id == "Dropper_1") and -10 or ((item.Id == "Dropper_3" or item.Id == "Dropper_5") and -4 or -10)
		return BASE_ORIGIN + Vector3.new(sideX, floorY, offsetZ)
	elseif item.Type == "Upgrader" then
		return BASE_ORIGIN + Vector3.new(sideX, floorY, 2)
	elseif item.Type == "Stairs" then
		if item.Floor == 1 then
			return BASE_ORIGIN + Vector3.new(9, 1.2, 10) -- Al pie de la escalera al Piso 2
		else
			return BASE_ORIGIN + Vector3.new(-9, FLOOR_HEIGHT + 1.2, -8) -- Al pie de la escalera al Piso 3
		end
	elseif item.Type == "Structure" then
		return BASE_ORIGIN + Vector3.new(sideX, floorY, -14)
	end

	return BASE_ORIGIN + Vector3.new(sideX, floorY, 0)
end

function TycoonManager.SpawnButton(item: TycoonConfig.TycoonItem)
	if activeButtons[item.Id] then
		return
	end

	local buttonPos = getButtonPlacement(item)

	local buttonModel = Instance.new("Model")
	buttonModel.Name = "Button_" .. item.Id
	buttonModel.Parent = tycoonModel

	local basePart = Instance.new("Part")
	basePart.Name = "Base"
	basePart.Size = Vector3.new(4.2, 0.4, 4.2)
	basePart.Position = buttonPos
	basePart.Anchored = true
	basePart.Material = Enum.Material.Metal
	basePart.Color = Color3.fromRGB(40, 44, 52)
	basePart.Parent = buttonModel

	local pad = Instance.new("Part")
	pad.Name = "Pad"
	pad.Size = Vector3.new(3.5, 0.6, 3.5)
	pad.Position = buttonPos + Vector3.new(0, 0.3, 0)
	pad.Anchored = true
	pad.Material = Enum.Material.Neon
	pad.Color = Color3.fromRGB(0, 200, 255)
	pad.Parent = buttonModel

	-- Cartel con Nombre y Precio
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 180, 0, 52)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = pad

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.5, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = item.Name
	titleLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
	titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = gui

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Size = UDim2.new(1, 0, 0.5, 0)
	priceLabel.Position = UDim2.new(0, 0, 0.5, 0)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Text = item.Cost == 0 and "¡GRATIS!" or "COMPRAR: $" .. tostring(item.Cost)
	priceLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
	priceLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	priceLabel.TextStrokeTransparency = 0.2
	priceLabel.TextScaled = true
	priceLabel.Font = Enum.Font.GothamBlack
	priceLabel.Parent = gui

	activeButtons[item.Id] = buttonModel

	-- Evento de pisar el botón
	local debounce = false
	pad.Touched:Connect(function(hit)
		if debounce then
			return
		end

		local char = hit.Parent
		if not char then
			return
		end

		local player = Players:GetPlayerFromCharacter(char)
		if not player then
			return
		end

		local currentMoney = DataStoreManager.GetMoney(player)
		if currentMoney >= item.Cost then
			debounce = true

			if item.Cost > 0 then
				DataStoreManager.SpendMoney(player, item.Cost)
			end

			DataStoreManager.UnlockItem(player, item.Id)

			-- Efectos de compra
			playSound(TycoonConfig.Sounds.Purchase, pad, 1)
			spawnBurstParticles(pad.Position + Vector3.new(0, 1, 0), Color3.fromRGB(0, 255, 170))

			-- Animación de presionado y desaparición
			TweenService:Create(
				pad,
				TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = buttonPos + Vector3.new(0, 0.05, 0), Color = Color3.fromRGB(0, 255, 150) }
			):Play()

			task.wait(0.3)
			buttonModel:Destroy()
			activeButtons[item.Id] = nil

			-- Construir el elemento desbloqueado
			TycoonManager.BuildItem(item)

			-- Actualizar el árbol de botones disponibles
			TycoonManager.UpdateButtonsForPlayer(player)
		end
	end)
end

function TycoonManager.BuildItem(item: TycoonConfig.TycoonItem)
	local floorOffset = (item.Floor - 1) * FLOOR_HEIGHT
	local conveyorObj = tycoonModel:FindFirstChild("Conveyor_Floor" .. item.Floor)
	local belt = conveyorObj and conveyorObj:FindFirstChild("Belt") :: Part?

	if item.Type == "Dropper" then
		if belt then
			local zPos = (item.Floor == 1) and ((item.Id == "Dropper_1") and -10 or -4) or -8
			buildDropper(item, belt, zPos)
		end
	elseif item.Type == "Upgrader" then
		if belt then
			buildUpgrader(item, belt, 3)
		end
	elseif item.Type == "Structure" or item.Type == "Stairs" then
		buildStructure(item)
	end
end

function TycoonManager.UpdateButtonsForPlayer(player: Player)
	for _, item in ipairs(TycoonConfig.Items) do
		local isUnlocked = DataStoreManager.IsItemUnlocked(player, item.Id)

		if not isUnlocked then
			-- Comprobar si su dependencia ya está desbloqueada
			local depUnlocked = true
			if item.Dependency then
				depUnlocked = DataStoreManager.IsItemUnlocked(player, item.Dependency)
			end

			if depUnlocked then
				TycoonManager.SpawnButton(item)
			end
		end
	end
end

--------------------------------------------------------------------
-- INICIALIZACIÓN GLOBAL DEL TYCOON
--------------------------------------------------------------------
function TycoonManager.Init()
	-- Limpiar Tycoon previo si existe
	local old = workspace:FindFirstChild("MiniTycoon")
	if old then
		old:Destroy()
	end

	tycoonModel = Instance.new("Model")
	tycoonModel.Name = "MiniTycoon"
	tycoonModel.Parent = workspace

	-- Base principal del Piso 1
	local baseFloor1 = Instance.new("Part")
	baseFloor1.Name = "Floor1_Plate"
	baseFloor1.Size = Vector3.new(24, 1.2, 38)
	baseFloor1.Position = BASE_ORIGIN
	baseFloor1.Anchored = true
	baseFloor1.Material = Enum.Material.DiamondPlate
	baseFloor1.Color = Color3.fromRGB(24, 26, 32)
	baseFloor1.Parent = tycoonModel

	createNeonPart("Floor1_Trim", Vector3.new(24.2, 0.35, 38.2), BASE_ORIGIN + Vector3.new(0, 0.6, 0), Color3.fromRGB(0, 210, 255), tycoonModel)

	-- Generar Cinta y Venta del Piso 1
	createConveyorSystem(1, BASE_ORIGIN)

	print("[TycoonManager] Tycoon de 3 pisos inicializado con éxito.")
end

-- Cargar progresión del jugador
function TycoonManager.LoadTycoonForPlayer(player: Player)
	for _, item in ipairs(TycoonConfig.Items) do
		if DataStoreManager.IsItemUnlocked(player, item.Id) then
			TycoonManager.BuildItem(item)
		end
	end

	TycoonManager.UpdateButtonsForPlayer(player)
end

return TycoonManager
