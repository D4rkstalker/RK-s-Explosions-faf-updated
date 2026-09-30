--**********************************************************************************
--** Copyright (c) 2023 FAForever
--**
--** Permission is hereby granted, free of charge, to any person obtaining a copy
--** of this software and associated documentation files (the "Software"), to deal
--** in the Software without restriction, including without limitation the rights
--** to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--** copies of the Software, and to permit persons to whom the Software is
--** furnished to do so, subject to the following conditions:
--**
--** The above copyright notice and this permission notice shall be included in all
--** copies or substantial portions of the Software.
--**
--** THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--** IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--** FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--** AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--** LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--** OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--** SOFTWARE.
--**********************************************************************************

local AirUnit = import('/lua/sim/units/airunit.lua').AirUnit
local DefaultExplosions = import('/lua/defaultexplosions.lua')
local EffectTemplate = import('/lua/effecttemplates.lua')
local Utilities = import('/lua/utilities.lua')

local BoomSoundBlueprint = import('/mods/rks_explosions/boomsounds/BoomSounds.bp')
local RKEffectUtilities = import('/mods/rks_explosions/lua/RKEffectUtilities.lua')
local RKExplosions = import('/mods/rks_explosions/lua/SDExplosions.lua')
local NEffectTemplate = import('/mods/rks_explosions/lua/NEffectTemplates.lua')
local SDEffectTemplate = import('/mods/rks_explosions/lua/SDEffectTemplates.lua')
local toggle = import('/mods/rks_explosions/lua/Togglestuff.lua').toggle

local CustomEffectTemplate = toggle == 1 and SDEffectTemplate or NEffectTemplate

local AirUnitManageDamageEffects = AirUnit.ManageDamageEffects
local AirUnitOnAnimTerrainCollision = AirUnit.OnAnimTerrainCollision
local AirUnitOnDamage = AirUnit.OnDamage
local AirUnitOnImpact = AirUnit.OnImpact
local AirUnitOnKilled = AirUnit.OnKilled

local function DestroyEffects(effects)
    if not effects then
        return
    end

    for _, effect in effects do
        effect:Destroy()
    end
end

local function DestroyCoreBreachEffects(self)
    DestroyEffects(self.CoreBreachEffects1)
    DestroyEffects(self.CoreBreachEffects2)
    self.CoreBreachEffects1 = nil
    self.CoreBreachEffects2 = nil
end

local function PlaySubBoomSound(self, sound)
    local audio = BoomSoundBlueprint.Audio
    if audio and audio[sound] then
        self:PlaySound(audio[sound])
    end
end

local function CreateCoreBreachEffects(self)
    local numBones = self:GetBoneCount() - 1

    RKEffectUtilities.CreateBoneEffectsAttachedWithBag(
        self,
        Utilities.GetRandomInt(0, numBones),
        self.Army,
        CustomEffectTemplate.CZAR_Center_Core_Breach01,
        3.15,
        'CoreBreachEffects1'
    )
    RKEffectUtilities.CreateBoneEffectsAttachedWithBag(
        self,
        Utilities.GetRandomInt(0, numBones),
        self.Army,
        CustomEffectTemplate.CZAR_Center_Core_Breach02,
        3,
        'CoreBreachEffects1'
    )
    RKEffectUtilities.CreateBoneEffectsAttachedWithBag(
        self,
        0,
        self.Army,
        CustomEffectTemplate.CZAR_Air_Rushing_In,
        1,
        'CoreBreachEffects2'
    )
    RKEffectUtilities.CreateBoneEffectsAttachedWithBag(
        self,
        Utilities.GetRandomInt(0, numBones),
        self.Army,
        CustomEffectTemplate.CZAR_Core_Rupture,
        3,
        'CoreBreachEffects1'
    )

    PlaySubBoomSound(self, 'CZARCoreDestroyed')
end

---@class AAirUnit : AirUnit
AAirUnit = ClassUnit(AirUnit) {
    CreateDeathExplosionInitialShockwave = function(self)
        local sides = 180
        local angle = 2 * math.pi / sides
        local velocity = 50

        for i = 0, sides - 1 do
            local x = math.sin(i * angle)
            local z = math.cos(i * angle)

            self:CreateProjectile(
                '/mods/rks_explosions/effects/entities/Aeon/CZARShockwaveEdge/CZARShockwaveEdge_proj.bp',
                x, 1.5, z, x, 0, z
            ):SetVelocity(velocity):SetAcceleration(0)
            self:CreateProjectile(
                '/mods/rks_explosions/effects/entities/Aeon/CZARShockwaveEdge/CZARShockwaveEdge_proj.bp',
                x, 0.5, z, x, 0, z
            ):SetVelocity(velocity):SetAcceleration(0)
            self:CreateProjectile(
                '/mods/rks_explosions/effects/entities/Aeon/CZARShockwaveEdgeUpper/CZARShockwaveEdgeUpper_proj.bp',
                x, -0.5, z, x, 0, z
            ):SetVelocity(velocity):SetAcceleration(0)
            self:CreateProjectile(
                '/mods/rks_explosions/effects/entities/Aeon/CZARShockwaveEdge/CZARShockwaveEdge_proj.bp',
                x, -1.5, z, x, 0, z
            ):SetVelocity(velocity):SetAcceleration(0)
        end
    end,

    CreateDeathExplosionTareThroughEffect = function(self)
        local sides = 36
        local angle = 2 * math.pi / sides
        local velocity = 34 * 4 / 3

        for i = 0, sides - 1 do
            local x = math.sin(i * angle)
            local z = math.cos(i * angle)

            self:CreateProjectile(
                '/mods/rks_explosions/effects/entities/Aeon/CZARCenterEffectUp/CZARCenterEffectUp_proj.bp',
                x, 0, z, x, 0, z
            ):SetVelocity(velocity):SetAcceleration(0)
            self:CreateProjectile(
                '/mods/rks_explosions/effects/entities/Aeon/CZARCenterEffectDown/CZARCenterEffectDown_proj.bp',
                x, 0, z, x, 0, z
            ):SetVelocity(velocity):SetAcceleration(0)
        end
    end,

    --- FAF drives the normal 75/50/25 percent effects through OnHealthChanged.
    --- This override only adds and removes the experimental core-breach effect.
    ManageDamageEffects = function(self, newHealth, oldHealth)
        AirUnitManageDamageEffects(self, newHealth, oldHealth)

        if EntityCategoryContains(categories.EXPERIMENTAL, self) and newHealth > oldHealth and newHealth > 0.1 then
            DestroyCoreBreachEffects(self)
        end
    end,

    OnDamage = function(self, instigator, amount, vector, damageType)
        if not EntityCategoryContains(categories.EXPERIMENTAL, self) then
            AirUnitOnDamage(self, instigator, amount, vector, damageType)
            return
        end

        local maxHealth = self:GetMaxHealth()
        local oldHealth = self:GetHealth() / maxHealth
        AirUnitOnDamage(self, instigator, amount, vector, damageType)
        local newHealth = self:GetHealth() / maxHealth

        if oldHealth > 0.1 and newHealth <= 0.1 and newHealth > 0 then
            DestroyCoreBreachEffects(self)
            CreateCoreBreachEffects(self)
        end
    end,

    DeathThreadFn = function(self)
        WaitSeconds(0.35)

        if self:BeenDestroyed() then
            return
        end

        RKExplosions.CreateFactionalExplosionAtBone(
            self,
            0,
            13.5,
            CustomEffectTemplate.ExplosionTECH2AEON
        )
        local shake = Utilities.GetRandomFloat(1.5, 2.5) / 3.5
        self:ShakeCamera(225 * shake, 7.5 * shake, 0, 7.5 * shake / 1.375)
        self:PlayUnitSound('Killed')
    end,

    OnKilled = function(self, instigator, type, overkillRatio)
        if EntityCategoryContains(categories.EXPERIMENTAL, self)
            and self:GetFractionComplete() == 1
            and self:GetCurrentLayer() == 'Air'
            and type ~= 'TransportDamage'
        then
            DestroyCoreBreachEffects(self)

            self:CreateEffects(CustomEffectTemplate.CZAR_Center_FallDown_Smoke, self.Army, 1)
            self:CreateEffects(CustomEffectTemplate.CZAR_Center_FallDown_Aura, self.Army, 1)
            self:CreateEffects(CustomEffectTemplate.CZAR_Center_Charge, self.Army, 4)
            RKExplosions.CreateInheritedVelocityDebrisProjectiles(
                self,
                150,
                { self:GetVelocity() },
                12.75,
                0.23,
                50.35,
                '/mods/rks_explosions/effects/entities/CZAR_Debris/CZAR_Debris_proj.bp'
            )
            self:CreateDeathExplosionTareThroughEffect()
            RKExplosions.CreateFactionalExplosionAtBone(
                self,
                0,
                0.5,
                CustomEffectTemplate.CZAR_Initial_Center_Explosion
            )
            self:CreateDeathExplosionInitialShockwave()
            self:ForkThread(self.DeathThreadFn)
        end

        AirUnitOnKilled(self, instigator, type, overkillRatio)
    end,

    OnImpact = function(self, with)
        if not EntityCategoryContains(categories.EXPERIMENTAL, self) then
            AirUnitOnImpact(self, with)
            return
        end

        if self.GroundImpacted then
            return
        end
        self.GroundImpacted = true

        local deathWeapon = self.deathWep
        if not deathWeapon or not self.DeathCrashDamage then
            WARN('AAirUnit.OnImpact: no DeathImpact weapon was found for ' .. self.UnitId)
        elseif self.DeathCrashDamage > 0 then
            DamageArea(
                self,
                self:GetPosition(),
                deathWeapon.DamageRadius,
                self.DeathCrashDamage,
                deathWeapon.DamageType,
                deathWeapon.DamageFriendly
            )
            DamageArea(self, self:GetPosition(), deathWeapon.DamageRadius, 1, 'TreeForce', false)
        end

        self:PlayUnitSound('Destroyed')
        RKExplosions.CreateScorchMarkDecalRKSExpAeon(self, 50, self.Army)

        if with == 'Water' then
            for _, emitter in self.RKEmitters or {} do
                emitter:ScaleEmitter(0)
            end

            self:PlayUnitSound('AirUnitWaterImpact')
            self:CreateEffects(EffectTemplate.Splashy, self.Army, 12)
            DefaultExplosions.CreateFlash(self, -1, 1, self.Army)
            self:CreateEffects(CustomEffectTemplate.OilSlick, self.Army, 7)
            self.shallSink = true

            if self.colliderProj then
                self.colliderProj:Destroy()
                self.colliderProj = nil
            end
        else
            RKExplosions.CreateFactionalExplosionAtBone(
                self,
                0,
                14.5,
                CustomEffectTemplate.CZARCenterImpactExplosion
            )
            local shake = Utilities.GetRandomFloat(1.5, 2.5) / 3.5
            self:ShakeCamera(225 * shake, 7.5 * shake, 0, 7.5 * shake / 1.375)
        end

        self:DisableUnitIntel('Killed')
        self:DisableIntel('Vision')
        self:ForkThread(self.DeathThread, self.OverKillRatio)
    end,

    OnAnimTerrainCollision = function(self, bone, x, y, z)
        if not EntityCategoryContains(categories.EXPERIMENTAL, self) then
            AirUnitOnAnimTerrainCollision(self, bone, x, y, z)
            return
        end

        self:PlayUnitSound('TerrainImpact')
        DamageArea(self, { x, y, z }, 5, 1000, 'Default', true, false)
        RKExplosions.CreateFactionalExplosionAtBone(
            self,
            bone,
            3,
            CustomEffectTemplate.ExplosionTECH3AEON
        )

        local blueprint = self.Blueprint
        DefaultExplosions.CreateDebrisProjectiles(
            self,
            DefaultExplosions.GetAverageBoundingXYZRadius(self),
            { blueprint.SizeX, blueprint.SizeY, blueprint.SizeZ }
        )

        AirUnitOnAnimTerrainCollision(self, bone, x, y, z)
    end,

}
