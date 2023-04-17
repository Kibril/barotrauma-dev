
Hook.Add("character.applyDamage", "NT.ondamaged", function (characterHealth, attackResult, hitLimb)
    
    --print(hitLimb.HealthIndex or hitLimb ~= nil)

    if -- invalid attack data, don't do anything
        characterHealth == nil or 
        characterHealth.Character == nil or 
        characterHealth.Character.IsDead or
        not characterHealth.Character.IsHuman or 
        attackResult == nil or 
        attackResult.Afflictions == nil or
        #attackResult.Afflictions <= 0 or
        hitLimb == nil or
        hitLimb.IsSevered
    then return end

    local afflictions = attackResult.Afflictions

    -- ntc
    -- modifying ondamaged hooks
    for key, val in pairs(NTC.ModifyingOnDamagedHooks) do
        afflictions = val(characterHealth, afflictions, hitLimb)
    end
    
    local identifier = ""
    local methodtorun = nil
    for value in afflictions do
        -- execute fitting method, if available
        identifier = value.Prefab.Identifier.Value
        methodtorun = NT.OnDamagedMethods[identifier]
        if methodtorun ~= nil then 
            methodtorun(characterHealth.Character,value.Strength,hitLimb.type)
        end
    end

    -- ntc
    -- ondamaged hooks
    for key, val in pairs(NTC.OnDamagedHooks) do
        val(characterHealth, attackResult, hitLimb)
    end
end)

NT.OnDamagedMethods = {}

local function HasLungs(c) return not HF.HasAffliction(c,"lungremoved") end
local function HasHeart(c) return not HF.HasAffliction(c,"heartremoved") end

-- cause foreign bodies, rib fractures, pneumothorax, tamponade, internal bleeding, fractures, neurotrauma
NT.OnDamagedMethods.gunshotwound = function(character,strength,limbtype) 
    limbtype = HF.NormalizeLimbType(limbtype)

    local causeFullForeignBody = false

    -- torso specific
    if strength >= 1 and limbtype==LimbType.Torso then
        local hitOrgan = false
        if strength >= 10 and HF.Chance(HF.Clamp(strength*0.02,0,0.3)*NTC.GetMultiplier(character,"anyfracturechance")*NT.Config.fractureChance) then
            NT.BreakLimb(character,limbtype)
            causeFullForeignBody = true
        end
        if strength >= 5 and HasLungs(character) and HF.Chance(0.3*NTC.GetMultiplier(character,"pneumothoraxchance")*NT.Config.pneumothoraxChance) then
            HF.AddAffliction(character,"pneumothorax",5)
            HF.AddAffliction(character,"lungdamage",strength/2) 
            HF.AddAffliction(character,"organdamage",strength/4)
            hitOrgan=true
        end
        if strength >= 10 and HasHeart(character) and hitOrgan == false and HF.Chance(strength/50*NTC.GetMultiplier(character,"tamponadechance")*NT.Config.tamponadeChance) then
            HF.AddAffliction(character,"tamponade",5) 
            HF.AddAffliction(character,"heartdamage",strength/2)
            HF.AddAffliction(character,"organdamage",strength/4)
            hitOrgan=true
        end
        if strength >= 15 then
            HF.AddAffliction(character,"internalbleeding",strength*HF.RandomRange(0.3,0.6)) end

        -- liver and kidney damage
        if hitOrgan==false and HF.Chance(0.5) then
            HF.AddAfflictionLimb(character,"organdamage",limbtype,strength/4)
            if HF.Chance(0.5) then
                HF.AddAffliction(character,"liverdamage",strength/2)
            else
                HF.AddAffliction(character,"kidneydamage",strength/2)
            end
        end
    end

    -- head
    if strength >= 10 and limbtype==LimbType.Head then
        if HF.Chance(strength/90*NTC.GetMultiplier(character,"anyfracturechance")*NT.Config.fractureChance) then
            NT.BreakLimb(character,limbtype)
            causeFullForeignBody = true
        end
        if strength >= 15 and HF.Chance(0.7) then
            HF.AddAffliction(character,"cerebralhypoxia",strength*HF.RandomRange(0.1,0.4)) end
    end

    -- extremities
    if strength >= 5 and HF.LimbIsExtremity(limbtype) then
        if NT.LimbIsBroken(character,limbtype) and not NT.LimbIsAmputated(character,limbtype) and HF.Chance(strength/60*NTC.GetMultiplier(character,"traumamputatechance")) then
            NT.TraumamputateLimb(character,limbtype) end
        if HF.Chance(strength/60*NTC.GetMultiplier(character,"anyfracturechance")*NT.Config.fractureChance) then
            NT.BreakLimb(character,limbtype)
            causeFullForeignBody = true
        end
    end

    -- foreign bodies
    if causeFullForeignBody then
        HF.AddAfflictionLimb(character,"foreignbody",limbtype,HF.Clamp(strength,0,30)*NTC.GetMultiplier(character,"foreignbodymultiplier"))
    else
        if HF.Chance(0.75) then
            HF.AddAfflictionLimb(character,"foreignbody",limbtype,HF.Clamp(strength/4,0,20)*NTC.GetMultiplier(character,"foreignbodymultiplier"))
        end
    end
end

-- cause foreign bodies, rib fractures, pneumothorax, internal bleeding, concussion, fractures
NT.OnDamagedMethods.explosiondamage = function(character,strength,limbtype) 
    limbtype = HF.NormalizeLimbType(limbtype)

    if HF.Chance(0.75) then
        HF.AddAfflictionLimb(character,"foreignbody",limbtype,strength/2*NTC.GetMultiplier(character,"foreignbodymultiplier"))
    end

    -- torso specific
    if strength >= 1 and limbtype==LimbType.Torso then
        if strength >= 10 and HF.Chance(strength/50*NTC.GetMultiplier(character,"anyfracturechance")*NT.Config.fractureChance) then
            NT.BreakLimb(character,limbtype) end
        if HasLungs(character) and strength >= 5 and HF.Chance(strength/50*NTC.GetMultiplier(character,"pneumothoraxchance")*NT.Config.pneumothoraxChance) then
            HF.AddAffliction(character,"pneumothorax",5) end
        if strength >= 5 then
            HF.AddAffliction(character,"internalbleeding",strength*HF.RandomRange(0.2,0.5)) end
    end

    -- head
    if strength >= 1 and limbtype==LimbType.Head then
        if strength >= 15 and HF.Chance(math.min(strength/60,0.7)) then
            HF.AddAfflictionResisted(character,"concussion",10) end
        if strength >= 15 and HF.Chance(math.min(strength/60,0.7)*NTC.GetMultiplier(character,"anyfracturechance")*NT.Config.fractureChance) then
            NT.BreakLimb(character,limbtype) end
        if strength >= 15 and HF.Chance(math.min(strength/60,0.7)*NTC.GetMultiplier(character,"anyfracturechance")*NT.Config.fractureChance) then
            HF.AddAffliction(character,"n_fracture",5) end
        if strength >= 25 and HF.Chance(0.25) then
            HF.AddAfflictionLimb(character,"gate_ta_h",limbtype,5) end
    end

    -- extremities
    if strength >= 1 and HF.LimbIsExtremity(limbtype) then
        if NT.LimbIsBroken(character,limbtype) and not NT.LimbIsAmputated(character,limbtype) and HF.Chance(strength/60*NTC.GetMultiplier(character,"traumamputatechance")) then
            NT.TraumamputateLimb(character,limbtype) end
        if HF.Chance(strength/60*NTC.GetMultiplier(character,"anyfracturechance")*NT.Config.fractureChance) then
            NT.BreakLimb(character,limbtype) end
        if HF.Chance(0.35*NTC.GetMultiplier(character,"dislocationchance")*NT.Config.dislocationChance) and not NT.LimbIsAmputated(character,limbtype) then
            NT.DislocateLimb(character,limbtype) end
    end
end

-- cause rib fractures, pneumothorax, internal bleeding, concussion, fractures
NT.OnDamagedMethods.bitewounds = function(character,strength,limbtype) 
    limbtype = HF.NormalizeLimbType(limbtype)

    -- torso specific
    if strength >= 1 and limbtype==LimbType.Torso then
        if strength >= 15 and HF.Chance((strength-10)/50*NTC.GetMultiplier(character,"anyfracturechance")*NT.Config.fractureChance) then
            NT.BreakLimb(character,limbtype) end
        if HasLungs(character) and strength >= 10 and HF.Chance((strength-5)/50*NTC.GetMultiplier(character,"pneumothoraxchance")*NT.Config.pneumothoraxChance) then
            HF.AddAffliction(character,"pneumothorax",5) end
        if strength >= 15 then
            HF.AddAffliction(character,"internalbleeding",strength*HF.RandomRange(0.2,0.5)) end
    end

    -- head
    if strength >= 1 and limbtype==LimbType.Head then
        if strength >= 15 and HF.Chance(math.min(strength/60,0.7)) then
            HF.AddAfflictionResisted(character,"concussion",10) end
        if strength >= 15 and HF.Chance(math.min((strength-10)/60,0.7)*NTC.GetMultiplier(character,"anyfracturechance")*NT.Config.fractureChance) then
            NT.BreakLimb(character,limbtype) end
    end

    -- extremities
    if strength >= 1 and HF.LimbIsExtremity(limbtype) then
        if NT.LimbIsBroken(character,limbtype) and not NT.LimbIsAmputated(character,limbtype) and HF.Chance((strength-5)/60*NTC.GetMultiplier(character,"traumamputatechance")) then
            NT.TraumamputateLimb(character,limbtype) end
        if HF.Chance((strength-5)/60*NTC.GetMultiplier(character,"anyfracturechance")*NT.Config.fractureChance) then
            NT.BreakLimb(character,limbtype) end
    end
end

-- cause rib fractures, pneumothorax, tamponade, internal bleeding, fractures
NT.OnDamagedMethods.lacerations = function(character,strength,limbtype) 
    limbtype = HF.NormalizeLimbType(limbtype)

    -- torso specific
    if strength >= 1 and limbtype==LimbType.Torso then
        if strength >= 20 and HF.Chance((strength-15)/50*NTC.GetMultiplier(character,"anyfracturechance")*NT.Config.fractureChance) then
            NT.BreakLimb(character,limbtype) end
        if HasLungs(character) and strength >= 5 and HF.Chance((strength-5)/50*NTC.GetMultiplier(character,"pneumothoraxchance")*NT.Config.pneumothoraxChance) then
            HF.AddAffliction(character,"pneumothorax",5) end
        if HasHeart(character) and strength >= 10 and HF.Chance((strength-10)/50*NTC.GetMultiplier(character,"tamponadechance")*NT.Config.tamponadeChance) then
            HF.AddAffliction(character,"tamponade",5) end
        if strength >= 15 then
            HF.AddAffliction(character,"internalbleeding",strength*HF.RandomRange(0.2,0.5)) end
    end

    -- head
    if strength >= 1 and limbtype==LimbType.Head then
        if strength >= 15 and HF.Chance(math.min((strength-15)/60,0.7)*NTC.GetMultiplier(character,"anyfracturechance")*NT.Config.fractureChance) then
            NT.BreakLimb(character,limbtype) end
    end

    -- extremities
    if strength >= 1 and HF.LimbIsExtremity(limbtype) then
        if NT.LimbIsBroken(character,limbtype) and not NT.LimbIsAmputated(character,limbtype) and HF.Chance(strength/60*NTC.GetMultiplier(character,"traumamputatechance")) then
            NT.TraumamputateLimb(character,limbtype) end
        if HF.Chance((strength-5)/60*NTC.GetMultiplier(character,"anyfracturechance")*NT.Config.fractureChance) then
            NT.BreakLimb(character,limbtype) end
    end
end

-- cause rib fractures, organ damage, pneumothorax, concussion, fractures, neurotrauma
NT.OnDamagedMethods.blunttrauma = function(character,strength,limbtype) 
    limbtype = HF.NormalizeLimbType(limbtype)

    local fractureImmune = HF.HasAffliction(character,"cpr_fracturebuff")

    -- torso
    if not fractureImmune and strength >= 1 and limbtype==LimbType.Torso then
        if HF.Chance(strength/50*NTC.GetMultiplier(character,"anyfracturechance")*NT.Config.fractureChance) then
            NT.BreakLimb(character,limbtype) end

        HF.AddAfflictionLimb(character,"lungdamage",limbtype,strength*HF.RandomRange(0,1))
        HF.AddAfflictionLimb(character,"heartdamage",limbtype,strength*HF.RandomRange(0,1))
        HF.AddAfflictionLimb(character,"liverdamage",limbtype,strength*HF.RandomRange(0,1))
        HF.AddAfflictionLimb(character,"kidneydamage",limbtype,strength*HF.RandomRange(0,1))
        HF.AddAfflictionLimb(character,"organdamage",limbtype,strength*HF.RandomRange(0,1))

        if HasLungs(character) and strength >= 5 and HF.Chance(strength/50*NTC.GetMultiplier(character,"pneumothoraxchance")*NT.Config.pneumothoraxChance) then
            HF.AddAffliction(character,"pneumothorax",5) end
    end

    -- head
    if not fractureImmune and strength >= 1 and limbtype==LimbType.Head then
        if strength >= 15 and HF.Chance(math.min(strength/60,0.7)) then
            HF.AddAfflictionResisted(character,"concussion",10) end
        if strength >= 15 and HF.Chance(math.min((strength-10)/60,0.7)*NTC.GetMultiplier(character,"anyfracturechance")*NT.Config.fractureChance) then
            NT.BreakLimb(character,limbtype) end
        if strength >= 15 and HF.Chance(math.min((strength-10)/60,0.7)*NTC.GetMultiplier(character,"anyfracturechance")*NT.Config.fractureChance) then
            HF.AddAffliction(character,"n_fracture",5) end
        if strength >= 5 and HF.Chance(0.7) then
            HF.AddAffliction(character,"cerebralhypoxia",strength*HF.RandomRange(0.1,0.4)) end
    end

    -- extremities
    if not fractureImmune and strength >= 1 and HF.LimbIsExtremity(limbtype) then
        if strength > 15 and NT.LimbIsBroken(character,limbtype) and not NT.LimbIsAmputated(character,limbtype) and HF.Chance(strength/100*NTC.GetMultiplier(character,"traumamputatechance")) then
            NT.TraumamputateLimb(character,limbtype) end
        if strength >= 5 and HF.Chance((strength-5)/60*NTC.GetMultiplier(character,"anyfracturechance")*NT.Config.fractureChance) then
            NT.BreakLimb(character,limbtype) end
        if HF.Chance(HF.Clamp(strength/80,0.1,0.5)*NTC.GetMultiplier(character,"dislocationchance")*NT.Config.dislocationChance) and not NT.LimbIsAmputated(character,limbtype) then
            NT.DislocateLimb(character,limbtype) end
    end
end

-- cause rib fractures, organ damage, pneumothorax, concussion, fractures
NT.OnDamagedMethods.internaldamage = function(character,strength,limbtype) 
    limbtype = HF.NormalizeLimbType(limbtype)

    -- torso
    if strength >= 1 and limbtype==LimbType.Torso then
        if HF.Chance((strength-5)/50*NTC.GetMultiplier(character,"anyfracturechance")*NT.Config.fractureChance) then
        NT.BreakLimb(character,limbtype) end

        HF.AddAfflictionLimb(character,"lungdamage",limbtype,strength*HF.RandomRange(0,1))
        HF.AddAfflictionLimb(character,"heartdamage",limbtype,strength*HF.RandomRange(0,1))
        HF.AddAfflictionLimb(character,"liverdamage",limbtype,strength*HF.RandomRange(0,1))
        HF.AddAfflictionLimb(character,"kidneydamage",limbtype,strength*HF.RandomRange(0,1))
        HF.AddAfflictionLimb(character,"organdamage",limbtype,strength*HF.RandomRange(0,1))
    
        if HasLungs(character) and strength >= 10 and HF.Chance((strength-10)/50*NTC.GetMultiplier(character,"pneumothoraxchance")*NT.Config.pneumothoraxChance) then
            HF.AddAffliction(character,"pneumothorax",5) end
    end

    -- head
    if strength >= 1 and limbtype==LimbType.Head then
        if strength >= 15 and HF.Chance(math.min(strength/60,0.7)) then
            HF.AddAfflictionResisted(character,"concussion",10) end
        if strength >= 15 and HF.Chance(math.min((strength-5)/60,0.7)*NTC.GetMultiplier(character,"anyfracturechance")*NT.Config.fractureChance) then
            NT.BreakLimb(character,limbtype) end
        if strength >= 15 and HF.Chance(math.min((strength-5)/60,0.7)*NTC.GetMultiplier(character,"anyfracturechance")*NT.Config.fractureChance) then
            HF.AddAffliction(character,"n_fracture",5) end
    end

    -- extremities
    if strength >= 1 and HF.LimbIsExtremity(limbtype) then
        if strength > 10 and NT.LimbIsBroken(character,limbtype) and not NT.LimbIsAmputated(character,limbtype) and HF.Chance((strength-10)/60*NTC.GetMultiplier(character,"traumamputatechance")) then
            NT.TraumamputateLimb(character,limbtype) end
        if HF.Chance((strength-5)/60*NTC.GetMultiplier(character,"anyfracturechance")*NT.Config.fractureChance) then
            NT.BreakLimb(character,limbtype) end
        if HF.Chance(0.25*NTC.GetMultiplier(character,"dislocationchance")*NT.Config.dislocationChance) and not NT.LimbIsAmputated(character,limbtype) then
            NT.DislocateLimb(character,limbtype) end
    end
end
