BDMod = RegisterMod("Blackjack Dealer", 1)
local json = require("json")

local hf = require('scripts.helpers')
local bj = require('scripts.blackjack_base')

-- Don't change this unles you want your logs flooded with debug stuff
BDMod.enableLogs = false
BDMod.rng = RNG()
game = Game()

local vz = Vector.Zero
local requiredCoins = 3

BDMod.hands = {
    player = nil,
    dealer = nil
}

BDMod.data = {
    arrowPos = nil,
    controlsDisabledMenu = nil,
    dealerCardRevealed = nil,
    finishGame = nil,
    lockControl = nil,
    winnerGot = nil,
    gameWon = nil,

    dealerHitAmount = nil,
    displayMenu = nil,
    standTime = nil,
    doStand = nil,
    finishTime = nil,
    printDeckInfo = false,
    closeDeckInfoIn = 0,
    hitAmount = nil,
    menuPlayer = nil,

    declareBet = nil,
}

BDMod.deck = {2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14}
--                                         J   Q   K   A                             J   Q   K   A                                 J   Q   K   A                              J   Q   K   A


local entData = {
    flags = EntityFlag.FLAG_NO_TARGET | EntityFlag.FLAG_NO_STATUS_EFFECTS,
    type = Isaac.GetEntityTypeByName("Blackjack Dealer"),
    var = Isaac.GetEntityVariantByName("Blackjack Dealer"),
}

local specialCards = {Card.CARD_CLUBS_2, Card.CARD_DIAMONDS_2, Card.CARD_SPADES_2, Card.CARD_HEARTS_2, Card.CARD_ACE_OF_CLUBS, Card.CARD_ACE_OF_DIAMONDS, Card.CARD_ACE_OF_SPADES, Card.CARD_ACE_OF_HEARTS, Card.CARD_JOKER, Card.CARD_QUEEN_OF_HEARTS} 

-- Mod config menu configurables
local saveData = {
    bdSpawnChance = nil,
}

--- log stuff
local amountGamesPlayed
local amountTimesHit
local amountTimesStood
local amountWins

local initTrueGame

local f = Font()
f:Load("font/Upheaval.fnt")

-- Mod Data
local function saveModData()
    local jsonData = json.encode(saveData)
    BDMod:SaveData(jsonData)
end

local function defaultModData()
    saveData.bdSpawnChance = 50
    saveData.dealerHitMax = 17
    saveData.displayCardAmt = false
    saveData.lockToArcade = true
    saveModData()
end

local function loadModData()
    if BDMod:HasData() then
        local data = json.decode(BDMod:LoadData())

        -- Ensure old data gets fixed
        if data.dealerHitMax == nil then
            defaultModData()
            return
        end

        saveData = data
    else
        defaultModData()
    end
end

loadModData()

local function getBdEnt(player)
    local possibleEnts = Isaac.FindByType(6, 72)
    if #possibleEnts == 0 then
        return nil
    end

    local lowestDistance = 99999
    local nearestEnt = possibleEnts[1]

    for _, ent in ipairs(possibleEnts) do
        local dist = ent.Position:Distance(player.Position)
        if dist < lowestDistance then
            lowestDistance = dist
            nearestEnt = ent
        end
    end

    return nearestEnt
end

-- 1st argument: RNG object, 2 and above: chances (int) |
-- if rng is nil, creates a new rng based on Random()
local function getResultByChance(rng, ...)
    local args = {...}

    -- Validate argument amount
    if #args < 2 then
        error("Less than 2 arguments given!")
    end

    -- Validate argument sum
    local argSum = 0
    for i = 1, #args do
        argSum = argSum + args[i]
    end

    if argSum > 100 then
        error("Argument sum (" .. argSum .. ") is higher than 100!")
    elseif argSum < 100 then
        error("Argument sum (" .. argSum .. ") is lower than 100!")
    end
    -- END VALIDATIONS

    local assignedArgs = {}
    local lastValue = 0
    local highestValue
    for i, _ in ipairs(args) do
        assignedArgs[i] = {low = lastValue, high = args[i] + lastValue, id = i}
        lastValue = assignedArgs[i].high + 1
        if i == #args then
            highestValue = lastValue - 1
        end
    end

    if rng == nil then
        rng = RNG()
        local seed = Random() + 1
        rng:SetSeed(seed, 0)
    end

    local nRng = rng:RandomInt(highestValue + 1)

    local matchedRng = 0
    for i, _ in ipairs(args) do
        if nRng >= assignedArgs[i].low and nRng <= assignedArgs[i].high then
            matchedRng = assignedArgs[i].id
        end
    end

    return matchedRng
end

local paperBg = Sprite()
local arrowSprite = Sprite()

local smallPaperBg = Sprite()
local pennySprite = Sprite()
local nickelSprite = Sprite()

local function initSprite(sprite, path, animation)
    if animation == nil then animation = "main" end
    sprite:Load(path, true)
    sprite:SetAnimation(animation, true)
    sprite:SetFrame(1)
end

function BDMod:OnGameStart(isSave)

    if BDMod then
        hf.bdLog("EVENT | New run started / continued, all values reset!")
    end

    bj.resetGame()
    BDMod.data.gameWon = false

    amountGamesPlayed = 0
    amountTimesHit = 0
    amountTimesStood = 0
    amountWins = 0

    local startseed = game:GetSeeds():GetStartSeed()
    BDMod.rng = RNG()
    BDMod.rng:SetSeed(startseed, 0)

    initSprite(paperBg, "gfx/ui/paperbg.anm2")
    initSprite(arrowSprite, "gfx/ui/arrow.anm2")

    initSprite(smallPaperBg, "gfx/ui/paper_small.anm2")
    initSprite(pennySprite, "gfx/ui/coin.anm2", "penny")
    initSprite(nickelSprite, "gfx/ui/coin.anm2", "nickel")


end
BDMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, BDMod.OnGameStart)

local function endDeclaringBet()
    BDMod.data.declareBet = false
end

local arrowPositions = {
    { -- Top (X)
        -- Right (1) (1, 1) (Y)
        Vector(185, 125),

        -- Left (2) (1, 2) (Y)
        Vector(255, 125),

    },
    { -- Bottom (X)
        -- Right (3) (2, 1) (Y)
        Vector(185, 155),

        -- Left (4) (2, 2) (Y)
        Vector(255, 155),
    }
}

local arrowValues = {
    {
        1,
        3
    },
    {
        5,
        10
    },
}

local betToSpritesheet = {
    [1] = "gfx/ui/penny.png",
    [3] = "gfx/ui/pennies.png",
    [5] = "gfx/ui/nickel.png",
    [10] = "gfx/ui/nickels.png"
}

local function handleChangingArrowPos(cIndex)
    if Input.IsActionTriggered(ButtonAction.ACTION_SHOOTUP, cIndex) then
        if BDMod.data.dbArrowPos.x ~= 2 then return end
        BDMod.data.dbArrowPos.x = 1
    elseif Input.IsActionTriggered(ButtonAction.ACTION_SHOOTDOWN, cIndex) then
        if BDMod.data.dbArrowPos.x ~= 1 then return end
        BDMod.data.dbArrowPos.x = 2
    elseif Input.IsActionTriggered(ButtonAction.ACTION_SHOOTRIGHT, cIndex) then
        if BDMod.data.dbArrowPos.y ~= 1 then return end
        BDMod.data.dbArrowPos.y = 2
    elseif Input.IsActionTriggered(ButtonAction.ACTION_SHOOTLEFT, cIndex) then
        if BDMod.data.dbArrowPos.y ~= 2 then return end
        BDMod.data.dbArrowPos.y = 1
    end
end

local function betRender()
    if BDMod.data.controlsDisabledMenu == nil then -- Handle control enable / disable
        BDMod.data.controlsDisabledMenu = true
        for i=0, game:GetNumPlayers()-1 do
            local player = Isaac.GetPlayer(i)

            player.ControlsEnabled = false
        end
    end

    local cIndex = BDMod.data.menuPlayer.ControllerIndex
    handleChangingArrowPos(cIndex)

    smallPaperBg:Render(Vector(240, 135), vz, vz)
    f:DrawString("Choose bet", 170, 95, KColor(0,0,0,1), 140, true)

    -- Top Left (1c)
    pennySprite:Render(Vector(200, 125))

    -- Top Right (3c)
    pennySprite:Render(Vector(270, 125))
    pennySprite:Render(Vector(276, 125))
    pennySprite:Render(Vector(282, 125))

    -- Bottom Left (5c)
    nickelSprite:Render(Vector(200, 155))

    -- Bottom Right (10c)
    nickelSprite:Render(Vector(270, 155))
    nickelSprite:Render(Vector(276, 155))

    -- Render Arrow Sprite
    local arrowPos = BDMod.data.dbArrowPos

    arrowSprite:Render(arrowPositions[arrowPos.x][arrowPos.y])

    if Input.IsActionTriggered(ButtonAction.ACTION_BOMB, cIndex) then -- Finish choosing bet
        local cost = arrowValues[arrowPos.x][arrowPos.y]
        if cost > BDMod.data.menuPlayer:GetNumCoins() then
            hf.playSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ)
            return
        end

        hf.playSound(SoundEffect.SOUND_PAPER_OUT)
        BDMod.data.menuPlayer:AddCoins(-cost)
        BDMod.data.betAmount = cost
        BDMod.data.declareBet = false
        initTrueGame = true
    end

end

function BDMod:onRender()
    if Input.IsButtonPressed(Keyboard.KEY_LEFT_SHIFT, 0) and Input.IsButtonPressed(Keyboard.KEY_B, 0) and Input.IsButtonPressed(Keyboard.KEY_D, 0) then 
        BDMod.data.displayMenu = false
        BDMod.data.declareBet = false
        for i=0, game:GetNumPlayers()-1 do
            local player = Isaac.GetPlayer(i)
            player.ControlsEnabled = true
        end
        bj.resetGame()
    end

    if BDMod.data.menuPlayer == nil then
        BDMod.data.menuPlayer = Isaac.GetPlayer(0)
    end

    local cIndex = BDMod.data.menuPlayer.ControllerIndex

    if Input.IsActionTriggered(ButtonAction.ACTION_DROP, cIndex) then
        if BDMod.data.displayMenu then
            if BDMod.data.finishGame and bj.declareWinner(BDMod.hands.player, BDMod.hands.dealer) == "player" then
                BDMod.data.gameWon = true
                if BDMod then 
                    amountWins = amountWins + 1
                    -- hf.bdLog("EVENT | Player won, Amount of wins: " .. amountWins)
                end
            end
            bj.resetGame()
        elseif BDMod.data.declareBet then
            endDeclaringBet()
        end
    end

    if not BDMod.data.displayMenu and BDMod.data.controlsDisabledMenu or not BDMod.data.declareBet and BDMod.data.controlsDisabledMenu then
        BDMod.data.controlsDisabledMenu = nil
        for i=0, game:GetNumPlayers()-1 do
            local player = Isaac.GetPlayer(i)
            player.ControlsEnabled = true
        end
    end

    -- Bet Menu
    if BDMod.data.declareBet then betRender() end

    if not BDMod.data.displayMenu then return end

    if BDMod.data.controlsDisabledMenu == nil then -- Handle control enable / disable
        BDMod.data.controlsDisabledMenu = true
        for i=0, game:GetNumPlayers()-1 do
            local player = Isaac.GetPlayer(i)

            player.ControlsEnabled = false
        end
    end

    if BDMod.hands.player == nil then
        -- print("Game started!")
        BDMod.hands.player = bj.deal()
        BDMod.hands.dealer = bj.deal()

        if BDMod then
            amountGamesPlayed = amountGamesPlayed + 1
            hf.bdLog("EVENT | ================--------- New game started, Amount of games played: " .. amountGamesPlayed .. " ---------================")
        end

        if bj.getTotalInHand(BDMod.hands.player, true, "check player hand after start") == 21 or bj.getTotalInHand(BDMod.hands.dealer, true, "check dealer hand after start") == 21 then -- Player or dealer has Blackjack
            BDMod.data.finishGame = true
        end
    end

    if BDMod.data.arrowPos == 1 and Input.IsActionTriggered(ButtonAction.ACTION_SHOOTRIGHT, cIndex) then
        BDMod.data.arrowPos = 2
    elseif BDMod.data.arrowPos == 2 and Input.IsActionTriggered(ButtonAction.ACTION_SHOOTLEFT, cIndex)  then
        BDMod.data.arrowPos = 1
    end

    paperBg:Render(Vector(235, 135), vz, vz)

    if BDMod.data.arrowPos == 1 and not BDMod.data.lockControl then
        arrowSprite:Render(Vector(98, 205), vz, vz) -- Hit
    elseif BDMod.data.arrowPos == 2 and not BDMod.data.lockControl  then
        arrowSprite:Render(Vector(298, 205), vz, vz) -- Stand
    end

    local cardSprite = Sprite()
    cardSprite:Load("gfx/ui/card.anm2", true)

    if BDMod.data.printDeckInfo then
        if game:GetFrameCount() <= BDMod.data.closeDeckInfoIn then
            f:DrawString("New deck!", 140, 195, KColor(0.75,0,0,1), 160, true)
        else
            BDMod.data.printDeckInfo = false
            BDMod.data.closeDeckInfoIn = nil
        end
    end

    local offset = {
        player = function(cardIdx)
            local tempV = Vector(140 + (cardIdx * 40), 170)
            return tempV
        end,

        dealer = function(cardIdx)
            local tempV = Vector(140 + (cardIdx * 40), 85)
            return tempV
        end
    }

    -- Dealer hand
    if BDMod.hands.dealer ~= nil then

        for i, card in ipairs(BDMod.hands.dealer) do
            if i == 2 and not BDMod.data.dealerCardRevealed then
                cardSprite:SetAnimation("back", true)
            else
                cardSprite:SetAnimation(card, true)
            end
            cardSprite:SetFrame(1)
            cardSprite:Render(offset.dealer(i), vz, vz)
        end

    end

    -- Player hand
    if BDMod.hands.player ~= nil then
        for i, card in ipairs(BDMod.hands.player) do
            cardSprite:SetAnimation(card, true)
            cardSprite:SetFrame(1)
            cardSprite:Render(offset.player(i), vz, vz)
        end
    end


    -- Dealer total:
    if BDMod.hands.dealer ~= nil then
        local dealerTotal = tostring(bj.getTotalInHand(BDMod.hands.dealer))
        if BDMod.data.dealerCardRevealed then
            if hf.has_value(BDMod.hands.dealer, "A") and not hf.has_value(BDMod.hands.dealer, "sA") then
                f:DrawString("Total: ", 80, 62, KColor(0,0,0,1), 0, true)
                f:DrawString("Soft " .. dealerTotal, 75, 78, KColor(0,0,0,1), 78, true)
            else
                f:DrawString("Total: ", 80, 62, KColor(0,0,0,1), 0, true)
                f:DrawString(dealerTotal, 75, 78, KColor(0,0,0,1), 78, true)
            end
        else
            f:DrawString("Total: ", 80, 62, KColor(0,0,0,1), 0, true)
            f:DrawString(dealerTotal, 75, 78, KColor(0,0,0,1), 78, true)
        end
    end

    -- Player total:
    if BDMod.hands.player ~= nil then
        local playerTotal = tostring(bj.getTotalInHand(BDMod.hands.player))
        if hf.has_value(BDMod.hands.player, "A") and not hf.has_value(BDMod.hands.player, "sA") then
            f:DrawString("Total: ", 80, 151, KColor(0,0,0,1), 0, true)
            f:DrawString("Soft " .. playerTotal, 75, 167, KColor(0,0,0,1), 78, true)
        else
            f:DrawString("Total: ", 80, 151, KColor(0,0,0,1), 0, true)
            f:DrawString(playerTotal, 75, 167, KColor(0,0,0,1), 78, true)
        end
    end

    f:DrawString("Hit", 105, 195, KColor(0,0,0,1), 0, true)
    f:DrawString("Stand", 305, 195 ,KColor(0,0,0,1), 0, true)
    if saveData.displayCardAmt then
        f:DrawString("Dealer's hand", 125, 40, KColor(0,0,0,1), 130, true)
        -- Render # of cards in deck
        f:DrawString("Cards: " .. #BDMod.deck, 300, 40, KColor(0,0,0,1), 100, true)
    else
        f:DrawString("Dealer's hand", 125, 40, KColor(0,0,0,1), 231, true)
    end
    f:DrawString("Your hand", 75, 128, KColor(0,0,0,1), 331, true)



    if Input.IsActionTriggered(ButtonAction.ACTION_BOMB, cIndex) and BDMod.data.arrowPos == 1 and not BDMod.data.lockControl then -- hit / stand
        bj.hit(BDMod.hands.player)
        BDMod.data.hitAmount = BDMod.data.hitAmount + 1
        if BDMod then
            amountTimesHit = amountTimesHit + 1
            hf.bdLog("EVENT | Player Hit, Amount of times: " .. amountTimesHit)
        end
        hf.playSound(SoundEffect.SOUND_PAPER_OUT)

        if bj.getTotalInHand(BDMod.hands.player, true, "check player hand after hit") >= 21 then
            BDMod.data.finishGame = true
        end

    elseif Input.IsActionTriggered(ButtonAction.ACTION_BOMB, cIndex) and BDMod.data.arrowPos == 2 and not BDMod.data.lockControl then
        -- print("--- You stand ---")
        BDMod.data.standTime = game:GetFrameCount()
        BDMod.data.doStand = true
        BDMod.data.lockControl = true
        if BDMod then
            amountTimesStood = amountTimesStood + 1
            hf.bdLog("EVENT | Player stood, Stand amount: " .. amountTimesStood)
        end
        -- hf.bdLog("1) Standing, controls: " ..  tostring(BDMod.data.lockControl) .. " ; BDMod.data.doStand: " .. tostring(BDMod.data.doStand) .. " ; BDMod.data.standTime: " .. tostring(BDMod.data.standTime) )
    end

    -- local mousePos = Input.GetMousePosition(true) -- get mouse position in world coordinates
    -- local screenPos = Isaac.WorldToScreen(mousePos) -- transfer game- to screen coordinates
    -- print(screenPos.X .. " " .. screenPos.Y)
    -- Isaac.RenderText(".", screenPos.X, screenPos.Y, 1 ,1 ,1 ,1 )


    if BDMod.data.doStand then
        if BDMod.data.dealerCardRevealed == false and game:GetFrameCount() >= BDMod.data.standTime + 60 then
            BDMod.data.dealerCardRevealed = true
            hf.playSound(SoundEffect.SOUND_PAPER_OUT)
            BDMod.data.standTime = game:GetFrameCount()
        end

        if bj.getTotalInHand(BDMod.hands.dealer) < saveData.dealerHitMax then
            if game:GetFrameCount() >= BDMod.data.standTime + 60 then
                bj.hit(BDMod.hands.dealer)
                BDMod.data.dealerHitAmount = BDMod.data.dealerHitAmount + 1
                hf.playSound(SoundEffect.SOUND_PAPER_OUT)
                if bj.getTotalInHand(BDMod.hands.dealer, true, "check if dealer hand bust when standing") > 21 then
                    BDMod.data.doStand = false
                    BDMod.data.finishGame = true
                    return nil
                end
                BDMod.data.standTime = game:GetFrameCount()
            end
        else
            BDMod.data.dealerCardRevealed = true
            BDMod.data.doStand = false
            BDMod.data.finishGame = true
            return nil
        end
    end

    if BDMod.data.finishGame then
        BDMod.data.lockControl = true

        if not BDMod.data.winnerGot then
            BDMod.data.winnerGot = true
            bj.declareWinner(BDMod.hands.player, BDMod.hands.dealer)
        end

        if BDMod.data.finishTime == nil then
            BDMod.data.finishTime = game:GetFrameCount()
        end

        if game:GetFrameCount() <= BDMod.data.finishTime + 70 then
            local winner, winMsg = bj.declareWinner(BDMod.hands.player, BDMod.hands.dealer)
            if winner == "player" then
                f:DrawString(winMsg, 78, 110 ,KColor(0,0.5,0,1), 331, true)
            else
                f:DrawString(winMsg, 78, 110 ,KColor(0.5,0,0,1), 331, true)
            end
        else
            f:DrawString("Press DROP to exit", 78, 110 ,KColor(0,0,0.5,1), 331, true)
        end
    end

end
BDMod:AddCallback(ModCallbacks.MC_POST_RENDER, BDMod.onRender)

local rewardMap = {
    [1] = {
        [1] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_PENNY}
        },

        [2] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_DOUBLEPACK}
        },

        [3] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_PENNY},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_PENNY},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_PENNY}
        },

        [4] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_DOUBLEPACK},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_DOUBLEPACK},
        },

        [5] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_LUCKYPENNY}
        },

        [6] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_NICKEL}
        },

        [7] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, Card.CARD_DIAMONDS_2}
        },

        [8] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_DOLLAR}
        },

        [9] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_DIME}
        },

        [10] = {
            {'break'}
        },

        [11] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, Card.CARD_JUDGEMENT}
        },

    },

    [3] = {
        [1] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_KEY, KeySubType.KEY_DOUBLEPACK},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_KEY, KeySubType.KEY_DOUBLEPACK},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_KEY, KeySubType.KEY_DOUBLEPACK},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_KEY, KeySubType.KEY_DOUBLEPACK},
        },

        [2] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BOMB, BombSubType.BOMB_DOUBLEPACK},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BOMB, BombSubType.BOMB_DOUBLEPACK},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BOMB, BombSubType.BOMB_DOUBLEPACK},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BOMB, BombSubType.BOMB_DOUBLEPACK},
        },

        [3] = {
            {'break'}
        },

        [4] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_DOLLAR},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_SKELETON_KEY},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_PYRO},
        },

        [5] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_LIL_BATTERY, BatterySubType.BATTERY_MICRO},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_LIL_BATTERY, BatterySubType.BATTERY_MICRO},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_LIL_BATTERY, BatterySubType.BATTERY_MICRO},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_LIL_BATTERY, BatterySubType.BATTERY_MICRO},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_LIL_BATTERY, BatterySubType.BATTERY_MICRO},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_LIL_BATTERY, BatterySubType.BATTERY_MICRO},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_LIL_BATTERY, BatterySubType.BATTERY_MICRO},
        },

        [6] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_KEY, KeySubType.KEY_NORMAL},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BOMB, BombSubType.BOMB_NORMAL},
        },

        [7] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, Card.CARD_CLUBS_2},
        },

        [8] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, Card.CARD_SPADES_2},
        },

        [9] = {
            {'usemega'},
        },

        [10] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, game:GetItemPool():GetCard(Random(), false, true, true)}
        },

        [11] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_NICKEL}
        },

        [12] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_PILL, game:GetItemPool():GetPill(Random())}
        },

    },

    [5] = {
        [1] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, game:GetItemPool():GetCard(Random(), true, false, false)}
        },

        [2] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, specialCards[hf.randint(BDMod.rng, 1, #specialCards)]},
        },

        [3] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, game:GetItemPool():GetCard(Random(), true, false, false)},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, game:GetItemPool():GetCard(Random(), true, false, false)},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, game:GetItemPool():GetCard(Random(), true, false, false)},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, game:GetItemPool():GetCard(Random(), true, false, false)}
        },

        [4] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, specialCards[hf.randint(BDMod.rng, 1, #specialCards)]},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, specialCards[hf.randint(BDMod.rng, 1, #specialCards)]},
        },

        [5] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, game:GetItemPool():GetCard(Random(), true, false, false)},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, game:GetItemPool():GetCard(Random(), true, false, false)},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, game:GetItemPool():GetCard(Random(), true, false, false)},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, game:GetItemPool():GetCard(Random(), true, false, false)},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, specialCards[hf.randint(BDMod.rng, 1, #specialCards)]},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, specialCards[hf.randint(BDMod.rng, 1, #specialCards)]},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, game:GetItemPool():GetCard(Random(), false, true, true)},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, game:GetItemPool():GetCard(Random(), false, true, true)},
        },

        [6] = {
            {'break'}
        },

        [7] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, Card.CARD_HOLY},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, Card.CARD_HOLY},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, Card.CARD_HOLY},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, Card.CARD_HOLY},
        },

        [8] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_LUCKYPENNY},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_LUCKYPENNY},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_LUCKYPENNY},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_LUCKYPENNY},
        },

        [9] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TRINKET, game:GetItemPool():GetTrinket()},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TRINKET, game:GetItemPool():GetTrinket()}
        },

        [10] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_CHEST, 1},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_CHEST, 1},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_CHEST, 1},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_LOCKEDCHEST, 1}

        },

        [11] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, Card.CARD_REVERSE_JUDGEMENT}
        },

    },

    [10] = {
        [1] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_DIME},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_DIME},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_NICKEL},
        },

        [2] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_LUCKYPENNY},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_LUCKYPENNY},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_LUCKYPENNY},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_LUCKYPENNY},
        },

        [3] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, game:GetItemPool():GetCollectible(ItemPoolType.POOL_TREASURE, true)},
        },

        [4] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, game:GetItemPool():GetCollectible(ItemPoolType.POOL_SHOP, true)},
        },

        [5] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, game:GetItemPool():GetCollectible(ItemPoolType.POOL_ANGEL, true)},
        },

        [6] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, game:GetItemPool():GetCollectible(ItemPoolType.POOL_DEVIL, true)},
        },

        [7] = {
            {'break'},
        },

        [8] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_DOLLAR},
        },

        [9] = {
            {'43coins'}
        },

        [10] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_POOP},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_POOP},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_POOP},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_POOP},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_POOP},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_POOP},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_POOP},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_POOP},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, Card.CARD_DICE_SHARD},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, Card.CARD_DICE_SHARD},
        },

        [11] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, game:GetItemPool():GetCollectible(ItemPoolType.POOL_BABY_SHOP, true)},
        },

        [12] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TRINKET, game:GetItemPool():GetTrinket()},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TRINKET, game:GetItemPool():GetTrinket()},
        },

        [13] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_LOCKEDCHEST, 1},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_LOCKEDCHEST, 1},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_LOCKEDCHEST, 1},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_LOCKEDCHEST, 1},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_REDCHEST, 1},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_REDCHEST, 1},
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_CHEST, 1},

        },

        [14] = {
            {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, game:GetItemPool():GetCollectible(ItemPoolType.POOL_CURSE, true)},
        },
    },
}

local betToRewardIdx = {
    [1] = getResultByChance(BDMod.rng, 40, 20, 10, 5, 5, 5, 5, 1, 2, 2, 5),
    [3] = getResultByChance(BDMod.rng, 10, 10, 4, 1, 5, 20, 5, 5, 5, 5, 20, 10),
    [5] = getResultByChance(BDMod.rng, 20, 20, 10, 10, 1, 2, 2, 5, 10, 10, 10),
    [10] = getResultByChance(BDMod.rng, 10, 10, 10, 20, 5, 5, 2, 2, 5, 1, 5, 10, 10, 5)
}

---@param bdEnt EntityNPC
local function spawnReward(bdEnt)
    local betAmt = BDMod.data.betAmount
    local rewardIdx = betToRewardIdx[betAmt]
    local rewards = rewardMap[betAmt][rewardIdx]

    local freePos = function (step)
        if step == nil then
            step = 50
        end
        return Isaac.GetFreeNearPosition(bdEnt.Position, step)
    end

    for _, reward in pairs(rewards) do
        if reward[1] == 'break' then
            return false
        end

        if reward[1] == 'usemega' then
            BDMod.data.menuPlayer:UseActiveItem(CollectibleType.COLLECTIBLE_MAMA_MEGA)
            return
        end

        if reward[1] == '43coins' then
            for _ = 0, 43 do
                Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_PENNY,
                            Isaac.GetFreeNearPosition(Isaac.GetRandomPosition(), 20), vz, bdEnt)
            end
            return
        end

        Isaac.Spawn(reward[1], reward[2], reward[3], freePos(), vz, bdEnt)
    end
end


local function removeBd(ent)
    ent:Kill()
    ent:Remove()
    return nil, nil, nil
end

---@param player EntityPlayer
function BDMod:update(player)

    local bdEnt = getBdEnt(player)
    if bdEnt == nil then return end

    local data = bdEnt:GetData()
    local bdSprite = bdEnt:GetSprite()
    local bdPos = bdEnt.Position

    -- Set ent flags
    if data.bdInit == nil then
        bdEnt:ClearEntityFlags(bdEnt:GetEntityFlags())
        bdEnt:AddEntityFlags(entData.flags)
        bdEnt.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYERONLY
    end

    -- Bomb destruction
    for i, entity in pairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.BOMB_EXPLOSION)) do
        if bdPos:Distance(entity.Position) < 120 then
            bdEnt, bdPos, bdSprite = removeBd(bdEnt)
            return
        end
    end

    if (bdEnt.Position - player.Position):Length() > 20 then
        data.wasTouched = false
    end

    if (bdEnt.Position - player.Position):Length() <= 20 and not data.wasTouched then -- Collision
        if bdSprite:GetAnimation() ~= "Idle" then
            return nil
        end

        if player:GetNumCoins() < 1 then return end

        data.wasTouched = true

        bdSprite:Play("PrePlay", true)
        BDMod.data.menuPlayer = player
    end

    if initTrueGame then
        bdSprite:ReplaceSpritesheet(2, betToSpritesheet[BDMod.data.betAmount])
        bdSprite:LoadGraphics()
        bdSprite:Play("PayPrize", true)
        initTrueGame = false
    end

    if bdSprite:IsFinished("PrePlay") then
        bdSprite:SetAnimation("Idle", true)
        bdSprite:SetFrame(1)
        if not BDMod.data.declareBet then
            BDMod.data.dbArrowPos = {
                x = 1,
                y = 1
            }
            BDMod.data.declareBet = true
        end
    end

    if bdSprite:IsFinished("PayPrize") then
        bdSprite:SetAnimation("Idle", true)
        bdSprite:SetFrame(1)
        if not BDMod.data.displayMenu then
            BDMod.data.displayMenu = true
        end
    end

    if BDMod.data.gameWon then
        bdSprite:Play("Prize")
        if bdSprite:IsEventTriggered("Prize") then
            hf.playSound(SoundEffect.SOUND_NICKELPICKUP)

            local reward = spawnReward(bdEnt)

            if reward == false then
                bdEnt, bdPos, bdSprite = removeBd(bdEnt)
                return
            end
        end

        if bdSprite:IsFinished("Prize") then
            bdSprite:SetAnimation("Idle", true)
            bdSprite:SetFrame(1)
            BDMod.data.gameWon = false
            BDMod.data.menuPlayer = nil
        end
    end
end

BDMod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, BDMod.update)

function BDMod:newRoom()
    local room = game:GetRoom()
    local level = game:GetLevel()

    -- Credit to Sentinel and his Crane Machine mod for the code:
    if room:GetType() == RoomType.ROOM_ARCADE and room:IsFirstVisit() or saveData.lockToArcade == false then 
        local stage = level:GetAbsoluteStage()
		local seed = game:GetSeeds():GetStageSeed(stage)
		local rng = RNG()
		rng:SetSeed(seed, 0)

        if rng:RandomInt(100) <= tonumber(saveData.bdSpawnChance) then 
            local slotEnts = Isaac.FindByType(EntityType.ENTITY_SLOT, -1, -1, false, false)
            local viable_slots = {}

            for _, slot in ipairs(slotEnts) do
                if slot.Variant <= 12 and not slot:IsDead() then
					table.insert(viable_slots, slot)
				end
            end

            local num_viable_slots = #viable_slots
			if num_viable_slots > 0 then
				local slot = viable_slots[rng:RandomInt(num_viable_slots) + 1]
				Isaac.Spawn(entData.type, entData.var, 0, slot.Position, vz, nil)
				slot:Remove()
			end

        end
    end
end
BDMod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, BDMod.newRoom)

if ModConfigMenu then -- Mod config menu support
	ModConfigMenu.AddSetting("Blackjack Dealer", "General", {
		Type = ModConfigMenu.OptionType.NUMBER,

		CurrentSetting = function()
			return saveData.bdSpawnChance
		end,

		Display = function()
			return "Spawn Chance: " .. tostring(saveData.bdSpawnChance) .. "%"
		end,

		Minimum = 0,
		Maximum = 100,

		OnChange = function(currentNum)
			saveData.bdSpawnChance = currentNum

            saveModData()
		end,

		Info = {
            "Chance to replace a slot machine",
            "Default: 50%"
		}
	})

    ModConfigMenu.AddSetting("Blackjack Dealer", "General", {
		Type = ModConfigMenu.OptionType.BOOLEAN,

		CurrentSetting = function()
			return saveData.lockToArcade
		end,

		Display = function()
            local text
            if saveData.lockToArcade then
                text = "On"
            elseif saveData.lockToArcade == false then
                text = "Off"
            else
                text = "ERROR"
            end
			return "Lock spawns to arcade: " .. text
		end,

		OnChange = function(currentNum)
			saveData.lockToArcade = currentNum

            saveModData()
		end,

		Info = {
			"When enabled, the dealer will only spawn in arcades. When disabled, chance to replace slots in general.",
            "Default: On"
		}
	})

    ModConfigMenu.AddSetting("Blackjack Dealer", "General", {
		Type = ModConfigMenu.OptionType.NUMBER,

		CurrentSetting = function()
			return saveData.dealerHitMax
		end,

		Display = function()
			return "Dealer must hit until: " .. saveData.dealerHitMax
		end,


		OnChange = function(currentNum)
			saveData.dealerHitMax = currentNum

            saveModData()
		end,

		Info = {
            "Decides what total the dealer must reach before standing",
            "Default: 17"
		}
    })

    ModConfigMenu.AddSetting("Blackjack Dealer", "General", {
		Type = ModConfigMenu.OptionType.BOOLEAN,

		CurrentSetting = function()
			return saveData.displayCardAmt
		end,

		Display = function()
            local text
            if saveData.displayCardAmt then
                text = "On"
            elseif saveData.displayCardAmt == false then
                text = "Off"
            else
                text = "ERROR"
            end

			return "Display card amount: " .. text
		end,


		OnChange = function(currentNum)
			saveData.displayCardAmt = currentNum

            saveModData()
		end,

		Info = {
            "When enabled will display the number of cards left in the deck",
            "Default: Off"
		}
    })
end

hf.bdLog("Blackjack dealer mod initialized. Version 2.0")