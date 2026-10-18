local ADDON_NAME = ...
local VERSION = "1.0.0"

local addon = CreateFrame("Frame")

-- WoW Forever Ice Lance ranks.
local ICE_LANCE_IDS = {
    1312002, -- Rank 1
    400640,  -- Rank 2
    1240044, -- Rank 3
    1240045, -- Rank 4
    1240046, -- Rank 5
    1240047, -- Rank 6
}

local ICE_LANCE_SET = {}
for _, spellID in ipairs(ICE_LANCE_IDS) do
    ICE_LANCE_SET[spellID] = true
end

-- Fingers of Frost variants seen in Forever data.
local FOF_IDS = {
    [400647] = true,
    [400669] = true,
    [400670] = true,
}

-- Hard-freeze auras only. Slows are intentionally excluded.
local FROZEN_AURA_IDS = {
    [122] = true,      -- Frost Nova Rank 1
    [865] = true,      -- Frost Nova Rank 2
    [6131] = true,     -- Frost Nova Rank 3
    [10230] = true,    -- Frost Nova Rank 4
    [12494] = true,    -- Frostbite
    [33395] = true,    -- Freeze
    [44572] = true,    -- Deep Freeze compatibility
    [463448] = true,   -- Frost Nova compatibility
    [1220855] = true,  -- Forever Frost Nova compatibility
    [1289447] = true,  -- Forever Frost Nova compatibility
}

local SOUND_CHOICES = {
    crystal = { label = "Crystal", file = "Interface\\AddOns\\ShatterPulse\\Media\\Crystal.ogg" },
    crack   = { label = "Ice Crack", file = "Interface\\AddOns\\ShatterPulse\\Media\\IceCrack.ogg" },
    chime   = { label = "Frost Chime", file = "Interface\\AddOns\\ShatterPulse\\Media\\FrostChime.ogg" },
    ping    = { label = "Sharp Ping", file = "Interface\\AddOns\\ShatterPulse\\Media\\SharpPing.ogg" },
    whoosh  = { label = "Frost Whoosh", file = "Interface\\AddOns\\ShatterPulse\\Media\\FrostWhoosh.ogg" },
}

local SOUND_ORDER = { "crystal", "crack", "chime", "ping", "whoosh" }

local function GetSelectedSound()
    local key = ShatterPulseDB and ShatterPulseDB.freezeSoundChoice or "crystal"
    return SOUND_CHOICES[key] or SOUND_CHOICES.crystal
end
local BASE_SECURE_SIZE = 82

local STYLE_SPLIT = "split"
local STYLE_RETAIL = "retail" -- legacy only
local STYLE_BLIZZARD = "blizzard"
local STYLE_CLEAN = "clean"
local STYLE_COMBO = "combo"

-- Bundled artwork so the proc visuals work even when Forever does not ship
-- Retail's SpellActivationOverlay textures.
local FROST_SIDE_TEXTURE = "Interface\\AddOns\\ShatterPulse\\Media\\FrostSide.tga"
local FROST_TOP_TEXTURE  = "Interface\\AddOns\\ShatterPulse\\Media\\FrostTop.tga"
local RETAIL_FOF_TEXTURE = "Textures\\SpellActivationOverlays\\Frozen_Fingers.blp"

local defaults = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = -120,
    size = 82,
    alpha = 1,
    locked = true,
    enabled = true,
    trackFoF = true,
    trackFrozen = true,
    pulse = true,
    flashSpeed = 1.00,
    flashStrength = 1.00,
    glowIntensity = 1.35,
    showText = true,
    showReason = false,
    fofSound = false,
    freezeSound = true,
    freezeSoundChoice = "crystal",
    displayStyle = STYLE_SPLIT,
    retailScale = 1.0,
    barDistance = 205,
    sideScale = 1.0,
    topScale = 1.0,
    topHeight = 175,
    splitLayoutRevision = 3,
    minimapShown = true,
    minimapAngle = 215,
}

local function Chat(message)
    print("|cff66ccffShatterPulse:|r " .. tostring(message))
end

local function Clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local function Atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    elseif x == 0 and y > 0 then
        return math.pi / 2
    elseif x == 0 and y < 0 then
        return -math.pi / 2
    end
    return 0
end

local function ApplyDefaults()
    ShatterPulseDB = ShatterPulseDB or {}

    -- Migrate the old single sound option to the FoF option.
    if ShatterPulseDB.fofSound == nil and ShatterPulseDB.sound ~= nil then
        ShatterPulseDB.fofSound = ShatterPulseDB.sound and true or false
    end

    for key, value in pairs(defaults) do
        if ShatterPulseDB[key] == nil then
            ShatterPulseDB[key] = value
        end
    end

    -- 2.0 layout migration: new hand-cut Retail-inspired proc art uses wider
    -- spacing and independent side/top scaling. This prevents the old bubble look.
    if (ShatterPulseDB.splitLayoutRevision or 0) < 3 then
        ShatterPulseDB.barDistance = 205
        ShatterPulseDB.sideScale = 1.0
        ShatterPulseDB.topScale = 1.0
        ShatterPulseDB.topHeight = 175
        ShatterPulseDB.retailScale = 1.0
        ShatterPulseDB.splitLayoutRevision = 3
    end

    local style = ShatterPulseDB.displayStyle
    -- 1.5 migration: Retail texture paths are not present in every Forever build.
    -- Move old Retail/bars layouts to the bundled split overlay.
    if style == "bars" or style == STYLE_RETAIL then
        ShatterPulseDB.displayStyle = STYLE_SPLIT
    elseif style ~= STYLE_SPLIT and style ~= STYLE_BLIZZARD and style ~= STYLE_CLEAN and style ~= STYLE_COMBO then
        ShatterPulseDB.displayStyle = STYLE_SPLIT
    end

    if not SOUND_CHOICES[ShatterPulseDB.freezeSoundChoice] then
        ShatterPulseDB.freezeSoundChoice = "crystal"
    end
end

local function SafeSpellName(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and type(name) == "string" then
            return name
        end
    end
    return nil
end

local function IsIceLanceSpell(spellID)
    if type(spellID) ~= "number" then return false end
    if ICE_LANCE_SET[spellID] then return true end
    local name = SafeSpellName(spellID)
    return name == "Ice Lance" or name == "Eislanze"
end

local state = {
    fofGlow = false,
    previewMode = "off", -- off, frozen, fof, both
    moving = false,
    iceLanceID = ICE_LANCE_IDS[1],
}

local function PreviewHas(kind)
    return state.previewMode == "both" or state.previewMode == kind
end

local RefreshOptionsMenu
local ApplyMinimapPosition
local ApplyFrozenLayout
local RefreshFrozenTarget
local ConfigureFreezeSounds

-- ---------------------------------------------------------------------------
-- Shared proc visuals
-- ---------------------------------------------------------------------------

local function CreateVisualSet(parent, secure)
    local visual = {
        parent = parent,
        secure = secure,
    }

    visual.icon = parent:CreateTexture(nil, "ARTWORK")
    visual.icon:SetTexture("Interface\\Icons\\Spell_Frost_FrostBlast")
    visual.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Blizzard's actual Retail Fingers of Frost spell-alert artwork.
    -- This is the three-piece icy arc shown around the character in Retail.
    visual.retailOverlay = parent:CreateTexture(nil, "ARTWORK", nil, 0)
    visual.retailOverlay:SetTexture(RETAIL_FOF_TEXTURE)
    visual.retailOverlay:SetBlendMode("ADD")
    visual.retailOverlay:SetVertexColor(1, 1, 1, 1)

    -- Bundled Blizzard-like split overlay.
    visual.frostTopGlow = parent:CreateTexture(nil, "BACKGROUND", nil, 0)
    visual.frostTopGlow:SetTexture(FROST_TOP_TEXTURE)
    visual.frostTopGlow:SetBlendMode("ADD")

    visual.frostTop = parent:CreateTexture(nil, "ARTWORK", nil, 1)
    visual.frostTop:SetTexture(FROST_TOP_TEXTURE)
    visual.frostTop:SetBlendMode("ADD")
    visual.frostTop:SetVertexColor(1.00, 1.00, 1.00, 1.00)

    visual.frostLeftGlow = parent:CreateTexture(nil, "BACKGROUND", nil, 0)
    visual.frostLeftGlow:SetTexture(FROST_SIDE_TEXTURE)
    visual.frostLeftGlow:SetBlendMode("ADD")

    visual.frostLeft = parent:CreateTexture(nil, "ARTWORK", nil, 1)
    visual.frostLeft:SetTexture(FROST_SIDE_TEXTURE)
    visual.frostLeft:SetBlendMode("ADD")
    visual.frostLeft:SetVertexColor(1.00, 1.00, 1.00, 1.00)

    visual.frostRightGlow = parent:CreateTexture(nil, "BACKGROUND", nil, 0)
    visual.frostRightGlow:SetTexture(FROST_SIDE_TEXTURE)
    visual.frostRightGlow:SetBlendMode("ADD")
    visual.frostRightGlow:SetTexCoord(1, 0, 0, 1)

    visual.frostRight = parent:CreateTexture(nil, "ARTWORK", nil, 1)
    visual.frostRight:SetTexture(FROST_SIDE_TEXTURE)
    visual.frostRight:SetBlendMode("ADD")
    visual.frostRight:SetVertexColor(1.00, 1.00, 1.00, 1.00)
    -- Mirror the same texture for the right side.
    visual.frostRight:SetTexCoord(1, 0, 0, 1)

    visual.glowOuter = parent:CreateTexture(nil, "OVERLAY", nil, 4)
    visual.glowOuter:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    visual.glowOuter:SetBlendMode("ADD")
    visual.glowOuter:SetVertexColor(0.35, 0.86, 1.00, 0.55)

    visual.glowInner = parent:CreateTexture(nil, "OVERLAY", nil, 5)
    visual.glowInner:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    visual.glowInner:SetBlendMode("ADD")
    visual.glowInner:SetVertexColor(0.75, 0.95, 1.00, 0.90)

    visual.leftBarGlow = parent:CreateTexture(nil, "ARTWORK", nil, 1)
    visual.leftBarGlow:SetColorTexture(0.20, 0.72, 1.00, 0.22)
    visual.leftBar = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    visual.leftBar:SetColorTexture(0.68, 0.93, 1.00, 0.82)
    visual.leftBarCore = parent:CreateTexture(nil, "ARTWORK", nil, 3)
    visual.leftBarCore:SetColorTexture(0.92, 0.99, 1.00, 0.88)

    visual.rightBarGlow = parent:CreateTexture(nil, "ARTWORK", nil, 1)
    visual.rightBarGlow:SetColorTexture(0.20, 0.72, 1.00, 0.22)
    visual.rightBar = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    visual.rightBar:SetColorTexture(0.68, 0.93, 1.00, 0.82)
    visual.rightBarCore = parent:CreateTexture(nil, "ARTWORK", nil, 3)
    visual.rightBarCore:SetColorTexture(0.92, 0.99, 1.00, 0.88)

    visual.leftSparkTop = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    visual.leftSparkTop:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    visual.leftSparkTop:SetBlendMode("ADD")
    visual.leftSparkTop:SetVertexColor(0.65, 0.92, 1.00, 0.95)
    visual.leftSparkBottom = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    visual.leftSparkBottom:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    visual.leftSparkBottom:SetBlendMode("ADD")
    visual.leftSparkBottom:SetVertexColor(0.65, 0.92, 1.00, 0.70)

    visual.rightSparkTop = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    visual.rightSparkTop:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    visual.rightSparkTop:SetBlendMode("ADD")
    visual.rightSparkTop:SetVertexColor(0.65, 0.92, 1.00, 0.95)
    visual.rightSparkBottom = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    visual.rightSparkBottom:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    visual.rightSparkBottom:SetBlendMode("ADD")
    visual.rightSparkBottom:SetVertexColor(0.65, 0.92, 1.00, 0.70)

    visual.label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    visual.label:SetText("ICE LANCE")
    visual.label:SetTextColor(0.70, 0.93, 1.00)

    visual.reason = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    visual.reason:SetText(secure and "TARGET FROZEN" or "FINGERS OF FROST")
    visual.reason:SetTextColor(0.78, 0.88, 1.00)

    return visual
end

local function TryCall(object, methodName, ...)
    if not object then return false end
    local method = object[methodName]
    if type(method) ~= "function" then return false end
    return pcall(method, object, ...)
end

local function TryShow(region, shown)
    if not region then return false end
    if region.SetShown then
        return pcall(region.SetShown, region, shown)
    elseif shown and region.Show then
        return pcall(region.Show, region)
    elseif not shown and region.Hide then
        return pcall(region.Hide, region)
    end
    return false
end

local function CreatePulseGroup(frame)
    local group = frame:CreateAnimationGroup()

    local scaleOut = group:CreateAnimation("Scale")
    scaleOut:SetOrder(1)
    local scaleIn = group:CreateAnimation("Scale")
    scaleIn:SetOrder(2)

    local fadeOut = group:CreateAnimation("Alpha")
    fadeOut:SetOrder(1)
    local fadeIn = group:CreateAnimation("Alpha")
    fadeIn:SetOrder(2)

    group.scaleOut = scaleOut
    group.scaleIn = scaleIn
    group.fadeOut = fadeOut
    group.fadeIn = fadeIn
    group:SetLooping("REPEAT")
    return group
end

local function RefreshPulseGroup(group)
    if not group or not ShatterPulseDB then return end
    local speed = Clamp(ShatterPulseDB.flashSpeed or 1.0, 0.40, 2.20)
    local strength = Clamp(ShatterPulseDB.flashStrength or 1.0, 0.20, 2.00)
    local half = 0.46 / speed
    local scaleFactor = 1 + (0.020 * strength)
    local alphaLow = Clamp(0.82 - (0.16 * strength), 0.40, 0.92)
    local alphaHigh = Clamp(0.96 + (0.02 * strength), 0.92, 1.00)
    local baseAlpha = Clamp(ShatterPulseDB.alpha or 1, 0.20, 1.00)
    local pulseAlphaLow = baseAlpha * alphaLow
    local pulseAlphaHigh = baseAlpha * alphaHigh

    group:Stop()
    if group:GetParent() and group:GetParent().SetScale then
        group:GetParent():SetScale(1)
    end
    if group:GetParent() and group:GetParent().SetAlpha then
        group:GetParent():SetAlpha(pulseAlphaHigh)
    end

    group.scaleOut:SetScale(scaleFactor, scaleFactor)
    group.scaleOut:SetDuration(half)
    group.scaleIn:SetScale(1 / scaleFactor, 1 / scaleFactor)
    group.scaleIn:SetDuration(half)
    group.fadeOut:SetFromAlpha(pulseAlphaLow)
    group.fadeOut:SetToAlpha(pulseAlphaHigh)
    group.fadeOut:SetDuration(half)
    group.fadeIn:SetFromAlpha(pulseAlphaHigh)
    group.fadeIn:SetToAlpha(pulseAlphaLow)
    group.fadeIn:SetDuration(half)
end

local function ConfigureVisualSet(visual, coordinateScale)
    local db = ShatterPulseDB
    if not db or not visual then return false end

    coordinateScale = coordinateScale or 1
    local style = db.displayStyle
    local useSplit = style == STYLE_SPLIT or style == STYLE_COMBO
    local showSplitTop = useSplit and not visual.secure
    local showSplitSides = useSplit and visual.secure
    local showIcon = style == STYLE_BLIZZARD or style == STYLE_CLEAN or style == STYLE_COMBO
    local showGlow = style == STYLE_BLIZZARD

    local iconSize = db.size * coordinateScale
    local glowOuterSize = iconSize * 1.70
    local glowInnerSize = iconSize * 1.42

    local overlayScale = (db.retailScale or 1.0) * coordinateScale
    local sideDistance = (db.barDistance or 205) * coordinateScale
    local sideScale = (db.sideScale or 1.0)
    local topScale = (db.topScale or 1.0)
    local glowIntensity = Clamp(db.glowIntensity or 1.35, 0.50, 2.00)

    -- 2.0 Retail-inspired artwork: narrow crystalline side shards for an exact
    -- frozen target, plus a separate crown for Fingers of Frost. The source
    -- textures contain transparent padding so these dimensions intentionally
    -- leave a generous gap around the character.
    local sideW = 180 * overlayScale * sideScale
    local sideH = 330 * overlayScale * sideScale
    local sideY = -8 * overlayScale
    local topW = 390 * overlayScale * topScale
    local topH = 210 * overlayScale * topScale
    local topY = (db.topHeight or 175) * coordinateScale

    -- Legacy Retail texture is kept only as a compatibility fallback and hidden
    -- in the new split layout.
    TryCall(visual.retailOverlay, "ClearAllPoints")
    TryCall(visual.retailOverlay, "SetPoint", "CENTER", visual.parent, "CENTER", 0, 0)
    TryCall(visual.retailOverlay, "SetSize", 360 * overlayScale, 360 * overlayScale)

    -- Bundled split artwork. Frozen target = side arcs, FoF = top arc.
    local glowScale = 1.08 + (0.08 * glowIntensity)
    local topGlowAlpha = Clamp(0.22 + (0.18 * glowIntensity), 0.18, 0.70)
    local sideGlowAlpha = Clamp(0.24 + (0.20 * glowIntensity), 0.20, 0.74)
    local shardAlpha = Clamp(0.86 + (0.10 * glowIntensity), 0.86, 1.00)

    TryCall(visual.frostTopGlow, "ClearAllPoints")
    TryCall(visual.frostTopGlow, "SetPoint", "CENTER", visual.parent, "CENTER", 0, topY)
    TryCall(visual.frostTopGlow, "SetSize", topW * glowScale, topH * glowScale)
    TryCall(visual.frostTopGlow, "SetVertexColor", 0.70, 0.92, 1.00, topGlowAlpha)

    TryCall(visual.frostTop, "ClearAllPoints")
    TryCall(visual.frostTop, "SetPoint", "CENTER", visual.parent, "CENTER", 0, topY)
    TryCall(visual.frostTop, "SetSize", topW, topH)
    TryCall(visual.frostTop, "SetVertexColor", 1.00, 1.00, 1.00, shardAlpha)

    TryCall(visual.frostLeftGlow, "ClearAllPoints")
    TryCall(visual.frostLeftGlow, "SetPoint", "CENTER", visual.parent, "CENTER", -sideDistance, sideY)
    TryCall(visual.frostLeftGlow, "SetSize", sideW * glowScale, sideH * glowScale)
    TryCall(visual.frostLeftGlow, "SetVertexColor", 0.72, 0.93, 1.00, sideGlowAlpha)

    TryCall(visual.frostLeft, "ClearAllPoints")
    TryCall(visual.frostLeft, "SetPoint", "CENTER", visual.parent, "CENTER", -sideDistance, sideY)
    TryCall(visual.frostLeft, "SetSize", sideW, sideH)
    TryCall(visual.frostLeft, "SetVertexColor", 1.00, 1.00, 1.00, shardAlpha)

    TryCall(visual.frostRightGlow, "ClearAllPoints")
    TryCall(visual.frostRightGlow, "SetPoint", "CENTER", visual.parent, "CENTER", sideDistance, sideY)
    TryCall(visual.frostRightGlow, "SetSize", sideW * glowScale, sideH * glowScale)
    TryCall(visual.frostRightGlow, "SetVertexColor", 0.72, 0.93, 1.00, sideGlowAlpha)

    TryCall(visual.frostRight, "ClearAllPoints")
    TryCall(visual.frostRight, "SetPoint", "CENTER", visual.parent, "CENTER", sideDistance, sideY)
    TryCall(visual.frostRight, "SetSize", sideW, sideH)
    TryCall(visual.frostRight, "SetVertexColor", 1.00, 1.00, 1.00, shardAlpha)

    TryCall(visual.icon, "ClearAllPoints")
    TryCall(visual.icon, "SetPoint", "CENTER", visual.parent, "CENTER", 0, 0)
    TryCall(visual.icon, "SetSize", iconSize, iconSize)

    TryCall(visual.glowOuter, "ClearAllPoints")
    TryCall(visual.glowOuter, "SetPoint", "CENTER", visual.parent, "CENTER", 0, 0)
    TryCall(visual.glowOuter, "SetSize", glowOuterSize, glowOuterSize)
    TryCall(visual.glowInner, "ClearAllPoints")
    TryCall(visual.glowInner, "SetPoint", "CENTER", visual.parent, "CENTER", 0, 0)
    TryCall(visual.glowInner, "SetSize", glowInnerSize, glowInnerSize)

    TryCall(visual.label, "ClearAllPoints")
    TryCall(visual.label, "SetPoint", "TOP", visual.parent, "BOTTOM", 0, -7 * coordinateScale)
    TryCall(visual.reason, "ClearAllPoints")
    TryCall(visual.reason, "SetPoint", "TOP", visual.label, "BOTTOM", 0, -2 * coordinateScale)

    -- Hide all old custom bar pieces. 1.5 uses bundled artwork instead.
    TryShow(visual.retailOverlay, false)
    TryShow(visual.frostTopGlow, showSplitTop)
    TryShow(visual.frostLeftGlow, showSplitSides)
    TryShow(visual.frostRightGlow, showSplitSides)
    TryShow(visual.frostTop, showSplitTop)
    TryShow(visual.frostLeft, showSplitSides)
    TryShow(visual.frostRight, showSplitSides)

    TryShow(visual.icon, showIcon)
    TryShow(visual.glowOuter, showGlow)
    TryShow(visual.glowInner, showGlow)
    TryShow(visual.leftBarGlow, false)
    TryShow(visual.leftBar, false)
    TryShow(visual.leftBarCore, false)
    TryShow(visual.rightBarGlow, false)
    TryShow(visual.rightBar, false)
    TryShow(visual.rightBarCore, false)
    TryShow(visual.leftSparkTop, false)
    TryShow(visual.leftSparkBottom, false)
    TryShow(visual.rightSparkTop, false)
    TryShow(visual.rightSparkBottom, false)

    -- Keep the split overlay clean; text is useful only for icon modes.
    TryShow(visual.label, showIcon and db.showText)
    TryShow(visual.reason, showIcon and db.showText and db.showReason)

    return true
end

-- ---------------------------------------------------------------------------
-- Fingers of Frost / preview display
-- ---------------------------------------------------------------------------

local display = CreateFrame("Frame", "ShatterPulseDisplay", UIParent)
display:SetFrameStrata("HIGH")
display:SetClampedToScreen(true)
display:SetMovable(true)
display:RegisterForDrag("LeftButton")
display:Hide()

local displayVisual = CreateVisualSet(display, false)

-- Manual preview frame for the frozen-target side arcs. The real frozen display
-- is owned by Blizzard's AuraContainer and only exists while a matching aura is
-- actually active, so preview needs a separate unrestricted frame.
local frozenPreview = CreateFrame("Frame", "ShatterPulseFrozenPreview", UIParent)
frozenPreview:SetFrameStrata("HIGH")
frozenPreview:SetClampedToScreen(true)
frozenPreview:Hide()
local frozenPreviewVisual = CreateVisualSet(frozenPreview, true)
frozenPreviewVisual.reason:SetText("TARGET FROZEN")

local dragText = display:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dragText:SetPoint("CENTER", display, "CENTER", 0, 0)
dragText:SetText("DRAG")
dragText:SetTextColor(1.00, 0.90, 0.35)
dragText:Hide()

local pulse = CreatePulseGroup(display)
local frozenPreviewPulse = CreatePulseGroup(frozenPreview)
local frozenActualPulse

local function FindBestIceLanceID()
    local best = ICE_LANCE_IDS[1]
    for _, spellID in ipairs(ICE_LANCE_IDS) do
        if C_Spell and C_Spell.IsSpellDataCached and C_Spell.RequestLoadSpellData then
            local ok, cached = pcall(C_Spell.IsSpellDataCached, spellID)
            if ok and not cached then
                pcall(C_Spell.RequestLoadSpellData, spellID)
            end
        end
        local name = SafeSpellName(spellID)
        if name == "Ice Lance" or name == "Eislanze" then
            best = spellID
        end
    end
    state.iceLanceID = best

    if C_Spell and C_Spell.GetSpellTexture then
        local ok, texture = pcall(C_Spell.GetSpellTexture, best)
        if ok and texture then
            displayVisual.icon:SetTexture(texture)
        end
    end
end

local function CheckFoFOverlay()
    if not ShatterPulseDB or not ShatterPulseDB.trackFoF then
        state.fofGlow = false
        return
    end

    if not (C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed) then
        return
    end

    local found = false
    for _, spellID in ipairs(ICE_LANCE_IDS) do
        local ok, active = pcall(C_SpellActivationOverlay.IsSpellOverlayed, spellID)
        if ok and active then
            found = true
            break
        end
    end
    if not found then
        for spellID in pairs(FOF_IDS) do
            local ok, active = pcall(C_SpellActivationOverlay.IsSpellOverlayed, spellID)
            if ok and active then
                found = true
                break
            end
        end
    end
    state.fofGlow = found
end

local function PlayFoFSound()
    if ShatterPulseDB and ShatterPulseDB.fofSound then
        local sound = GetSelectedSound()
        local ok, played = pcall(PlaySoundFile, sound.file, "Master")
        if not ok or played == false then
            pcall(PlaySound, 8959, "Master")
        end
    end
end

local function UpdateDisplay()
    local db = ShatterPulseDB
    if not db or not db.enabled then
        pulse:Stop()
        display:SetScale(1)
        display:Hide()
        frozenPreview:Hide()
        return
    end

    local previewFoF = PreviewHas("fof")
    local previewFrozen = PreviewHas("frozen")
    local showFoF = previewFoF or (db.trackFoF and state.fofGlow) or (not db.locked and state.moving)
    local showFrozenPreview = previewFrozen or (not db.locked and state.moving)

    if previewFoF then
        displayVisual.reason:SetText("FINGERS OF FROST PREVIEW")
    elseif state.fofGlow then
        displayVisual.reason:SetText("FINGERS OF FROST")
    else
        displayVisual.reason:SetText("MOVE MODE")
    end

    if showFoF then
        display:Show()
        if db.pulse and not state.moving then
            if not pulse:IsPlaying() then pulse:Play() end
        else
            if pulse:IsPlaying() then pulse:Stop() end
            display:SetScale(1)
            display:SetAlpha(db.alpha or 1)
        end
    else
        if pulse:IsPlaying() then pulse:Stop() end
        display:SetScale(1)
        display:SetAlpha(db.alpha or 1)
        display:Hide()
    end

    if showFrozenPreview then
        frozenPreview:Show()
        if db.pulse and not state.moving then
            if not frozenPreviewPulse:IsPlaying() then frozenPreviewPulse:Play() end
        else
            if frozenPreviewPulse:IsPlaying() then frozenPreviewPulse:Stop() end
            frozenPreview:SetScale(1)
            frozenPreview:SetAlpha(db.alpha or 1)
        end
    else
        if frozenPreviewPulse:IsPlaying() then frozenPreviewPulse:Stop() end
        frozenPreview:SetScale(1)
        frozenPreview:SetAlpha(db.alpha or 1)
        frozenPreview:Hide()
    end

    if RefreshOptionsMenu then RefreshOptionsMenu() end
end

-- ---------------------------------------------------------------------------
-- Exact frozen-target display via Blizzard AuraContainer
-- No guessed timer is used. When the aura breaks, the AuraButton disappears.
-- ---------------------------------------------------------------------------

local frozenTracker = {
    wrapper = nil,
    container = nil,
    slot = nil,
    visual = nil,
    ready = false,
    failed = false,
    reason = nil,
    pendingLayout = false,
}

local function InitFrozenAuraButton(button)
    if not button then return end

    pcall(button.SetSize, button, BASE_SECURE_SIZE, BASE_SECURE_SIZE)

    -- Give the AuraButton a valid icon sink. It stays invisible under our UI.
    if button.SetIcon then
        local engineIcon = button:CreateTexture(nil, "BACKGROUND")
        engineIcon:SetAllPoints()
        engineIcon:SetAlpha(0)
        pcall(button.SetIcon, button, engineIcon)
    end

    local visual = CreateVisualSet(button, true)
    visual.reason:SetText("TARGET FROZEN")
    frozenTracker.visual = visual

    -- Blizzard-driven fade-in for the two frozen-target side arcs.
    -- No combat-log hook and no guessed timer are used.
    if button.AddAuraShownAnimation then
        local function AddFadeIn(texture)
            local group = texture:CreateAnimationGroup()
            local fade = group:CreateAnimation("Alpha")
            fade:SetFromAlpha(0)
            fade:SetToAlpha(1)
            fade:SetDuration(0.14)
            fade:SetOrder(1)
            pcall(button.AddAuraShownAnimation, button, group)
        end
        AddFadeIn(visual.frostLeft)
        AddFadeIn(visual.frostRight)
    end

    local scale = BASE_SECURE_SIZE / math.max(1, (ShatterPulseDB and ShatterPulseDB.size) or BASE_SECURE_SIZE)
    ConfigureVisualSet(visual, scale)
end

local function CreateFrozenTracker()
    if frozenTracker.ready or frozenTracker.failed then return end

    local wrapper = CreateFrame("Frame", "ShatterPulseFrozenDisplay", UIParent)
    wrapper:SetSize(BASE_SECURE_SIZE, BASE_SECURE_SIZE)
    wrapper:SetFrameStrata("HIGH")
    wrapper:SetClampedToScreen(true)
    frozenTracker.wrapper = wrapper
    frozenActualPulse = CreatePulseGroup(wrapper)
    frozenActualPulse.isFrozenWrapper = true

    local okCreate, container = pcall(CreateFrame, "AuraContainer", nil, wrapper, "CustomAuraContainerTemplate")
    if not (okCreate and container) then
        frozenTracker.failed = true
        frozenTracker.reason = "AuraContainer could not be created"
        wrapper:Hide()
        return
    end

    frozenTracker.container = container
    pcall(container.SetSize, container, BASE_SECURE_SIZE, BASE_SECURE_SIZE)
    pcall(container.ClearAllPoints, container)
    pcall(container.SetPoint, container, "CENTER", wrapper, "CENTER", 0, 0)

    if type(container.AddAuraSlot) ~= "function" then
        frozenTracker.failed = true
        frozenTracker.reason = "AuraContainer:AddAuraSlot is unavailable"
        wrapper:Hide()
        return
    end

    local options = {
        candidateFilters = { includeSpellIDs = FROZEN_AURA_IDS },
        initializeFrame = InitFrozenAuraButton,
    }

    local okSlot, slot = pcall(container.AddAuraSlot, container, "ilh_frozen_target", "HARMFUL", options)
    if not (okSlot and slot) then
        frozenTracker.failed = true
        frozenTracker.reason = "The frozen-target AuraSlot was rejected by the client"
        wrapper:Hide()
        return
    end

    frozenTracker.slot = slot
    pcall(slot.SetSize, slot, BASE_SECURE_SIZE, BASE_SECURE_SIZE)
    pcall(slot.ClearAllPoints, slot)
    pcall(slot.SetPoint, slot, "CENTER", wrapper, "CENTER", 0, 0)

    local okUnit = pcall(container.SetUnit, container, "target")
    if not okUnit then
        frozenTracker.failed = true
        frozenTracker.reason = "AuraContainer:SetUnit(target) was rejected"
        wrapper:Hide()
        return
    end

    if container.SetEnabled then pcall(container.SetEnabled, container, true) end
    pcall(container.Show, container)

    frozenTracker.ready = true
    frozenTracker.reason = nil
end

ApplyFrozenLayout = function()
    local db = ShatterPulseDB
    local wrapper = frozenTracker.wrapper
    if not db or not wrapper then return end

    -- AuraButtons become restricted while enemy auras are secret. Do not touch
    -- their frame tree in combat; apply appearance changes once combat ends.
    if InCombatLockdown and InCombatLockdown() then
        frozenTracker.pendingLayout = true
        return
    end

    frozenTracker.pendingLayout = false
    wrapper:SetScale((db.size or BASE_SECURE_SIZE) / BASE_SECURE_SIZE)
    wrapper:SetAlpha(db.alpha or 1)
    wrapper:ClearAllPoints()
    wrapper:SetPoint(db.point or "CENTER", UIParent, db.relativePoint or "CENTER", db.x or 0, db.y or -120)

    if frozenTracker.visual then
        local coordinateScale = BASE_SECURE_SIZE / math.max(1, db.size or BASE_SECURE_SIZE)
        ConfigureVisualSet(frozenTracker.visual, coordinateScale)
    end

    if db.enabled and db.trackFrozen and frozenTracker.ready then
        wrapper:Show()
        if frozenTracker.container and frozenTracker.container.SetAuraSlotEnabled then
            pcall(frozenTracker.container.SetAuraSlotEnabled, frozenTracker.container, "ilh_frozen_target", true)
        end
        if frozenActualPulse then
            if db.pulse then
                if not frozenActualPulse:IsPlaying() then frozenActualPulse:Play() end
            else
                if frozenActualPulse:IsPlaying() then frozenActualPulse:Stop() end
                wrapper:SetScale((db.size or BASE_SECURE_SIZE) / BASE_SECURE_SIZE)
                wrapper:SetAlpha(db.alpha or 1)
            end
        end
    else
        if frozenTracker.container and frozenTracker.container.SetAuraSlotEnabled then
            pcall(frozenTracker.container.SetAuraSlotEnabled, frozenTracker.container, "ilh_frozen_target", false)
        end
        if frozenActualPulse and frozenActualPulse:IsPlaying() then frozenActualPulse:Stop() end
        wrapper:Hide()
    end
end

RefreshFrozenTarget = function()
    local container = frozenTracker.container
    if not (frozenTracker.ready and container) then return end

    if container.UpdateAllAuras then
        pcall(container.UpdateAllAuras, container)
    end

    -- Forever builds have occasionally needed the token reassigned after a
    -- target swap. Both calls are guarded so a restricted build cannot break UI.
    if container.SetUnit then
        pcall(container.SetUnit, container, "none")
        pcall(container.SetUnit, container, "target")
    end
end

-- ---------------------------------------------------------------------------
-- Exact freeze proc sound via C_UnitAuras.AddAuraSound
-- ---------------------------------------------------------------------------

local freezeAudio = {
    registrations = {},
    registeredCount = 0,
    pending = false,
    lastError = nil,
}

local function ClearFreezeSounds()
    if C_UnitAuras and C_UnitAuras.RemoveAuraSound then
        for _, auraSoundID in ipairs(freezeAudio.registrations) do
            pcall(C_UnitAuras.RemoveAuraSound, auraSoundID)
        end
    end
    wipe(freezeAudio.registrations)
    freezeAudio.registeredCount = 0
end

local function RegisterOneFreezeSound(spellID)
    if not (C_UnitAuras and C_UnitAuras.AddAuraSound) then
        return nil, "C_UnitAuras.AddAuraSound is unavailable"
    end

    local trigger = 0
    if Enum and Enum.UnitAuraSoundTrigger and Enum.UnitAuraSoundTrigger.Added ~= nil then
        trigger = Enum.UnitAuraSoundTrigger.Added
    end

    local soundInfo = {
        unitToken = "target",
        spellID = spellID,
        soundFileName = GetSelectedSound().file,
        outputChannel = "Master",
        throttleSeconds = 0.15,
    }

    local ok, auraSoundID = pcall(C_UnitAuras.AddAuraSound, trigger, soundInfo)
    if ok and auraSoundID then
        return auraSoundID
    end

    -- Compatibility retry for builds that do not yet accept throttleSeconds.
    soundInfo.throttleSeconds = nil
    local okRetry, retryID = pcall(C_UnitAuras.AddAuraSound, trigger, soundInfo)
    if okRetry and retryID then
        return retryID
    end

    return nil, tostring(auraSoundID or retryID or "registration failed")
end

ConfigureFreezeSounds = function()
    if not ShatterPulseDB then return end

    if InCombatLockdown and InCombatLockdown() then
        freezeAudio.pending = true
        return
    end

    freezeAudio.pending = false
    freezeAudio.lastError = nil
    ClearFreezeSounds()

    if not ShatterPulseDB.enabled or not ShatterPulseDB.trackFrozen or not ShatterPulseDB.freezeSound then
        if RefreshOptionsMenu then RefreshOptionsMenu() end
        return
    end

    for spellID in pairs(FROZEN_AURA_IDS) do
        local auraSoundID, err = RegisterOneFreezeSound(spellID)
        if auraSoundID then
            table.insert(freezeAudio.registrations, auraSoundID)
        elseif not freezeAudio.lastError then
            freezeAudio.lastError = err
        end
    end

    freezeAudio.registeredCount = #freezeAudio.registrations
    if RefreshOptionsMenu then RefreshOptionsMenu() end
end

local function TestFreezeSound()
    local sound = GetSelectedSound()
    local ok, played = pcall(PlaySoundFile, sound.file, "Master")
    if not ok or played == false then
        pcall(PlaySound, 8959, "Master")
    end
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

local function ApplyLayout()
    local db = ShatterPulseDB
    if not db then return end

    display:SetSize(db.size, db.size)
    display:SetAlpha(db.alpha)
    display:ClearAllPoints()
    display:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
    display:EnableMouse(not db.locked)
    display:EnableMouseWheel(not db.locked)
    ConfigureVisualSet(displayVisual, 1)

    frozenPreview:SetSize(db.size, db.size)
    frozenPreview:SetAlpha(db.alpha)
    frozenPreview:ClearAllPoints()
    frozenPreview:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
    ConfigureVisualSet(frozenPreviewVisual, 1)

    RefreshPulseGroup(pulse)
    RefreshPulseGroup(frozenPreviewPulse)
    if frozenActualPulse then RefreshPulseGroup(frozenActualPulse) end

    dragText:SetShown(not db.locked and state.moving)

    if ApplyFrozenLayout then ApplyFrozenLayout() end
    if ApplyMinimapPosition then ApplyMinimapPosition() end
    if RefreshOptionsMenu then RefreshOptionsMenu() end
end

-- ---------------------------------------------------------------------------
-- Minimap button
-- ---------------------------------------------------------------------------

local minimapButton = CreateFrame("Button", "ShatterPulseMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local minimapBackground = minimapButton:CreateTexture(nil, "BACKGROUND")
minimapBackground:SetSize(20, 20)
minimapBackground:SetPoint("CENTER")
minimapBackground:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

local minimapIcon = minimapButton:CreateTexture(nil, "ARTWORK")
minimapIcon:SetSize(20, 20)
minimapIcon:SetPoint("CENTER")
minimapIcon:SetTexture("Interface\\Icons\\Spell_Frost_FrostBlast")
minimapIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local minimapBorder = minimapButton:CreateTexture(nil, "OVERLAY")
minimapBorder:SetSize(54, 54)
minimapBorder:SetPoint("TOPLEFT")
minimapBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

ApplyMinimapPosition = function()
    if not ShatterPulseDB then return end
    if ShatterPulseDB.minimapShown then
        minimapButton:Show()
    else
        minimapButton:Hide()
        return
    end

    local angle = math.rad(ShatterPulseDB.minimapAngle or defaults.minimapAngle)
    local radius = math.max(72, (Minimap:GetWidth() or 140) / 2 + 8)
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function UpdateMinimapDrag()
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1
    cursorX = cursorX / scale
    cursorY = cursorY / scale
    local centerX, centerY = Minimap:GetCenter()
    if not centerX or not centerY then return end

    ShatterPulseDB.minimapAngle = math.deg(Atan2(cursorY - centerY, cursorX - centerX))
    ApplyMinimapPosition()
end

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("ShatterPulse", 0.4, 0.85, 1)
    GameTooltip:AddLine("Left-click: Open settings", 1, 1, 1)
    GameTooltip:AddLine("Right-click: Preview both overlays", 1, 1, 1)
    GameTooltip:AddLine("Drag: Move minimap button", 0.75, 0.75, 0.75)
    GameTooltip:Show()
end)
minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
minimapButton:SetScript("OnDragStart", function(self)
    self.isDragging = true
    self:SetScript("OnUpdate", UpdateMinimapDrag)
end)
minimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    C_Timer.After(0, function() self.isDragging = false end)
end)

-- ---------------------------------------------------------------------------
-- Options menu - 2.0 Bartender-inspired page layout
-- ---------------------------------------------------------------------------

local function SafeBackdrop(frame, bgAlpha, borderR, borderG, borderB)
    if not frame then return end
    if frame.SetBackdrop then
        pcall(frame.SetBackdrop, frame, {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        if frame.SetBackdropColor then
            pcall(frame.SetBackdropColor, frame, 0.035, 0.045, 0.055, bgAlpha or 0.96)
        end
        if frame.SetBackdropBorderColor then
            pcall(frame.SetBackdropBorderColor, frame, borderR or 0.42, borderG or 0.35, borderB or 0.15, 1)
        end
    else
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.035, 0.045, 0.055, bgAlpha or 0.96)
    end
end

local function GoldLine(parent, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", 16, y)
    line:SetPoint("TOPRIGHT", -16, y)
    line:SetHeight(1)
    line:SetColorTexture(0.52, 0.42, 0.16, 0.80)
    return line
end

local options = CreateFrame("Frame", "ShatterPulseOptionsFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
options:SetSize(810, 730)
options:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
options:SetFrameStrata("DIALOG")
options:SetClampedToScreen(true)
options:SetMovable(true)
options:EnableMouse(true)
options:RegisterForDrag("LeftButton")
options:Hide()
SafeBackdrop(options, 0.98, 0.80, 0.68, 0.32)

local header = options:CreateTexture(nil, "ARTWORK")
header:SetPoint("TOPLEFT", 8, -8)
header:SetPoint("TOPRIGHT", -8, -8)
header:SetHeight(54)
header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
header:SetTexCoord(0.08, 0.92, 0.18, 0.82)
header:SetVertexColor(0.55, 0.55, 0.55, 0.95)

local headerShade = options:CreateTexture(nil, "BACKGROUND", nil, 1)
headerShade:SetPoint("TOPLEFT", 12, -12)
headerShade:SetPoint("TOPRIGHT", -12, -12)
headerShade:SetHeight(50)
headerShade:SetColorTexture(0.025, 0.03, 0.04, 0.82)

local headerTop = options:CreateTexture(nil, "OVERLAY")
headerTop:SetPoint("TOPLEFT", 10, -10)
headerTop:SetPoint("TOPRIGHT", -10, -10)
headerTop:SetHeight(1)
headerTop:SetColorTexture(0.86, 0.68, 0.20, 0.85)

local optionsTitle = options:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
optionsTitle:SetPoint("TOPLEFT", 24, -20)
optionsTitle:SetText("ShatterPulse")
optionsTitle:SetTextColor(1.00, 0.82, 0.00)

local optionsVersion = options:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
optionsVersion:SetPoint("LEFT", optionsTitle, "RIGHT", 10, -2)
optionsVersion:SetText("v" .. VERSION)
optionsVersion:SetTextColor(0.78, 0.78, 0.78)

local subtitle = options:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", 25, -45)
subtitle:SetText("Classic Blizzard-style Frost / Fingers of Frost proc helper")
subtitle:SetTextColor(0.72, 0.70, 0.60)

local closeX = CreateFrame("Button", nil, options, "UIPanelCloseButton")
closeX:SetPoint("TOPRIGHT", -8, -8)

options:SetScript("OnDragStart", function(self) self:StartMoving() end)
options:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

local sidebar = CreateFrame("Frame", nil, options, BackdropTemplateMixin and "BackdropTemplate")
sidebar:SetPoint("TOPLEFT", 14, -72)
sidebar:SetPoint("BOTTOMLEFT", 14, 48)
sidebar:SetWidth(164)
SafeBackdrop(sidebar, 0.92, 0.55, 0.43, 0.18)

local content = CreateFrame("Frame", nil, options, BackdropTemplateMixin and "BackdropTemplate")
content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, 0)
content:SetPoint("BOTTOMRIGHT", -14, 48)
SafeBackdrop(content, 0.92, 0.55, 0.43, 0.18)

local footer = options:CreateTexture(nil, "ARTWORK")
footer:SetPoint("BOTTOMLEFT", 10, 10)
footer:SetPoint("BOTTOMRIGHT", -10, 10)
footer:SetHeight(30)
footer:SetColorTexture(0.04, 0.05, 0.06, 0.96)

local footerStatus = options:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
footerStatus:SetPoint("LEFT", 22, 25)
footerStatus:SetTextColor(0.78, 0.75, 0.62)

local pages = {}
local navButtons = {}
local controls = {}
local styleButtons = {}
local soundButtons = {}
local currentPage = "General"

local function CreatePage(name)
    local page = CreateFrame("Frame", nil, content)
    page:SetAllPoints()
    page:Hide()
    pages[name] = page
    return page
end

local generalPage = CreatePage("General")
local visualsPage = CreatePage("Visuals")
local soundsPage = CreatePage("Sounds")
local previewPage = CreatePage("Preview")
local faqPage = CreatePage("FAQ / About")

local function CreateNavButton(name, index)
    local button = CreateFrame("Button", nil, sidebar)
    button:SetPoint("TOPLEFT", 8, -10 - ((index - 1) * 44))
    button:SetPoint("TOPRIGHT", -8, -10 - ((index - 1) * 44))
    button:SetHeight(38)

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.055, 0.065, 0.075, 0.92)
    button.bg = bg

    local hl = button:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hl:SetBlendMode("ADD")
    hl:SetAlpha(0.55)

    local selected = button:CreateTexture(nil, "ARTWORK")
    selected:SetPoint("TOPLEFT", 1, -1)
    selected:SetPoint("BOTTOMRIGHT", -1, 1)
    selected:SetColorTexture(0.08, 0.22, 0.38, 0.75)
    selected:Hide()
    button.selected = selected

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", 12, 0)
    text:SetText(name)
    text:SetTextColor(1.00, 0.82, 0.00)
    button.text = text

    button:SetScript("OnClick", function()
        currentPage = name
        for pageName, page in pairs(pages) do page:SetShown(pageName == name) end
        for navName, nav in pairs(navButtons) do nav.selected:SetShown(navName == name) end
    end)

    navButtons[name] = button
    return button
end

CreateNavButton("General", 1)
CreateNavButton("Visuals", 2)
CreateNavButton("Sounds", 3)
CreateNavButton("Preview", 4)
CreateNavButton("FAQ / About", 5)

local function ShowPage(name)
    currentPage = pages[name] and name or "General"
    for pageName, page in pairs(pages) do page:SetShown(pageName == currentPage) end
    for navName, nav in pairs(navButtons) do nav.selected:SetShown(navName == currentPage) end
end

local function PageTitle(parent, text, subtext)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -18)
    title:SetText(text)
    title:SetTextColor(1.00, 0.82, 0.00)
    local sub = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", 20, -42)
    sub:SetText(subtext or "")
    sub:SetTextColor(0.70, 0.72, 0.74)
    GoldLine(parent, -62)
end

local function SectionTitle(parent, text, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 20, y)
    fs:SetText(text)
    fs:SetTextColor(1.00, 0.82, 0.00)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("LEFT", fs, "RIGHT", 10, 0)
    line:SetPoint("RIGHT", parent, "RIGHT", -20, 0)
    line:SetHeight(1)
    line:SetColorTexture(0.45, 0.38, 0.16, 0.55)
    return fs
end

local function CreateCheck(parent, key, label, x, y, onChanged)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetSize(26, 26)
    local textLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    textLabel:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    textLabel:SetText(label)
    textLabel:SetTextColor(0.94, 0.93, 0.88)
    cb.label = textLabel
    cb:SetScript("OnClick", function(self)
        ShatterPulseDB[key] = self:GetChecked() and true or false
        if onChanged then onChanged() end
        ApplyLayout()
        UpdateDisplay()
    end)
    controls[key] = cb
    return cb
end

local function CreateSlider(parent, key, label, x, y, width, minValue, maxValue, step, formatText, onChanged)
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    labelText:SetPoint("TOPLEFT", x, y)
    labelText:SetText(label)
    labelText:SetTextColor(0.94, 0.93, 0.88)

    local valueText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("TOPLEFT", x + width - 52, y)
    valueText:SetWidth(52)
    valueText:SetJustifyH("RIGHT")
    valueText:SetTextColor(1.00, 0.82, 0.00)

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x + 2, y - 24)
    slider:SetWidth(width)
    slider:SetHeight(18)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    if slider.Low then slider.Low:SetText("") end
    if slider.High then slider.High:SetText("") end
    if slider.Text then slider.Text:SetText("") end
    slider.valueText = valueText
    slider.formatText = formatText
    slider:SetScript("OnValueChanged", function(self, value)
        if self.refreshing then return end
        value = math.floor((value / step) + 0.5) * step
        ShatterPulseDB[key] = value
        valueText:SetText(formatText(value))
        if onChanged then onChanged(value) end
        ApplyLayout()
        UpdateDisplay()
    end)
    controls[key] = slider
    return slider
end

local function CreateActionButton(parent, label, x, y, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 28)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
end

local function SetStyle(style)
    ShatterPulseDB.displayStyle = style
    state.previewMode = "both"
    ApplyLayout()
    UpdateDisplay()
end

local function SetPreviewMode(mode)
    if mode ~= "off" and mode ~= "frozen" and mode ~= "fof" and mode ~= "both" then mode = "off" end
    if state.previewMode == mode and mode ~= "off" then state.previewMode = "off" else state.previewMode = mode end
    UpdateDisplay()
end

local function CreateStyleButton(parent, style, label, x, y, width)
    local button = CreateActionButton(parent, label, x, y, width, function() SetStyle(style) end)
    button.baseLabel = label
    button.style = style
    styleButtons[#styleButtons + 1] = button
    return button
end

local function SetSoundChoice(key)
    if not SOUND_CHOICES[key] then return end
    ShatterPulseDB.freezeSoundChoice = key
    ConfigureFreezeSounds()
    if RefreshOptionsMenu then RefreshOptionsMenu() end
    TestFreezeSound()
end

local function CreateSoundButton(parent, key, label, x, y, width)
    local button = CreateActionButton(parent, label, x, y, width, function() SetSoundChoice(key) end)
    button.baseLabel = label
    button.soundKey = key
    soundButtons[#soundButtons + 1] = button
    return button
end

-- GENERAL PAGE
PageTitle(generalPage, "General", "Core tracking and addon behavior")
SectionTitle(generalPage, "Tracking", -86)
CreateCheck(generalPage, "enabled", "Enable ShatterPulse", 20, -106, ConfigureFreezeSounds)
CreateCheck(generalPage, "trackFoF", "Track Fingers of Frost", 20, -138, CheckFoFOverlay)
CreateCheck(generalPage, "trackFrozen", "Track frozen target / Shatter", 20, -170, function()
    ApplyFrozenLayout()
    ConfigureFreezeSounds()
end)
CreateCheck(generalPage, "minimapShown", "Show minimap button", 290, -106, ApplyMinimapPosition)
CreateCheck(generalPage, "locked", "Lock proc position", 290, -138, function()
    state.moving = not ShatterPulseDB.locked
    dragText:SetShown(state.moving)
end)
CreateCheck(generalPage, "pulse", "Enable flash / animation", 290, -170)

SectionTitle(generalPage, "Icon Mode", -224)
CreateCheck(generalPage, "showText", "Show ICE LANCE text in icon styles", 20, -244)
CreateCheck(generalPage, "showReason", "Show proc reason in icon styles", 20, -276)

local genNote = generalPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
genNote:SetPoint("TOPLEFT", 20, -330)
genNote:SetWidth(520)
genNote:SetJustifyH("LEFT")
genNote:SetText("Frozen tracking is aura-driven: when Frost Nova/Frostbite/Freeze disappears, the side overlay disappears with it. No guessed freeze duration is used.")
genNote:SetTextColor(0.72, 0.74, 0.76)

-- VISUALS PAGE
PageTitle(visualsPage, "Visuals", "Classic Blizzard-like proc layout with adjustable glow and flash")
SectionTitle(visualsPage, "Display Style", -86)
CreateStyleButton(visualsPage, STYLE_SPLIT, "Retail Split Overlay", 20, -110, 240)
CreateStyleButton(visualsPage, STYLE_COMBO, "Split + Ice Lance", 280, -110, 240)
CreateStyleButton(visualsPage, STYLE_CLEAN, "Clean Ice Lance", 20, -146, 240)
CreateStyleButton(visualsPage, STYLE_BLIZZARD, "Ice Lance + Glow", 280, -146, 240)

SectionTitle(visualsPage, "Overlay Placement", -204)
CreateSlider(visualsPage, "retailScale", "Master overlay scale", 20, -228, 220, 0.60, 1.50, 0.05, function(v)
    return tostring(math.floor(v * 100 + 0.5)) .. "%"
end)
CreateSlider(visualsPage, "alpha", "Opacity", 290, -228, 220, 0.20, 1.00, 0.05, function(v)
    return tostring(math.floor(v * 100 + 0.5)) .. "%"
end)
CreateSlider(visualsPage, "barDistance", "Left / right distance", 20, -300, 220, 130, 320, 5, function(v)
    return tostring(math.floor(v + 0.5))
end)
CreateSlider(visualsPage, "sideScale", "Side arc scale", 290, -300, 220, 0.60, 1.60, 0.05, function(v)
    return tostring(math.floor(v * 100 + 0.5)) .. "%"
end)
CreateSlider(visualsPage, "topHeight", "FoF top height", 20, -372, 220, 90, 300, 5, function(v)
    return tostring(math.floor(v + 0.5))
end)
CreateSlider(visualsPage, "topScale", "FoF crown scale", 290, -372, 220, 0.60, 1.60, 0.05, function(v)
    return tostring(math.floor(v * 100 + 0.5)) .. "%"
end)
CreateSlider(visualsPage, "size", "Ice Lance icon size", 20, -444, 220, 40, 220, 2, function(v)
    return tostring(math.floor(v + 0.5)) .. " px"
end)

SectionTitle(visualsPage, "Animation & Glow", -498)
CreateSlider(visualsPage, "flashSpeed", "Flash speed", 20, -522, 220, 0.40, 2.20, 0.05, function(v)
    return string.format("%.2fx", v)
end)
CreateSlider(visualsPage, "flashStrength", "Flash strength", 290, -522, 220, 0.20, 2.00, 0.05, function(v)
    return tostring(math.floor(v * 100 + 0.5)) .. "%"
end)
CreateSlider(visualsPage, "glowIntensity", "Glow intensity", 20, -594, 220, 0.50, 2.00, 0.05, function(v)
    return tostring(math.floor(v * 100 + 0.5)) .. "%"
end)

local visualNote = visualsPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
visualNote:SetPoint("TOPLEFT", 20, -662)
visualNote:SetWidth(520)
visualNote:SetJustifyH("LEFT")
visualNote:SetText("Retail Split Overlay is the recommended mode: frozen targets use left/right crystalline arcs, while Fingers of Frost uses the top crown. Glow and flash controls affect this style without changing the basic artwork.")
visualNote:SetTextColor(0.72, 0.74, 0.76)

-- SOUNDS PAGE
PageTitle(soundsPage, "Sounds", "Choose a proc sound and decide what triggers it")
SectionTitle(soundsPage, "Triggers", -86)
CreateCheck(soundsPage, "freezeSound", "Play selected sound when a freeze aura is added", 20, -106, ConfigureFreezeSounds)
CreateCheck(soundsPage, "fofSound", "Play selected sound when Fingers of Frost procs", 20, -138)

SectionTitle(soundsPage, "Sound Selection", -196)
CreateSoundButton(soundsPage, "crystal", "Crystal", 20, -220, 160)
CreateSoundButton(soundsPage, "crack", "Ice Crack", 196, -220, 160)
CreateSoundButton(soundsPage, "chime", "Frost Chime", 372, -220, 160)
CreateSoundButton(soundsPage, "ping", "Sharp Ping", 20, -258, 248)
CreateSoundButton(soundsPage, "whoosh", "Frost Whoosh", 284, -258, 248)

CreateActionButton(soundsPage, "Test selected sound", 20, -318, 248, TestFreezeSound)

local soundNote = soundsPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
soundNote:SetPoint("TOPLEFT", 20, -370)
soundNote:SetWidth(520)
soundNote:SetJustifyH("LEFT")
soundNote:SetText("Five bundled frost sounds are included and work without relying on client-specific Blizzard sound IDs. Freeze sounds are registered for Frost Nova, Frostbite and the other configured hard-freeze auras. Selecting a sound previews it immediately.")
soundNote:SetTextColor(0.72, 0.74, 0.76)

-- PREVIEW PAGE
PageTitle(previewPage, "Preview", "Test each state without waiting for a proc")
SectionTitle(previewPage, "Proc Preview", -86)
local previewFrozenButton = CreateActionButton(previewPage, "Preview Frozen", 20, -110, 165, function() SetPreviewMode("frozen") end)
local previewFoFButton = CreateActionButton(previewPage, "Preview FoF", 198, -110, 165, function() SetPreviewMode("fof") end)
local previewBothButton = CreateActionButton(previewPage, "Preview Both", 376, -110, 165, function() SetPreviewMode("both") end)
local previewOffButton = CreateActionButton(previewPage, "Preview Off", 20, -148, 165, function() SetPreviewMode("off") end)

SectionTitle(previewPage, "Utility", -214)
CreateActionButton(previewPage, "Reset proc position", 20, -238, 220, function()
    ShatterPulseDB.point = defaults.point
    ShatterPulseDB.relativePoint = defaults.relativePoint
    ShatterPulseDB.x = defaults.x
    ShatterPulseDB.y = defaults.y
    ApplyLayout()
    UpdateDisplay()
    Chat("Proc position reset.")
end)
CreateActionButton(previewPage, "Reset visual spacing", 258, -238, 220, function()
    ShatterPulseDB.barDistance = defaults.barDistance
    ShatterPulseDB.retailScale = defaults.retailScale
    ShatterPulseDB.sideScale = defaults.sideScale
    ShatterPulseDB.topScale = defaults.topScale
    ShatterPulseDB.topHeight = defaults.topHeight
    ApplyLayout()
    UpdateDisplay()
    Chat("Visual spacing reset.")
end)
CreateActionButton(previewPage, "Unlock and move", 20, -276, 220, function()
    ShatterPulseDB.locked = false
    state.moving = true
    ApplyLayout()
    UpdateDisplay()
    dragText:Show()
    Chat("Unlocked. Drag the proc anchor, then lock it from General.")
end)
CreateActionButton(previewPage, "Test selected sound", 258, -276, 220, TestFreezeSound)


-- FAQ / ABOUT PAGE
PageTitle(faqPage, "FAQ / About", "Quick help, technical notes and addon credits")

SectionTitle(faqPage, "Frequently Asked Questions", -86)
local faqText = faqPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
faqText:SetPoint("TOPLEFT", 20, -112)
faqText:SetWidth(520)
faqText:SetJustifyH("LEFT")
faqText:SetJustifyV("TOP")
faqText:SetText([[|cffffd100What does ShatterPulse do?|r
Shows a Blizzard-style Ice Lance proc display when Fingers of Frost is active or your current target is actually frozen.

|cffffd100Why do the side arcs disappear immediately?|r
Frozen tracking is aura-driven. When Frost Nova, Frostbite, Freeze or another configured hard-freeze aura disappears, the side arcs disappear with it. There is no guessed timer.

|cffffd100What does the top crown mean?|r
The top crown is reserved for Fingers of Frost. If the target is frozen at the same time, the side arcs and top crown can appear together.

|cffffd100How do I move or test the display?|r
Open Preview and use Unlock and move, Preview Frozen, Preview FoF or Preview Both. The minimap button also opens this menu.

|cffffd100Why does the addon avoid Combat Log tracking?|r
WoW Forever restricts some combat and aura information. ShatterPulse uses Blizzard-safe proc events and AuraContainer tracking instead of restricted combat-log tricks.

|cffffd100Useful slash commands|r
/sp menu  /sp test both  /sp move  /sp lock  /sp soundtest  /sp status]])
faqText:SetTextColor(0.86, 0.86, 0.82)

SectionTitle(faqPage, "About", -500)
local aboutText = faqPage:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
aboutText:SetPoint("TOPLEFT", 20, -526)
aboutText:SetWidth(520)
aboutText:SetJustifyH("LEFT")
aboutText:SetText("ShatterPulse v" .. VERSION .. "\nCreated by |cffffd100Schrubber|r\nBuilt for WoW Forever Frost Mage gameplay.")
aboutText:SetTextColor(0.92, 0.92, 0.88)

local statusText = previewPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
statusText:SetPoint("TOPLEFT", 20, -342)
statusText:SetWidth(520)
statusText:SetJustifyH("LEFT")
statusText:SetTextColor(0.82, 0.80, 0.70)

local function RefreshOptionsMenuImpl()
    if not ShatterPulseDB then return end

    for key, control in pairs(controls) do
        if control.SetChecked and type(ShatterPulseDB[key]) == "boolean" then
            control:SetChecked(ShatterPulseDB[key])
        elseif control.SetValue and type(ShatterPulseDB[key]) == "number" then
            control.refreshing = true
            control:SetValue(ShatterPulseDB[key])
            control.refreshing = false
            if control.valueText and control.formatText then
                control.valueText:SetText(control.formatText(ShatterPulseDB[key]))
            end
        end
    end

    for _, button in ipairs(styleButtons) do
        local selected = ShatterPulseDB.displayStyle == button.style
        button:SetText((selected and "• " or "") .. button.baseLabel)
    end

    for _, button in ipairs(soundButtons) do
        local selected = ShatterPulseDB.freezeSoundChoice == button.soundKey
        button:SetText((selected and "• " or "") .. button.baseLabel)
    end

    previewFrozenButton:SetText((state.previewMode == "frozen" and "• " or "") .. "Preview Frozen")
    previewFoFButton:SetText((state.previewMode == "fof" and "• " or "") .. "Preview FoF")
    previewBothButton:SetText((state.previewMode == "both" and "• " or "") .. "Preview Both")
    previewOffButton:SetText((state.previewMode == "off" and "• " or "") .. "Preview Off")

    local frozenState = frozenTracker.ready and "Frozen tracker READY" or (frozenTracker.failed and "Frozen tracker ERROR" or "Frozen tracker loading")
    local audioState
    if not ShatterPulseDB.freezeSound then
        audioState = "Freeze sound OFF"
    elseif freezeAudio.registeredCount > 0 then
        audioState = "Freeze sound READY (" .. freezeAudio.registeredCount .. ") - " .. GetSelectedSound().label
    elseif freezeAudio.lastError then
        audioState = "Freeze sound ERROR"
    else
        audioState = "Freeze sound loading"
    end

    statusText:SetText(frozenState .. "\n" .. audioState .. "\nFoF: " .. (state.fofGlow and "ACTIVE" or "idle") .. "\nPreview: " .. state.previewMode)
    footerStatus:SetText("Created by Schrubber   •   Frozen: " .. (frozenTracker.ready and "ready" or "loading") .. "   •   FoF: " .. (state.fofGlow and "active" or "idle") .. "   •   Sound: " .. GetSelectedSound().label)
end

RefreshOptionsMenu = RefreshOptionsMenuImpl

local closeButton = CreateFrame("Button", nil, options, "UIPanelButtonTemplate")
closeButton:SetSize(110, 24)
closeButton:SetPoint("BOTTOMRIGHT", -18, 14)
closeButton:SetText("Close")
closeButton:SetScript("OnClick", function() options:Hide() end)

local defaultsButton = CreateFrame("Button", nil, options, "UIPanelButtonTemplate")
defaultsButton:SetSize(110, 24)
defaultsButton:SetPoint("RIGHT", closeButton, "LEFT", -8, 0)
defaultsButton:SetText("Defaults")
defaultsButton:SetScript("OnClick", function()
    ShatterPulseDB.retailScale = defaults.retailScale
    ShatterPulseDB.barDistance = defaults.barDistance
    ShatterPulseDB.sideScale = defaults.sideScale
    ShatterPulseDB.topScale = defaults.topScale
    ShatterPulseDB.topHeight = defaults.topHeight
    ShatterPulseDB.alpha = defaults.alpha
    ShatterPulseDB.size = defaults.size
    ShatterPulseDB.flashSpeed = defaults.flashSpeed
    ShatterPulseDB.flashStrength = defaults.flashStrength
    ShatterPulseDB.glowIntensity = defaults.glowIntensity
    ApplyLayout()
    UpdateDisplay()
    Chat("Visual defaults restored.")
end)

local function ToggleOptionsMenu()
    if options:IsShown() then
        options:Hide()
    else
        RefreshOptionsMenu()
        ShowPage(currentPage)
        options:Show()
    end
end

ShowPage("General")

minimapButton:SetScript("OnClick", function(self, button)
    if self.isDragging then return end
    if button == "RightButton" then
        SetPreviewMode("both")
        Chat("Preview = " .. state.previewMode)
    else
        ToggleOptionsMenu()
    end
end)

-- ---------------------------------------------------------------------------
-- Moving the proc display
-- ---------------------------------------------------------------------------

display:SetScript("OnDragStart", function(self)
    if ShatterPulseDB.locked then return end
    state.moving = true
    dragText:Show()
    if pulse:IsPlaying() then pulse:Stop() end
    self:SetScale(1)
    self:StartMoving()
end)

display:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    state.moving = false
    dragText:Hide()

    local point, _, relativePoint, x, y = self:GetPoint(1)
    ShatterPulseDB.point = point or "CENTER"
    ShatterPulseDB.relativePoint = relativePoint or "CENTER"
    ShatterPulseDB.x = x or 0
    ShatterPulseDB.y = y or 0

    ApplyLayout()
    UpdateDisplay()
end)

display:SetScript("OnMouseWheel", function(_, delta)
    if ShatterPulseDB.locked then return end
    ShatterPulseDB.size = Clamp(ShatterPulseDB.size + (delta > 0 and 4 or -4), 40, 220)
    ApplyLayout()
    Chat("Proc size = " .. ShatterPulseDB.size .. " px")
end)

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")
addon:RegisterEvent("PLAYER_TARGET_CHANGED")
addon:RegisterEvent("PLAYER_REGEN_ENABLED")
addon:RegisterEvent("PLAYER_REGEN_DISABLED")
addon:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
addon:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
addon:RegisterEvent("SPELL_DATA_LOAD_RESULT")

addon:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, ...)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            ApplyDefaults()
            FindBestIceLanceID()
            CreateFrozenTracker()
            ApplyLayout()
            ApplyMinimapPosition()
            RefreshOptionsMenu()
        end
        return
    end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        FindBestIceLanceID()
        CheckFoFOverlay()
        RefreshFrozenTarget()
        ConfigureFreezeSounds()
        ApplyLayout()
        UpdateDisplay()
        return
    end

    if event == "SPELL_DATA_LOAD_RESULT" then
        if ICE_LANCE_SET[arg1] then
            FindBestIceLanceID()
        end
        return
    end

    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        if ShatterPulseDB and ShatterPulseDB.trackFoF and (IsIceLanceSpell(arg1) or FOF_IDS[arg1]) then
            local wasActive = state.fofGlow
            state.fofGlow = true
            if not wasActive then PlayFoFSound() end
            UpdateDisplay()
        end
        return
    end

    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        if IsIceLanceSpell(arg1) or FOF_IDS[arg1] then
            state.fofGlow = false
            UpdateDisplay()
        end
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        RefreshFrozenTarget()
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        -- No enemy aura data is read here. The Blizzard AuraContainer owns it.
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if frozenTracker.pendingLayout then
            ApplyFrozenLayout()
        end
        if freezeAudio.pending then
            ConfigureFreezeSounds()
        end
        CheckFoFOverlay()
        UpdateDisplay()
        return
    end
end)

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------

local function PrintStatus()
    Chat("Status")
    print("  Version: " .. VERSION)
    print("  Addon: " .. (ShatterPulseDB.enabled and "ON" or "OFF"))
    print("  Fingers of Frost tracking: " .. (ShatterPulseDB.trackFoF and "ON" or "OFF"))
    print("  Frozen/Shatter tracking: " .. (ShatterPulseDB.trackFrozen and "ON" or "OFF"))
    print("  FoF currently active: " .. (state.fofGlow and "YES" or "NO"))
    print("  Frozen tracker: " .. (frozenTracker.ready and "READY" or (frozenTracker.failed and ("ERROR - " .. tostring(frozenTracker.reason)) or "LOADING")))
    print("  Frozen display timing: exact AuraContainer state; no guessed freeze timer")
    print("  Freeze sound: " .. GetSelectedSound().label .. " [" .. tostring(ShatterPulseDB.freezeSoundChoice) .. "]")
    print("  Freeze sound registrations: " .. tostring(freezeAudio.registeredCount))
    if freezeAudio.lastError then print("  Freeze sound error: " .. tostring(freezeAudio.lastError)) end
    print("  Display style: " .. tostring(ShatterPulseDB.displayStyle))
    print("  Flash speed: " .. tostring(ShatterPulseDB.flashSpeed))
    print("  Flash strength: " .. tostring(ShatterPulseDB.flashStrength))
    print("  Glow intensity: " .. tostring(ShatterPulseDB.glowIntensity))
    print("  Preview mode: " .. tostring(state.previewMode))
    print("  Ice Lance SpellID: " .. tostring(state.iceLanceID))
end

local function ToggleDB(key, label, onChanged)
    ShatterPulseDB[key] = not ShatterPulseDB[key]
    Chat(label .. " = " .. (ShatterPulseDB[key] and "ON" or "OFF"))
    if onChanged then onChanged() end
    ApplyLayout()
    UpdateDisplay()
end

SLASH_SHATTERPULSE1 = "/sp"
SLASH_SHATTERPULSE2 = "/shatterpulse"
SlashCmdList.SHATTERPULSE = function(message)
    local msg = (message or ""):lower():match("^%s*(.-)%s*$")

    if msg == "on" then
        ShatterPulseDB.enabled = true
        ConfigureFreezeSounds()
        ApplyLayout()
        UpdateDisplay()
        Chat("Addon ON")
    elseif msg == "off" then
        ShatterPulseDB.enabled = false
        ConfigureFreezeSounds()
        ApplyLayout()
        UpdateDisplay()
        Chat("Addon OFF")
    elseif msg == "menu" or msg == "options" or msg == "config" then
        ToggleOptionsMenu()
    elseif msg == "minimap" then
        ShatterPulseDB.minimapShown = not ShatterPulseDB.minimapShown
        ApplyMinimapPosition()
        RefreshOptionsMenu()
        Chat("Minimap button = " .. (ShatterPulseDB.minimapShown and "ON" or "OFF"))
    elseif msg == "test" or msg == "preview" then
        SetPreviewMode("both")
        Chat("Preview = " .. state.previewMode)
    elseif msg == "test frozen" or msg == "preview frozen" then
        SetPreviewMode("frozen")
        Chat("Preview = " .. state.previewMode)
    elseif msg == "test fof" or msg == "preview fof" then
        SetPreviewMode("fof")
        Chat("Preview = " .. state.previewMode)
    elseif msg == "test both" or msg == "preview both" then
        SetPreviewMode("both")
        Chat("Preview = " .. state.previewMode)
    elseif msg == "test off" or msg == "preview off" then
        state.previewMode = "off"
        UpdateDisplay()
        Chat("Preview = off")
    elseif msg:match("^sound%s+[%a]+$") then
        local key = msg:match("^sound%s+([%a]+)$")
        if SOUND_CHOICES[key] then
            SetSoundChoice(key)
            Chat("Proc sound = " .. SOUND_CHOICES[key].label)
        else
            Chat("Unknown sound. Use: crystal, crack, chime, ping, whoosh")
        end
    elseif msg == "sounds" then
        Chat("Sounds: crystal, crack, chime, ping, whoosh")
    elseif msg == "soundtest" then
        TestFreezeSound()
    elseif msg == "freezesound" then
        ToggleDB("freezeSound", "Freeze sound", ConfigureFreezeSounds)
    elseif msg == "fofsound" then
        ToggleDB("fofSound", "Fingers of Frost sound")
    elseif msg == "fof" then
        ToggleDB("trackFoF", "Fingers of Frost tracking", CheckFoFOverlay)
    elseif msg == "frozen" or msg == "freeze" then
        ToggleDB("trackFrozen", "Frozen/Shatter tracking", function()
            ApplyFrozenLayout()
            ConfigureFreezeSounds()
        end)
    elseif msg == "move" or msg == "unlock" then
        ShatterPulseDB.locked = false
        state.moving = true
        ApplyLayout()
        UpdateDisplay()
        dragText:Show()
        Chat("Unlocked. Drag the proc display; mouse wheel changes size. Use /sp lock when done.")
    elseif msg == "lock" then
        ShatterPulseDB.locked = true
        state.moving = false
        dragText:Hide()
        ApplyLayout()
        UpdateDisplay()
        Chat("Proc position locked.")
    elseif msg:match("^size%s+%d+") then
        local value = tonumber(msg:match("^size%s+(%d+)")) or defaults.size
        ShatterPulseDB.size = Clamp(value, 40, 220)
        ApplyLayout()
        Chat("Proc size = " .. ShatterPulseDB.size .. " px")
    elseif msg:match("^alpha%s+[%d%.]+") then
        local value = tonumber(msg:match("^alpha%s+([%d%.]+)")) or 1
        ShatterPulseDB.alpha = Clamp(value, 0.2, 1)
        ApplyLayout()
        Chat("Opacity = " .. string.format("%.2f", ShatterPulseDB.alpha))
    elseif msg:match("^flash%s+[%d%.]+") then
        local value = tonumber(msg:match("^flash%s+([%d%.]+)")) or defaults.flashSpeed
        ShatterPulseDB.flashSpeed = Clamp(value, 0.40, 2.20)
        ApplyLayout()
        Chat("Flash speed = " .. string.format("%.2fx", ShatterPulseDB.flashSpeed))
    elseif msg:match("^strength%s+[%d%.]+") then
        local value = tonumber(msg:match("^strength%s+([%d%.]+)")) or defaults.flashStrength
        ShatterPulseDB.flashStrength = Clamp(value, 0.20, 2.00)
        ApplyLayout()
        Chat("Flash strength = " .. math.floor(ShatterPulseDB.flashStrength * 100 + 0.5) .. "%")
    elseif msg:match("^glow%s+[%d%.]+") then
        local value = tonumber(msg:match("^glow%s+([%d%.]+)")) or defaults.glowIntensity
        ShatterPulseDB.glowIntensity = Clamp(value, 0.50, 2.00)
        ApplyLayout()
        Chat("Glow intensity = " .. math.floor(ShatterPulseDB.glowIntensity * 100 + 0.5) .. "%")
    elseif msg:match("^overlay%s+[%d%.]+") then
        local value = tonumber(msg:match("^overlay%s+([%d%.]+)")) or defaults.retailScale
        ShatterPulseDB.retailScale = Clamp(value, 0.60, 1.50)
        ApplyLayout()
        Chat("Frost overlay scale = " .. math.floor(ShatterPulseDB.retailScale * 100 + 0.5) .. "%")
    elseif msg == "style split" or msg == "style retail" or msg == "style bars" then
        SetStyle(STYLE_SPLIT)
    elseif msg == "style blizzard" then
        SetStyle(STYLE_BLIZZARD)
    elseif msg == "style clean" then
        SetStyle(STYLE_CLEAN)
    elseif msg == "style combo" then
        SetStyle(STYLE_COMBO)
    elseif msg == "text" then
        ToggleDB("showText", "ICE LANCE text")
    elseif msg == "reason" then
        ToggleDB("showReason", "Proc reason")
    elseif msg == "pulse" then
        ToggleDB("pulse", "Pulse")
    elseif msg == "status" or msg == "frostbite" then
        RefreshFrozenTarget()
        PrintStatus()
    elseif msg == "reset" then
        ShatterPulseDB.point = defaults.point
        ShatterPulseDB.relativePoint = defaults.relativePoint
        ShatterPulseDB.x = defaults.x
        ShatterPulseDB.y = defaults.y
        ApplyLayout()
        UpdateDisplay()
        Chat("Proc position reset.")
    else
        Chat("Commands:")
        print("  /sp menu                         open settings")
        print("  /sp test [frozen|fof|both|off]  preview overlays")
        print("  /sp move | lock                  move/lock display")
        print("  /sp style split|blizzard|clean|combo")
        print("  /sp size 82                      proc size")
        print("  /sp overlay 1.0                  frost overlay scale")
        print("  /sp alpha 0.9                    opacity")
        print("  /sp flash 1.2                    flash speed")
        print("  /sp strength 1.4                 flash strength")
        print("  /sp glow 1.5                     glow intensity")
        print("  /sp freezesound | fofsound       sound toggles")
        print("  /sp sound crystal|crack|chime|ping|whoosh")
        print("  /sp soundtest                    test selected sound")
        print("  /sp text | reason | pulse        appearance toggles")
        print("  /sp status                       diagnostic status")
    end
end
