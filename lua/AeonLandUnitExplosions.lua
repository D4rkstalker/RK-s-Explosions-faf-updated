local DefaultExplosions = import('/lua/defaultexplosions.lua')
local Utilities = import('/lua/utilities.lua')

local RKEffectUtilities = import('/mods/rks_explosions/lua/RKEffectUtilities.lua')
local RKExplosions = import('/mods/rks_explosions/lua/SDExplosions.lua')
local NEffectTemplate = import('/mods/rks_explosions/lua/NEffectTemplates.lua')
local SDEffectTemplate = import('/mods/rks_explosions/lua/SDEffectTemplates.lua')
local toggle = import('/mods/rks_explosions/lua/Togglestuff.lua').toggle

local EffectTemplate = toggle == 1 and SDEffectTemplate or NEffectTemplate

local function CreateDebris(self)
    local blueprint = self.Blueprint
    DefaultExplosions.CreateDebrisProjectiles(
        self,
        DefaultExplosions.GetAverageBoundingXYZRadius(self),
        { blueprint.SizeX, blueprint.SizeY, blueprint.SizeZ }
    )
end

local function ApplyDeathWeaponDamage(self, label)
    local blueprint = self.Blueprint
    local fractionThreshold = blueprint.General.FractionThreshold or 0.5
    if self:GetFractionComplete() < fractionThreshold then
        return
    end

    for _, weapon in blueprint.Weapon or {} do
        if weapon.Label == label then
            DamageArea(
                self,
                self:GetPosition(),
                weapon.DamageRadius,
                weapon.Damage,
                weapon.DamageType,
                weapon.DamageFriendly
            )
            return
        end
    end
end

local function CreateDamageEffect(self, effect, scale, bag)
    RKEffectUtilities.CreateBoneEffectsAttachedWithBag(
        self,
        Utilities.GetRandomInt(0, self:GetBoneCount() - 1),
        self.Army,
        effect,
        scale,
        bag
    )
end

local function CreateCoreBreachEffects(self)
    CreateDamageEffect(self, EffectTemplate.GC_Core_Breach02, 2.15, 'CoreBreach')

    for _ = 1, 7 do
        CreateDamageEffect(self, EffectTemplate.GC_Body_Part_Damage, 0.15, 'SmokingDeath')
    end
end

local function DeathThreadWater(self, loopDelay)
    local numBones = self:GetBoneCount() - 1
    local shake = Utilities.GetRandomFloat(1.5, 2.5) / 3.5

    RKExplosions.CreateAeonLargeInitialHitExplosionAtBone(self, Utilities.GetRandomInt(0, numBones), 5.0)
    CreateDebris(self)
    self:PlayUnitSound('Destroyed')
    self:ShakeCamera(30 * shake, shake, 0, shake / 1.5)

    for _ = 0, numBones / 2 do
        self:PlayUnitSound('Destroyed')
        RKExplosions.CreateGenericFlashExplosionAtBone(
            self,
            Utilities.GetRandomInt(0, numBones),
            Utilities.GetRandomFloat(0.3, 0.6)
        )
        self:ShakeCamera(30 * shake, shake, 0, shake / 1.375)
        RKExplosions.CreateAeonMediumHitExplosionAtBone(self, Utilities.GetRandomInt(0, numBones), 0.2)
        CreateDebris(self)

        if loopDelay then
            WaitSeconds(loopDelay)
        else
            WaitSeconds(Utilities.GetRandomFloat(0, 0.5))
        end
    end

    WaitSeconds(0.58)
    self:PlayUnitSound('Destroyed')
    RKExplosions.CreateGenericFlashExplosionAtBone(self, Utilities.GetRandomInt(0, numBones), 4.5)
    self:ShakeCamera(45 * shake, 1.5 * shake, 0, 1.5 * shake / 1.375)
    ApplyDeathWeaponDamage(self, 'CollossusDeathMedBoom')

    WaitSeconds(2.5)
    RKExplosions.CreateGenericFlashExplosionAtBone(self, Utilities.GetRandomInt(0, numBones), 6.5)
    self:ShakeCamera(75 * shake * 2.5, 2.5 * shake, 0, 3.5 * shake)
    ApplyDeathWeaponDamage(self, 'CollossusDeathBigBoom')

    if self.DeathAnimManip then
        WaitFor(self.DeathAnimManip)
    end
end

local function DeathThreadLand(self, hoverTiming, walkingTiming)
    local numBones = self:GetBoneCount() - 1
    local shake = Utilities.GetRandomFloat(1.5, 2.5) / 3.5

    self:ShakeCamera(45 * shake, 1.5 * shake, 0, 1.5 * shake / 1.375)
    self:PlayUnitSound('Destroyed')
    CreateCoreBreachEffects(self)

    RKExplosions.CreateAeonLargeInitialHitExplosionAtBone(self, Utilities.GetRandomInt(0, numBones), 5.0)
    CreateDebris(self)
    ApplyDeathWeaponDamage(self, 'CollossusDeathMedBoom')

    WaitSeconds(2.1)
    for _ = 0, numBones / 2 do
        self:PlayUnitSound('Destroyed')
        RKExplosions.CreateAeonMediumHitExplosionAtBone(
            self,
            Utilities.GetRandomInt(0, numBones),
            Utilities.GetRandomFloat(0.3, 0.6)
        )

        if hoverTiming then
            self:ShakeCamera(30 * shake, shake, 0, shake / 1.375)
        end

        if walkingTiming then
            WaitSeconds(Utilities.GetRandomFloat(0, 1))
        else
            WaitSeconds(Utilities.GetRandomFloat(0, 0.5))
        end

        RKExplosions.CreateAeonSmallHitExplosionAtBone(
            self,
            Utilities.GetRandomInt(0, numBones),
            Utilities.GetRandomFloat(0.2, 0.4)
        )
        self:ShakeCamera(30 * shake, shake, 0, shake / 1.375)
        CreateDebris(self)

        if walkingTiming then
            WaitSeconds(0.2)
        else
            WaitSeconds(Utilities.GetRandomFloat(0, 0.5))
        end
    end

    WaitSeconds(0.5)
    self:PlayUnitSound('Destroyed')
    RKExplosions.CreateAeonLargeHitExplosionAtBone(self, Utilities.GetRandomInt(0, numBones), 4.5)
    CreateDebris(self)
    self:ShakeCamera(45 * shake, 1.5 * shake, 0, 1.5 * shake / 1.375)
    ApplyDeathWeaponDamage(self, 'CollossusDeathMedBoom')

    WaitSeconds(4)
    RKExplosions.CreateGCFinalLargeHitExplosionAtBone(self, Utilities.GetRandomInt(0, numBones), 6.5)
    CreateDebris(self)
    self:ShakeCamera(75 * shake * 2.5, 2.5 * shake, 0, 3.5 * shake)
    ApplyDeathWeaponDamage(self, 'CollossusDeathBigBoom')

    if self.DeathAnimManip then
        WaitFor(self.DeathAnimManip)
    end
end

--- Creates an Aeon land-unit class with RK's experimental death sequence.
---@param base Class
---@param options { waterLoopDelay: number?, hoverTiming: boolean?, walkingTiming: boolean? }
---@return Class
function CreateClass(base, options)
    local BaseOnCreate = base.OnCreate
    local BaseDeathThread = base.DeathThread
    local waterLoopDelay = options.waterLoopDelay
    local hoverTiming = options.hoverTiming
    local walkingTiming = options.walkingTiming

    return ClassUnit(base) {
        OnCreate = function(self)
            BaseOnCreate(self)

            self.FxDamage1 = {
                EffectTemplate['LightLandUnitDmg' .. self.TechLevel .. self.factionCategory]
            }
            self.FxDamage2 = {
                EffectTemplate['MediumLandUnitDmg' .. self.TechLevel .. self.factionCategory]
            }
            self.FxDamage3 = {
                EffectTemplate['HeavyLandUnitDmg' .. self.TechLevel .. self.factionCategory]
            }
        end,

        DeathThreadWater = function(self)
            DeathThreadWater(self, waterLoopDelay)
        end,

        DeathThreadLand = function(self)
            DeathThreadLand(self, hoverTiming, walkingTiming)
        end,

        DeathThread = function(self, overkillRatio, instigator)
            WARN('start custom death thread')
            if not EntityCategoryContains(categories.EXPERIMENTAL, self) then
                BaseDeathThread(self, overkillRatio, instigator)
                return
            end

            local layer = self:GetCurrentLayer()
            if layer == 'Water' or layer == 'Seabed' or layer == 'Sub' then
                self:DeathThreadWater()
            else
                self:DeathThreadLand()
            end

            if not self.BagsDestroyed then
                self:DestroyAllBuildEffects()
                self:DestroyAllTrashBags()
                self.BagsDestroyed = true
            end

            self:DestroyAllDamageEffects()

            if self.ShowUnitDestructionDebris and overkillRatio then
                self:CreateUnitDestructionDebris(true, true, overkillRatio > 2)
            end

            RKExplosions.CreateScorchMarkDecalRKSExpAeon(self, 20, self.Army)
            self:DestroyUnit(overkillRatio)
        end,
    }
end
