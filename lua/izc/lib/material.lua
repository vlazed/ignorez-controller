---@module "izc.lib.constants"
local IZCConstants = include("izc/lib/constants.lua")

local ENTITY_BIT_COUNT = IZCConstants.ENTITY_BIT_COUNT

local IZCMaterialSingleton = {}
---@cast IZCMaterialSingleton IZCMaterialSingleton

---On initialization, use the default parameters above for new materials
---@param props IZCProps
---@return IZCProps
local function setDefaultProps(props)
	local defaultProps = {
		maxLookAngle = IZCConstants.MAX_LOOK_ANGLE,
		inverted = IZCConstants.IS_INVERTED,
		useEyeAngle = IZCConstants.USE_EYE_ANGLE,
		boneId = IZCConstants.DEFAULT_BONE_ID,
		angleOffset = IZCConstants.DEFAULT_ANGLE_OFFSET,
	}

	for key, defaultProp in pairs(defaultProps) do
		if not props[key] then
			props[key] = defaultProp
		end
	end
	return props
end

function IZCMaterialSingleton.updateProps(oldProps, targetProps)
	local newProps = oldProps
	for key, targetProp in pairs(targetProps) do
		newProps[key] = targetProp
	end
	return newProps
end

function IZCMaterialSingleton.readMaterialInfo()
	local entIndex = net.ReadUInt(ENTITY_BIT_COUNT)
	if not entIndex then
		return
	end
	local materialName = net.ReadString()
	local maxLookAngle = net.ReadFloat()
	local inverted = net.ReadBool()
	local useEyeAngle = net.ReadBool()
	local boneId = net.ReadUInt(8)
	local angleOffset = net.ReadAngle()
	return {
		entIndex = entIndex,
		name = materialName,
		props = {
			maxLookAngle = maxLookAngle,
			inverted = inverted,
			useEyeAngle = useEyeAngle,
			boneId = boneId,
			angleOffset = angleOffset,
		},
	}
end

function IZCMaterialSingleton.writeMaterialInfo(entIndex, materialName, props)
	net.WriteUInt(entIndex, ENTITY_BIT_COUNT)
	net.WriteString(materialName)
	net.WriteFloat(props.maxLookAngle)
	net.WriteBool(props.inverted)
	net.WriteBool(props.useEyeAngle)
	net.WriteUInt(props.boneId, 8)
	net.WriteAngle(props.angleOffset)
end

local function copyTexturesTo(target, source)
	-- format: multiline
	local textures = {
		"$basetexture",
		"$bumpmap",
		"$detail",
		"$phongexponenttexture",
		"$phongwarptexture",
		"$envmap",
		"$envmapmask",
		"$lightwarptexture",
		"$iris",
		"$ambientoccltexture",
		"$corneatexture",
	}

	for _, texture in ipairs(textures) do
		if source:GetTexture(texture) then
			target:SetTexture(texture, source:GetTexture(texture))
		end
	end
end

function IZCMaterialSingleton.createClientMaterial(materialName, props, entIndex)
	if CLIENT then
		-- local translucentFlag = 2097152
		local baseMaterial, _ = Material(materialName)
		if baseMaterial then
			local baseFlags = baseMaterial:GetInt("$flags")
			-- local baseFlags2 = baseMaterial:GetInt("$flags2")
			local newMaterialName = string.format("%s_IZC_%s", materialName, entIndex)
			local newMaterial = CreateMaterial(newMaterialName, baseMaterial:GetShader(), baseMaterial:GetKeyValues())
			copyTexturesTo(newMaterial, baseMaterial)
			newMaterial:SetInt("$flags", baseFlags)
			-- newMaterial:SetInt("$flags2", baseFlags2)
			-- newMaterial:SetMatrix("$phongfresnelranges", baseMaterial:GetMatrix("$phongfresnelranges"))
			-- newMaterial:SetMatrix("$phongtint", baseMaterial:GetMatrix("$phongtint"))
			return {
				material = newMaterial,
				defaultFlags = baseMaterial:GetInt("$flags"),
				prevOption = false,
				name = materialName,
				props = setDefaultProps(props),
			}
		end
	end
end

function IZCMaterialSingleton.createServerMaterial(materialName, props)
	if SERVER then
		local newMaterial, _ = Material(materialName)
		if newMaterial then
			return {
				name = materialName,
				props = setDefaultProps(props),
			}
		end
	end
end

return IZCMaterialSingleton
