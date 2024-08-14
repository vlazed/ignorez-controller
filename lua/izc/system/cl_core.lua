print("Loading clientside izc system")
local acos = math.acos
local deg = math.deg
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

timer.Create("izc_system", 0.1, -1, function()
    local eyePos = pl:EyePos()
    local viewEntity = pl:GetViewEntity()
    if IsValid(viewEntity) then eyePos = viewEntity:EyePos() end
    for _, entityId in ipairs_sparse(controlledEntities) do
        local entity = ents.GetByIndex(entityId)
        if not IsValid(entity) then continue end
        if not entity.izc_materials then continue end
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
            local currentFlags = matInfo.defaultFlags
            local ignoreZFlag = 32768
            -- Bit flags are the intended method for setting ignorez for VertexLitGeneric; we cannot
            -- set it directly by 'matInfo.material:SetInt("$ignorez", booltonumber(option))'
            if bit.band(ignoreZFlag, currentFlags) == ignoreZFlag then
                -- The material has $ignorez turned on by default
                matInfo.material:SetInt("$flags", currentFlags - ignoreZFlag * booltonumber(not option))
            else
                -- The material has $ignorez turned off by default
                matInfo.material:SetInt("$flags", currentFlags + ignoreZFlag * booltonumber(option))
            end

            matInfo.prevOption = option
        end
    end
end)