local blackjackDealerMod = RegisterMod("Blackjack Dealer", 1)
local json = require("json")

local game = Game()
local vz = Vector.Zero

-- Don't change this unles you want your logs flooded with debug stuff
local enableLogs = true

local hands = {
    player = nil,
    dealer = nil
}

local pData = {
    hitAmount = nil,
    menuPlayer = nil
}

local gData = {
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
    finishTime = nil
}

local entData = {
    flags = EntityFlag.FLAG_NO_TARGET | EntityFlag.FLAG_NO_STATUS_EFFECTS,
    type = Isaac.GetEntityTypeByName("Blackjack Dealer"),
    var = Isaac.GetEntityVariantByName("Blackjack Dealer"),
}

local deck = {2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14}
--                                         J   Q   K   A                             J   Q   K   A                                 J   Q   K   A                              J   Q   K   A

local specialCards = {Card.CARD_CLUBS_2, Card.CARD_DIAMONDS_2, Card.CARD_SPADES_2, Card.CARD_HEARTS_2, Card.CARD_ACE_OF_CLUBS, Card.CARD_ACE_OF_DIAMONDS, Card.CARD_ACE_OF_SPADES, Card.CARD_ACE_OF_HEARTS, Card.CARD_JOKER, Card.CARD_QUEEN_OF_HEARTS} 
local bRng

-- Mod config menu configurables
local saveData = {
    bdSpawnChance = nil,
}

--- log stuff
local amountGamesPlayed
local amountTimesHit
local amountTimesStood
local amountWins

--[[
    rewrite goals:
    - decrease local var amount
    - improve code quality
    - remove redundant code
    - make code readible
    - remove logs from live, keep dev version w/ logs

    - dont touch checking code
]]

--[[
   version 2.0 goals:
   - improve sprite quality
   - add actual decks
   - rework balance
]]

local f = Font()
f:Load("font/Upheaval.fnt")

local function randint(rng, min, max)
    if min > max then
        error("Min greater than Max!")
        return rng:RandomInt(max)
    else
        return min + (rng:RandomInt(max - min + 1))
    end
end

local function playSound(soundName)
    local sfxm = SFXManager()
    sfxm:Play(soundName)
end

local function bjPrint(text)
    Isaac.DebugString(game:GetFrameCount() .. " BJ| " .. tostring(text))
    print("BJ| " .. tostring(text))
end

local function shuffle(tbl) -- https://gist.github.com/Uradamus/10323382
    for i = #tbl, 2, -1 do
        local j = randint(bRng, 1, i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end

local function has_value (tab, val)
    for _, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

-- Blackjack base implementation, inspired by https://gist.github.com/mjhea0/5680216
local function deal()
    local hand = {}
    shuffle(deck)
    for i = 0, 1 do
        local card = table.remove(deck, 1)
        if card == 11 then
            card = "J"
        elseif card == 12 then
            card = "Q"
        elseif card == 13 then
            card = "K"
        elseif card == 14 then
            card = "A"
        end
        table.insert(hand, card)
    end
    return hand
end

local function hit(hand)
    local card = table.remove(deck, 1)
    if card == 11 then
        card = "J"
    elseif card == 12 then
        card = "Q"
    elseif card == 13 then
        card = "K"
    elseif card == 14 then
        card = "A"
    end
    table.insert(hand, card)
    return hand
end

local function checkAces(hand, total, log) -- Check for soft aces

    if not enableLogs then
        log = false
    end

    if log then
        bjPrint("ACE | Ace eval started")
    end

    local softAce = false
    local aceValue = 0

    if total + 11 > 21 then
        softAce = true
        if log then bjPrint("ACE | Ace is soft, " .. total + 11) end
    else
        if log then bjPrint("ACE | Ace is NOT soft, " .. total + 11) end
    end

    for i, card in pairs(hand) do
        if log then bjPrint("ACE | Card isnt ace") end
         if card == "A" then
            if log then bjPrint("ACE | Card is ace") end

            if softAce and not has_value(hand, "sA") then
                aceValue = aceValue + 1
                hand[i] = "sA"
                if log then bjPrint("ACE | Ace more than and declared soft") end
            elseif total < 11 then
                aceValue = aceValue + 11
                -- hand[i] = "hA"
                if log then bjPrint("ACE | Ace less than 11") end
            else
                aceValue = aceValue + 1
                -- hand[i] = "hA"
                if log then bjPrint("ACE | Ace more than 11") end
            end

            if card == "sA" then
                if log then bjPrint("ACE | Soft ace") end
            elseif card == "hA" then
                if log then bjPrint("ACE | Hard ace") end
            end
        end   

    end

    if log then bjPrint("final aceval: " .. aceValue) end
    return aceValue

end

local function getTotalInHand(hand, log, logReason)
    local total = 0

    if not enableLogs then
        log = false
    end

    if log and enableLogs and logReason ~= nil then
        bjPrint("TOTAL | ====== New total eval started ======")
        bjPrint("TOTAL |    Reason: " .. logReason)
        bjPrint("TOTAL |    " .. tostring(hand[1]) .. " " .. tostring(hand[2])  .. " " .. tostring(hand[3])  .. " " .. tostring(hand[4]) .. " " .. tostring(hand[5]))
    end

    if hand == hands.dealer and not gData.dealerCardRevealed then

        -- DELAER HAND ONLY!

        if log and enableLogs then
            bjPrint("TOTAL |    Dealer hand, card not revealed! ")
        end

        local card = hand[1]

        if log then bjPrint("TOTAL | Starting evaluation of non-aces, current total: " .. total) end

        if log and enableLogs then
            bjPrint("TOTAL |     -- NEW CARD --")
            bjPrint("TOTAL |     Current total: " .. total)
            bjPrint("TOTAL |    Card: " .. card)
        end

        if card == "J" or card == "Q" or card == "K" then           
            total = total + 10
        end

        if card ~= "J" and card ~= "Q" and card ~= "K" and card ~= "A" and card ~= "sA" and card ~= "hA" then
            total = total + card
        end   


        if log then bjPrint("TOTAL |    Starting checkAces: " .. total) end
        if has_value(hand, "A") and not has_value(hand, "sA") then
            checkAces(hand, total, log)
            if log then bjPrint("TOTAL |Checkaces finished.") end
        end

        if log then bjPrint("TOTAL |    Starting Ace eval, total: " .. total) end

        if card == "sA" or card == "A" then
            if log then bjPrint("TOTAL |       sA and hA eval started") end
            if card == "sA" then
                if log then bjPrint("TOTAL |       sA adds 1, card: " .. card) end
                total = total + 1
            elseif card == "A" and total < 11 then
                if log then bjPrint("TOTAL |       hA, adds 11, card: " .. card) end
                total = total + 11
            else
                if log then bjPrint("TOTAL |       x adds 1, card: " .. card) end
                total = total + 1
            end
        end

        if log then bjPrint("TOTAL |    Eval ended, total: " .. total) end

        return total

        -- DEALER HAND ONLY
    else
    
        if log and enableLogs then bjPrint("TOTAL |    Dealer hand w. card or / player hand ") end

        if log then bjPrint("TOTAL | Starting evaluation of non-aces, current total: " .. total) end
        for i, card in pairs(hand) do

            if log and enableLogs then
                bjPrint("TOTAL |     -- NEW CARD --")
                bjPrint("TOTAL |     Current total: " .. total)
                bjPrint("TOTAL |    Card: " .. card)
            end

            if card == "J" or card == "Q" or card == "K" then           
                total = total + 10
            end

            if card ~= "J" and card ~= "Q" and card ~= "K" and card ~= "A" and card ~= "sA" and card ~= "hA" then
                total = total + card
            end   

        end

        if log then bjPrint("TOTAL |    Starting checkAces: " .. total) end
        if has_value(hand, "A") and not has_value(hand, "sA") then
            checkAces(hand, total, log)
            if log then bjPrint("TOTAL |Checkaces finished.") end
        end

        if log then bjPrint("TOTAL |    Starting Ace eval, total: " .. total) end
        for i, card in pairs(hand) do

            if card == "sA" or card == "A" then
                if log then bjPrint("TOTAL |       sA and hA eval started") end
                if card == "sA" then
                    if log then bjPrint("TOTAL |       sA adds 1, card: " .. card) end
                    total = total + 1
                elseif card == "A" and total < 11 then
                    if log then bjPrint("TOTAL |       hA, adds 11, card: " .. card) end
                    total = total + 11
                else
                    if log then bjPrint("TOTAL |       x adds 1, card: " .. card) end
                    total = total + 1
                end
            end

        end

        if log then bjPrint("TOTAL |    Eval ended, total: " .. total) end

        return total
    end
end

local function resetGame()
    pData.hitAmount = 0
    gData.dealerHitAmount = 0

    hands.player = nil
    hands.dealer = nil

    gData.arrowPos = 1
    gData.controlsDisabledMenu = true
    gData.dealerCardRevealed = false
    gData.lockControl = false
    gData.finishGame = false
    gData.winnerGot = false

    gData.standTime = 0
    gData.doStand = false
    gData.finishTime = nil
    gData.displayMenu = false

    pData.menuPlayer = nil
    deck = {2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14}
end

local function declareWinner(ph, dh)
    local winner = nil
    local winMsg = nil
    local playerTotal = getTotalInHand(ph)
    local dealerTotal = getTotalInHand(dh)

    if playerTotal == 21 then -- Player has Blackjack
        winner = "player"
        winMsg = "You've won the by Blackjack"
    elseif dealerTotal == 21 then -- Dealer has Blackjack
        winner = "dealer"
        winMsg = "Dealer has won by Blackjack"
    elseif playerTotal > 21 then -- Player bust
        winner = "dealer"
        winMsg = "Dealer has won by Player bust"
    elseif dealerTotal > 21 then -- Dealer bust
        winner = "player"
        winMsg = "You've won by Dealer bust"
    elseif playerTotal < dealerTotal then -- Dealer has more value
        winner = "dealer"
        winMsg = "Dealer has won by More value"
    elseif playerTotal > dealerTotal then -- Player has more value
        winner = "player"
        winMsg = "You've won by More value"
    elseif playerTotal == dealerTotal then
        winner = "tie"
        winMsg = "Tie! Both have the same values"
    else
        bjPrint("ERR | Something weird has happened in the Blackjack Dealer mod. Please report this to the mod developer if you can")
        bjPrint("ERR | Details: DeclareWinner didnt find a win condition.")
    end

    if not gData.finishGame then
        resetGame()
    end

    return winner, winMsg
end

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

function blackjackDealerMod:OnGameStart(isSave)

    if enableLogs then
        bjPrint("EVENT | New run started / continued, all values reset!")
    end

    if not blackjackDealerMod:HasData() then
        saveData.bdSpawnChance = 50
    else
        saveData.bdSpawnChance = json.decode(blackjackDealerMod:LoadData()).bdSpawnChance
    end

    resetGame()
    gData.gameWon = false
    bRng = nil

    amountGamesPlayed = 0
    amountTimesHit = 0
    amountTimesStood = 0
    amountWins = 0

    local startseed = game:GetSeeds():GetStartSeed()
    bRng = RNG()
    bRng:SetSeed(startseed, 0)

end
blackjackDealerMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, blackjackDealerMod.OnGameStart)

function blackjackDealerMod:onRender()
    if Input.IsButtonPressed(Keyboard.KEY_LEFT_SHIFT, 0) and Input.IsButtonPressed(Keyboard.KEY_B, 0) and Input.IsButtonPressed(Keyboard.KEY_J, 0) then 
        gData.displayMenu = false
        for i=0, game:GetNumPlayers()-1 do
            local player = Isaac.GetPlayer(i)
            player.ControlsEnabled = true
        end
        resetGame()
    end

    if pData.menuPlayer == nil then
        pData.menuPlayer = Isaac.GetPlayer(0)
    end

    local cIndex = pData.menuPlayer.ControllerIndex
    if Input.IsActionTriggered(ButtonAction.ACTION_DROP, cIndex) then
        if gData.displayMenu then
            if gData.finishGame and declareWinner(hands.player, hands.dealer) == "player" then
                gData.gameWon = true
                if enableLogs then 
                    amountWins = amountWins + 1
                    -- bjPrint("EVENT | Player won, Amount of wins: " .. amountWins)
                end
            end
            resetGame()
        end
    end

    if not gData.displayMenu and gData.controlsDisabledMenu then
        gData.controlsDisabledMenu = nil
        for i=0, game:GetNumPlayers()-1 do
            local player = Isaac.GetPlayer(i)
            player.ControlsEnabled = true
        end
    end

    if not gData.displayMenu then return end

    if gData.controlsDisabledMenu == nil then -- Handle control enable / disable
        gData.controlsDisabledMenu = true
        for i=0, game:GetNumPlayers()-1 do
            local player = Isaac.GetPlayer(i)

            player.ControlsEnabled = false
        end
    end

    if hands.player == nil then
        -- print("Game started!")
        hands.player = deal()
        hands.dealer = deal()

        if enableLogs then
            amountGamesPlayed = amountGamesPlayed + 1
            bjPrint("EVENT | ================--------- New game started, Amount of games played: " .. amountGamesPlayed .. " ---------================")
        end

        if getTotalInHand(hands.player, true, "check player hand after start") == 21 or getTotalInHand(hands.dealer, true, "check dealer hand after start") == 21 then -- Player or dealer has Blackjack
            gData.finishGame = true
        end
    end

    if gData.arrowPos == 1 and Input.IsActionTriggered(ButtonAction.ACTION_SHOOTRIGHT, cIndex) then
        gData.arrowPos = 2
    elseif gData.arrowPos == 2 and Input.IsActionTriggered(ButtonAction.ACTION_SHOOTLEFT, cIndex)  then
        gData.arrowPos = 1
    end

    local paperBg = Sprite()
    paperBg:Load("gfx/ui/paperbg.anm2", true)
    paperBg:SetAnimation("main", true)
    paperBg:SetFrame(1)
    paperBg.Scale = Vector(3, 3)
    paperBg:Render(Vector(95, 45), vz, vz)

    local arrowSprite = Sprite()
    arrowSprite:Load("gfx/ui/arrow.anm2", true)
    arrowSprite:SetAnimation("main", true)
    arrowSprite:SetFrame(1)

    if gData.arrowPos == 1 and not gData.lockControl then
        arrowSprite:Render(Vector(98, 205), vz, vz) -- Hit
    elseif gData.arrowPos == 2 and not gData.lockControl  then
        arrowSprite:Render(Vector(298, 205), vz, vz) -- Stand
    end

    local cardSprite = Sprite()
    cardSprite:Load("gfx/ui/card.anm2")

    local offset = {
        player = function(cardIdx)
            local tempV = Vector(
                140 + (cardIdx * 40),
                170)
            return tempV
        end,

        dealer = function(cardIdx)
            local tempV = Vector(
                140 + (cardIdx * 40),
                85)
            return tempV
        end
    }

    -- Dealer hand
    if hands.dealer ~= nil then

        for i, card in ipairs(hands.dealer) do
            if i == 2 and not gData.dealerCardRevealed then
                cardSprite:SetAnimation("back", true)
            else
                cardSprite:SetAnimation(card, true)
            end
            cardSprite:SetFrame(1)
            cardSprite:Render(offset.dealer(i), vz, vz)
        end

    end

    -- Player hand
    if hands.player ~= nil then
        for i, card in ipairs(hands.player) do
            cardSprite:SetAnimation(card, true)
            cardSprite:SetFrame(1)
            cardSprite:Render(offset.player(i), vz, vz)
        end
    end


    -- Dealer total:
    if hands.dealer ~= nil then
        if gData.dealerCardRevealed then
            if has_value(hands.dealer, "A") and not has_value(hands.dealer, "sA") then
                f:DrawString("Total: ", 80, 62, KColor(0,0,0,1), 0, true)
                f:DrawString("Soft " .. tostring(getTotalInHand(hands.dealer)), 75, 78, KColor(0,0,0,1), 78, true)
            else
                f:DrawString("Total: ", 80, 62, KColor(0,0,0,1), 0, true)
                f:DrawString(tostring(getTotalInHand(hands.dealer)), 75, 78, KColor(0,0,0,1), 78, true)
            end
        else
            f:DrawString("Total: ", 80, 62, KColor(0,0,0,1), 0, true)
            f:DrawString(tostring(getTotalInHand(hands.dealer)), 75, 78, KColor(0,0,0,1), 78, true)
        end
    end

    -- Player total:
    if hands.player ~= nil then
        if has_value(hands.player, "A") and not has_value(hands.player, "sA") then
            f:DrawString("Total: ", 80, 151, KColor(0,0,0,1), 0, true)
            f:DrawString("Soft " .. tostring(getTotalInHand(hands.player)), 75, 167, KColor(0,0,0,1), 78, true)
        else
            f:DrawString("Total: ", 80, 151, KColor(0,0,0,1), 0, true)
            f:DrawString(tostring(getTotalInHand(hands.player)), 75, 167, KColor(0,0,0,1), 78, true)
        end
    end

    f:DrawString("Hit", 105, 195, KColor(0,0,0,1), 0, true)
    f:DrawString("Stand", 305, 195 ,KColor(0,0,0,1), 0, true)
    f:DrawString("Dealer's hand", 125, 40, KColor(0,0,0,1), 231, true)
    f:DrawString("Your hand", 75, 128, KColor(0,0,0,1), 0331, true)

    -- Isaac.RenderText("[]", screenPos.X, screenPos.Y, 1 ,1 ,1 ,1 )

    -- print(screenPos)

    if Input.IsActionTriggered(ButtonAction.ACTION_BOMB, cIndex) and gData.arrowPos == 1 and not gData.lockControl then -- Hit / stand
        hit(hands.player)
        pData.hitAmount = pData.hitAmount + 1
        if enableLogs then
            amountTimesHit = amountTimesHit + 1
            bjPrint("EVENT | Player hit, Amount of times hit: " .. amountTimesHit)
        end
        playSound(SoundEffect.SOUND_PAPER_OUT)

        if getTotalInHand(hands.player, true, "check player hand after hit") >= 21 then
            gData.finishGame = true
        end

    elseif Input.IsActionTriggered(ButtonAction.ACTION_BOMB, cIndex) and gData.arrowPos == 2 and not gData.lockControl then
        -- print("--- You stand ---")
        gData.standTime = game:GetFrameCount()
        gData.doStand = true
        gData.lockControl = true
        if enableLogs then
            amountTimesStood = amountTimesStood + 1
            bjPrint("EVENT | Player stood, Stand amount: " .. amountTimesStood)
        end
        -- bjPrint("1) Standing, controls: " ..  tostring(gData.lockControl) .. " ; gData.doStand: " .. tostring(gData.doStand) .. " ; gData.standTime: " .. tostring(gData.standTime) )
    end

    if gData.doStand then
        if gData.dealerCardRevealed == false and game:GetFrameCount() >= gData.standTime + 60 then
            gData.dealerCardRevealed = true
            playSound(SoundEffect.SOUND_PAPER_OUT)
            gData.standTime = game:GetFrameCount()
        end

        if getTotalInHand(hands.dealer) < 17 then
            if game:GetFrameCount() >= gData.standTime + 60 then
                hit(hands.dealer)
                gData.dealerHitAmount = gData.dealerHitAmount + 1
                playSound(SoundEffect.SOUND_PAPER_OUT)
                if getTotalInHand(hands.dealer, true, "check if dealer hand bust when standing") > 21 then
                    gData.doStand = false
                    gData.finishGame = true
                    return nil
                end
                gData.standTime = game:GetFrameCount()
            end
        else
            gData.doStand = false
            gData.finishGame = true
            return nil
        end
    end

    if gData.finishGame then
        gData.lockControl = true

        if not gData.winnerGot then
            gData.winnerGot = true
            declareWinner(hands.player, hands.dealer)
        end

        if gData.finishTime == nil then
            gData.finishTime = game:GetFrameCount()
        end

        if game:GetFrameCount() <= gData.finishTime + 70 then
            local winner, winMsg = declareWinner(hands.player, hands.dealer)
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
blackjackDealerMod:AddCallback(ModCallbacks.MC_POST_RENDER, blackjackDealerMod.onRender)

local function removeBd(ent)
    ent:Kill()
    ent:Remove()
    return nil, nil, nil
end

function blackjackDealerMod:update(player)

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

        data.wasTouched = true
        if player:GetNumCoins() >= 5 then
            player:AddCoins(-5)
            bdSprite:Play("PayPrize", false)
            pData.menuPlayer = player
        end
    end

    if bdSprite:IsFinished("PayPrize") then
        bdSprite:SetAnimation("Idle", true)
        bdSprite:SetFrame(1)
        if not gData.displayMenu then
            gData.displayMenu = true
        end
    end

    if gData.gameWon then
        bdSprite:Play("Prize")
        if bdSprite:IsEventTriggered("Prize") then
            player:AddCoins(5)
            playSound(SoundEffect.SOUND_NICKELPICKUP)

            local rewardSeedRng = bRng:RandomInt(1000)

            local reward = getResultByChance(bRng, 40, 20, 15, 10, 5, 3, 1, 2, 4)
            local freePos =  Isaac.GetFreeNearPosition(bdPos, 50)

            if reward == 1 then
                local card = specialCards[randint(bRng, 1, #specialCards)]
                Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, card, freePos, vz, bdEnt)
            elseif reward == 2 then
                local card = game:GetItemPool():GetCard(rewardSeedRng, true, true, false)
                Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, card, freePos, vz, bdEnt)
                
                local card = game:GetItemPool():GetCard(rewardSeedRng+1, true, true, false)
                Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, card, freePos, vz, bdEnt)
            elseif reward == 3 then
                Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_PENNY, freePos, vz, bdEnt)
                Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_PENNY, freePos, vz, bdEnt)
                Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_LUCKYPENNY, freePos, vz, bdEnt)
            elseif reward == 4 then
                for i = 0, 1 do
                    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BOMB, BombSubType.BOMB_NORMAL, freePos, vz, bdEnt)
                    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_KEY, KeySubType.KEY_NORMAL, freePos, vz, bdEnt)
                end
            elseif reward == 5 then
                Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_DIME, freePos, vz, bdEnt)
            elseif reward == 6 then
                local rewardItem = game:GetItemPool():GetCollectible(ItemPoolType.POOL_CRANE_GAME, true, rewardSeedRng, 0)
                Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, rewardItem, freePos, vz, bdEnt)
            elseif reward == 7 then
                bdEnt, bdPos, bdSprite = removeBd(bdEnt)
                return
            elseif reward == 8 then
                local rewardTrinket = game:GetItemPool():GetTrinket(false)
                Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TRINKET, rewardTrinket, freePos, vz, bdEnt)
            elseif reward == 9 then
                Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_CHEST, 1, freePos, vz, bdEnt)
            end

        end

        if bdSprite:IsFinished("Prize") then
            bdSprite:SetAnimation("Idle", true)
            bdSprite:SetFrame(1)
            gData.gameWon = false
            pData.menuPlayer = nil
        end
    end
end

blackjackDealerMod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, blackjackDealerMod.update)

function blackjackDealerMod:newRoom()
    local room = game:GetRoom()
    local level = game:GetLevel()

    if room:GetType() == RoomType.ROOM_ARCADE and room:IsFirstVisit() then -- Credit to Sentinel and his Crane Machine mod for the code:
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
blackjackDealerMod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, blackjackDealerMod.newRoom)

if ModConfigMenu then -- Mod config menu support
	ModConfigMenu.AddSetting("Blackjack Dealer",{ 
		Type = ModConfigMenu.OptionType.NUMBER,

		CurrentSetting = function()
			return saveData.bdSpawnChance
		end,

		Display = function()
			return "Blackjack Dealer spawn chance: " .. tostring(saveData.bdSpawnChance) .. "%"
		end,

		Minimum = 0,
		Maximum = 99,

		OnChange = function(currentNum)
			saveData.bdSpawnChance = currentNum

            blackjackDealerMod:SaveData(json.encode(saveData))
		end,

		Info = {
			"Percentage chance for Blackjack Dealer",
			"to spawn/replace a machine/beggar/shell game",
            "inside of an arcade."
		}
	})
end

bjPrint("Blackjack dealer mod initialized. Version 2.0")