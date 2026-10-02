--!strict
-- init.server.luau
-- Script principal del servidor que arranca el Tycoon y gestiona los jugadores.

local Players = game:GetService("Players")

local TycoonManager = require(script:WaitForChild("TycoonManager"))
local DataStoreManager = require(script:WaitForChild("DataStoreManager"))

print("[Server] Iniciando sistema de Tycoon...")

-- Inicializar el mundo del Tycoon (Piso 1, Cinta transportadora base y zona de venta)
TycoonManager.Init()

local function onPlayerAdded(player: Player)
	-- Crear carpeta leaderstats para mostrar el dinero en la tabla de jugadores
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local dinero = Instance.new("IntValue")
	dinero.Name = "Dinero"
	dinero.Value = 0
	dinero.Parent = leaderstats

	-- Cargar datos del jugador
	local data = DataStoreManager.LoadData(player)
	dinero.Value = data.Dinero

	-- Cargar el progreso, droppers y botones disponibles
	TycoonManager.LoadTycoonForPlayer(player)
	print("[Server] Tycoon cargado para " .. player.Name)
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Manejar jugadores que ya estén conectados (en pruebas de Studio)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
