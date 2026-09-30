local DefaultExplosions = import('/lua/defaultexplosions.lua')
local Utilities = import('/lua/utilities.lua')

local RKExplosions = import('/mods/rks_explosions/lua/SDExplosions.lua')

local function CreateFlamingDebris(self)
    local blueprint = self.Blueprint
    RKExplosions.CreateShipFlamingDebrisProjectiles(
        self,
        DefaultExplosions.GetAverageBoundingXYZRadius(self),
        { blueprint.SizeX, blueprint.SizeY, blueprint.SizeZ }
    )
end

local function ShakeUnitCamera(self, shake, multiplier, timeMultiplier)
    self:ShakeCamera(
        30 * shake * multiplier,
        shake * multiplier,
        0,
        shake * timeMultiplier / 1.375
    )
end

local function ApplyBigDeathBoom(self)
    local blueprint = self.Blueprint
    local fractionThreshold = blueprint.General.FractionThreshold or 0.5
    if self:GetFractionComplete() < fractionThreshold then
        return
    end

    for _, weapon in blueprint.Weapon or {} do
        if weapon.Label == 'BigDeathBoom' then
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

local function DeathThreadLand(self)
    local numBones = self:GetBoneCount() - 1
    local shake = Utilities.GetRandomFloat(0.5, 1.5) / 8

    self:PlayUnitSound('Destroyed')
    CreateFlamingDebris(self)
    CreateFlamingDebris(self)
    RKExplosions.CreateUEFMediumHitExplosionAtBone(self, 0, 1)
    ShakeUnitCamera(self, shake, 4.5, 1.55)

    WaitSeconds(0.7)
    for _ = 0, numBones / 3 + 1 do
        if Utilities.GetRandomInt(0, 1) == 0 then
            RKExplosions.CreateUEFSmallHitExplosionAtBone(
                self,
                Utilities.GetRandomInt(0, numBones),
                0.625
            )
            ShakeUnitCamera(self, shake, 4.5, 1.55)
            self:PlayUnitSound('Destroyed')
            WaitSeconds(0.1)
            RKExplosions.CreateUEFMediumHitExplosionAtBone(
                self,
                Utilities.GetRandomInt(0, numBones),
                0.625
            )
            ShakeUnitCamera(self, shake, 4.5, 1.55)
            WaitSeconds(0.3)
        else
            RKExplosions.CreateUEFMediumHitExplosionAtBone(
                self,
                Utilities.GetRandomInt(0, numBones),
                1
            )
            ShakeUnitCamera(self, shake, 4.5, 1.55)
            CreateFlamingDebris(self)
            self:PlayUnitSound('Destroyed')
            WaitSeconds(0.2)
            RKExplosions.CreateUEFSmallHitExplosionAtBone(
                self,
                Utilities.GetRandomInt(0, numBones),
                0.625
            )
            ShakeUnitCamera(self, shake, 4.5, 1.55)
            WaitSeconds(0.5)
        end
    end

    WaitSeconds(1)
    for _ = 1, 5 do
        CreateFlamingDebris(self)
    end

    RKExplosions.CreateUEFMediumHitExplosionAtBone(self, 0, 2.5)
    ShakeUnitCamera(self, shake, 4.5, 1.55)
    self:PlayUnitSound('DestroyedStep4')
    WaitSeconds(0.1)
    RKExplosions.CreateUEFSmallHitExplosionAtBone(
        self,
        Utilities.GetRandomInt(0, numBones),
        1.125
    )
    self:PlayUnitSound('DestroyedStep4')
    RKExplosions.CreateUEFSmallHitExplosionAtBone(
        self,
        Utilities.GetRandomInt(0, numBones),
        1.125
    )
    self:PlayUnitSound('DestroyedStep4')
    WaitSeconds(0.1)
    RKExplosions.CreateUEFMediumHitExplosionAtBone(
        self,
        Utilities.GetRandomInt(0, numBones),
        2.5
    )
    self:PlayUnitSound('DestroyedStep4')
    RKExplosions.CreateUEFSmallHitExplosionAtBone(
        self,
        Utilities.GetRandomInt(0, numBones),
        0.5625
    )
    RKExplosions.CreateUEFLargeHitExplosionAtBone(self, 0, 4.25)
    self:PlayUnitSound('DestroyedStep4')
    ShakeUnitCamera(self, shake, 9.5, 7.55)
    WaitSeconds(0.1)

    ApplyBigDeathBoom(self)
    self:PlayUnitSound('DestroyedStep3')

    -- The original UEF sequence uses the common black experimental scorch decal.
    RKExplosions.CreateScorchMarkDecalRKSExpCyb(self, 19, self.Army)
end

local function DeathThreadWater(self)
    self:PlayUnitSound('DestroyedStep3')
    RKExplosions.CreateScorchMarkDecalRKSExpCyb(self, 19, self.Army)
end

--- Creates a current-FAF UEF land class with RK's experimental death sequence.
---@param base Class
---@return Class
function CreateClass(base)
    local BaseDeathThread = base.DeathThread

    return ClassUnit(base) {
        DeathThreadLand = DeathThreadLand,
        DeathThreadWater = DeathThreadWater,

        DeathThread = function(self, overkillRatio, instigator)
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

            self:StopUnitAmbientSound()
            self:DestroyAllDamageEffects()
            self:DestroyUnit(0.1)
        end,
    }
end

