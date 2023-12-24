local this = {}

-- Imports
local common = require("tew.AURA.common")
local soundData = require("tew.AURA.soundData")

-- Load logger
local debugLog = common.debugLog

-- Load or create soundstate
local manifest
local fileAddedToManifest, fileRemovedFromManifest = false, false

-- Paths shortcuts
local manifestPath = "mods\\tew\\AURA\\manifest"
local AURAdir = "Data Files\\Sound\\tew\\A"
local soundDir = "tew\\A"
local climDir = "\\C\\"
local comDir = "\\S\\"
local popDir = "\\P\\"
local interiorDir = "I"
local intToExtDir = "IE"
local wDir = "\\W\\"
local quietDir = "q"
local warmDir = "w"
local coldDir = "c"

local config = require("tew.AURA.config")
local messages = require(config.language).messages


-- Create sound objects against manifest file
local function createSound(objectId, filename, soundTable, i)
	debugLog("File id: " .. objectId)
	debugLog("Filename: " .. filename)

	local timestamp = lfs.attributes("Data Files\\Sound\\" .. filename, "modification")
	local fileUnmodified = (manifest[objectId] == timestamp)

	local sound = tes3.createObject {
		id = objectId,
		objectType = tes3.objectType.sound,
		filename = filename,
		getIfExists = fileUnmodified,
	}

	if soundTable then
		table.insert(soundTable, i or #soundTable + 1, sound)
	end

	manifest[objectId] = timestamp

	if fileUnmodified then
		debugLog(filename .. " unmodified.\n---------------")
	else
		if (not fileAddedToManifest) then fileAddedToManifest = true end
		debugLog(filename .. " modified. Refreshing object.\n---------------")
	end

	return sound
end

----- Building tables -----

-- General climate/time table --
local function buildClearSounds()
	debugLog("|---------------------- Building clear weather table. ----------------------|\n")
	for climate in lfs.dir(AURAdir .. climDir) do
		if climate ~= ".." and climate ~= "." then
			soundData.clear[climate] = {}
			for time in lfs.dir(AURAdir .. climDir .. climate) do
				if time ~= ".." and time ~= "." then
					soundData.clear[climate][time] = {}
					for soundfile in lfs.dir(AURAdir .. climDir .. climate .. "\\" .. time) do
						if soundfile ~= ".." and soundfile ~= "." then
							if string.endswith(soundfile, ".wav") then
								local objectId = string.sub(climate .. "_" .. time .. "_" .. soundfile, 1, -5)
								local filename = soundDir .. climDir .. climate .. "\\" .. time .. "\\" .. soundfile
								createSound(objectId, filename, soundData.clear[climate][time])
							end
						end
					end
				end
			end
		end
	end
end

-- Weather-specific --
local function buildContextSounds(dir, array)
	debugLog("|---------------------- Building '" .. dir .. "' weather table. ----------------------|\n")
	for soundfile in lfs.dir(AURAdir .. comDir .. dir) do
		if string.endswith(soundfile, ".wav") then
			local objectId = string.sub("S_" .. dir .. "_" .. soundfile, 1, -5)
			local filename = soundDir .. comDir .. "\\" .. dir .. "\\" .. soundfile
			createSound(objectId, filename, array)
		end
	end
end

-- Populated --
local function buildPopulatedSounds()
	debugLog("|---------------------- Building populated sounds table. ----------------------|\n")
	for populatedType, _ in pairs(soundData.populated) do
		for soundfile in lfs.dir(AURAdir .. popDir .. populatedType) do
			if soundfile and soundfile ~= ".." and soundfile ~= "." and string.endswith(soundfile, ".wav") then
				local objectId = string.sub("P_" .. populatedType .. "_" .. soundfile, 1, -5)
				local filename = soundDir .. popDir .. populatedType .. "\\" .. soundfile
				createSound(objectId, filename, soundData.populated[populatedType])
			end
		end
	end
end

-- Interior + Interior-to-Exterior --
local function buildInteriorSounds()
	local function buildSoundDataTable(parentDir, soundDataTable)
		for interiorType, subTable in pairs(soundDataTable) do
			if not table.empty(subTable) then
				local subDir = parentDir .. "\\" .. interiorType
				buildSoundDataTable(subDir, subTable)
			else
				local path = ("%s\\%s\\%s"):format(AURAdir, parentDir, interiorType)
				for soundfile in lfs.dir(path) do
					if soundfile and soundfile ~= ".." and soundfile ~= "." and string.endswith(soundfile, ".wav") then
						local objectId = ("%s_%s_%s"):format(parentDir:gsub("\\", "_"), interiorType,
							soundfile:gsub(".wav", ""))
						local filename = ("%s\\%s\\%s\\%s"):format(soundDir, parentDir, interiorType, soundfile)
						createSound(objectId, filename, soundDataTable[interiorType])
					end
				end
			end
		end
	end
	debugLog("|---------------------- Building interior sounds table. ----------------------|\n")
	buildSoundDataTable(interiorDir, soundData.interior)
	debugLog("|---------------------- Building interiorToExterior sounds table. ----------------------|\n")
	buildSoundDataTable(intToExtDir, soundData.interiorToExterior)
end

local function buildWeatherSounds()
	debugLog("|---------------------- Building interior weather sounds. ----------------------|\n")

	local filename, objectId

	filename = soundDir .. wDir .. "\\big\\rl.wav"
	objectId = "tew_b_rainlight"
	soundData.interiorRainLoops["big"]["light"] = createSound(objectId, filename, soundData.weatherLoops)

	filename = soundDir .. wDir .. "\\big\\rm.wav"
	objectId = "tew_b_rainmedium"
	soundData.interiorRainLoops["big"]["medium"] = createSound(objectId, filename, soundData.weatherLoops)
	createSound(objectId, filename, soundData.interiorWeather["big"], 4)
	createSound(objectId, filename, soundData.interiorWeather["big"], 5)

	filename = soundDir .. wDir .. "\\big\\rh.wav"
	objectId = "tew_b_rainheavy"
	soundData.interiorRainLoops["big"]["heavy"] = createSound(objectId, filename, soundData.weatherLoops)

	filename = soundDir .. wDir .. "\\sma\\rl.wav"
	objectId = "tew_s_rainlight"
	soundData.interiorRainLoops["sma"]["light"] = createSound(objectId, filename, soundData.weatherLoops)

	filename = soundDir .. wDir .. "\\sma\\rm.wav"
	objectId = "tew_s_rainmedium"
	soundData.interiorRainLoops["sma"]["medium"] = createSound(objectId, filename, soundData.weatherLoops)
	createSound(objectId, filename, soundData.interiorWeather["sma"], 4)
	createSound(objectId, filename, soundData.interiorWeather["sma"], 5)

	filename = soundDir .. wDir .. "\\sma\\rh.wav"
	objectId = "tew_s_rainheavy"
	soundData.interiorRainLoops["sma"]["heavy"] = createSound(objectId, filename, soundData.weatherLoops)

	filename = soundDir .. wDir .. "\\ten\\rl.wav"
	objectId = "tew_t_rainlight"
	soundData.interiorRainLoops["ten"]["light"] = createSound(objectId, filename, soundData.weatherLoops)

	filename = soundDir .. wDir .. "\\ten\\rm.wav"
	objectId = "tew_t_rainmedium"
	soundData.interiorRainLoops["ten"]["medium"] = createSound(objectId, filename, soundData.weatherLoops)
	createSound(objectId, filename, soundData.interiorWeather["ten"], 4)
	createSound(objectId, filename, soundData.interiorWeather["ten"], 5)

	filename = soundDir .. wDir .. "\\ten\\rh.wav"
	objectId = "tew_t_rainheavy"
	soundData.interiorRainLoops["ten"]["heavy"] = createSound(objectId, filename, soundData.weatherLoops)

	filename, objectId = nil, nil
end

local function buildMisc()
	debugLog("|---------------------- Creating misc sound objects. ----------------------|\n")

	local filename, objectId

	tes3.createObject {
		id = "splash_lrg",
		objectType = tes3.objectType.sound,
		filename = "Fx\\envrn\\splash_lrg.wav",
		getIfExists = true,
	}
	debugLog("Adding misc file: splash_lrg")

	tes3.createObject {
		id = "splash_sml",
		objectType = tes3.objectType.sound,
		filename = "Fx\\envrn\\splash_sml.wav",
		getIfExists = true,
	}
	debugLog("Adding misc file: splash_sml")

	tes3.createObject {
		id = "tew_clap",
		objectType = tes3.objectType.sound,
		filename = "Fx\\envrn\\ent_react04a.wav",
		getIfExists = true,
	}

	tes3.createObject {
		id = "tew_potnpour",
		objectType = tes3.objectType.sound,
		filename = "Fx\\item\\potnpour.wav",
		getIfExists = true,
	}

	tes3.createObject {
		id = "tew_shield",
		objectType = tes3.objectType.sound,
		filename = "Fx\\item\\shield.wav",
		getIfExists = true,
	}

	tes3.createObject {
		id = "tew_blunt",
		objectType = tes3.objectType.sound,
		filename = "Fx\\item\\bluntOut.wav",
		getIfExists = true,
	}

	tes3.createObject {
		id = "tew_longblad",
		objectType = tes3.objectType.sound,
		filename = "Fx\\item\\longblad.wav",
		getIfExists = true,
	}

	tes3.createObject {
		id = "tew_spear",
		objectType = tes3.objectType.sound,
		filename = "Fx\\item\\spear.wav",
		getIfExists = true,
	}

	filename = "tew\\A\\M\\yurtflap.wav"
	objectId = "tew_yurt"
	createSound(objectId, filename)


	filename = "tew\\A\\M\\serviceboat.wav"
	objectId = "tew_boat"
	createSound(objectId, filename)

	filename = "tew\\A\\M\\servicegondola.wav"
	objectId = "tew_gondola"
	createSound(objectId, filename)

	filename, objectId = nil, nil
end

local function buildRain()
	debugLog("|---------------------- Creating rain sound objects. ----------------------|\n")

	local filename, objectId

	filename = "tew\\A\\R\\tew_rain_light.wav"
	objectId = "tew_rain_light"
	soundData.rainLoops["Rain"]["light"] = createSound(objectId, filename, soundData.weatherLoops)

	filename = "tew\\A\\R\\tew_rain_medium.wav"
	objectId = "tew_rain_medium"
	soundData.rainLoops["Rain"]["medium"] = createSound(objectId, filename, soundData.weatherLoops)

	filename = "tew\\A\\R\\tew_rain_heavy.wav"
	objectId = "tew_rain_heavy"
	soundData.rainLoops["Rain"]["heavy"] = createSound(objectId, filename, soundData.weatherLoops)

	filename = "tew\\A\\R\\tew_thunder_light.wav"
	objectId = "tew_thunder_light"
	soundData.rainLoops["Thunderstorm"]["light"] = createSound(objectId, filename, soundData.weatherLoops)

	filename = "tew\\A\\R\\tew_thunder_medium.wav"
	objectId = "tew_thunder_medium"
	soundData.rainLoops["Thunderstorm"]["medium"] = createSound(objectId, filename, soundData.weatherLoops)

	filename = "tew\\A\\R\\tew_thunder_heavy.wav"
	objectId = "tew_thunder_heavy"
	soundData.rainLoops["Thunderstorm"]["heavy"] = createSound(objectId, filename, soundData.weatherLoops)

	filename, objectId = nil, nil
end

local function buildThunders()
	debugLog("|---------------------- Creating thunder sound objects. ----------------------|\n")
	for soundfile in lfs.dir(AURAdir .. "\\T") do
		if string.endswith(soundfile, ".wav") then
			local objectId = "tew_thndr" .. soundfile:gsub(".wav", "")
			local filename = soundDir .. "\\T\\" .. soundfile
			createSound(objectId, filename, soundData.thunders)
		end
	end
end

local function buildStaticsSounds()
	debugLog("|---------------------- Creating statics sound objects. ----------------------|\n")
	createSound("tew_tentwind", "tew\\A\\ST\\tentwind.wav")
	createSound("tew_ropebridge", "tew\\A\\ST\\ropebridge.wav")
	createSound("tew_photodragons", "tew\\A\\ST\\photodragons.wav")
	soundData.bannerFlaps["light"] = createSound("tew_banner_light", "tew\\A\\ST\\bannerlight.wav")
	soundData.bannerFlaps["strong"] = createSound("tew_banner_strong", "tew\\A\\ST\\bannerstrong.wav")
	for soundfile in lfs.dir(AURAdir .. "\\ST\\flo") do
		if string.endswith(soundfile, ".wav") then
			local objectId = "tew_flora" .. soundfile:gsub(".wav", "")
			local filename = soundDir .. "\\ST\\flo\\" .. soundfile
			createSound(objectId, filename, soundData.flora)
		end
	end
end

function this.flushManifestFile()
	tes3.messageBox({
		message = messages.manifestConfirm,
		buttons = { tes3.findGMST(tes3.gmst.sYes).value, tes3.findGMST(tes3.gmst.sNo).value },
		callback = function(e)
			if (e.button == 0) then
				local empty = {}
				json.savefile(manifestPath, empty)
				local message = messages.manifestRemoved
				debugLog(message)
				tes3.messageBox({ message = message })
			end
		end,
	})
end

local function getWeatherSounds()
	local ashSound = tes3.getSound("ashstorm")
	local blightSound = tes3.getSound("Blight")
	local blizzardSound = tes3.getSound("BM Blizzard")
	local rainSound = tes3.getSound("Rain")
	local thunderSound = tes3.getSound("rain heavy")

	for type in pairs(soundData.interiorWeather) do
		table.insert(soundData.interiorWeather[type], 6, ashSound)
		table.insert(soundData.interiorWeather[type], 7, blightSound)
		table.insert(soundData.interiorWeather[type], 9, blizzardSound)
	end

	table.insert(soundData.weatherLoops, rainSound)
	table.insert(soundData.weatherLoops, thunderSound)
	table.insert(soundData.weatherLoops, ashSound)
	table.insert(soundData.weatherLoops, blightSound)
	table.insert(soundData.weatherLoops, blizzardSound)
end

local function checkForRemovedFiles()
	local removedSounds = {}
	for k, _ in pairs(manifest) do
		if not tes3.getSound(k) then
			table.insert(removedSounds, k)
		end
	end

	if #removedSounds > 0 then
		fileRemovedFromManifest = true
		for _, v in ipairs(removedSounds) do
			debugLog(v .. " removed from manifest.")
			manifest[v] = nil
		end
	end
end

function this.build()
	--event.register("loaded", getWeatherSounds) -- Needed to do after initialisation, errors out otherwise
	getWeatherSounds()

	manifest = json.loadfile(manifestPath) or {}

	buildClearSounds()
	buildContextSounds(quietDir, soundData.quiet)
	buildContextSounds(warmDir, soundData.warm)
	buildContextSounds(coldDir, soundData.cold)
	buildPopulatedSounds()
	buildInteriorSounds()
	buildWeatherSounds()
	buildMisc()
	buildRain()
	buildThunders()
	buildStaticsSounds()

	checkForRemovedFiles()
	-- Write manifest file if it was modified
	if fileRemovedFromManifest or fileAddedToManifest then
		json.savefile(manifestPath, manifest)
		debugLog("Manifest file updated.")
	else
		debugLog("Manifest file unchanged.")
	end
	manifest = nil
end

return this
