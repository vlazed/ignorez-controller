-- 2^10 might be an under-guesstimate of the average number of entities for a Gmod sandbox. 
-- I don't expect there to be that many entities for Gmod animators  
ENTITY_BIT_COUNT = 10
--[[
    Measured from the look vector, the angle beyond which we toggle the ignorez parameter
    
    If this is set to +/-180 degrees and above (or below), we do not control anything, and
    we skip dot product calculations.
--]]
local MAX_LOOK_ANGLE = 115
--[[
    Whether we switch the ignorez parameter

    We give the option for users to switch the see-through behavior of materials if a predicate 
    is true 
--]]
local IS_INVERTED = false
-- TODO: Test if Entity:SetEyeTarget() changes Entity:EyeAngles()
--[[
    Whether we should use a ragdoll's eye angles (hopefully not changed eyetarget)

    By default, we use the world look vector obtained from Entity:EyeAngles as we assume proper 
    eye orientation for the given ragdoll If this is false, the user can specify their reference 
    heading with respect to a specific bone angle (on or offset by some degrees)
--]]
local USE_EYE_ANGLE = true
--[[
    The name of the bone to use for reference heading if USE_EYE_ANGLE is false

    The default id is arbitrary. The CPanel frontend automatically replaces this value with
    a valid bone id corresponding to the ragdoll's head. 
    
    The frontend may be used to change the bone for dot product calculations
--]]
local DEFAULT_BONE_ID = 1
--[[
    The offset from the bone's reference heading if USE_EYE_ANGLE is false
--]]
local DEFAULT_ANGLE_OFFSET = angle_zero
local function setDefaultProps(props)
    local defaultProps = {
        maxLookAngle = MAX_LOOK_ANGLE,
        inverted = IS_INVERTED,
        useEyeAngle = USE_EYE_ANGLE,
        boneId = DEFAULT_BONE_ID,
        angleOffset = DEFAULT_ANGLE_OFFSET
    }

    for key, defaultProp in pairs(defaultProps) do
        if not props[key] then props[key] = prop end
    end
    return props
end

function updateProps(oldProps, targetProps)
    local newProps = oldProps
    for key, targetProp in pairs(targetProps) do
        newProps[key] = targetProp
    end
    return newProps
end

function readMaterialInfo()
    local entIndex = net.ReadUInt(ENTITY_BIT_COUNT)
    if not entIndex then return end
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
        }
    }
end

function writeMaterialInfo(entIndex, materialName, props)
    net.WriteUInt(entIndex, ENTITY_BIT_COUNT)
    net.WriteString(materialName)
    net.WriteFloat(props.maxLookAngle)
    net.WriteBool(props.inverted)
    net.WriteBool(props.useEyeAngle)
    net.WriteUInt(props.boneId, 8)
    net.WriteAngle(props.angleOffset)
end

function createClientMaterial(materialName, props)
    if CLIENT then
        local newMaterial, _ = Material(materialName)
        if newMaterial then
            return {
                material = newMaterial,
                defaultFlags = newMaterial:GetInt("$flags"),
                prevOption = false,
                name = materialName,
                props = setDefaultProps(props)
            }
        end
    end
end

function createServerMaterial(materialName, props)
    if SERVER then
        local newMaterial, _ = Material(materialName)
        if newMaterial then
            return {
                name = materialName,
                props = setDefaultProps(props)
            }
        end
    end
end
return ENTITY_BIT_COUNT