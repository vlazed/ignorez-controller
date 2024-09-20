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

---@param panel DForm
---@param materials table
---@return DListView
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

---@param panel DForm
---@param entity Entity
---@return DComboBox
local function boneComboBox(panel, entity)
	---@diagnostic disable-next-line
	local boneBox = panel:ComboBox("Bones")
	---@cast boneBox DComboBox

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

---@param entity IZCEntity
---@param materialName string
---@return IZCProps
local function getMaterialProps(entity, materialName)
	if entity.izc_materialSet[materialName] then
		local matInfo = entity.izc_materials[entity.izc_materialSet[materialName]]
		if matInfo and matInfo.props then
			return matInfo.props
		end
	end
end

---@param panel DForm
---@param entity IZCEntity
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
	---@diagnostic disable-next-line
	local controlMaterial = panel:CheckBox("Control material with IgnoreZ Controller?")
	---@cast controlMaterial DCheckBox
	---@diagnostic disable-next-line
	local maxLookAngle = panel:NumSlider("Angle boundary (deg)", "", 0, 180)
	---@cast maxLookAngle DNumSlider
	---@diagnostic disable-next-line
	local inverted = panel:CheckBox("Invert $ignorez parameter?")
	---@cast maxLookAngle DCheckBox
	---@diagnostic disable-next-line
	local useEyeAngle = panel:CheckBox("Use model eye angles?")
	---@cast useEyeAngle DCheckBox
	local boneBox = boneComboBox(panel, entity)
	controlMaterial:SetChecked(false)

	boneBox:Dock(BOTTOM)
	controlMaterial:Dock(BOTTOM)
	maxLookAngle:Dock(BOTTOM)
	inverted:Dock(BOTTOM)
	useEyeAngle:Dock(BOTTOM)

	function matList:OnRowSelected(_, row)
		local materialName = row:GetValue(1)
		if entity.izc_materialSet and entity.izc_materialSet[materialName] then
			settingProps = true
			controlMaterial:SetChecked(true)
			local props = getMaterialProps(entity, materialName)
			maxLookAngle:SetValue(props.maxLookAngle)
			inverted:SetChecked(props.inverted)
			useEyeAngle:SetChecked(props.useEyeAngle)
			boneBox:ChooseOptionID(props.boneId + 1)

			maxLookAngle:SetEnabled(true)
			inverted:SetEnabled(true)
			useEyeAngle:SetEnabled(true)
			boneBox:SetEnabled(true)

			settingProps = false
		else
			settingProps = true
			controlMaterial:SetChecked(false)
			maxLookAngle:SetValue(90)
			inverted:SetChecked(false)
			useEyeAngle:SetChecked(true)
			settingProps = false

			maxLookAngle:SetEnabled(false)
			inverted:SetEnabled(false)
			useEyeAngle:SetEnabled(false)
			boneBox:SetEnabled(false)
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

	function controlMaterial:OnChange(checked)
		if #matList:GetSelected() == 0 then
			return
		end
		if checked then
			if not entity.izc_materials or #entity.izc_materials == 0 then
				net.Start("izc_addEntity")
				net.WriteUInt(entity:EntIndex(), ENTITY_BIT_COUNT)
				net.SendToServer()
			end

			maxLookAngle:SetEnabled(true)
			inverted:SetEnabled(true)
			useEyeAngle:SetEnabled(true)
			boneBox:SetEnabled(true)

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

			maxLookAngle:SetEnabled(false)
			inverted:SetEnabled(false)
			useEyeAngle:SetEnabled(false)
			boneBox:SetEnabled(false)
		end
	end

	function maxLookAngle:OnValueChanged(_)
		if settingProps then
			return
		end
		updateMaterialProps()
	end

	function useEyeAngle:OnChecked(_)
		if settingProps then
			return
		end
		updateMaterialProps()
	end

	function inverted:OnChecked(_)
		if settingProps then
			return
		end
		updateMaterialProps()
	end

	function boneBox:OnSelect(_, _)
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
