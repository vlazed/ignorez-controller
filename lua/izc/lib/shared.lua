function removeMaterialForEntity()
    local entIndex = net.ReadUInt(ENTITY_BIT_COUNT)
    local materialName = net.ReadString()
    local targetEntity = ents.GetByIndex(entIndex)
    if not IsValid(targetEntity) then return end
    if not targetEntity.izc_materialSet[materialName] then return end
    targetEntity.izc_materialSet[materialName] = nil
    for ind, matInfo in ipairs(targetEntity.izc_materials) do
        if matInfo.name == materialName then
            table.remove(targetEntity.izc_materials, ind)
            break
        end
    end

    -- Revert submaterial
    for matInd, matName in ipairs(targetEntity:GetMaterials()) do
        if matName == materialName then
            targetEntity:SetSubMaterial(matInd - 1)
            break
        end
    end

    print(string.format("%s: removed %s", targetEntity:GetModel(), materialName))
    if SERVER then
        -- Replicate to all clients
        net.Start("izc_removeMaterialForEntity")
        net.WriteUInt(entIndex, ENTITY_BIT_COUNT)
        net.WriteString(materialName)
        net.Broadcast()
    end
end

function addMaterialForEntity()
    local materialInfo = readMaterialInfo()
    if not materialInfo then return end
    local targetEntity = ents.GetByIndex(materialInfo.entIndex)
    if not targetEntity.izc_materials then
        targetEntity.izc_materials = {}
        targetEntity.izc_materialSet = {}
    end

    if not targetEntity.izc_materialSet[materialInfo.name] then
        local material
        if SERVER then
            material = createServerMaterial(materialInfo.name, materialInfo.props, materialInfo.entIndex)
            table.insert(targetEntity.izc_materials, material)
        else
            material = createClientMaterial(materialInfo.name, materialInfo.props, materialInfo.entIndex)
        end

        if not material then error(string.format("%s is not a valid material", materialInfo.name)) end
        table.insert(targetEntity.izc_materials, material)
        targetEntity.izc_materialSet[materialInfo.name] = true
        print(string.format("%s: added %s", targetEntity:GetModel(), materialInfo.name))
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
            writeMaterialInfo(targetEntity:EntIndex(), matInfo.name, matInfo.props)
            net.Broadcast()
        end
    end
end

function updateMaterialPropsForEntity()
    local newMatInfo = readMaterialInfo()
    if not newMatInfo then return end
    local targetEntity = ents.GetByIndex(newMatInfo.entIndex)
    for _, matInfo in ipairs(targetEntity.izc_materials) do
        if matInfo.name == newMatInfo.name then updateProps(matInfo.props, newMatInfo.props) end
    end

    print(string.format("%s: updated %s", targetEntity:GetModel(), newMatInfo.name))
    if SERVER then
        for _, matInfo in ipairs(targetEntity.izc_materials) do
            net.Start("izc_updateMaterialPropsForEntity")
            writeMaterialInfo(targetEntity:EntIndex(), matInfo.name, matInfo.props)
            net.Broadcast()
        end
    end
end