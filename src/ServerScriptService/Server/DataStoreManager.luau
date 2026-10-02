--!strict
-- DataStoreManager.luau
-- Maneja el guardado y carga segura de datos con DataStoreService y protección para Roblox Studio.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local DATA_VERSION = "Tycoon_v1"
local AUTOSAVE_INTERVAL = 120 -- Guardar automáticamente cada 2 minutos

local DataStoreManager = {}

-- Caché en memoria para cada jugador en la sesión
type PlayerData = {
	Dinero: number,
	UnlockedItems: { [string]: boolean },
	LastSave: number,
}

local sessionData: { [Player]: PlayerData } = {}
local tycoonStore: GlobalDataStore? = nil

-- Inicialización segura del DataStore
local isStudio = RunService:IsStudio()
local success, result = pcall(function()
	return DataStoreService:GetDataStore(DATA_VERSION)
end)

if success and result then
	tycoonStore = result
	print("[DataStore] Conexión establecida con DataStoreService (" .. DATA_VERSION .. ").")
else
	warn("[DataStore] No se pudo conectar a DataStoreService (¿Acceso a API desactivado en Studio?). Usando modo de memoria local.")
end

-- Cargar datos cuando un jugador entra
function DataStoreManager.LoadData(player: Player): PlayerData
	local defaultData: PlayerData = {
		Dinero = 0,
		UnlockedItems = {
			["Dropper_1"] = true, -- Dropper inicial gratis desbloqueado
		},
		LastSave = os.time(),
	}

	if not tycoonStore then
		sessionData[player] = defaultData
		return defaultData
	end

	local key = "Player_" .. tostring(player.UserId)
	local loadSuccess, loadedData = pcall(function()
		return tycoonStore:GetAsync(key)
	end)

	if loadSuccess and loadedData and type(loadedData) == "table" then
		local data: PlayerData = {
			Dinero = loadedData.Dinero or 0,
			UnlockedItems = {},
			LastSave = os.time(),
		}

		if type(loadedData.UnlockedItems) == "table" then
			for _, itemId in ipairs(loadedData.UnlockedItems) do
				data.UnlockedItems[tostring(itemId)] = true
			end
		end

		-- Asegurar que el Dropper 1 esté presente
		data.UnlockedItems["Dropper_1"] = true
		sessionData[player] = data
		print("[DataStore] Datos cargados exitosamente para " .. player.Name .. " ($" .. data.Dinero .. ")")
		return data
	else
		if not loadSuccess then
			if string.find(tostring(loadedData), "Studio access to APIs is not allowed") then
				tycoonStore = nil -- Desactivar llamadas futuras en Studio para no saturar consola
				print("[DataStore] Modo local activo para Studio (datos gestionados en memoria de sesión).")
			else
				warn("[DataStore] Error al leer datos de " .. player.Name .. ": " .. tostring(loadedData))
			end
		end
		sessionData[player] = defaultData
		return defaultData
	end
end

-- Guardar datos del jugador
function DataStoreManager.SaveData(player: Player, isRemoving: boolean?): boolean
	local data = sessionData[player]
	if not data then
		return false
	end

	-- Sincronizar dinero desde leaderstats si existe
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local dineroVal = leaderstats:FindFirstChild("Dinero")
		if dineroVal and dineroVal:IsA("IntValue") then
			data.Dinero = dineroVal.Value
		end
	end

	if not tycoonStore then
		return true -- En modo local se mantiene en memoria
	end

	local key = "Player_" .. tostring(player.UserId)

	-- Convertir tabla hash a lista de strings para guardado compacto en JSON
	local itemsList: {string} = {}
	for itemId, unlocked in pairs(data.UnlockedItems) do
		if unlocked then
			table.insert(itemsList, itemId)
		end
	end

	local payload = {
		Dinero = data.Dinero,
		UnlockedItems = itemsList,
		SavedAt = os.time(),
	}

	local saveSuccess, err = pcall(function()
		tycoonStore:SetAsync(key, payload)
	end)

	if saveSuccess then
		data.LastSave = os.time()
		print("[DataStore] Partida guardada para " .. player.Name .. " ($" .. data.Dinero .. ", " .. #itemsList .. " mejoras)")
		return true
	else
		warn("[DataStore] Fallo al guardar datos de " .. player.Name .. ": " .. tostring(err))
		return false
	end
end

-- API de modificación de datos
function DataStoreManager.GetMoney(player: Player): number
	local data = sessionData[player]
	if data then
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local dinero = leaderstats:FindFirstChild("Dinero")
			if dinero and dinero:IsA("IntValue") then
				return dinero.Value
			end
		end
		return data.Dinero
	end
	return 0
end

function DataStoreManager.AddMoney(player: Player, amount: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local dinero = leaderstats:FindFirstChild("Dinero")
		if dinero and dinero:IsA("IntValue") then
			dinero.Value += amount
		end
	end

	local data = sessionData[player]
	if data then
		data.Dinero += amount
	end
end

function DataStoreManager.SpendMoney(player: Player, amount: number): boolean
	local current = DataStoreManager.GetMoney(player)
	if current >= amount then
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local dinero = leaderstats:FindFirstChild("Dinero")
			if dinero and dinero:IsA("IntValue") then
				dinero.Value -= amount
			end
		end

		local data = sessionData[player]
		if data then
			data.Dinero -= amount
		end
		return true
	end
	return false
end

function DataStoreManager.IsItemUnlocked(player: Player, itemId: string): boolean
	local data = sessionData[player]
	if data and data.UnlockedItems then
		return data.UnlockedItems[itemId] == true
	end
	return false
end

function DataStoreManager.UnlockItem(player: Player, itemId: string)
	local data = sessionData[player]
	if data then
		data.UnlockedItems[itemId] = true
	end
end

-- Bucle de guardado automático
task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			DataStoreManager.SaveData(player, false)
		end
	end
end)

-- Guardar al desconectarse el jugador
Players.PlayerRemoving:Connect(function(player)
	DataStoreManager.SaveData(player, true)
	sessionData[player] = nil
end)

-- Guardar en el cierre del servidor
game:BindToClose(function()
	if not RunService:IsStudio() then
		for _, player in ipairs(Players:GetPlayers()) do
			DataStoreManager.SaveData(player, true)
		end
	end
end)

return DataStoreManager
