print("Loading serverside izc system")

---@module "izc.lib.constants"
local IZCConstants = include("izc/lib/constants.lua")

---@module "izc.lib.material"
local IZCMaterialSingleton = include("izc/lib/material.lua")

---@module "izc.lib.shared"
local IZCMaterialUtil = include("izc/lib/shared.lua")

local izc_hook = "IGNOREZCONTROLLER_HOOK"
local izc_dupeId = "izcMaterialInfo"

local ENTITY_BIT_COUNT = IZCConstants.ENTITY_BIT_COUNT

net.Receive("izc_addEntity", function()
	local entIndex = net.ReadUInt(ENTITY_BIT_COUNT)
	net.Start("izc_addEntity")
	net.WriteUInt(entIndex, ENTITY_BIT_COUNT)
	net.Broadcast()
end)

net.Receive("izc_removeEntity", function()
	local entIndex = net.ReadUInt(ENTITY_BIT_COUNT)
	net.Start("izc_removeEntity")
	net.WriteUInt(entIndex, ENTITY_BIT_COUNT)
	net.Broadcast()
end)

net.Receive("izc_addMaterialForEntity", function()
	IZCMaterialUtil.addMaterialForEntity()
end)
net.Receive("izc_removeMaterialForEntity", function()
	IZCMaterialUtil.removeMaterialForEntity()
end)
net.Receive("izc_updateMaterialPropsForEntity", function()
	IZCMaterialUtil.updateMaterialPropsForEntity()
end)

hook.Add("PostEntityCopy", izc_hook, function(ply, ent, entTable)
	if IsValid(ent) and ent.izc_materials then
		duplicator.StoreEntityModifier(ent:EntIndex(), izc_dupeId, {
			izc_materials = ent.izc_materials,
		})
	end
end)

hook.Add("PreEntityPaste", izc_hook, function(ply, ent, entTable)
	if entTable and entTable[izc_dupeId] then
		ent.izc_materials = entTable[izc_dupeId].izc_materials
		-- Replicate to all clients
		net.Start("izc_addEntity")
		net.Broadcast()
		for _, matInfo in ipairs(ent.izc_materials) do
			net.Start("izc_addMaterialForEntity")
			IZCMaterialSingleton.writeMaterialInfo(ent:EntIndex(), matInfo.name, matInfo.props)
			net.Broadcast()
		end
	end
end)

hook.Add("EntityRemoved", izc_hook, function(ent)
	if ent.izc_materials then
		local entId = ent:EntIndex()
		net.Start("izc_removeEntity")
		net.WriteUInt(entId, ENTITY_BIT_COUNT)
		net.Broadcast()
	end
end)
