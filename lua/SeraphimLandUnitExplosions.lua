local Utilities = import('/lua/utilities.lua')

local RKExplosions = import('/mods/rks_explosions/lua/SDExplosions.lua')
local NEffectTemplate = import('/mods/rks_explosions/lua/NEffectTemplates.lua')
local SDEffectTemplate = import('/mods/rks_explosions/lua/SDEffectTemplates.lua')
local toggle = import('/mods/rks_explosions/lua/Togglestuff.lua').toggle
local damage_toggle = import('/mods/rks_explosions/lua/Togglestuff.lua').damage_toggle

local CustomEffectTemplate = toggle == 1 and SDEffectTemplate or NEffectTemplate

local SpawnEffects = {
    '/effects/emitters/seraphim_othuy_spawn_01_emit.bp',
    '/effects/emitters/seraphim_othuy_spawn_02_emit.bp',
    '/effects/emitters/seraphim_othuy_spawn_03_emit.bp',
    '/effects/emitters/seraphim_othuy_spawn_04_emit.bp',
}

local function CreateImpactExplosion(self)
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

local function SpawnElectroStorm(self)
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
end

local function ExperimentalDeathThread(self, overkillRatio)
    local numBones = self:GetBoneCount() - 1

    CreateImpactExplosion(self)
    WaitSeconds(1)

    local minimumExplosions = math.floor(numBones / 2)
    for _ = 0, Random(minimumExplosions, numBones) do
        WaitSeconds(Utilities.GetRandomFloat(0, 0.3))
        RKExplosions.CreateSeraLargeHitExplosionAtBone(
            self,
            Utilities.GetRandomInt(0, numBones),
            1
        )
        self:PlayUnitSound('Destroyed')

        local shake = Utilities.GetRandomFloat(1.5, 2.5) / 3.5
        self:ShakeCamera(30 * shake, shake, 0, shake / 1.375)
        WaitTicks(Random(2, 4))
        RKExplosions.CreateSeraMediumHitExplosionAtBone(
            self,
            Utilities.GetRandomInt(0, numBones),
            1
        )
    end

    WaitSeconds(0.5)

    if self.DeathAnimManip then
        WaitFor(self.DeathAnimManip)
    end

    CreateImpactExplosion(self)

    if self.ShowUnitDestructionDebris and overkillRatio then
        self:CreateUnitDestructionDebris(true, true, overkillRatio > 2)
    end

    if self:GetFractionComplete() == 1 and damage_toggle ==1 then
        self:SpawnElectroStorm()

    end

    if not self.BagsDestroyed then
        self:DestroyAllBuildEffects()
        self:DestroyAllTrashBags()
        self.BagsDestroyed = true
    end

    self:StopUnitAmbientSound()
    self:DestroyAllDamageEffects()
    self:DestroyUnit(overkillRatio)
end

--- Creates a current-FAF Seraphim land class with RK's experimental death sequence.
---@param base Class
---@return Class
function CreateClass(base)
    local BaseDeathThread = base.DeathThread

    return ClassUnit(base) {
        SpawnEffects = SpawnEffects,
        SpawnElectroStorm = SpawnElectroStorm,

        DeathThread = function(self, overkillRatio, instigator)
            if not EntityCategoryContains(categories.EXPERIMENTAL, self) then
                BaseDeathThread(self, overkillRatio, instigator)
                return
            end

            ExperimentalDeathThread(self, overkillRatio)
        end,
    }
end

