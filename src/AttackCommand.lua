require "Helper"
require "Manager"
require "GlobalVariables"

AttackManager = List.new()
function solveAttacks(dt)
    for val = AttackManager.last, AttackManager.first, -1 do
        local attack = AttackManager[val]
        local apos = getPosTable(attack) 
        if attack.mask == EnumRaceType.KNIGHT or attack.mask == EnumRaceType.ARCHER or attack.mask == EnumRaceType.MAGE then
            --if heroes attack, then lets check monsters
            for mkey = MonsterManager.last, MonsterManager.first, -1 do
                --check distance first
                local monster = MonsterManager[mkey]
                local mpos = getPosTable(monster)
                local dist = cc.pGetDistance(apos, mpos)
                if dist < (attack.maxRange + monster._radius) and dist > attack.minRange then
                    --range test passed, now angle test
                    local angle = radNormalize(cc.pToAngleSelf(cc.pSub(mpos,apos)))
                    local afacing = radNormalize(attack.facing)
                    if attack.mask == EnumRaceType.MAGE then
                        print("attack is ", angle, afacing)
                    end
                    
                    if(afacing + attack.angle/2)>angle and angle > (afacing- attack.angle/2) then
                        attack:onCollide(monster)
                    end
                end
            end
        elseif attack.mask == EnumRaceType.MONSTER then
            --if heroes attack, then lets check monsters
            for hkey = HeroManager.last, HeroManager.first, -1 do
                --check distance first
                local hero = HeroManager[hkey]
                local hpos = getPosTable(hero)
                local dist = cc.pGetDistance(getPosTable(attack), hpos)
                if dist < (attack.maxRange + hero._radius) and dist > attack.minRange then
                    --range test passed, now angle test
                    local angle = cc.pToAngleSelf(cc.pSub(hpos,getPosTable(attack)))
                    if(attack.facing + attack.angle/2)>angle and angle > (attack.facing- attack.angle/2) then
                        attack:onCollide(hero)
                    end
                end
            end
        end
        attack.curDuration = attack.curDuration+dt
        if attack.curDuration > attack.duration then
            attack:onTimeOut()
            List.remove(AttackManager,val)
        else
            attack:onUpdate(dt)
        end
    end
end

BasicCollider = class("BasicCollider", function()
    return cc.Node:create()
end)

function BasicCollider:ctor()
    self.minRange = 0   --the min radius of the fan
    self.maxRange = 150 --the max radius of the fan
    self.angle    = 120 --arc of attack, in radians
    self.knock    = 150 --default knock, knocks 150 units 
    self.mask     = 1   --1 is Heroes, 2 is enemy, 3 ??
    self.damage   = 100
    self.facing    = 0 --this is radians
    self.duration = 0
    self.curDuration = 0
    self.speed = 0 --traveling speed}
    self.criticalChance = 0
end
--callback when the collider has being solved by the attack manager, 
--make sure you delete it from node tree, if say you have an effect attached to the collider node
function BasicCollider:onTimeOut()
    self:removeFromParent()
end

function BasicCollider:playHitAudio()
    ccexp.AudioEngine:play2d(CommonAudios.hit, false,1)
end

function BasicCollider:hurtEffect(target)
    
    local hurtAction = cc.Animate:create(animationCathe:getAnimation("hurtAnimation"))
    local hurtEffect = cc.BillBoard:create()
    hurtEffect:setScale(1.5)
    hurtEffect:runAction(cc.Sequence:create(hurtAction, cc.RemoveSelf:create()))
    hurtEffect:setPosition3D(cc.V3(0,0,50))
    target:addChild(hurtEffect)  
end

function BasicCollider:onCollide(target)
    
    self:hurtEffect(target)
    self:playHitAudio()    
    target:hurt(self)
end

function BasicCollider:onUpdate()
    -- implement this function if this is a projectile
end

function BasicCollider:initData(pos, facing, attackInfo)
    self.minRange = attackInfo.minRange or self.minRange
    self.maxRange = attackInfo.maxRange or self.maxRange
    self.angle = attackInfo.angle or self.angle
    self.knock = attackInfo.knock or self.knock
    self.mask = attackInfo.mask or self.mask
    self.facing = facing or self.facing
    self.damage = attackInfo.damage or self.damage
    self.duration = attackInfo.duration or self.duration
    self.speed = attackInfo.speed or self.speed
    self.criticalChance = attackInfo.criticalChance
    self:setPosition(pos)
    List.pushlast(AttackManager, self)
    currentLayer:addChild(self, -10)
end

function BasicCollider.create(pos, facing, attackInfo)
    local ret = BasicCollider.new()    
    ret:initData(pos,facing,attackInfo)
    return ret
end


KnightNormalAttack = class("KnightNormalAttack", function()
    return BasicCollider.new()
end)

function KnightNormalAttack.create(pos, facing, attackInfo)
    local ret = KnightNormalAttack.new()
    ret:initData(pos,facing,attackInfo)
--    ret.sp = cc.Sprite:create("btn_circle_normal.png")
--    ret.sp:setPosition3D(cc.V3(100,0,50))
--    ret.sp:setScale(5)
--    ret:addChild(ret.sp)
--    ret:setRotation(RADIANS_TO_DEGREES(facing))
--    ret:setGlobalZOrder(-ret:getPositionY()+FXZorder)
    return ret
end

function KnightNormalAttack:onTimeOut()
    --self.sp:runAction(cc.FadeOut:create(1))
    --self:runAction(cc.Sequence:create(cc.DelayTime:create(1),cc.RemoveSelf:create()))
    self:removeFromParent()
end

MageNormalAttack = class("MageNormalAttack", function()
    return BasicCollider.new()
end)

function MageNormalAttack.create(pos,facing,attackInfo, target)
    local ret = MageNormalAttack.new()
    ret:initData(pos,facing,attackInfo)
    ret._target = target
    
    ret.sp = cc.BillBoard:create("FX/FX.png", cc.rect(208,290,45,44), 0)
    --ret.sp:setCamera(camera)
    ret.sp:setPosition3D(cc.V3(0,0,50))
    ret.sp:setScale(2)
    ret:addChild(ret.sp)
    
    local smoke = cc.ParticleSystemQuad:create("FX/iceTrail.plist")
    local magicf = cc.SpriteFrameCache:getInstance():getSpriteFrame("puff.png")
    smoke:setTextureWithRect(magicf:getTexture(), magicf:getRect())
    smoke:setScale(2)
    ret:addChild(smoke)
    smoke:setRotation3D({x=90, y=0, z=0})
    smoke:setGlobalZOrder(-ret:getPositionY()*2+FXZorder)
    smoke:setPositionZ(50)
    
    local pixi = cc.ParticleSystemQuad:create("FX/pixi.plist")
    local pixif = cc.SpriteFrameCache:getInstance():getSpriteFrame("particle.png")
    pixi:setTextureWithRect(pixif:getTexture(), pixif:getRect())
    pixi:setScale(2)
    ret:addChild(pixi)
    pixi:setRotation3D({x=90, y=0, z=0})
    pixi:setGlobalZOrder(-ret:getPositionY()*2+FXZorder)
    pixi:setPositionZ(50)
    
    ret.part1 = smoke
    ret.part2 = pixi
    return ret
end

function MageNormalAttack:onTimeOut()
    self.part1:stopSystem()
    self.part2:stopSystem()
    self.sp:removeFromParent()
    self:runAction(cc.Sequence:create(cc.DelayTime:create(1),cc.RemoveSelf:create()))
    
    local magic = cc.ParticleSystemQuad:create("FX/magic.plist")
    local magicf = cc.SpriteFrameCache:getInstance():getSpriteFrame("particle.png")
    magic:setTextureWithRect(magicf:getTexture(), magicf:getRect())
    magic:setScale(1.5)
    magic:setRotation3D({x=90, y=0, z=0})
    self:addChild(magic)
    magic:setGlobalZOrder(-self:getPositionY()*2+FXZorder)
    magic:setPositionZ(0)
    
    local ice = cc.BillBoard:create("FX/FX.png", cc.rect(75,327,35,25),0)
    ice:setScale(4)
    self:addChild(ice)
    ice:setPositionZ(50)
    ice:runAction(cc.FadeOut:create(1))
end

function MageNormalAttack:playHitAudio()
    ccexp.AudioEngine:play2d(MageProperty.ice_normalAttackHit, false,1)
end

function MageNormalAttack:onCollide(target)

    self:hurtEffect(target)
    self:playHitAudio()    
    target:hurt(self)
    --set cur duration to its max duration, so it will be removed when checking time out
    self.curDuration = self.duration+1
end

function MageNormalAttack:onUpdate(dt)
    local nextPos
    if self._target and self._target._isalive then
        local selfPos = getPosTable(self)
        local tpos = getPosTable(self._target)
        local angle = cc.pToAngleSelf(cc.pSub(tpos,selfPos))
        nextPos = cc.pRotateByAngle(cc.pAdd({x=self.speed*dt, y=0},selfPos),selfPos,angle)
    else
        local selfPos = getPosTable(self)
        nextPos = cc.pRotateByAngle(cc.pAdd({x=self.speed*dt, y=0},selfPos),selfPos,self.facing)
    end
    self:setPosition(nextPos)
end


MageIceSpikes = class("MageIceSpikes", function()
    return BasicCollider.new()
end)

function MageIceSpikes:playHitAudio()
    ccexp.AudioEngine:play2d(MageProperty.ice_specialAttackHit, false,1)
end

function MageIceSpikes.create(pos, facing, attackInfo)
    local ret = MageIceSpikes.new()
    ret:initData(pos,facing,attackInfo)
    ret.sp = cc.Sprite:createWithSpriteFrameName("shadow.png")
    ret.sp:setGlobalZOrder(-ret:getPositionY()+FXZorder)
    ret.sp:setOpacity(100)
    ret.sp:setPosition3D(cc.V3(0,0,1))
    ret.sp:setScale(ret.maxRange/12)
    ret:addChild(ret.sp)
    ret.DOTTimer = 0.5 --it will be able to hurt every 0.5 seconds
    ret.curDOTTime = 0.5
    ret.DOTApplied = false
    ---========
    --create 3 spikes
    local x = cc.Node:create()
    ret.spikes = x
    ret:addChild(x)
    for var=0, 10 do
        local rand = math.ceil(math.random()*3)
        local spike = cc.Sprite:createWithSpriteFrameName(string.format("iceSpike%d.png",rand))
        spike:setAnchorPoint(0.5,0)
        spike:setRotation3D(cc.V3(90,0,0))
        x:addChild(spike)
        if rand == 3 then
            spike:setScale(1.5)
        else
            spike:setScale(2)
        end
        spike:setOpacity(165)
        spike:setFlippedX(not(math.floor(math.random()*2)))
        spike:setPosition3D(cc.V3(math.random(-ret.maxRange/1.5, ret.maxRange/1.5),math.random(-ret.maxRange/1.5, ret.maxRange/1.5),1))
        spike:setGlobalZOrder(-ret:getPositionY()-spike:getPositionY()+FXZorder)
        x:setScale(0)
        x:setPositionZ(-210)
    end
    x:runAction(cc.EaseBackOut:create(cc.MoveBy:create(0.3,cc.V3(0,0,200))))
    x:runAction(cc.EaseBounceOut:create(cc.ScaleTo:create(0.4, 1)))
    
--    local puff = cc.BillboardParticleSystem:create("FX/puffRing2.plist")
--    --local puff = cc.ParticleSystemQuad:create("FX/puffRing.plist")
--    local puffFrame = cc.SpriteFrameCache:getInstance():getSpriteFrame("puff.png")
--    puff:setTextureWithRect(puffFrame:getTexture(), puffFrame:getRect())
--    puff:setCamera(camera)
--    puff:setScale(3)
--    ret:addChild(puff)
--    puff:setGlobalZOrder(-ret:getPositionY()*2+FXZorder)
    
    local magic = cc.BillboardParticleSystem:create(ParticleManager:getInstance():getPlistData("magic"))
    local magicf = cc.SpriteFrameCache:getInstance():getSpriteFrame("particle.png")
    magic:setTextureWithRect(magicf:getTexture(), magicf:getRect())
    magic:setCamera(camera)
    magic:setScale(1.5)
    ret:addChild(magic)
    magic:setGlobalZOrder(-ret:getPositionY()*2+FXZorder)
    magic:setPositionZ(0)

    
    return ret
end

function MageIceSpikes:onTimeOut()
    self.spikes:setVisible(false)
    local puff = cc.BillboardParticleSystem:create(ParticleManager:getInstance():getPlistData("puffRing"))
    --local puff = cc.ParticleSystemQuad:create("FX/puffRing.plist")
    local puffFrame = cc.SpriteFrameCache:getInstance():getSpriteFrame("puff.png")
    puff:setTextureWithRect(puffFrame:getTexture(), puffFrame:getRect())
    puff:setCamera(camera)
    puff:setScale(3)
    self:addChild(puff)
    puff:setGlobalZOrder(-self:getPositionY()+FXZorder)
    puff:setPositionZ(20)
    
    local magic = cc.BillboardParticleSystem:create(ParticleManager:getInstance():getPlistData("magic"))
    local magicf = cc.SpriteFrameCache:getInstance():getSpriteFrame("particle.png")
    magic:setTextureWithRect(magicf:getTexture(), magicf:getRect())
    magic:setCamera(camera)
    magic:setScale(1.5)
    self:addChild(magic)
    magic:setGlobalZOrder(-self:getPositionY()+FXZorder)
    magic:setPositionZ(0)
        
    self.sp:runAction(cc.FadeOut:create(1))
    self:runAction(cc.Sequence:create(cc.DelayTime:create(1),cc.RemoveSelf:create()))
end

function MageIceSpikes:playHitAudio()

end

function MageIceSpikes:onCollide(target)
    if self.curDOTTime > self.DOTTimer then
        self:hurtEffect(target)
        self:playHitAudio()    
        target:hurt(self)
        self.DOTApplied = true
    end
end

function MageIceSpikes:onUpdate(dt)
-- implement this function if this is a projectile
    self.curDOTTime = self.curDOTTime + dt
    if self.DOTApplied then
        self.DOTApplied = false
        self.curDOTTime = 0
    end
end

ArcherNormalAttack = class("ArcherNormalAttack", function()
    return BasicCollider.new()
end)

function ArcherNormalAttack.create(pos,facing,attackInfo)
    local ret = ArcherNormalAttack.new()
    ret:initData(pos,facing,attackInfo)
    
    ret.sp = Archer:createArrow()
    ret.sp:setRotation(RADIANS_TO_DEGREES(-facing)-90)
    ret:addChild(ret.sp)

    return ret
end

function ArcherNormalAttack:onTimeOut()
    self:runAction(cc.RemoveSelf:create())
end

function ArcherNormalAttack:onCollide(target)
    self:hurtEffect(target)
    self:playHitAudio()    
    target:hurt(self)
    --set cur duration to its max duration, so it will be removed when checking time out
    self.curDuration = self.duration+1
end

function ArcherNormalAttack:onUpdate(dt)
    local selfPos = getPosTable(self)
    local nextPos = cc.pRotateByAngle(cc.pAdd({x=self.speed*dt, y=0},selfPos),selfPos,self.facing)
    self:setPosition(nextPos)
end

DragonAttack = class("DragonAttack", function()
    return BasicCollider.new()
end)

function DragonAttack.create(pos,facing,attackInfo)
    local ret = DragonAttack.new()
    ret:initData(pos,facing,attackInfo)

    ret.sp = cc.Sprite:create("btn_circle_normal.png")
    ret.sp:setPosition3D(cc.V3(0,0,50))
    ret.sp:setScale(2)
    ret.sp:setColor({r=255,g=0,b=0})
    ret:addChild(ret.sp)

    return ret
end

function DragonAttack:onTimeOut()
    self:runAction(cc.RemoveSelf:create())
end

function DragonAttack:playHitAudio()

end

function DragonAttack:onCollide(target)
    self:hurtEffect(target)
    self:playHitAudio()    
    target:hurt(self)
    --set cur duration to its max duration, so it will be removed when checking time out
    self.curDuration = self.duration+1
end

function DragonAttack:onUpdate(dt)
    local selfPos = getPosTable(self)
    local nextPos = cc.pRotateByAngle(cc.pAdd({x=self.speed*dt, y=0},selfPos),selfPos,self.facing)
    self:setPosition(nextPos)
end

return AttackManager