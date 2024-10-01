---@module "izc.lib.constants"
local IZCConstants = include("izc/lib/constants.lua")

---@module "izc.lib.material"
local IZCMaterialSingleton = include("izc/lib/material.lua")

local ENTITY_BIT_COUNT = IZCConstants.ENTITY_BIT_COUNT

local IZCMaterialUtility = {}

---@param entity IZCEntity
local function resetMaterialIndicesOf(entity)
	for index, matInfo in ipairs(entity.izc_materials) do
		entity.izc_materialSet[matInfo.name] = index
	end
end

---@return IZCEntity
function IZCMaterialUtility.removeMaterialForEntity()
	local entIndex = net.ReadUInt(ENTITY_BIT_COUNT)
	local materialName = net.ReadString()
	local targetEntity = ents.GetByIndex(entIndex)
	---@cast targetEntity IZCEntity

	if not IsValid(targetEntity) then
		return NULL
	end
	if not targetEntity.izc_materialSet or not targetEntity.izc_materialSet[materialName] then
		return NULL
	end
	local index = targetEntity.izc_materialSet[materialName]
	table.remove(targetEntity.izc_materials, index)

	-- Revert submaterial
	for matInd, matName in ipairs(targetEntity:GetMaterials()) do
		if matName == materialName then
			targetEntity:SetSubMaterial(matInd - 1)
			break
		end
	end

	targetEntity.izc_materialSet[materialName] = nil
	resetMaterialIndicesOf(targetEntity)

	if SERVER then
		-- Replicate to all clients
		net.Start("izc_removeMaterialForEntity")
		net.WriteUInt(entIndex, ENTITY_BIT_COUNT)
		net.WriteString(materialName)
		net.Broadcast()
	end

	return targetEntity
end

---@return IZCEntity
function IZCMaterialUtility.addMaterialForEntity()
	local materialInfo = IZCMaterialSingleton.readMaterialInfo()
	if not materialInfo then
		return NULL
	end
	local targetEntity = ents.GetByIndex(materialInfo.entIndex)
	---@cast targetEntity IZCEntity

	if not targetEntity.izc_materials or not targetEntity.izc_materialSet then
		targetEntity.izc_materials = {}
		targetEntity.izc_materialSet = {}
	end

	if not targetEntity.izc_materialSet[materialInfo.name] then
		local material
		if SERVER then
			material = IZCMaterialSingleton.createServerMaterial(materialInfo.name, materialInfo.props)
		else
			material =
				IZCMaterialSingleton.createClientMaterial(materialInfo.name, materialInfo.props, materialInfo.entIndex)
		end

		if not material then
			error(string.format("%s is not a valid material", materialInfo.name))
		end
		local index = table.insert(targetEntity.izc_materials, material)
		targetEntity.izc_materialSet[materialInfo.name] = index

		if CLIENT then
			for i, origMat in ipairs(targetEntity:GetMaterials()) do
				if origMat == materialInfo.name then
					targetEntity:SetSubMaterial(i - 1, "!" .. material.material:GetName())
					break
				end
			end
		end
	end

	if SERVER then
		-- Replicate to all clients
		for _, matInfo in ipairs(targetEntity.izc_materials) do
			net.Start("izc_addMaterialForEntity")
			IZCMaterialSingleton.writeMaterialInfo(targetEntity:EntIndex(), matInfo.name, matInfo.props)
			net.Broadcast()
		end
	end

	return targetEntity
end

---@return IZCEntity
function IZCMaterialUtility.updateMaterialPropsForEntity()
	local newMatInfo = IZCMaterialSingleton.readMaterialInfo()
	if not newMatInfo then
		return NULL
	end
	local targetEntity = ents.GetByIndex(newMatInfo.entIndex)
	---@cast targetEntity IZCEntity

	local index = targetEntity.izc_materialSet[newMatInfo.name]
	local matInfo = targetEntity.izc_materials[index]
	IZCMaterialSingleton.updateProps(matInfo.props, newMatInfo.props)

	-- print(string.format("%s: updated %s", targetEntity:GetModel(), newMatInfo.name))
	if SERVER then
		for _, matInfo in ipairs(targetEntity.izc_materials) do
			net.Start("izc_updateMaterialPropsForEntity")
			IZCMaterialSingleton.writeMaterialInfo(targetEntity:EntIndex(), matInfo.name, matInfo.props)
			net.Broadcast()
		end
	end

	return targetEntity
end


return IZCMaterialUtility
