local types = {}

---@class IZCProps
---@field maxLookAngle number?
---@field inverted boolean?
---@field useEyeAngle boolean?
---@field boneId integer?
---@field angleOffset Angle?

---@class IZCMaterial
---@field material Material
---@field defaultFlags integer
---@field prevOption boolean
---@field name string
---@field props IZCProps

---@class IZCMaterialSingleton
---@field ENTITY_BIT_COUNT integer
---@field updateProps fun(oldProps: IZCProps, targetProps: IZCProps): IZCProps
---@field readMaterialInfo fun(): IZCMaterialInfo?
---@field writeMaterialInfo fun(entIndex: number, materialName: string, props: IZCProps): nil
---@field createClientMaterial fun(materialName: string, props: IZCProps, entIndex: integer): IZCMaterial?
---@field createServerMaterial fun(materialName: string, props: IZCProps): IZCMaterial?

---@class IZCMaterialInfo
---@field entIndex integer
---@field name string
---@field props IZCProps

---@class IZCEntity: Entity
---@field izc_materials {[number]: IZCMaterial}
---@field izc_materialSet {[string]: integer}

return types
