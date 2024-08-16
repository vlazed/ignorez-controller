print("Loading clientside izc system")
local acos = math.acos
local cos = math.cos
local deg = math.deg
local rad = math.rad
local xy_proj = Vector(1, 1, 0)
local performOcclusion = CreateClientConVar("izc_performocclusion", "1", true, false, "Whether the IgnoreZ Controller should perform occlusion calculations", 0, 1):GetBool()
cvars.AddChangeCallback("izc_performocclusion", function(new) performOcclusion = tobool(new) end)
local controlledEntities = {}
local function removeControlledEntity(entIndex)
    controlledEntities[entIndex] = nil
    print(string.format("Removed %d", entIndex))
end

local function addControlledEntity(entIndex)
    local entity = ents.GetByIndex(entIndex)
    if not IsValid(entity) then return end
    controlledEntities[entIndex] = entity
    -- print(string.format("Added %d", targetEntityIndex))
end

local function booltonumber(bool)
    if bool then
        return 1
    else
        return 0
    end
end

net.Receive("izc_addMaterialForEntity", function() addMaterialForEntity() end)
net.Receive("izc_removeMaterialForEntity", function() removeMaterialForEntity() end)
net.Receive("izc_updateMaterialPropsForEntity", function() updateMaterialPropsForEntity() end)
net.Receive("izc_addEntity", function()
    local targetEntityIndex = net.ReadUInt(ENTITY_BIT_COUNT)
    if targetEntityIndex then addControlledEntity(targetEntityIndex) end
end)

net.Receive("izc_removeEntity", function()
    local targetEntityIndex = net.ReadUInt(ENTITY_BIT_COUNT)
    if targetEntityIndex then removeControlledEntity(targetEntityIndex) end
end)

-- https://github.com/noaccessl/gmod-PerformantRender/blob/master/main.lua
local IsInFOV
do
    local VECTOR = FindMetaTable("Vector")
    local VectorCopy = VECTOR.Set
    local VectorSubtract = VECTOR.Sub
    local VectorNormalize = VECTOR.Normalize
    local VectorDot = VECTOR.Dot
    local diff = Vector()
    function IsInFOV(vecViewOrigin, vecViewDirection, vecPoint, flFOVCosine, min, max)
        VectorCopy(diff, vecPoint)
        VectorSubtract(diff, vecViewOrigin)
        VectorNormalize(diff)
        return VectorDot(vecViewDirection, diff) > flFOVCosine
    end
end

local function isEntityOccluded(entity, start)
    local traceLine = util.TraceLine
    local min, max = entity:GetRotatedAABB(entity:OBBMins(), entity:OBBMaxs())
    local center = entity:GetPos() + (min + max) / 2
    local cornersVisible = 0
    for i = 1, 8 do
        local v1 = (i % 2) == 0 and min or max
        local v2 = (i % 4) < 2 and min or max
        local v3 = i > 4 and min or max
        local corner = Vector(v1.x, v2.y, v3.z)
        local endPos = center + corner
        local tr = traceLine({
            start = start,
            endpos = endPos,
            filter = function(e)
                if e == entity or e == LocalPlayer() then
                    return false
                else
                    return true
                end
            end,
        })

        if tr.HitPos == endPos then cornersVisible = cornersVisible + 1 end
    end
    return cornersVisible < 2
end

timer.Create("izc_system", 0.1, -1, function()
    local pl = LocalPlayer()
    if not IsValid(pl) then return end
    -- Make sure player is in the world
    local eyePos = pl:EyePos()
    local eyeLook = pl:EyeAngles():Forward()
    local viewEntity = pl:GetViewEntity()
    local fov = pl:GetFOV()
    local fovCosine = cos(rad(fov * 0.75))
    if IsValid(viewEntity) then
        eyePos = viewEntity:EyePos()
        eyeLook = viewEntity:EyeAngles():Forward()
    end

    for entIndex, entity in ipairs_sparse(controlledEntities) do
        if not IsValid(entity) then continue end
        if not entity.izc_materials then continue end
        local entEyePos = entity:EyePos()
        local entLookVector = entity:EyeAngles():Forward()
        local eyeAttachment = entity:GetAttachment(entity:LookupAttachment("eyes"))
        if eyeAttachment then
            entEyePos = eyeAttachment.Pos
            entLookVector = eyeAttachment.Ang:Forward()
        end

        -- Filter entities if outside of PVS
        if entity:IsDormant() then continue end
        -- Filter entities if not in FOV
        if not IsInFOV(eyePos, eyeLook, entEyePos, fovCosine) then
            print("Not in FOV")
            continue
        end

        local occluded = performOcclusion and isEntityOccluded(entity, eyePos)
        local lookVector = ((eyePos - entEyePos) * xy_proj):GetNormalized()
        local angle = deg(acos(lookVector:Dot(entLookVector)))
        -- Filter entities that don't have controlled ignorez materials
        if not entity.izc_materials then continue end
        for _, matInfo in pairs(entity.izc_materials) do
            local option = false
            local props = matInfo.props
            if not props.useEyeAngle then
                local _, boneAng = entity:GetBonePosition(props.boneId)
                local offset = props.angleOffset
                if bone then
                    entLookVector = (boneAng + offset):Forward()
                    angle = deg(acos(lookVector:Dot(entLookVector)))
                end
            end

            if angle <= props.maxLookAngle then option = true end
            if props.inverted then option = not option end
            option = option and not occluded
            -- Only set $ignorez if we are outside of the material
            if matInfo.prevOption == option then continue end
            local defaultFlags = matInfo.defaultFlags
            local ignoreZFlag = 32768
            -- Bit flags are the intended method for setting ignorez for VertexLitGeneric; we cannot
            -- set it directly by 'matInfo.material:SetInt("$ignorez", booltonumber(option))'
            if bit.band(ignoreZFlag, defaultFlags) == ignoreZFlag then
                -- The material has $ignorez turned on by default
                matInfo.material:SetInt("$flags", defaultFlags - ignoreZFlag * booltonumber(not option))
            else
                -- The material has $ignorez turned off by default
                matInfo.material:SetInt("$flags", defaultFlags + ignoreZFlag * booltonumber(option))
            end

            matInfo.prevOption = option
        end
    end
end)