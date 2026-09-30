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

local BoomSoundBlueprint = import('/mods/rks_explosions/boomsounds/BoomSounds.bp')
local RKEffectUtilities = import('/mods/rks_explosions/lua/RKEffectUtilities.lua')
local RKExplosions = import('/mods/rks_explosions/lua/SDExplosions.lua')
local NEffectTemplate = import('/mods/rks_explosions/lua/NEffectTemplates.lua')
local SDEffectTemplate = import('/mods/rks_explosions/lua/SDEffectTemplates.lua')
local toggle = import('/mods/rks_explosions/lua/Togglestuff.lua').toggle
local damage_toggle = import('/mods/rks_explosions/lua/Togglestuff.lua').damage_toggle

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

local function DestroyEngineEffects(self)
    DestroyEffects(self.EngineFailing1)
    DestroyEffects(self.EngineFail1)
    DestroyEffects(self.EngineFail2)
    self.EngineFailing1 = nil
    self.EngineFail1 = nil
    self.EngineFail2 = nil
end

local function PlaySubBoomSound(self)
    local audio = BoomSoundBlueprint.Audio
    if audio and audio.SubBoomSoundSERAPHIM then
        self:PlaySound(audio.SubBoomSoundSERAPHIM)
    end
end

local function CreatePreFailEffects(self)
    RKEffectUtilities.CreateBoneEffectsAttachedWithBag(
        self,
        0,
        self.Army,
        CustomEffectTemplate.Ahwassa_Engine_PreFail_Electricity,
        0.5,
        'EngineFailing1'
    )
    RKEffectUtilities.CreateBoneEffectsAttachedWithBag(
        self,
        0,
        self.Army,
        CustomEffectTemplate.Ahwassa_Engine_PreFail_Smoke,
        5.115,
        'EngineFailing1'
    )
    PlaySubBoomSound(self)
end

local function CreateCriticalEffects(self)
    RKEffectUtilities.CreateBoneEffectsAttachedWithBag(
        self,
        0,
        self.Army,
        CustomEffectTemplate.Ahwassa_Engine_Critical_Explosion_Flashes,
        2.1,
        'EngineFail1'
    )
    RKEffectUtilities.CreateBoneEffectsAttachedWithBag(
        self,
        0,
        self.Army,
        CustomEffectTemplate.Ahwassa_Engine_Critical_Explosion_Sparks,
        0.6,
        'EngineFail1'
    )
    RKEffectUtilities.CreateBoneEffectsAttachedWithBag(
        self,
        0,
        self.Army,
        CustomEffectTemplate.Ahwassa_Engine_Critical_Smoke,
        15.115 / 6,
        'EngineFail1'
    )
    RKEffectUtilities.CreateBoneEffectsAttachedWithBag(
        self,
        0,
        self.Army,
        CustomEffectTemplate.Ahwassa_Engine_Critical_Breach,
        2,
        'EngineFail2'
    )
    RKEffectUtilities.CreateBoneEffectsAttachedWithBag(
        self,
        0,
        self.Army,
        CustomEffectTemplate.Ahwassa_Engine_Critical_Breach_Electricity,
        1,
        'EngineFail2'
    )
end

local SpawnEffects = {
    '/effects/emitters/seraphim_othuy_spawn_01_emit.bp',
    '/effects/emitters/seraphim_othuy_spawn_02_emit.bp',
    '/effects/emitters/seraphim_othuy_spawn_03_emit.bp',
    '/effects/emitters/seraphim_othuy_spawn_04_emit.bp',
}

---@class SAirUnit : AirUnit
SAirUnit = ClassUnit(AirUnit) {
    ContrailEffects = { '/effects/emitters/contrail_ser_polytrail_01_emit.bp' },
    SpawnEffects = SpawnEffects,

    --- FAF drives the normal 75/50/25 percent effects through OnHealthChanged.
    --- This override only removes the experimental pre-failure effect after healing.
    ManageDamageEffects = function(self, newHealth, oldHealth)
        AirUnitManageDamageEffects(self, newHealth, oldHealth)

        if EntityCategoryContains(categories.EXPERIMENTAL, self)
            and newHealth > oldHealth
            and newHealth > 0.1
        then
            DestroyEffects(self.EngineFailing1)
            self.EngineFailing1 = nil
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
            DestroyEffects(self.EngineFailing1)
            self.EngineFailing1 = nil
            CreatePreFailEffects(self)
        end
    end,

    DeathThreadFn = function(self)
        local shake = Utilities.GetRandomFloat(1.5, 2.5) / 3.5

        for _ = 1, 3 do
            self:PlayUnitSound('Destroyed')
            self:ShakeCamera(225 * shake, 7.5 * shake, 0, 0.15 * shake / 1.375)
            RKExplosions.CreateFlashShort(self, -1, 1.5, self.Army, 3)
            WaitSeconds(0.3)
        end

        self:PlayUnitSound('Destroyed')
        self:ShakeCamera(135 * shake, 4.5 * shake, 0, 1.55 * shake / 1.375)
        RKExplosions.CreateFlashShort(self, -1, 1.5, self.Army, 3)
    end,

    OnKilled = function(self, instigator, type, overkillRatio)
        if EntityCategoryContains(categories.EXPERIMENTAL, self)
            and self:GetFractionComplete() == 1
            and self:GetCurrentLayer() == 'Air'
            and type ~= 'TransportDamage'
            -- The legacy XSA0402 hook may already have created this sequence.
            and not self.EngineFail1
            and not self.EngineFail2
        then
            DestroyEngineEffects(self)
            CreateCriticalEffects(self)
            RKExplosions.CreateInheritedVelocityDebrisProjectiles(
                self,
                50,
                { self:GetVelocity() },
                17,
                0.23,
                50.35,
                '/mods/rks_explosions/effects/entities/Ahwassa_Debris/Ahwassa_Debris_proj.bp'
            )
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

        self:PlayUnitSound('Destroyed')
        self:PlayUnitSound('Destroyed')
        DestroyEffects(self.EngineFail1)
        DestroyEffects(self.EngineFail2)
        self.EngineFail1 = nil
        self.EngineFail2 = nil

        -- Let FAF apply shield-adjusted crash damage, sinking and intel cleanup
        -- before adding emitters that the mod's generic water impact suppresses.
        AirUnitOnImpact(self, with)

        if with == 'Water' then
            for _, emitter in self.RKEmitters or {} do
                emitter:ScaleEmitter(0)
            end

            self:CreateEffects(EffectTemplate.Splashy, self.Army, 12)
            DefaultExplosions.CreateFlash(self, -1, 1, self.Army)
            self:CreateEffects(CustomEffectTemplate.OilSlick, self.Army, 7)
        else
            RKExplosions.CreateFactionalExplosionAtBone(
                self,
                0,
                3.5,
                CustomEffectTemplate.Ahwassa_Impact_Explosion
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
            RKExplosions.CreateFlashLong(self, -1, 5.5, self.Army, 3)

            local shake = Utilities.GetRandomFloat(1.5, 2.5) / 3.5
            self:ShakeCamera(255 * shake, 8.5 * shake, 0, 9.15 * shake / 1.375)
        end

        RKExplosions.CreateScorchMarkDecalRKSExpSera(self, 37, self.Army)
        if damage_toggle == 1 then
            self:SpawnElectroStorm()
        end
    end,

    SpawnElectroStorm = function(self)
        local position = self:GetPosition()
        local spiritUnit = CreateUnitHPR(
            'XSL0402',
            self.Army,
            position[1],
            position[2],
            position[3],
            0,
            0,
            0
        )

        for _, effect in self.SpawnEffects do
            CreateAttachedEmitter(spiritUnit, -1, self.Army, effect)
        end
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
            CustomEffectTemplate.ExplosionTECH3SERAPHIM
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
