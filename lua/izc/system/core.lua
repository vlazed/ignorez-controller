print("Loading serverside izc system")
local izc_hook = "IGNOREZCONTROLLER_HOOK"
local izc_dupeId = "izcMaterialInfo"
net.Receive("izc_addEntity", function()
    local entIndex = net.ReadUInt(ENTITY_BIT_COUNT)
    net.Start("izc_addEntity")
    net.WriteUInt(entIndex, ENTITY_BIT_COUNT)
    net.Broadcast()
end)

net.Receive("izc_removeEntity", function()
    local entIndex = net.ReadUInt(ENTITY_BIT_COUNT)
    net.Start("izc_removeEntity")
    net.WriteUInt(entIndex, ENTITY_BIT_COUNT)
    net.Broadcast()
end)

net.Receive("izc_addMaterialForEntity", function() addMaterialForEntity() end)
net.Receive("izc_removeMaterialForEntity", function() removeMaterialForEntity() end)
net.Receive("izc_updateMaterialPropsForEntity", function() updateMaterialPropsForEntity() end)
hook.Add("PostEntityCopy", izc_hook, function(ply, ent, entTable)
    if IsValid(ent) and ent.izc_materials then
        duplicator.StoreEntityModifier(ent:EntIndex(), izc_dupeId, {
            izc_materials = ent.izc_materials
        })
    end
end)

hook.Add("PreEntityPaste", izc_hook, function(ply, ent, entTable)
    if entTable and entTable[izc_dupeId] then
        ent.izc_materials = entTable[izc_dupeId].izc_materials
        -- Replicate to all clients
        net.Start("izc_addEntity")
        net.Broadcast()
        for _, matInfo in ipairs(ent.izc_materials) do
            net.Start("izc_addMaterialForEntity")
            writeMaterialInfo(ent:EntIndex(), matInfo.name, matInfo.props)
            net.Broadcast()
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