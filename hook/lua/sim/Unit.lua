-- Includes changes to the fundamental Unit class,
-- in case some type of unit does not have a specifically modified OnKilled to use the
-- factional explosions, this acts as sort of a backup to still spawn them.
-- It is also neccesary because the changes here remove the current generic
-- explosion, since it's replaced by the factional ones.

local SDModifiedExplosion = import('/lua/defaultexplosions.lua')
local SDExplosions = import('/mods/rks_explosions/lua/SDExplosions.lua')
local SDEffectTemplate = import('/mods/rks_explosions/lua/SDEffectTemplates.lua')
local Utilities = import('/lua/utilities.lua')

local TechLevelMultiplierTbl = {
    ['TECH1'] = 0.425,
    ['TECH2'] = 0.707,
    ['TECH3'] = 0.872,
    -- 1
}

local oldUnitOnCreate = Unit.OnCreate
local oldUnitOnKilled = Unit.OnKilled
local oldUnitManageDamageEffects = Unit.ManageDamageEffects
local oldUnitOnStopBeingBuilt = Unit.OnStopBeingBuilt

Unit.OnCreate = function (self)
        oldUnitOnCreate(self)

        local blueprint = self.Blueprint or self:GetBlueprint()

        -- FAF no longer keeps these legacy fields on every Unit instance. The
        -- explosion code still uses them extensively, so initialise them from
        -- the blueprint instead of relying on the compatibility shim.
        self.factionCategory = blueprint.FactionCategory
        self.techCategory = blueprint.TechCategory

        -- Emitters belong to one unit. A class-level table causes every unit to
        -- share the same list and lets one aircraft impact modify other units.
        self.RKEmitters = {}

        -- Save commonly used variables
        self.TechLevelMultiplier = TechLevelMultiplierTbl[self.techCategory] or 1

        -- Currently only TECH1 - TECH3 is supported in the code
        if self.techCategory and StringStartsWith(self.techCategory, "TECH") then
            self.TechLevel = self.techCategory
        else
            self.TechLevel = 'TECH1'
        end
        
        local SDFactionalSmallSmoke = SDEffectTemplate['LightStructureUnitDmg'.. self.TechLevel ..self.factionCategory]
        local SDFactionalSmallFire = SDEffectTemplate['MediumStructureUnitDmg'.. self.TechLevel ..self.factionCategory]
        local SDFactionalBigFireSmoke = SDEffectTemplate['HeavyStructureUnitDmg'.. self.TechLevel ..self.factionCategory]

        -- Structure unit factional-specific damage effects and smoke
        self.FxDamage1 = {SDFactionalSmallSmoke} -- 75% HP
        self.FxDamage2 = {SDFactionalSmallFire} -- 50% HP
        self.FxDamage3 = {SDFactionalBigFireSmoke} -- 25% HP

    end

Unit.CreateEffects = function(self, EffectTable, army, scale)
        for _, v in EffectTable or {} do
            local emitter = CreateAttachedEmitter(self, -1, army, v):ScaleEmitter(scale)
            table.insert(self.RKEmitters, emitter)
            self.Trash:Add(emitter)
        end
    end

Unit.GetUnitVolume = function(self)
        local x, y, z = self:GetUnitSizes()
        return x * y * z
    end

Unit.CreateDestructionEffects = function(self, overKillRatio)
        SDModifiedExplosion.CreateScalableUnitExplosion(self, overKillRatio)
    end

Unit.OnKilled = function(self, instigator, type, overkillRatio)
        if EntityCategoryContains(categories.AIR, self) then
            self:ForkThread(SDExplosions.ExplosionAirImpact)
        else
            self:ForkThread(SDExplosions.ExplosionLand)
        end

        oldUnitOnKilled(self, instigator, type, overkillRatio)
    end

Unit.SinkDestructionEffects = function(self)
        local vol = self:GetUnitVolume()
        local numBones = self:GetBoneCount() - 1
        local pos = self:GetPosition()
        local surfaceHeight = GetSurfaceHeight(pos[1], pos[3])
        local i = 0

        while i < 1 do
            local randBone = Utilities.GetRandomInt(0, numBones)
            local boneHeight = self:GetPosition(randBone)[2]
            local toSurface = surfaceHeight - boneHeight
            local y = toSurface
            local rx, ry, rz = self:GetRandomOffset(0.3)
            local rs = math.max(math.min(2.5, vol / 20), 0.5)
            local scale = Utilities.GetRandomFloat(rs/2, rs)

            self:DestroyAllDamageEffects()
            if toSurface < 1 then
                CreateAttachedEmitter(self, randBone, self.Army,'/effects/emitters/destruction_water_sinking_ripples_01_emit.bp'):OffsetEmitter(rx, y, rz):ScaleEmitter(scale)
                CreateAttachedEmitter(self, randBone, self.Army, '/effects/emitters/destruction_water_sinking_wash_01_emit.bp'):OffsetEmitter(rx, y, rz):ScaleEmitter(scale)
            end

            if toSurface < 0 then
                --explosion.CreateDefaultHitExplosionAtBone(self, randBone, scale*1.5)
            else
                local lifetime = Utilities.GetRandomInt(50, 200)

                if(toSurface > 1) then
                    CreateEmitterAtBone(self, randBone, self.Army, '/effects/emitters/underwater_bubbles_01_emit.bp'):OffsetEmitter(rx, ry, rz)
                        :ScaleEmitter(scale)
                        :SetEmitterParam('LIFETIME', lifetime)

                    CreateAttachedEmitter(self, -1, self.Army, '/effects/emitters/destruction_underwater_sinking_wash_01_emit.bp'):OffsetEmitter(rx, ry, rz):ScaleEmitter(scale)
                end
                CreateEmitterAtBone(self, randBone, self.Army, '/effects/emitters/destruction_underwater_explosion_flash_01_emit.bp'):OffsetEmitter(rx, ry, rz):ScaleEmitter(scale)
                CreateEmitterAtBone(self, randBone, self.Army, '/effects/emitters/destruction_underwater_explosion_splash_01_emit.bp'):OffsetEmitter(rx, ry, rz):ScaleEmitter(scale)
            end
            local rd = Utilities.GetRandomFloat(0.4, 1.0)
            WaitSeconds(i + rd)
            i = i + 0.3
        end
    end

-- Disable damage effects on unfinished units
Unit.ManageDamageEffects = function(self, newHealth, oldHealth)
        if not self.isFinishedUnit then return end

        oldUnitManageDamageEffects(self, newHealth, oldHealth)
    end

-- Because there are no damaged effects on unfinished buildings, we have to set them up when the unit is completed.
Unit.OnStopBeingBuilt = function(self, builder, layer)
        local completed = oldUnitOnStopBeingBuilt(self, builder, layer)
        if completed == false then
            return false
        end

        -- The effects are spawned in 3 stages, 75%, 50%, 25% and then removed one by one as the unit heals.
        local healthRatio = self:GetHealth() / self:GetMaxHealth()
        if healthRatio < 0.75 then
            self:ManageDamageEffects(0.75, 1)
        end
        if healthRatio < 0.5 then
            self:ManageDamageEffects(0.5, 0.75)
        end
        if healthRatio < 0.25 then
            self:ManageDamageEffects(0.25, 0.5)
        end

        return completed
    end
