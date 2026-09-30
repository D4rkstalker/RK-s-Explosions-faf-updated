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
local Utilities = import('/lua/utilities.lua')

local RKExplosions = import('/mods/rks_explosions/lua/SDExplosions.lua')

local AirUnitOnImpact = AirUnit.OnImpact
local AirUnitOnKilled = AirUnit.OnKilled

local function CreateFlamingDebris(self)
    local blueprint = self.Blueprint
    RKExplosions.CreateShipFlamingDebrisProjectiles(
        self,
        DefaultExplosions.GetAverageBoundingXYZRadius(self),
        { blueprint.SizeX, blueprint.SizeY, blueprint.SizeZ }
    )
end

local function CreateInitialExplosions(self)
    local numBones = self:GetBoneCount() - 1
    local shake = Utilities.GetRandomFloat(0.5, 1.5) / 8

    self:PlayUnitSound('Destroyed')
    CreateFlamingDebris(self)
    CreateFlamingDebris(self)
    RKExplosions.CreateUEFMediumHitExplosionAtBone(self, 0, 2)
    self:ShakeCamera(135 * shake, 4.5 * shake, 0, 1.55 * shake / 1.375)
    RKExplosions.CreateUEFSmallHitExplosionAtBone(
        self,
        Utilities.GetRandomInt(0, numBones),
        0.625
    )
    self:ShakeCamera(135 * shake, 4.5 * shake, 0, 1.55 * shake / 1.375)
    self:PlayUnitSound('Destroyed')
    RKExplosions.CreateUEFMediumHitExplosionAtBone(
        self,
        Utilities.GetRandomInt(0, numBones),
        0.625
    )
    self:ShakeCamera(135 * shake, 4.5 * shake, 0, 1.55 * shake / 1.375)
end

---@class TAirUnit : AirUnit
TAirUnit = ClassUnit(AirUnit) {
    OnKilled = function(self, instigator, type, overkillRatio)
        if EntityCategoryContains(categories.EXPERIMENTAL, self)
            and self:GetFractionComplete() == 1
            and type ~= 'TransportDamage'
        then
            CreateInitialExplosions(self)
            self:ForkThread(self.ExplosionThread)
        end

        AirUnitOnKilled(self, instigator, type, overkillRatio)
    end,

    ExplosionThread = function(self)
        local numBones = self:GetBoneCount() - 1

        while not self:BeenDestroyed() do
            for _ = 0, numBones / 3 + 1 do
                if Utilities.GetRandomInt(0, 3) == 0 then
                    RKExplosions.CreateUEFMediumHitExplosionAtBone(
                        self,
                        Utilities.GetRandomInt(0, numBones),
                        1
                    )
                    CreateFlamingDebris(self)
                    self:PlayUnitSound('Destroyed')
                    RKExplosions.CreateUEFSmallHitExplosionAtBone(
                        self,
                        Utilities.GetRandomInt(0, numBones),
                        0.625
                    )
                else
                    RKExplosions.CreateUEFSmallHitExplosionAtBone(
                        self,
                        Utilities.GetRandomInt(0, numBones),
                        0.625
                    )
                    self:PlayUnitSound('Destroyed')
                    RKExplosions.CreateUEFMediumHitExplosionAtBone(
                        self,
                        Utilities.GetRandomInt(0, numBones),
                        0.625
                    )
                end

                WaitSeconds(0.1)
            end
        end
    end,

    OnImpact = function(self, with)
        if not EntityCategoryContains(categories.EXPERIMENTAL, self) then
            AirUnitOnImpact(self, with)
            return
        end

        if self.GroundImpacted then
            return
        end

        CreateInitialExplosions(self)
        AirUnitOnImpact(self, with)
    end,
}
