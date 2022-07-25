--[[
    https://github.com/Meowlala/DeadSeaScrollsMenu

    thanks to jerb for the reference code (from antibirth announcer)
]]
local DSSModName = 'Dead Sea Scrolls (Blackjack Dealer)'

local DSSCoreVersion = 4

local MenuProvider = {}

function MenuProvider.SaveSaveData()
    BDMod.saveModData()
end

function MenuProvider.GetPaletteSetting()
    return BDMod.loadModData().MenuPalette
end

function MenuProvider.SavePaletteSetting(var)
    BDMod.loadModData().MenuPalette = var
end

function MenuProvider.GetHudOffsetSetting()
    if not REPENTANCE then
        return BDMod.loadModData().HudOffset
    else
        return Options.HUDOffset * 10
    end
end

function MenuProvider.SaveHudOffsetSetting(var)
    if not REPENTANCE then
        BDMod.loadModData().HudOffset = var
    end
end

function MenuProvider.GetGamepadToggleSetting()
    return BDMod.loadModData().GamepadToggle
end

function MenuProvider.SaveGamepadToggleSetting(var)
    BDMod.loadModData().GamepadToggle = var
end

function MenuProvider.GetMenuKeybindSetting()
    return BDMod.loadModData().MenuKeybind
end

function MenuProvider.SaveMenuKeybindSetting(var)
    BDMod.loadModData().MenuKeybind = var
end

function MenuProvider.GetMenusNotified()
    return BDMod.loadModData().MenusNotified
end

function MenuProvider.SaveMenusNotified(var)
    BDMod.loadModData().MenusNotified = var
end

function MenuProvider.GetMenusPoppedUp()
    return BDMod.loadModData().MenusPoppedUp
end

function MenuProvider.SaveMenusPoppedUp(var)
    BDMod.loadModData().MenusPoppedUp = var
end

local DSSInitializerFunction = include('bd_scripts.dssmenucore')
local dssmod = DSSInitializerFunction(DSSModName, DSSCoreVersion, MenuProvider)

local bdirectory = {
    main = {
    title = 'blackjack dealer',
        buttons = {
            {str = 'resume game', action = 'resume'},
            {str = 'settings', dest = 'settings'},
        },
        tooltip = dssmod.menuOpenToolTip
    },
    settings = {
        title = 'settings',
        buttons = {
            dssmod.gamepadToggleButton,
            dssmod.menuKeybindButton,
            dssmod.paletteButton,
            {
                str = 'arcade spawn %',
                suf = '%',
                increment = 1,
                max = 100,
                variable = 'bdSpawnChance',
                setting = 50,
                load = function()
                    return BDMod.savedata.bdSpawnChance
                end,
                store = function(var)
                    BDMod.savedata.bdSpawnChance = var
                end,
                tooltip = {strset = {'how often', 'should', 'the dealer', 'spawn', 'in arcades?'}}
            },
            {
                str = 'general spawn %',
                suf = '%',
                increment = 1,
                max = 100,
                variable = 'generalSpawnChance',
                setting = 0,
                load = function()
                    return BDMod.savedata.generalSpawnChance
                end,
                store = function(var)
                    BDMod.savedata.generalSpawnChance = var
                end,
                tooltip = {strset = {'how often', 'should', 'the dealer', 'spawn', 'outside', 'arcades?'}}
            },
            {
                str = 'must hit until',
                choices = {'always stand', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', 'always hit'},
                variable = 'dealerHitMax',
                increment = 1,
                min = 1,
                max = 20,
                setting = 17,
                load = function()
                    return BDMod.savedata.dealerHitMax
                end,
                store = function(var)
                    BDMod.savedata.dealerHitMax = tonumber(var)
                end,
                tooltip = {strset = {'at what', 'total amount', 'should', 'the dealer', 'stop', 'hitting?'}}
            },
            {
                str = 'card amount',
                choices = {'hidden', 'shown'},
                variable = 'displayCardAmt',
                setting = 1,
                load = function()
                    return BDMod.savedata.displayCardAmt and 2 or 1
                end,
                store = function(var)
                    BDMod.savedata.displayCardAmt = var == 2
                end,
                tooltip = {strset = {'should', 'the amount', 'of remaining', 'cards', 'in the deck', 'be shown?'}}
            },
        }
    }
}

local bdirectorykey = {
    Item = bdirectory.main,
    Main = 'main',
    Idle = false,
    MaskAlpha = 1,
    Settings = {},
    SettingsChanged = false,
    Path = {},
}

DeadSeaScrollsMenu.AddMenu('Blackjack Dealer', {Run = dssmod.runMenu, Open = dssmod.openMenu, Close = dssmod.closeMenu, Directory = bdirectory, DirectoryKey = bdirectorykey})