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

local AirUnit = import('/lua/defaultunits.lua').AirUnit
local DefaultExplosions = import('/lua/defaultexplosions.lua')
local EffectTemplate = import('/lua/effecttemplates.lua')
local Utilities = import('/lua/utilities.lua')

local RKEffectUtilities = import('/mods/rks_explosions/lua/RKEffectUtilities.lua')
local RKExplosions = import('/mods/rks_explosions/lua/SDExplosions.lua')
local NEffectTemplate = import('/mods/rks_explosions/lua/NEffectTemplates.lua')
local SDEffectTemplate = import('/mods/rks_explosions/lua/SDEffectTemplates.lua')
local toggle = import('/mods/rks_explosions/lua/Togglestuff.lua').toggle

local CustomEffectTemplate = toggle == 1 and SDEffectTemplate or NEffectTemplate

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

---@class CAirUnit : AirUnit
CAirUnit = ClassUnit(AirUnit) {
    --- Kept because the legacy Soul Ripper unit hook forks this inherited method.
    DeathThreadFn = function(self)
    end,

    OnKilled = function(self, instigator, type, overkillRatio)
        if EntityCategoryContains(categories.EXPERIMENTAL, self)
            and self:GetFractionComplete() == 1
            and self:GetCurrentLayer() == 'Air'
            and type ~= 'TransportDamage'
        then
            DestroyEffects(self.EngineFailing1)
            self.EngineFailing1 = nil

            local numBones = self:GetBoneCount() - 1
            RKExplosions.CreateUpwardsVelocityDebrisProjectiles(
                self,
                150,
                { self:GetVelocity() },
                12.75,
                0.23,
                50.35,
                '/mods/rks_explosions/effects/entities/SR_Debris/SR_Debris_proj.bp'
            )
            RKExplosions.CreateFactionalExplosionAtBone(
                self,
                0,
                Utilities.GetRandomFloat(1, 7.5),
                CustomEffectTemplate.SoulRipper_Final_Boom
            )
            self:PlayUnitSound('FinalBoom')

            for _ = 1, 14 do
                RKEffectUtilities.CreateBoneEffectsAttachedWithBag(
                    self,
                    Utilities.GetRandomInt(0, numBones),
                    self.Army,
                    CustomEffectTemplate.SoulRipper_Ambient_Electricity,
                    0.2,
                    'HullDamage'
                )
            end

            RKEffectUtilities.CreateBoneEffectsAttachedWithBag(
                self,
                0,
                self.Army,
                CustomEffectTemplate.SoulRipper_Ambient_Electricity_Upper,
                0.3,
                'HullDamage'
            )
            RKEffectUtilities.CreateBoneEffectsAttachedWithBag(
                self,
                0,
                self.Army,
                CustomEffectTemplate.SoulRipper_Fall_Down_Smoke,
                1,
                'HullDamage'
            )

            self:ForkThread(self.DeathThreadFn)
        end

        AirUnitOnKilled(self, instigator, type, overkillRatio)
    end,

    ExplodingThreadFn = function(self, overkillRatio)
        local numBones = self:GetBoneCount() - 1

        local function DoSubBoom(bound, effect)
            RKExplosions.CreateFactionalExplosionAtBone(
                self,
                Utilities.GetRandomInt(0, numBones),
                Utilities.GetRandomFloat(1, bound),
                effect
            )
            self:PlayUnitSound('SubBooms')
        end

        WaitSeconds(6.25 / 1.5)
        for _ = 1, 8 do
            DoSubBoom(2.5, CustomEffectTemplate.SoulRipper_First_Series_Booms)
            WaitSeconds(Utilities.GetRandomFloat(0.95 / 3, 1.35 / 3))
        end

        WaitSeconds(4 / 3)
        for _ = 1, 8 do
            DoSubBoom(1.5, CustomEffectTemplate.SoulRipper_Second_Series_Booms)
            WaitSeconds(Utilities.GetRandomFloat(0, 0.6 / 3))
        end

        WaitSeconds(1)
        for _ = 1, 3 do
            DoSubBoom(3.5, CustomEffectTemplate.SoulRipper_Third_Series_Booms)
            WaitSeconds(Utilities.GetRandomFloat(2 / 3, 1))
        end

        DestroyEffects(self.HullDamage)
        self.HullDamage = nil

        WaitSeconds(4 / 3)
        RKExplosions.CreateScorchMarkDecalRKSExpCyb(self, 19, self.Army)
        RKExplosions.CreateUpwardsVelocityDebrisProjectiles(
            self,
            150,
            { self:GetVelocity() },
            12.75,
            0.23,
            50.35,
            '/mods/rks_explosions/effects/entities/SR_Debris/SR_Debris_proj.bp'
        )
        RKExplosions.CreateFactionalExplosionAtBone(
            self,
            0,
            Utilities.GetRandomFloat(1, 7.5),
            CustomEffectTemplate.SoulRipper_Final_Boom
        )
        self:PlayUnitSound('FinalBoom')

        if not self.BagsDestroyed then
            self:DestroyAllBuildEffects()
            self:DestroyAllTrashBags()
            self.BagsDestroyed = true
        end

        self:StopUnitAmbientSound()
        self:DestroyAllDamageEffects()
        self:DestroyUnit(overkillRatio)
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
            WARN('CAirUnit.OnImpact: no DeathImpact weapon was found for ' .. self.UnitId)
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

        if with == 'Water' then
            for _, emitter in self.RKEmitters or {} do
                emitter:ScaleEmitter(0)
            end

            self:PlayUnitSound('AirUnitWaterImpact')
            self:CreateEffects(EffectTemplate.Splashy, self.Army, 12)
            DefaultExplosions.CreateFlash(self, -1, 1, self.Army)
            self:CreateEffects(CustomEffectTemplate.OilSlick, self.Army, 14)
            self.shallSink = true

            if self.colliderProj then
                self.colliderProj:Destroy()
                self.colliderProj = nil
            end

            self:ForkThread(self.DeathThread, self.OverKillRatio)
        else
            self:ForkThread(self.ExplodingThreadFn, self.OverKillRatio)
            RKExplosions.CreateFactionalExplosionAtBone(
                self,
                0,
                3.5,
                CustomEffectTemplate.SoulRipper_Impact_Explosion
            )
            CreateLightParticle(
                self,
                -1,
                self.Army,
                20,
                60,
                'glow_02',
                'ramp_quantum_warhead_flash_01'
            )
        end

        self:DisableUnitIntel('Killed')
        self:DisableIntel('Vision')
    end,
}
