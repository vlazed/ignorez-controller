print("Loading serverside izc system")

---@module "izc.lib.util"
local IZCUtil = include("izc/lib/util.lua")

---@module "izc.lib.constants"
local IZCConstants = include("izc/lib/constants.lua")

---@module "izc.lib.material"
local IZCMaterialSingleton = include("izc/lib/material.lua")

---@module "izc.lib.shared"
local IZCMaterialUtil = include("izc/lib/shared.lua")

local ipairs_sparse = IZCUtil.ipairs_sparse
local izc_hook = "IGNOREZCONTROLLER_HOOK"
local izc_dupeId = "izcMaterialInfo"

local ENTITY_BIT_COUNT = IZCConstants.ENTITY_BIT_COUNT

---@type (IZCEntity)[]
local controlledEntities = {}

---@param ply Player
---@param ent IZCEntity
---@param data any
local function registerIZCEntity(ply, ent, data)
	if data.izc_materials and not ent.izc_materials then
		ent.izc_materialSet = data.izc_materialSet
		ent.izc_materials = data.izc_materials
		controlledEntities[ent:EntIndex()] = ent
		net.Start("izc_addEntity")
		net.WriteUInt(ent:EntIndex(), ENTITY_BIT_COUNT)
		net.Broadcast()

		for _, matInfo in ipairs(ent.izc_materials) do
			net.Start("izc_addMaterialForEntity")
			IZCMaterialSingleton.writeMaterialInfo(ent:EntIndex(), matInfo.name, matInfo.props)
			net.Broadcast()
		end
	end

	if ent.izc_materials then
		duplicator.StoreEntityModifier(ent, izc_dupeId, data)
	elseif data.izc_materials and #data.izc_materials == 0 then
		duplicator.ClearEntityModifier(ent, izc_dupeId)
	end
end

duplicator.RegisterEntityModifier(izc_dupeId, registerIZCEntity)

net.Receive("izc_addEntity", function()
	local entIndex = net.ReadUInt(ENTITY_BIT_COUNT)
	local entity = Entity(entIndex)
	---@cast entity IZCEntity
	controlledEntities[entIndex] = entity
	net.Start("izc_addEntity")
	net.WriteUInt(entIndex, ENTITY_BIT_COUNT)
	net.Broadcast()
end)

net.Receive("izc_removeEntity", function()
	local entIndex = net.ReadUInt(ENTITY_BIT_COUNT)
	controlledEntities[entIndex] = nil
	net.Start("izc_removeEntity")
	net.WriteUInt(entIndex, ENTITY_BIT_COUNT)
	net.Broadcast()
end)

net.Receive("izc_addMaterialForEntity", function(_, ply)
	local entity = IZCMaterialUtil.addMaterialForEntity()
	registerIZCEntity(ply, entity, {
		izc_materials = entity.izc_materials,
		izc_materialSet = entity.izc_materialSet,
	})
end)

net.Receive("izc_removeMaterialForEntity", function(_, ply)
	local entity = IZCMaterialUtil.removeMaterialForEntity()
	registerIZCEntity(ply, entity, {
		izc_materials = entity.izc_materials,
		izc_materialSet = entity.izc_materialSet,
	})
end)

net.Receive("izc_updateMaterialPropsForEntity", function(_, ply)
	local entity = IZCMaterialUtil.updateMaterialPropsForEntity()
	registerIZCEntity(ply, entity, {
		izc_materials = entity.izc_materials,
		izc_materialSet = entity.izc_materialSet,
	})
end)

-- Replicate controlled entities to clients that have connected even after this system has started running
net.Receive("izc_requestEntities", function(_, ply)
	if not IsValid(ply) then
		return
	end

	for entIndex, targetEntity in ipairs_sparse(controlledEntities) do
		net.Start("izc_addEntity")
		net.WriteUInt(entIndex, ENTITY_BIT_COUNT)
		net.Send(ply)

		if IsValid(targetEntity) and targetEntity.izc_materials and #targetEntity.izc_materials > 0 then
			for _, matInfo in ipairs(targetEntity.izc_materials) do
				net.Start("izc_addMaterialForEntity")
				IZCMaterialSingleton.writeMaterialInfo(targetEntity:EntIndex(), matInfo.name, matInfo.props)
				net.Send(ply)
			end
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

