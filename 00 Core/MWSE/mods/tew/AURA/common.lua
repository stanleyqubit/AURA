local this = {}

local config = require("tew.AURA.config")
local debugLogOn = config.debugLogOn
local metadata = toml.loadMetadata("AURA")
local version = metadata.package.version

-- Centralised debug message printer --
function this.debugLog(message)
	if debugLogOn then
		local info = debug.getinfo(2, "Sl")
		local module = info.short_src:match("^.+\\(.+).lua$")
		local prepend = ("[%s.%s.%s:%s]:"):format(metadata.package.name, version, module, info.currentline)
		local aligned = ("%-36s"):format(prepend)
		mwse.log(aligned .. " -- " .. string.format("%s", message))
	end
end

-- Thunder sound IDs (as seen in the CS) --
this.thunArray = {
	"Thunder0",
	"Thunder1",
	"Thunder2",
	"Thunder3",
	"ThunderClap"
}

-- Small types of interiors --
this.cellTypesSmall = {
	"in_de_shack_",
	"s12_v_plaza",
	"rp_v_arena",
	"in_nord_house_04",
	"in_nord_house_02",
	"t_rea_set_i_house_",
	--"ab_in_ashlstriderhovel", -- Hmm...
}

-- Tent interiors --
this.cellTypesTent = {
	"in_ashl_tent_0",
	"drs_tnt",
	"_in_drs_tnt_0",
	"a1_dat_srt_in_0", -- Sea Rover's Tent
	"_ser_tent_in", -- On the move - the ashlander tent deluxe remod
	"t_de_set_i_tent_0", -- Tamriel_Data
	"t_orc_setnomad_i_tent_0", -- Tamriel_Data
	"rpnr_in_ashl_tent_0",
	"rpnr_t_de_set_i_tent_0",
	"rpnr_tent_bannered", -- yup, interior
}

-- String bit to match against window object ids --
this.windows = {
	"winkynaret",
	"_win_",
	"window",
	"cwin",
	"wincover",
	"swin",
	"palacewin",
	"triwin",
	"_windowin_"
}

local defaultModData = {
    visitedInteriorCells = {}
}

--- This function will recursively set all the fields on our
--- tes3.player.data table if they don't exist already
---@param data table
---@param t table
local function initTableValues(data, t)
    for k, v in pairs(t) do
        -- If a field already exists - we initialized the data
        -- table for this character before. Don't do anything.
        if data[k] == nil then
            if type(v) ~= "table" then
                data[k] = v
            elseif v == {} then
                data[k] = {}
            else
                -- Fill out the sub-tables
                data[k] = {}
                initTableValues(data[k], v)
            end
        end
    end
end

function this.initModData()
    local data = tes3.player.data
    data.AURA = data.AURA or {}
    local modData = data.AURA
    initTableValues(modData, defaultModData)
end

-- Check if transitioning int/ext or the other way around --
function this.checkCellDiff(cell, cellLast)
	if (cellLast == nil) then return true end

	if (cell.isInterior) and (cellLast.isOrBehavesAsExterior)
		or (cell.isOrBehavesAsExterior) and (cellLast.isInterior) then
		return true
	end

	return false
end

-- Pass me the cell and cell type array and I'll tell you if it matches --
function this.getCellType(cell, celltype)
	if not cell.isInterior then
		return false
	end
	for stat in cell:iterateReferences(tes3.objectType.static) do
		for _, pattern in pairs(celltype) do
			if string.startswith(stat.object.id:lower(), pattern) then
				return true
			end
		end
	end
end

-- Return doors and windows objects --
function this.getWindoors(cell)
	local windoors = {}
	for door in cell:iterateReferences(tes3.objectType.door) do
		if door.destination then
			if (door.destination.cell.isOrBehavesAsExterior)
			and not (this.isOpenPlaza(cell))
			and door.tempData then
				table.insert(windoors, door)
			end
		end
	end

	if table.empty(windoors) then
		return windoors
	else
		for stat in cell:iterateReferences(tes3.objectType.static) do
			if (not string.find(cell.name:lower(), "plaza")) then
				for _, window in pairs(this.windows) do
					if string.find(stat.object.id:lower(), window) and stat.tempData then
						table.insert(windoors, stat)
					end
				end
			end
		end

		-- Let's sort to ensure we scan the closest one first for the useLast flag further down the line
		local playerPos = tes3.player.position:copy()
		table.sort(windoors, function(a, b) return playerPos:distance(a.position:copy()) < playerPos:distance(b.position:copy()) end)

		return windoors
	end
end

-- Emulates a set of unique elements. This function adds a new element to the set. --
function this.setInsert(tab, elem)
	if not table.find(tab, elem) then
		table.insert(tab, elem)
	end
end

-- Emulates a set of unique elements. This function removes an existing element from the set. --
function this.setRemove(tab, elem)
	local index = table.find(tab, elem)
	if index then
		table.remove(tab, index)
	end
end

function this.getMatch(stringArray, str)
	for _, pattern in pairs(stringArray) do
		if string.find(str, pattern) then
			return pattern
		end
	end
end

function this.isTimerAlive(t)
    return t and t.state and (t.state < 2) or false
end

function this.cellIsInterior(cell)
    local c = cell or tes3.getPlayerCell()
	return (c and not c.isOrBehavesAsExterior)
end

function this.getInteriorType(cell)
    if this.getCellType(cell, this.cellTypesSmall) == true then
		return "sma"
	elseif this.getCellType(cell, this.cellTypesTent) == true then
		return "ten"
	else
		return "big"
	end
end

function this.getActorCount(cell)
    local count = 0
    if not cell then return count end
    for npc in cell:iterateReferences(tes3.objectType.npc) do
        local mobileObject = npc.object.mobile
        if (mobileObject) and (not mobileObject.isDead) then
            count = count + 1
        end
    end
    return count
end

function this.getTrackPlaying(track, ref)
	if track and ref and tes3.getSoundPlaying{sound = track, reference = ref} then
		return track
	end
end

-- If given a target ref, returns true if origin ref is sheltered by
-- target ref, or false otherwise. If not given a target ref, returns
-- whether origin ref is sheltered at all.
function this.isRefSheltered(options)

    local quiet = options.quiet
    local originRef = options.originRef or tes3.player
	local targetRef = options.targetRef
	local ignoreList = options.ignoreList
	local useModelCoordinates
	local useBackTriangles
	local maxDistance
	local cell = options.cell

    if this.cellIsInterior(cell) then
        return true
    end

    local function log(message)
        if quiet then return end
        this.debugLog(message)
    end

	local height = originRef.object.boundingBox
	and originRef.object.boundingBox.max.z or 0

	-- It seems that rayTest returns more accurate results for
	-- tes3.player if using back triangles and better results for
	-- statics when using model coordinates.

	if originRef == tes3.player then
		useModelCoordinates = false
		useBackTriangles = true
		-- Max distance from the player going upwards at which
		-- the ray should stop when testing for a shelter static.
		-- This value could use some more fine-tuning but finding
		-- a goldylocks value for every possible scenario and 3D model
		-- can be rather difficult (if not impossible).
		maxDistance = 300
	else
		useModelCoordinates = true
		useBackTriangles = false
		maxDistance = 500
	end

	log("[rayTest] Performing test on origin ref: " .. tostring(originRef))

    local hitResults = tes3.rayTest{
        position = {
            originRef.position.x,
            originRef.position.y,
            originRef.position.z + (height/2)
        },
        direction = {0, 0, 1},
        findAll = true,
        maxDistance = maxDistance,
        ignore = {originRef},
		useModelCoordinates = useModelCoordinates,
        useBackTriangles = useBackTriangles,
    }
    if hitResults then
		log("[rayTest] Got results.")
        for _, hit in ipairs(hitResults) do
            if hit and hit.reference and hit.reference.object then
				if (hit.reference.object.objectType == tes3.objectType.static)
				or (hit.reference.object.objectType == tes3.objectType.activator) then
					if ignoreList and this.getMatch(ignoreList, hit.reference.object.id:lower()) then
						log("[rayTest] Ignoring result -> " .. hit.reference.object.id:lower())
						goto continue
					end
					if targetRef then
						if (hit.reference.object.id:lower() == targetRef.object.id:lower()) then
							log("[rayTest] Matched target ref -> " .. tostring(targetRef))
							return true
						else
							log("[rayTest] Did not match target ref -> " .. tostring(targetRef))
							return false
						end
					end
					log("[rayTest] Ref " .. tostring(originRef) .. " is sheltered by " .. hit.reference.object.id:lower())
					return true
				end
            end
			:: continue ::
        end
    end
	log("[rayTest] Ref " .. tostring(originRef) .. " is NOT sheltered.")
	return false
end

function this.getCurrentWeather()
    return tes3.worldController.weatherController.currentWeather
end

function this.getRainLoopSoundPlaying()
    local cw = this.getCurrentWeather()
    if cw and cw.rainLoopSound and cw.rainLoopSound:isPlaying() then
        return cw.rainLoopSound
    end
end

function this.getExtremeWeatherTrackPlaying()
    local cw = this.getCurrentWeather()
    local track
    if (cw) and (cw.index == 6 or cw.index == 7 or cw.index == 9) then
        if cw.name == "Ashstorm" then
            track = tes3.getSound("Ashstorm")
        elseif cw.name == "Blight" then
            track = tes3.getSound("Blight")
        elseif cw.name == "Blizzard" then
            track = tes3.getSound("BM Blizzard")
        end
        if track and track:isPlaying() then return track end
    end
end

function this.getWeatherTrack()
    return this.getRainLoopSoundPlaying() or this.getExtremeWeatherTrackPlaying()
end

function this.isOpenPlaza(cell)
    if not cell then return false end
    if not cell.behavesAsExterior then
        return false
    else
        if (string.find(cell.name:lower(), "plaza") and string.find(cell.name:lower(), "vivec"))
        or (string.find(cell.name:lower(), "plaza") and string.find(cell.name:lower(), "molag mar"))
        or (string.find(cell.name:lower(), "arena pit") and string.find(cell.name:lower(), "vivec")) then
            return true
        else
            return false
        end
    end
end

function this.findWholeWords(string, pattern)
    return string.find(string, "%f[%a]"..pattern.."%f[%A]")
end

function this.getFallbackRegion()
	for region in tes3.iterate(tes3.dataHandler.nonDynamicData.regions) do
		if region.id == "Sheogorad" then
			return region
		end
	end
end

function this.getRegion()
    local regionObject = tes3.getRegion(true) or this.getFallbackRegion()
    if not regionObject then this.debugLog("Couldn't fetch region object.") end
    return regionObject
end

return this
