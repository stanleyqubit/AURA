return {
    moduleAmbientOutdoor = true,
    moduleAmbientInterior = true,
    moduleAmbientPopulated = true,
    moduleInteriorWeather = true,
    moduleServiceVoices = true,
    moduleUI = true,
    moduleContainers = true,
    moduleMisc = true,
    modulePC = true,
    playSplash = true,
    playInteriorAmbient = true,
    playInteriorWeather = true,
    playYurtFlap = true,
    debugLogOn = false,
    volumeSave = {keyCode = tes3.scanCode.v},
    tauntChance = 30,
    serviceChance = 100,
    serviceTravel = true,
    serviceRepair = true,
    serviceSpells = true,
    serviceTraining = true,
    serviceSpellmaking = true,
    serviceEnchantment = true,
    serviceBarter = true,
    UIEating = true,
    UISpells = true,
    UITravel = true,
    UITraining = true,
    UIBarter = true,
    pcVitalSigns = true,
    PChealth = true,
    PCfatigue = true,
    PCmagicka = true,
    PCDisease = true,
    PCBlight = true,
    PCtaunts = false,
    interiorMusic = false,
    windSounds = true,
    rainSounds = true,
    thunderSounds = true,
    thunderSoundsDelay = true,
    disabledTaverns = {},
    volumes = {
        modules = {
            ["outdoor"] = {volume = 55, big = 0.25, sma = 0.2, und = 0.4},
            ["populated"] = {volume = 50, big = 1, sma = 1, und = 0.3},
            ["interior"] = {volume = 60, big = 1, sma = 1, und = 0.5},
            ["interiorWeather"] = {volume = 65, big = 1, sma = 1, und = 0.3},
            ["wind"] = {volume = 65, big = 0.4, sma = 0.4, und = 0.3},
            ["rainOnStatics"] = {volume = 100, big = 1, sma = 1, und = 0},
        },
        rain = {
            ["Rain"] = {light = 100, medium = 100, heavy = 100},
            ["Thunderstorm"] = {light = 100, medium = 100, heavy = 100},
        },
        extremeWeather = {
            -- Vanilla sound object volumes for extreme weather is 0.5
            -- Defaults here should be kept at 50 in case replacers aren't used
            ["Ashstorm"] = 50,
            ["Blight"] = 50,
            ["Blizzard"] = 50,
        },
        misc = {
            yurtVol = 100,
            splashVol = 100,
            UIvol = 75,
            SVvol = 100,
            Cvol = 75,
            vsVol = 70,
            tVol = 75,
            thunderVolMin = 70,
            thunderVolMax = 100,
        },
    },
    playInteriorWind = true,
    playRainOnStatics = true,
    underwaterRain = true,
    language = "tew.AURA.i18n.en",
}
