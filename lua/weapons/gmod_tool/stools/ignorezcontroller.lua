---@module "izc.lib.constants"
local IZCConstants = include("izc/lib/constants.lua")
---@module "izc.lib.material"
local IZCMaterialSingleton = include("izc/lib/material.lua")

local ENTITY_BIT_COUNT = IZCConstants.ENTITY_BIT_COUNT

TOOL.Category = "Poser"
TOOL.Name = "#tool.ignorezcontroller.name"
TOOL.Command = nil
TOOL.ConfigName = ""
local lastSelectedEntity = nil
local lastSelectedEntityValid = false
local id = "izc_entity"
function TOOL:SetControlledEntity(newEntity)
	return self:GetWeapon():SetNWEntity(id, newEntity)
end

function TOOL:GetControlledEntity()
	return self:GetWeapon():GetNWEntity(id)
end

function TOOL:Think()
	if CLIENT then
		if
			self:GetControlledEntity() == lastSelectedEntity
			and lastSelectedEntityValid == IsValid(lastSelectedEntity)
		then
			return
		end
		lastSelectedEntity = self:GetControlledEntity()
		lastSelectedEntityValid = IsValid(lastSelectedEntity)
		self:RebuildControlPanel(self:GetControlledEntity())
		return
	end
end

-- Start identifying controlled materials for the entity
function TOOL:LeftClick(tr)
	local ent = tr.Entity
	local isEntity = ent and IsValid(ent)
	if not isEntity then
		return
	end
	if SERVER then
		self:SetControlledEntity(ent)
	end
	return true
end

-- Stop editing the entity
function TOOL:RightClick(tr)
	self:SetControlledEntity(nil)
	return true
end

if SERVER then
	return
end

local function materialList(panel, materials)
	local matList = vgui.Create("DListView", panel)
	matList:SetMultiSelect(false)
	matList:AddColumn("Material Name")
	for _, matName in ipairs(materials) do
		matList:AddLine(matName)
	end

	panel:AddItem(matList)
	return matList
end

local function boneComboBox(panel, entity)
	local boneBox = panel:ComboBox("Bones")
	local headIndex
	for i = 0, entity:GetBoneCount() - 1 do
		if string.find(entity:GetBoneName(i):lower(), "head") then
			headIndex = i + 1
		end
		boneBox:AddChoice(entity:GetBoneName(i), i)
	end

	if headIndex then
		boneBox:ChooseOptionID(headIndex)
	end
	boneBox:Dock(BOTTOM)
	return boneBox
end

local function getMaterialProps(entity, materialName)
	for _, matInfo in ipairs(entity.izc_materials) do
		if matInfo.name == materialName then
			return matInfo.props
		end
	end
end

function TOOL.BuildCPanel(panel, entity)
	if not IsValid(entity) then
		panel:Help("No entity selected")
		return
	end

	-- TODO: Add angle offset
	local settingProps = false
	local materials = entity:GetMaterials()
	local matList = materialList(panel, materials)
	matList:Dock(TOP)
	matList:SizeTo(-1, 500, 0.5)
	local controlMaterial = panel:CheckBox("Control material with IgnoreZ Controller?")
	local maxLookAngle = panel:NumSlider("Angle boundary (deg)", "", 0, 180)
	local inverted = panel:CheckBox("Invert $ignorez parameter?")
	local useEyeAngle = panel:CheckBox("Use model eye angles?")
	local boneBox = boneComboBox(panel, entity)
	controlMaterial:SetChecked(false)
	boneBox:Dock(BOTTOM)
	controlMaterial:Dock(BOTTOM)
	maxLookAngle:Dock(BOTTOM)
	inverted:Dock(BOTTOM)
	useEyeAngle:Dock(BOTTOM)

	matList.OnRowSelected = function(_, rowIndex, row)
		local materialName = row:GetValue(1)
		if entity.izc_materialSet and entity.izc_materialSet[materialName] then
			settingProps = true
			controlMaterial:SetChecked(true)
			local props = getMaterialProps(entity, materialName)
			maxLookAngle:SetValue(props.maxLookAngle)
			inverted:SetChecked(props.inverted)
			useEyeAngle:SetChecked(props.useEyeAngle)
			boneBox:ChooseOptionID(props.boneId + 1)
			settingProps = false
		else
			settingProps = true
			controlMaterial:SetChecked(false)
			maxLookAngle:SetValue(90)
			inverted:SetChecked(false)
			useEyeAngle:SetChecked(true)
			settingProps = false
		end
	end

	local function addMaterialProps()
		local materialName = matList:GetSelected()[1]:GetValue(1)
		local _, boneId = boneBox:GetSelected()
		net.Start("izc_addMaterialForEntity")
		IZCMaterialSingleton.writeMaterialInfo(entity:EntIndex(), materialName, {
			maxLookAngle = maxLookAngle:GetValue(),
			inverted = inverted:GetChecked(),
			useEyeAngle = useEyeAngle:GetChecked(),
			boneId = boneId,
			angleOffset = angle_zero,
		})

		net.SendToServer()
	end

	local function updateMaterialProps()
		local materialName = matList:GetSelected()[1]:GetValue(1)
		local _, boneId = boneBox:GetSelected()
		-- TODO: Only send what updated, rather than the entire prop table
		net.Start("izc_updateMaterialPropsForEntity")
		IZCMaterialSingleton.writeMaterialInfo(entity:EntIndex(), materialName, {
			maxLookAngle = maxLookAngle:GetValue(),
			inverted = inverted:GetChecked(),
			useEyeAngle = useEyeAngle:GetChecked(),
			boneId = boneId,
			angleOffset = angle_zero,
		})

		net.SendToServer()
	end

	controlMaterial.OnChange = function(_, checked)
		if #matList:GetSelected() == 0 then
			return
		end
		if checked then
			if not entity.izc_materials or #entity.izc_materials == 0 then
				net.Start("izc_addEntity")
				net.WriteUInt(entity:EntIndex(), ENTITY_BIT_COUNT)
				net.SendToServer()
			end

			addMaterialProps()
		else
			local materialName = matList:GetSelected()[1]:GetValue(1)
			net.Start("izc_removeMaterialForEntity")
			net.WriteUInt(entity:EntIndex(), ENTITY_BIT_COUNT)
			net.WriteString(materialName)
			net.SendToServer()
			if not entity.izc_materials or #entity.izc_materials == 0 then
				net.Start("izc_removeEntity")
				net.WriteUInt(entity:EntIndex(), ENTITY_BIT_COUNT)
				net.SendToServer()
			end
		end
	end

	maxLookAngle.OnValueChanged = function(_, newValue)
		if settingProps then
			return
		end
		updateMaterialProps()
	end

	useEyeAngle.OnChecked = function(_, checked)
		if settingProps then
			return
		end
		updateMaterialProps()
	end

	inverted.OnChecked = function(_, newValue)
		if settingProps then
			return
		end
		updateMaterialProps()
	end

	boneBox.OnSelect = function(_, _, _)
		if settingProps then
			return
		end
		updateMaterialProps()
	end
end

language.Add("tool.ignorezcontroller.name", "IgnoreZ Controller")
language.Add("tool.ignorezcontroller.desc", "Control how the $ignorez parameter renders")
language.Add("tool.ignorezcontroller.0", "Select ragdoll to edit $ignorez parameters")
language.Add("tool.ignorezcontroller.1", "Stop editing ragdoll")
