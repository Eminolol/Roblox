--!strict
-- TycoonConfig.luau
-- Configuración central de pisos, droppers, upgraders, botones y economía.

export type ItemType = "Dropper" | "Upgrader" | "Structure" | "Stairs"

export type TycoonItem = {
	Id: string,
	Name: string,
	Type: ItemType,
	Floor: number,
	Cost: number,
	Dependency: string?, -- ID del objeto previo requerido para desbloquear este
	Description: string,
	
	-- Parámetros específicos de Droppers
	Interval: number?,
	BaseValue: number?,
	AccentColor: Color3?,
	
	-- Parámetros específicos de Upgraders
	Multiplier: number?,
	LaserColor: Color3?,
}

local TycoonConfig = {}

-- Interruptor maestro de sonidos (Desactivado para evitar errores de permisos de audio en Studio)
TycoonConfig.EnableSounds = false

TycoonConfig.Sounds = {
	Drop = nil,
	Sell = nil,
	Purchase = nil,
	LaserUpgrade = nil,
	NewFloor = nil,
}

-- Definición ordenada de todos los desbloqueos del Tycoon (Pisos 1, 2 y 3)
TycoonConfig.Items = {
	----------------------------------------------------------------
	-- PISO 1: PLANTA BAJA (INICIO INDUSTRIAL)
	----------------------------------------------------------------
	{
		Id = "Dropper_1",
		Name = "Reactor Básico",
		Type = "Dropper",
		Floor = 1,
		Cost = 0, -- Gratis inicial
		Dependency = nil,
		Description = "Genera minerales básicos de carbón y cobre.",
		Interval = 2.4,
		BaseValue = 10,
		AccentColor = Color3.fromRGB(0, 180, 255),
	},
	{
		Id = "Upgrader_1",
		Name = "Láser Purificador x1.5",
		Type = "Upgrader",
		Floor = 1,
		Cost = 100,
		Dependency = "Dropper_1",
		Description = "Multiplica el valor de los minerales x1.5 al atravesarlo.",
		Multiplier = 1.5,
		LaserColor = Color3.fromRGB(0, 255, 170),
	},
	{
		Id = "Dropper_2",
		Name = "Reactor de Plasma",
		Type = "Dropper",
		Floor = 1,
		Cost = 250,
		Dependency = "Upgrader_1",
		Description = "Produce minerales de esmeralda y rubí a mayor velocidad.",
		Interval = 1.8,
		BaseValue = 35,
		AccentColor = Color3.fromRGB(255, 90, 0),
	},
	{
		Id = "Walls_Floor1",
		Name = "Paredes y Techo Piso 1",
		Type = "Structure",
		Floor = 1,
		Cost = 500,
		Dependency = "Dropper_2",
		Description = "Instala la estructura reforzada y ventanales con neón.",
	},
	{
		Id = "Stairs_Floor2",
		Name = "Escalera al Piso 2",
		Type = "Stairs",
		Floor = 1,
		Cost = 900,
		Dependency = "Walls_Floor1",
		Description = "Desbloquea el acceso físico al segundo piso.",
	},

	----------------------------------------------------------------
	-- PISO 2: LABORATORIO CUÁNTICO
	----------------------------------------------------------------
	{
		Id = "Floor2_Base",
		Name = "Suelo de Titanio Piso 2",
		Type = "Structure",
		Floor = 2,
		Cost = 1200,
		Dependency = "Stairs_Floor2",
		Description = "Construye el suelo del segundo piso y su cinta transportadora.",
	},
	{
		Id = "Dropper_3",
		Name = "Reactor Cuántico",
		Type = "Dropper",
		Floor = 2,
		Cost = 1800,
		Dependency = "Floor2_Base",
		Description = "Sintetiza amatistas cuánticas de alto poder.",
		Interval = 1.5,
		BaseValue = 90,
		AccentColor = Color3.fromRGB(160, 32, 240),
	},
	{
		Id = "Upgrader_2",
		Name = "Ionizador Molecular x2.0",
		Type = "Upgrader",
		Floor = 2,
		Cost = 3500,
		Dependency = "Dropper_3",
		Description = "Duplica el valor de cualquier mineral que lo cruce.",
		Multiplier = 2.0,
		LaserColor = Color3.fromRGB(180, 50, 255),
	},
	{
		Id = "Dropper_4",
		Name = "Reactor de Antimateria",
		Type = "Dropper",
		Floor = 2,
		Cost = 6500,
		Dependency = "Upgrader_2",
		Description = "Produce esferas hiperenergéticas a gran velocidad.",
		Interval = 1.2,
		BaseValue = 220,
		AccentColor = Color3.fromRGB(235, 47, 6),
	},
	{
		Id = "Stairs_Floor3",
		Name = "Ascensor / Escalera al Piso 3",
		Type = "Stairs",
		Floor = 2,
		Cost = 12000,
		Dependency = "Dropper_4",
		Description = "Construye el acceso a la terraza tecnológica superior.",
	},

	----------------------------------------------------------------
	-- PISO 3: TERRAZA CELESTIAL & MEGA REACTOR
	----------------------------------------------------------------
	{
		Id = "Floor3_Base",
		Name = "Plataforma Cielo Piso 3",
		Type = "Structure",
		Floor = 3,
		Cost = 16000,
		Dependency = "Stairs_Floor3",
		Description = "Habilita la terraza del tercer nivel con vistas panorámicas.",
	},
	{
		Id = "Dropper_5",
		Name = "Reactor Agujero Negro",
		Type = "Dropper",
		Floor = 3,
		Cost = 25000,
		Dependency = "Floor3_Base",
		Description = "Genera materia oscura con valor colosal.",
		Interval = 1.0,
		BaseValue = 650,
		AccentColor = Color3.fromRGB(44, 44, 84),
	},
	{
		Id = "Upgrader_3",
		Name = "Acelerador Taquiónico x3.0",
		Type = "Upgrader",
		Floor = 3,
		Cost = 50000,
		Dependency = "Dropper_5",
		Description = "Triplica el valor de los minerales del piso 3.",
		Multiplier = 3.0,
		LaserColor = Color3.fromRGB(255, 215, 0),
	},
	{
		Id = "Dropper_6",
		Name = "Generador Divino Celestial",
		Type = "Dropper",
		Floor = 3,
		Cost = 100000,
		Dependency = "Upgrader_3",
		Description = "El reactor definitivo que genera diamantes legendarios.",
		Interval = 0.8,
		BaseValue = 2000,
		AccentColor = Color3.fromRGB(255, 230, 0),
	},
	{
		Id = "Floor3_Beacon",
		Name = "Faro de Energía Estelar",
		Type = "Structure",
		Floor = 3,
		Cost = 200000,
		Dependency = "Dropper_6",
		Description = "Monumento final del Tycoon con rayo de luz al cielo.",
	},
}

-- Función auxiliar para obtener un objeto por su ID
function TycoonConfig.GetItem(id: string): TycoonItem?
	for _, item in ipairs(TycoonConfig.Items) do
		if item.Id == id then
			return item
		end
	end
	return nil
end

return TycoonConfig
