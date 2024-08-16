print("Loading clientside izc system")
local acos = math.acos
local cos = math.cos
local deg = math.deg
local rad = math.rad
local xy_proj = Vector(1, 1, 0)
local pl = LocalPlayer()
local controlledEntities = {}
local function removeControlledEntity(entityId)
    controlledEntities[entityId] = nil
    print(string.format("Removed %d", entityId))
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
    if targetEntityIndex then
        controlledEntities[targetEntityIndex] = targetEntityIndex
        print(string.format("Added %d", targetEntityIndex))
    end
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
    function IsInFOV(vecViewOrigin, vecViewDirection, vecPoint, flFOVCosine)
        VectorCopy(diff, vecPoint)
        VectorSubtract(diff, vecViewOrigin)
        VectorNormalize(diff)
        return VectorDot(vecViewDirection, diff) > flFOVCosine
    end
end

timer.Create("izc_system", 0.1, -1, function()
    -- Make sure player is in the world
    if not IsValid(pl) then return end
    local eyePos = pl:EyePos()
    local eyeLook = pl:EyeAngles():Forward()
    local viewEntity = pl:GetViewEntity()
    local flFOV = pl:GetFOV()
    local flFOVCosine = cos(rad(flFOV * 0.75))
    if IsValid(viewEntity) then
        eyePos = viewEntity:EyePos()
        eyeLook = viewEntity:EyeAngles():Forward()
    end

    for _, entityId in ipairs_sparse(controlledEntities) do
        local entity = ents.GetByIndex(entityId)
        if not IsValid(entity) then continue end
        if not entity.izc_materials then continue end
        -- Filter entities if outside of PVS
        if entity:IsDormant() then continue end
        local vecOrigin = entity:GetPos()
        -- Filter entities if not in FOV
        if not IsInFOV(eyePos, eyeLook, vecOrigin, flFOVCosine) then continue end
        local entLookVector = entity:EyeAngles():Forward()
        local entEyePos = entity:EyePos()
        local lookVector = ((eyePos - entEyePos) * xy_proj):GetNormalized()
        local angle = deg(acos(lookVector:Dot(entLookVector)))
        local eyeAttachment = entity:GetAttachment(entity:LookupAttachment("eyes"))
        if eyeAttachment then
            entEyePos = eyeAttachment.Pos
            entLookVector = eyeAttachment.Ang:Forward()
            lookVector = (eyePos - entEyePos):GetNormalized()
            angle = deg(acos(lookVector:Dot(entLookVector)))
        end

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