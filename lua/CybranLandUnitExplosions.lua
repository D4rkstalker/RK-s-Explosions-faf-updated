local DefaultExplosions = import('/lua/defaultexplosions.lua')
local EffectTemplate = import('/lua/effecttemplates.lua')
local Utilities = import('/lua/utilities.lua')

local RKExplosions = import('/mods/rks_explosions/lua/SDExplosions.lua')

local function CreateDamageEffects(self, bone, army)
    for _, effect in EffectTemplate.DamageFireSmoke01 do
        CreateAttachedEmitter(self, bone, army, effect):ScaleEmitter(1.5)
    end
end

local function CreateExplosionDebris(self, army)
    for _, effect in EffectTemplate.ExplosionDebrisLrg01 do
        CreateAttachedEmitter(self, 0, army, effect)
    end
end

local function CreateDeathExplosionDustRing(self)
    local sides = 18
    local angle = 2 * math.pi / sides

    for i = 0, sides - 1 do
        local x = math.sin(i * angle)
        local z = math.cos(i * angle)

        self:CreateProjectile(
            '/effects/entities/DestructionDust01/DestructionDust01_proj.bp',
            x, 1.5, z + 4,
            x, 0, z
        ):SetVelocity(2.8):SetAcceleration(-0.3)
    end
end

local function CreateFirePlumes(self, army, bones, yBoneOffset)
    local basePosition = self:GetPosition()

    for _, bone in bones do
        local position = self:GetPosition(bone)
        local offset = Utilities.GetDifferenceVector(position, basePosition)
        local velocity = Utilities.GetDirectionVector(position, basePosition)

        velocity[1] = velocity[1] + Utilities.GetRandomFloat(-0.3, 0.3)
        velocity[2] = velocity[2] + Utilities.GetRandomFloat(0, 0.3)
        velocity[3] = velocity[3] + Utilities.GetRandomFloat(-0.3, 0.3)

        local projectile = self:CreateProjectile(
            '/effects/entities/DestructionFirePlume01/DestructionFirePlume01_proj.bp',
            offset[1], offset[2] + yBoneOffset, offset[3],
            velocity[1], velocity[2], velocity[3]
        )
        projectile:SetBallisticAcceleration(Utilities.GetRandomFloat(-2, -1))
        projectile:SetVelocity(Utilities.GetRandomFloat(3, 4))
        projectile:SetCollision(false)
        CreateEmitterOnEntity(
            projectile,
            army,
            '/effects/emitters/destruction_explosion_fire_plume_02_emit.bp'
        )
    end
end

local function DeathThreadLand(self)
    local numBones = self:GetBoneCount() - 1
    local shake = Utilities.GetRandomFloat(1.5, 2.5) / 3.5

    self:PlayUnitSound('Destroyed')
    RKExplosions.CreateScorchMarkDecalRKSExpCyb(self, 12, self.Army)
    RKExplosions.CreateCybranMediumHitExplosionAtBone(self, Utilities.GetRandomInt(0, numBones), 0.25)
    RKExplosions.CreateCybranMediumHitExplosionAtBone(self, Utilities.GetRandomInt(0, numBones), 1)

    DefaultExplosions.CreateFlash(self, 0, 1, self.Army)
    CreateAttachedEmitter(self, 0, self.Army, '/effects/emitters/destruction_explosion_concussion_ring_03_emit.bp')
    CreateAttachedEmitter(self, 0, self.Army, '/effects/emitters/explosion_fire_sparks_02_emit.bp')
    CreateFirePlumes(self, self.Army, { 0 }, 0)
    CreateFirePlumes(self, self.Army, {
        Utilities.GetRandomInt(0, numBones),
        Utilities.GetRandomInt(0, numBones),
        Utilities.GetRandomInt(0, numBones),
        Utilities.GetRandomInt(0, numBones),
        Utilities.GetRandomInt(0, numBones),
    }, 0.5)

    for _ = 1, 3 do
        CreateExplosionDebris(self, self.Army)
    end

    for _ = 0, numBones / 4 do
        self:PlayUnitSound('Destroyed')
        RKExplosions.CreateCybranSmallHitExplosionAtBone(
            self,
            Utilities.GetRandomInt(0, numBones),
            Utilities.GetRandomFloat(0.3, 0.6)
        )
        self:ShakeCamera(30 * shake, shake, 0, shake / 1.375)
        WaitSeconds(Utilities.GetRandomFloat(0, 0.5))
        RKExplosions.CreateCybranMediumHitExplosionAtBone(
            self,
            Utilities.GetRandomInt(0, numBones),
            Utilities.GetRandomFloat(0.2, 0.4)
        )
        self:ShakeCamera(30 * shake, shake, 0, shake / 1.375)
        CreateFirePlumes(self, self.Army, { Utilities.GetRandomInt(0, numBones) }, 0)
        WaitSeconds(Utilities.GetRandomFloat(0, 0.5))
    end

    WaitSeconds(0.5)
    self:PlayUnitSound('Destroyed')

    -- Create damage effects on random turret and hull bones.
    for _ = 0, numBones / 8 + 1 do
        local bone = Utilities.GetRandomInt(0, numBones)
        RKExplosions.CreateCybranLargeHitExplosionAtBone(self, bone, 1.5)
        CreateDamageEffects(self, bone, self.Army)
        CreateDamageEffects(self, bone, self.Army)
        CreateFirePlumes(self, self.Army, { bone }, 0)
        self:PlayUnitSound('Destroyed')
        WaitSeconds(Utilities.GetRandomFloat(0, 0.3))
    end

    WaitSeconds(0.3)
    self:PlayUnitSound('Destroyed')
    local largeExplosionBone = Utilities.GetRandomInt(0, numBones)
    RKExplosions.CreateCybranLargeHitExplosionAtBone(self, largeExplosionBone, 1.5)
    CreateDamageEffects(self, largeExplosionBone, self.Army)
    CreateDamageEffects(self, largeExplosionBone, self.Army)
    CreateFirePlumes(self, self.Army, { largeExplosionBone }, 0)
    self:PlayUnitSound('Destroyed')
    CreateDeathExplosionDustRing(self)

    WaitSeconds(0.35)

    -- Ground-impact effects and force rings.
    self:PlayUnitSound('Destroyed')
    RKExplosions.CreateCybranMediumHitExplosionAtBone(self, Utilities.GetRandomInt(0, numBones), 0.65)
    for _, effect in EffectTemplate.FootFall01 do
        CreateAttachedEmitter(self, Utilities.GetRandomInt(0, numBones), self.Army, effect):ScaleEmitter(2)
        CreateAttachedEmitter(self, Utilities.GetRandomInt(0, numBones), self.Army, effect):ScaleEmitter(2)
    end

    CreateExplosionDebris(self, self.Army)
    CreateExplosionDebris(self, self.Army)

    local x, y, z = unpack(self:GetPosition())
    z = z + 3
    DamageRing(self, { x, y, z }, 0.1, 3, 1, 'Force', true)

    WaitSeconds(0.35)
    self:PlayUnitSound('Destroyed')
    RKExplosions.CreateCybranMediumHitExplosionAtBone(self, 0, 1)
    DamageRing(self, { x, y, z }, 0.1, 3, 1, 'Force', true)

    RKExplosions.CreateCybranMediumHitExplosionAtBone(self, Utilities.GetRandomInt(0, numBones), 0.25)
    RKExplosions.CreateCybranMediumHitExplosionAtBone(self, Utilities.GetRandomInt(0, numBones), 0.45)
    CreateDamageEffects(self, Utilities.GetRandomInt(0, numBones), self.Army)

    WaitSeconds(0.35)
    self:PlayUnitSound('Destroyed')
    RKExplosions.CreateCybranMediumHitExplosionAtBone(self, Utilities.GetRandomInt(0, numBones), 0.25)
    CreateDamageEffects(self, Utilities.GetRandomInt(0, numBones), self.Army)

    WaitSeconds(0.35)
    RKExplosions.CreateCybranMediumHitExplosionAtBone(self, Utilities.GetRandomInt(0, numBones), 1)
    CreateExplosionDebris(self, self.Army)
    self:PlayUnitSound('Destroyed')
    RKExplosions.CreateCybranMediumHitExplosionAtBone(self, Utilities.GetRandomInt(0, numBones), 0.25)
    CreateDamageEffects(self, Utilities.GetRandomInt(0, numBones), self.Army)

    WaitSeconds(0.3)
    self:PlayUnitSound('Destroyed')
    self:PlayUnitSound('Destroyed')
    RKExplosions.CreateCybranMediumHitExplosionAtBone(self, Utilities.GetRandomInt(0, numBones), 0.25)
    RKExplosions.CreateCybranMediumHitExplosionAtBone(self, Utilities.GetRandomInt(0, numBones), 0.45)
    CreateDamageEffects(self, Utilities.GetRandomInt(0, numBones), self.Army)

    WaitSeconds(0.4)
    self:PlayUnitSound('DestroyedStep3')
    RKExplosions.CreateCybranLargeHitExplosionAtBone(self, 0, 9)
end

local function DeathThreadWater(self)
    self:PlayUnitSound('Destroyed')
    RKExplosions.CreateScorchMarkDecalRKSExpCyb(self, 12, self.Army)
    DefaultExplosions.CreateFlash(self, 0, 3, self.Army)
end

--- Creates a current-FAF Cybran land class with RK's experimental death sequence.
---@param base Class
---@return Class
function CreateClass(base)
    local BaseDeathThread = base.DeathThread

    return ClassUnit(base) {
        CreateDamageEffects = CreateDamageEffects,
        CreateExplosionDebris = CreateExplosionDebris,
        CreateDeathExplosionDustRing = CreateDeathExplosionDustRing,
        CreateFirePlumes = CreateFirePlumes,

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

