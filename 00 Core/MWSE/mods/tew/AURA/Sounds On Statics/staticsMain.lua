local cellData = require("tew.AURA.cellData")
local common = require("tew.AURA.common")
local config = require("tew.AURA.config")
local modules = require("tew.AURA.modules")
local moduleData = modules.data
local sounds = require("tew.AURA.sounds")
local soundData = require("tew.AURA.soundData")
local fader = require("tew.AURA.fader")
local staticsData = require("tew.AURA.Sounds On Statics.staticsData")
local volumeController = require("tew.AURA.volumeController")
local getVolume = volumeController.getVolume
local debugLog = common.debugLog

local raining
local playingBlocked = false
local rainOnStaticsBlocked = false
local weatherVolumeDelta
local INTERVAL = 0.55

local currentShelter = cellData.currentShelter
local staticsCache = cellData.staticsCache

local bridgeStatics = staticsData.modules["ropeBridge"].ids
local rainyStatics = staticsData.modules["rainOnStatics"].ids
local shelterStatics = staticsData.shelterStatics

local mainTimer


---------------------------------------------------------------------
local function playing(sound, ref)
    return common.getTrackPlaying(sound, ref)
end
local function play(moduleName, sound, ref)
    sounds.play { module = moduleName, track = sound, reference = ref }
end
local function playImmediate(moduleName, sound, ref)
    sounds.playImmediate { module = moduleName, track = sound, reference = ref }
end
local function remove(moduleName, sound, ref)
    sounds.remove { module = moduleName, track = sound, reference = ref }
end
local function removeImmediate(moduleName, sound, ref)
    sounds.removeImmediate { module = moduleName, track = sound, reference = ref }
end
local function removeRefSound(sound, ref)
    if playing(sound, ref) then
        debugLog("Track " .. sound.id .. " playing on ref " .. tostring(ref) .. ", now removing it.")
        tes3.removeSound { sound = sound, reference = ref }
    end
end
local function removeRainOnStatics(maybeRef)
    local function rem(ref)
        for _, sound in pairs(soundData.interiorRainLoops["ten"]) do
            removeRefSound(sound, ref)
        end
    end
    if maybeRef then
        rem(maybeRef)
    else
        for _, ref in ipairs(staticsCache) do
            rem(ref)
        end
    end
end
---------------------------------------------------------------------


local function runResetter()
    if mainTimer then mainTimer:reset() end
    table.clear(currentShelter)
    weatherVolumeDelta = nil
    cellData.volumeModifiedWeatherLoop = nil
end

local function restoreWeatherLoopVolume()
    if cellData.volumeModifiedWeatherLoop then
        local trackId = cellData.volumeModifiedWeatherLoop.id
        debugLog("[shelterWeather] Restoring config volume for weather loop: " .. trackId)
        fader.cancel("shelterWeather")
        volumeController.setConfigVolumes(trackId)
    end
end

local function fadeWeatherLoop(fadeType, weatherLoop)
    if not (weatherLoop and weatherLoop:isPlaying()) then return end
    local trackId = weatherLoop.id
    debugLog("[shelterWeather] Fading %s weather track: %s", fadeType, trackId)
    fader.fade {
        module = "shelterWeather",
        fadeType = fadeType,
        track = weatherLoop,
        volume = weatherVolumeDelta,
        onSuccess = function()
            cellData.volumeModifiedWeatherLoop = (fadeType == "out") and weatherLoop or nil
        end,
        onFail = function()
            -- On fail we want to restore config volume regardless of whether
            -- cellData.volumeModifiedWeatherLoop has been set or not. That's
            -- why we're not calling restoreWeatherLoopVolume() here.
            volumeController.setConfigVolumes(trackId)
        end,
    }
end

local function adjustWeatherLoopVolume()
    local moduleName = "shelterWeather"
    local sheltered = cellData.currentShelter.ref

    local moduleActive = modules.isActive(moduleName)
    local weatherLoop = common.getWeatherTrack()
    local soundConfig = volumeController.getModuleSoundConfig(moduleName)
    local delta = soundConfig.mult

    if not moduleActive
        or not weatherLoop
        or not delta
        or cellData.playerUnderwater then
        restoreWeatherLoopVolume()
        return
    end

    local transitionScalar = tes3.worldController.weatherController.transitionScalar
    if transitionScalar and transitionScalar > 0 then
        if not sheltered then
            restoreWeatherLoopVolume()
        end
        return
    end

    if (weatherVolumeDelta) and (delta ~= weatherVolumeDelta) then
        debugLog("[%s] Different conditions.", moduleName)
        restoreWeatherLoopVolume()
    end

    if (not cellData.volumeModifiedWeatherLoop) and (sheltered) then
        weatherVolumeDelta = delta
        moduleData[moduleName].lastVolume = math.round(weatherLoop.volume, 2)
        fadeWeatherLoop("out", weatherLoop)
    elseif (cellData.volumeModifiedWeatherLoop) and (not sheltered) and (weatherVolumeDelta) then
        fadeWeatherLoop("in", weatherLoop)
    end
end

local function playRainOnStatic(ref)
    local moduleName = "rainOnStatics"
    local refTrack = modules.getRefTrackPlaying(ref, moduleName)
    local sound = sounds.getTrack { module = moduleName }

    -- If this ref is a shelter and we're not playing rain _insde_ shelters
    -- then we're not going to play rain _on_ this ref either because the
    -- sound will be heard when the player does get sheltered by this ref
    local noShelterRain = ref and not modules.isActive("shelterRain")
        and common.getMatch(shelterStatics, ref.object.id:lower())


    if not ref
        or not sound
        or noShelterRain
        or cellData.playerUnderwater
        or common.isRefSheltered {
            originRef = ref,
            ignoreList = staticsData.modules[moduleName].ignore,
            quiet = true,
        } then
        if (refTrack) and (ref) then removeImmediate(moduleName, refTrack, ref) end
        return
    end

    if (refTrack) and (sound ~= refTrack) then removeImmediate(moduleName, refTrack, ref) end

    if playing(sound, ref) then return end

    debugLog(string.format("[%s] Adding sound %s for -> %s", moduleName, sound.id, ref))

    playImmediate(moduleName, sound, ref)
end

local function playShelterRain()
    local moduleName = "shelterRain"

    if not modules.isActive(moduleName) or cellData.playerUnderwater then
        removeImmediate(moduleName)
        return
    end

    local shelter = cellData.currentShelter.ref
    local sound = sounds.getTrack { module = moduleName }

    if not raining or not shelter or not sound then
        remove(moduleName)
        return
    end

    -- Don't want to hear shelter rain if this shelter is sheltered
    -- by something else. Awnings are exempted from this because RayTest
    -- results for awnings may return some false positives
    if not string.find(shelter.object.id:lower(), "awning") then
        if common.isRefSheltered {
                originRef = shelter,
                ignoreList = staticsData.modules[moduleName].ignore,
                quiet = true,
            } then
            remove(moduleName)
            return
        end
    end

    local currentTrack, _ = table.unpack(modules.getCurrentlyPlaying(moduleName) or {})

    if (currentTrack) and (currentTrack == sound) then return end

    local refTrack = modules.getTempDataEntry("track", shelter, "rainOnStatics")
    local refTrackPlaying = playing(refTrack, shelter)
    local doCrossfade = (refTrackPlaying ~= nil)
    debugLog(string.format("[%s] Playing rain track: %s | RoS crossfade: %s", moduleName, sound.id, doCrossfade))

    if doCrossfade then remove("rainOnStatics", refTrackPlaying, shelter) end
    play(moduleName, sound)
end

local function playShelterWind()
    local moduleName = "shelterWind"

    if not modules.isActive(moduleName) or cellData.playerUnderwater then
        removeImmediate(moduleName)
        return
    end

    local supportedShelterTypes = staticsData.modules[moduleName].ids
    local shelter = cellData.currentShelter.ref
    local isValidShelterType = shelter and common.getMatch(supportedShelterTypes, shelter.object.id:lower())

    local weatherLoopPlaying = (common.getWeatherTrack() ~= nil)
    local sound = sounds.getTrack { module = moduleName }

    local ready = isValidShelterType and weatherLoopPlaying and sound
    if not ready then
        remove(moduleName)
        return
    end

    if modules.getCurrentlyPlaying(moduleName) then return end

    debugLog(string.format("[%s] Playing track: %s", moduleName, sound.id))

    play(moduleName, sound)
end

local function playRopeBridge(ref)
    local moduleName = "ropeBridge"
    local sound = tes3.getSound("tew_ropebridge")

    if sound and not playing(sound, ref) then
        debugLog(string.format("[%s] Adding sound %s for -> %s", moduleName, sound.id, tostring(ref)))
        playImmediate(moduleName, sound, ref)
    end
end

local function playPhotodragons(ref)
    local moduleName = "photodragons"
    local sound = tes3.getSound("tew_photodragons")

    if sound and not playing(sound, ref) then
        debugLog(string.format("[%s] Adding sound %s for -> %s", moduleName, sound.id, tostring(ref)))
        playImmediate(moduleName, sound, ref)
    end
end

local function playBannerFlap(ref)
    local moduleName = "bannerFlap"
    local breezeType

    if cellData.playerUnderwater then
        return
    end

    -- https://mwse.github.io/MWSE/references/animation-groups/
    -- 0: still
    -- 1: little breeze
    -- 2: large breeze

    -- First, see if ref has attached animation
    local anim = tes3.getAnimationGroups { reference = ref }
    if anim then
        -- Banners/flags that play animation groups change animation state per weather type
        if anim == 0 then
            removeRefSound(soundData.bannerFlaps["light"], ref)
            removeRefSound(soundData.bannerFlaps["strong"], ref)
            return
        elseif anim == 1 then
            removeRefSound(soundData.bannerFlaps["strong"], ref)
            breezeType = "light"
        elseif anim == 2 then
            removeRefSound(soundData.bannerFlaps["light"], ref)
            breezeType = "strong"
        end
    else
        local ac = modules.getTempDataEntry("ac", ref, moduleName)
        if ac == true then
            breezeType = "light"
        elseif ac == false then
            return
            -- If ref has no attached animation, see if its mesh has an animation controller
            -- i.e.: the large banners around Vivec cantons don't play animation groups,
            -- their meshes are animated by default via animation controllers
        elseif ref.sceneNode and ref.sceneNode.children then
            ac = false
            for node in table.traverse(ref.sceneNode.children) do
                if node:isInstanceOfType(ni.type.NiBSAnimationNode) and node.controller then
                    breezeType = "light"
                    ac = true
                    break
                end
            end
            -- Mark ref as scanned for an animation controller
            modules.setTempDataEntry("ac", ac, ref, moduleName)
        end
    end

    if not breezeType then return end

    local sound = soundData.bannerFlaps[breezeType]

    if sound and not playing(sound, ref) then
        debugLog(string.format("[%s] Adding sound %s for -> %s", moduleName, sound.id, tostring(ref)))
        playImmediate(moduleName, sound, ref)
    end
end




local function onInsideShelter()
    if config.playRainInsideShelter then playShelterRain() end
    if config.playWindInsideShelter then playShelterWind() end
    if config.shelterWeather then adjustWeatherLoopVolume() end
end

local function onExitedShelter()
    remove("shelterRain")
    remove("shelterWind")
    adjustWeatherLoopVolume()
end

local function onShelterDeactivated()
    removeImmediate("shelterRain")
    removeImmediate("shelterWind")
    restoreWeatherLoopVolume()
end

local function onConditionsNotMet()
    removeRainOnStatics()
    -- Not needed as removeRainOnStatics already clears the sound on relevant refs
    -- This call is buggy with interiorWeather on since it tries to remove the same sounds on all refs
    -- onShelterDeactivated()
end

local function isSafeRef(ref)
    -- We are interested in both statics and activators. Skipping location
    -- markers because they are invisible in-game. Also checking if
    -- the ref is deleted because even if they are, they get caught by
    -- cell:iterateReferences. As for ref.disabled, some mods disable
    -- instead of delete refs, but it's actually useful if used correctly.
    -- Gotta be extra careful not to call this function when a ref is
    -- deactivated, because its "disabled" property will be true.
    -- Also skipping refs with no implicit tempData tables because they're
    -- most likely not interesting to us. A location marker is one of them.

    return ref and ref.object
        and ((ref.object.objectType == tes3.objectType.static) or
            ((ref.object.objectType == tes3.objectType.activator)))
        and (not ref.object.isLocationMarker)
        and (not (ref.deleted or ref.disabled))
        and (ref.tempData)
end

-- Cheking to see whether this static should be processed by any of our modules --
local function isRelevantForModule(moduleName, ref)
    local data = staticsData.modules[moduleName]

    if common.getMatch(data.blocked, ref.object.id:lower()) then
        debugLog(string.format("[%s] Skipping blocked static: %s", moduleName, tostring(ref)))
        return false
    end
    if common.getMatch(data.ids, ref.object.id:lower()) then
        return true
    end

    return false
end

local function addToCache(ref)
    if common.cellIsInterior(ref.cell) or not isSafeRef(ref) then return end

    local relevantModule

    for moduleName in pairs(staticsData.modules) do
        if modules.isActive(moduleName) and isRelevantForModule(moduleName, ref) then
            relevantModule = moduleName
            break
        end
    end

    if not relevantModule then return end

    if not table.find(staticsCache, ref) then
        -- Resetting the timer on every cache insert to kind of block it
        -- from running while the cache is being populated. Placing this
        -- here and not at the top of the function body should avoid edge
        -- case where mainTimer is indefinitely being reset if some ref
        -- somewhere is constantly being (de)activated.
        if mainTimer then mainTimer:reset() end

        table.insert(staticsCache, ref)
        debugLog("Added static " .. tostring(ref) .. " to cache. staticsCache: " .. #staticsCache)
    else
        --debugLog("Already in cache: " .. tostring(ref))
    end
end

local function removeFromCache(ref)
    if (#staticsCache == 0) then return end

    local index = table.find(staticsCache, ref)
    if not index then return end

    if mainTimer then mainTimer:reset() end

    removeRainOnStatics(ref)
    table.remove(staticsCache, index)

    if (currentShelter.ref)
        and (currentShelter.ref == ref) then
        debugLog("Current shelter deactivated.")
        onShelterDeactivated()
        currentShelter.ref = nil
    end

    debugLog("Removed static " .. tostring(ref) .. " from cache. staticsCache: " .. #staticsCache)
end

local function proximityCheck(ref)
    local playerPos = tes3.player.position:copy()
    local refPos = ref.position:copy()
    local objId = ref.object.id:lower()
    local isShelter = common.getMatch(shelterStatics, objId)
    local playerRef = tes3.player

    ------------------------ Shelter stuff --------------------------
    if (not currentShelter.ref)
        and (isShelter)
        and (playerPos:distance(refPos) < 280)
        and (common.isRefSheltered { targetRef = ref }) then
        debugLog("Player entered shelter.")
        currentShelter.ref = ref
        onInsideShelter()
        return
    end

    if (currentShelter.ref == ref)
        and (not common.isRefSheltered { originRef = playerRef, targetRef = ref }) then
        debugLog("Player exited shelter.")
        currentShelter.ref = nil
        onExitedShelter()
        return
    end
    -----------------------------------------------------------------

    ---------------------- Point of no return -----------------------

    if currentShelter.ref == ref then
        onInsideShelter()
    end

    ------------------------- Rainy statics -------------------------
    if modules.isActive("rainOnStatics") and raining
        and common.getMatch(rainyStatics, objId)
        and not currentShelter.ref
        and (playerPos:distance(refPos) < 800) then
        rainOnStaticsBlocked = false
        playRainOnStatic(ref)
    end
    -----------------------------------------------------------------

    --------------------------- Bridges -----------------------------
    if modules.isActive("ropeBridge")
        and common.getMatch(bridgeStatics, objId)
        and playerPos:distance(refPos) < 800 then
        playRopeBridge(ref)
    end
    --------------------------- Insects -----------------------------
    if modules.isActive("photodragons")
        and common.getMatch(staticsData.modules["photodragons"].ids, objId)
        and playerPos:distance(refPos) < 700 then
        playPhotodragons(ref)
    end
    --------------------------- Banners -----------------------------
    if modules.isActive("bannerFlap")
        and common.getMatch(staticsData.modules["bannerFlap"].ids, objId)
        and playerPos:distance(refPos) < 700 then
        playBannerFlap(ref)
    end
    -----------------------------------------------------------------
    --                            etc                              --
    -----------------------------------------------------------------
end


local function conditionsAreMet()
    return cellData.cell and cellData.cell.isOrBehavesAsExterior
end

local function tick()
    for moduleName in pairs(staticsData.modules) do
        if fader.isRunning { module = moduleName } then
            debugLog(string.format("Fader is running for module %s. Returning.", moduleName))
            return
        end
    end
    if conditionsAreMet() then
        playingBlocked = false
        raining = common.getRainLoopSoundPlaying()

        for _, ref in ipairs(staticsCache) do proximityCheck(ref) end

        if not raining and not rainOnStaticsBlocked then
            removeRainOnStatics()
            rainOnStaticsBlocked = true
        end
    elseif (not playingBlocked) then
        debugLog("Conditions not met. Removing statics sounds.")
        onConditionsNotMet()
        playingBlocked = true
        runResetter() -- Clear everything when not outside
    end
end

local function onReferenceActivated(e)
    addToCache(e.reference)
end

local function onReferenceDeactivated(e)
    removeFromCache(e.reference)
end

local function registerActivationEvents()
    event.register(tes3.event.referenceActivated, onReferenceActivated)
    event.register(tes3.event.referenceDeactivated, onReferenceDeactivated)
end

local function unregisterActivationEvents()
    event.unregister(tes3.event.referenceActivated, onReferenceActivated)
    event.unregister(tes3.event.referenceDeactivated, onReferenceDeactivated)
end

-- Unmodified references will not trigger `referenceActivated`
-- when loading a save that's in the same cell as the player
local function refreshCache()
    if mainTimer then mainTimer:pause() end
    local activeCells = tes3.getActiveCells()
    for cell in tes3.iterate(activeCells) do
        if cell.isOrBehavesAsExterior then
            for ref in cell:iterateReferences() do
                addToCache(ref)
            end
        end
    end
    debugLog("staticsCache currently holds " .. #staticsCache .. " statics.")
    if mainTimer then mainTimer:reset() end
end

local function onLoaded()
    unregisterActivationEvents()
    runResetter()
    refreshCache()
    registerActivationEvents()
    debugLog("Starting timer.")
    if mainTimer then
        mainTimer:reset()
    else
        mainTimer = timer.start {
            type = timer.simulate,
            duration = INTERVAL,
            iterations = -1,
            callback = tick,
        }
    end
end


event.register(tes3.event.load, runResetter)

-- Make sure rainSounds.lua does its thing first, so lower priority here
event.register(tes3.event.loaded, onLoaded, { priority = -250 })
