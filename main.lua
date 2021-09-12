---@diagnostic disable

local blackjackDealerMod = RegisterMod("Blackjack Dealer", 1)

local game = Game()

local playerHand
local dealerHand
local deck = {2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14}
--                                         J   Q   K   A                             J   Q   K   A                                 J   Q   K   A                              J   Q   K   A
local waitForKeyPress
local hitAmount 
local dealerHitAmount 
local displayMenu
local arrowPos
local controlsDisabledMenu
local dealerCardRevealed
local standTime 
local doStand
local finishGame
local lockControl
local finishTime
local winnerGot
local gameWon 

local bjFlags = EntityFlag.FLAG_NO_TARGET | EntityFlag.FLAG_NO_STATUS_EFFECTS


local bjDealerType = Isaac.GetEntityTypeByName("Blackjack Dealer")
local bjDealerVar = Isaac.GetEntityVariantByName("Blackjack Dealer");
local bjEnt = nil
local bjPos
local bjSprite
local wasTouched

local vectorZero = Vector(0, 0)

local specialCards = {Card.CARD_CLUBS_2, Card.CARD_DIAMONDS_2, Card.CARD_SPADES_2, Card.CARD_HEARTS_2, Card.CARD_ACE_OF_CLUBS, Card.CARD_ACE_OF_DIAMONDS, Card.CARD_ACE_OF_SPADES, Card.CARD_ACE_OF_HEARTS, Card.CARD_JOKER, Card.CARD_QUEEN_OF_HEARTS} 

local startRng

local bjDealerSpawnChance 


local f = Font()
f:Load("font/Upheaval.fnt")

local function playSound(soundName) -- PlaySound() "hack"
    local sound_entity = Isaac.Spawn(EntityType.ENTITY_FLY, 0, 0, Vector(500,500), Vector(0,0), nil):ToNPC()
    sound_entity:PlaySound(soundName, 1, 0, false, 1)
    sound_entity:Remove()    
end 

local function bjPrint(text)
    Isaac.DebugString("BJ| " .. tostring(text))
    print("BJ| " .. tostring(text))
end

local function randomObjFromTable(table)
    local tableRng = startRng:RandomInt(#table) + 1

    if tableRng == 0 then
        local tableRng = tableRng + 1
    end

    return table[tableRng]
end

local function shuffle(tbl) -- Credit: https://gist.github.com/Uradamus/10323382
    for i = #tbl, 2, -1 do
        local j = startRng:RandomInt(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
    end

-- Blackjack base implementation, heavily "inspired" by https://gist.github.com/mjhea0/5680216
local function deal(deck)
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

local function getTotalInHand(hand)
    local total = 0

    if hand == dealerHand and dealerCardRevealed == false then
        local card = dealerHand[1]
        if card == "J" or card == "Q" or card == "K" or card == "A" then
            if card == "A" then
                if total >= 11 then
                    total = total + 1
                else
                    total = total + 11
                end                
            else
                total = total + 10
            end

        elseif card ~= "J" or card ~= "Q" or card ~= "K" or card ~= "A" then
            total = total + card
        end

        return total     
    else
        for i, card in pairs(hand) do

            -- bjPrint(card)
            if card == "J" or card == "Q" or card == "K" or card == "A" then
                -- bjPrint("card delcared as special")
                if card == "A" then
                    -- bjPrint("card declared as ace")
                    if total >= 11 then
                        -- bjPrint("ace adds 1")
                        total = total + 1
                    else
                        -- bjPrint("ace adds 11")
                        total = total + 11
                    end                
                else
                    -- bjPrint("special card adds 10")
                    total = total + 10
                end
            elseif card ~= "J" or card ~= "Q" or card ~= "K" or card ~= "A" then
                -- bjPrint("card declared as non-special")
                total = total + card
            end   
        end

        return total
    end
end

local function resetGame()
    waitForKeyPress = false
    hitAmount = 0
    dealerHitAmount = 0
    playerHand = nil
    dealerHand = nil
    arrowPos = 1
    controlsDisabledMenu = true
    dealerCardRevealed = false
    standTime = 0
    doStand = false
    lockControl = false
    finishGame = false
    finishTime = nil
    displayMenu = false
    winnerGot = false
    deck = {2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14}
end

local function declareWinner(playerHand, dealerHand)
    local winner = nil
    if getTotalInHand(playerHand) == 21 then -- Player has Blackjack
        winner = "player"
        -- bjPrint("The player has won the game! (Blackjack)")
        -- print("The player has won the game! (Blackjack)")
    elseif getTotalInHand(dealerHand) == 21 then -- Dealer has Blackjack
        winner = "dealer"
        -- bjPrint("The dealer has won the game! (Blackjack)")
        -- print("The dealer has won the game!(Blackjack)")
    elseif getTotalInHand(playerHand) > 21 then -- Player bust
        winner = "dealer"
        -- bjPrint("The dealer has won the game! (Player bust)")
        -- print("The dealer has won the game! (Player bust)")
    elseif getTotalInHand(dealerHand) > 21 then -- Dealer bust
        winner = "player"
        -- bjPrint("The player has won the game! (Dealer bust)")
        -- print("The player has won the game!(Dealer bust)")
    elseif getTotalInHand(playerHand) < getTotalInHand(dealerHand) then -- Dealer has more value
        winner = "dealer"
        -- bjPrint("The dealer has won the game! (More value)")
        -- print("The dealer has won the game!(More value)")
    elseif getTotalInHand(playerHand) > getTotalInHand(dealerHand) then -- Player has more value
        winner = "player"
        -- bjPrint("The player has won the game! (More value)")
        -- print("The player has won the game! (More value)")
    elseif getTotalInHand(playerHand) == getTotalInHand(dealerHand) then
        winner = "tie"
        -- bjPrint("Push! (Both have the same card values!)")
        -- print("Push! (Both have the same card values!)")
    else
        bjPrint("Something weird has happened in the Blackjack Dealer mod. Please report this to the mod developer if you can")
        bjPrint("Details: DeclareWinner didnt find a win condition.")
    end

    if finishGame == false then
        resetGame()
    end

    return winner
end

local function getWinMessage(playerHand, dealerHand)
    local winMsg = nil
    if getTotalInHand(playerHand) == 21 then -- Player has Blackjack
        winMsg = "You've won the by Blackjack"
    elseif getTotalInHand(dealerHand) == 21 then -- Dealer has Blackjack
        winMsg = "Dealer has won by Blackjack"
    elseif getTotalInHand(playerHand) > 21 then -- Player bust
        winMsg = "Dealer has won by Player bust"
    elseif getTotalInHand(dealerHand) > 21 then -- Dealer bust
        winMsg = "You've won by Dealer bust"
    elseif getTotalInHand(playerHand) < getTotalInHand(dealerHand) then -- Dealer has more value
        winMsg = "Dealer has won by More value"
    elseif getTotalInHand(playerHand) > getTotalInHand(dealerHand) then -- Player has more value
        winMsg = "You've won by More value"
    elseif getTotalInHand(playerHand) == getTotalInHand(dealerHand) then
        winMsg = "Tie! Both have the same values"
    end

    return winMsg
end

function blackjackDealerMod:OnGameStart(isSave)

    if blackjackDealerMod:HasData() == false then
        bjDealerSpawnChance = 50
    else
        bjDealerSpawnChance = blackjackDealerMod:LoadData()
    end

    resetGame()
    bjEnt = nil
    bjPos = nil
    bjSprite = nil
    wasTouched = false
    gameWon = false
    startRng = nil

    local startseed = game:GetSeeds():GetStartSeed()
    startRng = RNG()
    startRng:SetSeed(startseed, 0)

end
blackjackDealerMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, blackjackDealerMod.OnGameStart)

function blackjackDealerMod:onRender()

    -- if game:GetFrameCount() == 1 then
    --     resetGame()
    --     bjEnt = nil
    --     bjPos = nil
    --     bjSprite = nil
    --     wasTouched = false
    --     gameWon = false
    --     startRng = nil

    --     local startseed = game:GetSeeds():GetStartSeed()
    --     startRng = RNG()
    --     startRng:SetSeed(startseed, 0)

    -- end

    if Input.IsActionTriggered(ButtonAction.ACTION_DROP, 0) then
        if displayMenu then
            if finishGame and declareWinner(playerHand, dealerHand) == "player" then
                gameWon = true
            end
            resetGame()
        end
    end

    if displayMenu then

        if controlsDisabledMenu == nil then -- Handle control enable / disable

            controlsDisabledMenu = true

            for i=0, game:GetNumPlayers()-1 do
			    local player = Isaac.GetPlayer(i)

                player.ControlsEnabled = false
            end
        end

        if playerHand == nil then
            -- print("Game started!")
            playerHand = deal(deck)
            dealerHand = deal(deck)

            if getTotalInHand(playerHand) == 21 or getTotalInHand(dealerHand) == 21 then -- Player or dealer has Blackjack
                finishGame = true
            end
        end

        if arrowPos == 1 and Input.IsActionTriggered(ButtonAction.ACTION_SHOOTRIGHT, 0) then
            arrowPos = 2
        elseif arrowPos == 2 and Input.IsActionTriggered(ButtonAction.ACTION_SHOOTLEFT, 0)  then
            arrowPos = 1
        end

        local paperBg = Sprite()
        paperBg:Load("gfx/ui/paperbg.anm2", true)
        paperBg:SetAnimation("main", true)
        paperBg:SetFrame(1)
        paperBg.Scale = Vector(3, 3)
        paperBg:Render(Vector(95, 45), Vector(0,0), Vector(0,0))

        local arrowSprite = Sprite()
        arrowSprite:Load("gfx/ui/arrow.anm2", true)
        arrowSprite:SetAnimation("main", true)
        arrowSprite:SetFrame(1)
        arrowSprite.Scale = Vector(0.3, 0.3)

        if arrowPos == 1 and lockControl == false then
            arrowSprite:Render(Vector(100, 205), Vector(0,0), Vector(0,0)) -- Hit
        elseif arrowPos == 2 and lockControl == false then
            arrowSprite:Render(Vector(300, 205), Vector(0,0), Vector(0,0)) -- Stand
        end

        local cardSprite = Sprite()
        cardSprite:Load("gfx/ui/card.anm2")
        -- cardSprite.Scale = Vector(2, 1.1)

        -- Dealer hand
        if dealerHand ~= nil then
            
            if dealerHand[1] ~= nil then
                cardSprite:SetAnimation(dealerHand[1], true)
                cardSprite:SetFrame(1)
                cardSprite:Render(Vector(180, 85), Vector(0,0), Vector(0,0))
            end
         
            if dealerCardRevealed and dealerHand[2] ~= nil then
                cardSprite:SetAnimation(dealerHand[2], true)
                cardSprite:SetFrame(1)
                cardSprite:Render(Vector(220, 85), Vector(0,0), Vector(0,0))  

            elseif dealerCardRevealed == false and dealerHand[2] ~= nil then
                cardSprite:SetAnimation("back", true)
                cardSprite:SetFrame(1)
                cardSprite:Render(Vector(220, 85), Vector(0,0), Vector(0,0))
            end 

            if dealerHitAmount >= 1 and dealerHand[3] ~= nil then
                cardSprite:SetAnimation(dealerHand[3], true)
                cardSprite:SetFrame(1)
                cardSprite:Render(Vector(260, 85), Vector(0,0), Vector(0,0))
            end

            if dealerHitAmount >= 2 and dealerHand[4] ~= nil then
                cardSprite:SetAnimation(dealerHand[4], true)
                cardSprite:SetFrame(1)
                cardSprite:Render(Vector(300, 85), Vector(0,0), Vector(0,0))
            end

            if dealerHitAmount >= 3 and dealerHand[5] ~= nil then
                cardSprite:SetAnimation(dealerHand[5], true)
                cardSprite:SetFrame(1)
                cardSprite:Render(Vector(340, 85), Vector(0,0), Vector(0,0))
            end

            if dealerHitAmount >= 4 and dealerHand[6] ~= nil then
                cardSprite:SetAnimation(dealerHand[6], true)
                cardSprite:SetFrame(1)
                cardSprite:Render(Vector(380, 85), Vector(0,0), Vector(0,0))
            end

            if dealerHitAmount >= 5 and dealerHand[7] ~= nil then
                cardSprite:SetAnimation(dealerHand[7], true)
                cardSprite:SetFrame(1)
                cardSprite:Render(Vector(400, 85), Vector(0,0), Vector(0,0))
            end

        end


        -- Player hand
        if playerHand ~= nil then

            if playerHand[1] ~= nil then
                cardSprite:SetAnimation(playerHand[1], true)
                cardSprite:SetFrame(1)
                cardSprite:Render(Vector(180, 170), Vector(0,0), Vector(0,0))
            end

            if playerHand[2] ~= nil then
                cardSprite:SetAnimation(playerHand[2], true)
                cardSprite:SetFrame(1)
                cardSprite:Render(Vector(220, 170), Vector(0,0), Vector(0,0))
            end

            if hitAmount >= 1 and playerHand[3] ~= nil then
                cardSprite:SetAnimation(playerHand[3], true)
                cardSprite:SetFrame(1)
                cardSprite:Render(Vector(260, 170), Vector(0,0), Vector(0,0))
            end

            if hitAmount >= 2 and playerHand[4] ~= nil then
                cardSprite:SetAnimation(playerHand[4], true)
                cardSprite:SetFrame(1)
                cardSprite:Render(Vector(300, 170), Vector(0,0), Vector(0,0))
            end

            if hitAmount >= 3 and playerHand[5] ~= nil then
                cardSprite:SetAnimation(playerHand[5], true)    
                cardSprite:SetFrame(1)
                cardSprite:Render(Vector(340, 170), Vector(0,0), Vector(0,0))
            end

            if hitAmount >= 4 and playerHand[6] ~= nil then
                cardSprite:SetAnimation(playerHand[6], true)
                cardSprite:SetFrame(1)
                cardSprite:Render(Vector(380, 170), Vector(0,0), Vector(0,0))
            end

            if hitAmount >= 5 and playerHand[7] ~= nil then
                cardSprite:SetAnimation(playerHand[7], true)
                cardSprite:SetFrame(1)
                cardSprite:Render(Vector(420, 170), Vector(0,0), Vector(0,0))
            end

            if hitAmount >= 6 and playerHand[8] ~= nil then
                cardSprite:SetAnimation(playerHand[8], true)
                cardSprite:SetFrame(1)
                cardSprite:Render(Vector(460, 170), Vector(0,0), Vector(0,0))
            end
        end


        -- Dealer total:
        if dealerHand ~= nil then
            f:DrawString("Total: ", 80, 62, KColor(0,0,0,1), 0, true)
            f:DrawString(tostring(getTotalInHand(dealerHand)), 100, 78, KColor(0,0,0,1), 0, true)
        end

        -- Player total:
        if playerHand ~= nil then
            f:DrawString("Total: ", 80, 151, KColor(0,0,0,1), 0, true)
            f:DrawString(tostring(getTotalInHand(playerHand)), 100, 167, KColor(0,0,0,1), 0, true)
        end

        f:DrawString("Hit", 105, 195, KColor(0,0,0,1), 0, true)
        f:DrawString("Stand", 305, 195 ,KColor(0,0,0,1), 0, true)
        f:DrawString("Dealer's hand", 125, 40, KColor(0,0,0,1), 231, true)
        f:DrawString("Your hand", 75, 128, KColor(0,0,0,1), 0331, true)

        -- Isaac.RenderText("[]", screenPos.X, screenPos.Y, 1 ,1 ,1 ,1 )

        -- print(screenPos)

        if Input.IsActionTriggered(ButtonAction.ACTION_BOMB, 0) and arrowPos == 1 and lockControl == false then -- Hit / stand
            hit(playerHand)
            hitAmount = hitAmount + 1
            playSound(SoundEffect.SOUND_PAPER_OUT)

            if getTotalInHand(playerHand) >= 21 then
                finishGame = true
            end

        elseif Input.IsActionTriggered(ButtonAction.ACTION_BOMB, 0) and arrowPos == 2 and lockControl == false then
            -- print("--- You stand ---")
            standTime = game:GetFrameCount()
            doStand = true
            lockControl = true
            -- bjPrint("1) Standing, controls: " ..  tostring(lockControl) .. " ; dostand: " .. tostring(doStand) .. " ; standtime: " .. tostring(standTime) )
        end

        if doStand then
            if dealerCardRevealed == false and game:GetFrameCount() >= standTime + 60 then
                dealerCardRevealed = true
                -- print("Card revealed!")
                playSound(SoundEffect.SOUND_PAPER_OUT)
                standTime = game:GetFrameCount()
                -- bjPrint("2) Card revealed, standtime: " .. standTime)
                -- bjPrint("3) dealer's hand: " .. dealerHand[1] .. " ; " .. dealerHand[2])
            end

            if getTotalInHand(dealerHand) < 17 then

                -- bjPrint("4) Total in hand less than 17")

                if game:GetFrameCount() >= standTime + 60 then
                    -- bjPrint("5) About to hit.")
                    hit(dealerHand)
                    dealerHitAmount = dealerHitAmount + 1
                    playSound(SoundEffect.SOUND_PAPER_OUT)

                    -- bjPrint("6) Hit, hit count: " .. dealerHitAmount .. " Card 3: " .. tostring(dealerHand[3]) .. " | Card 4: " .. tostring(dealerHand[4]) .. " | Card 5: " .. tostring(dealerHand[5]) .. " | Card 6: " .. tostring(dealerHand[6]))

                    if getTotalInHand(dealerHand) > 21 then
                        -- bjPrint("7) Dealer bust")
                        doStand = false
                        finishGame = true
                        return nil
                    end

                    standTime = game:GetFrameCount()
                    -- bjPrint("8) Fully completed, reseting standTime, standtime: " .. standTime)
                end

            else

                -- bjPrint("9) Total in hand is more than 17 or something else")

                doStand = false
                finishGame = true
                return nil
            end
        end

        if finishGame then
            lockControl = true

            if winnerGot == false then
                winnerGot = true
                declareWinner(playerHand, dealerHand)
            end

            if finishTime == nil then
                finishTime = game:GetFrameCount()
            end

            if game:GetFrameCount() <= finishTime + 70 then
                if declareWinner(playerHand, dealerHand) == "player" then
                    f:DrawString(getWinMessage(playerHand, dealerHand), 78, 110 ,KColor(0,0.5,0,1), 331, true)
                else
                    f:DrawString(getWinMessage(playerHand, dealerHand), 78, 110 ,KColor(0.5,0,0,1), 331, true)
                end
            else
                f:DrawString("Press DROP to exit", 78, 110 ,KColor(0,0,0.5,1), 331, true)
            end
        end

    end

    if displayMenu == false and controlsDisabledMenu then

        controlsDisabledMenu = nil

        for i=0, game:GetNumPlayers()-1 do
            local player = Isaac.GetPlayer(i)

            player.ControlsEnabled = true
        end
        
    end

end
blackjackDealerMod:AddCallback(ModCallbacks.MC_POST_RENDER, blackjackDealerMod.onRender)

function blackjackDealerMod:update(player)

    if bjEnt ~= nil then
        -- print("no nil")
		if bjEnt:GetEntityFlags() ~= bjFlags then
			bjEnt:ClearEntityFlags(bjEnt:GetEntityFlags())
			bjEnt:AddEntityFlags(bjFlags)
			bjEnt.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYERONLY
		end

        for i, entity in pairs(Isaac.GetRoomEntities()) do
            if entity.Type == 1000 and entity.Variant == 1 then
                if bjPos:Distance(entity.Position) < 120 then
                    bjEnt:Kill()
                    bjEnt:Remove()
                    bjEnt = nil
                    bjPos = nil
                    bjSprite = nil
                    return 
                end
            end
        end

        if (bjEnt.Position - player.Position):Length() > 25 then
            wasTouched = false
        end

        if (bjEnt.Position - player.Position):Length() <= 25 and wasTouched == false then -- Collision
            wasTouched = true
            if player:GetNumCoins() >= 5 then
                player:AddCoins(-5)
                bjSprite:Play("PayPrize", false)
            end
        end 

        if bjSprite:IsFinished("PayPrize") then
            bjSprite:SetAnimation("Idle", true)
            bjSprite:SetFrame(1)
            if displayMenu == false then
                displayMenu = true
            end
        end

        if gameWon then
            bjSprite:Play("Prize")
            if bjSprite:IsEventTriggered("Prize") then
                local card = 1
                local rewardItem = 1
                local rewardTrinket = 1
                local rewardRng = nil

                player:AddCoins(5)
                playSound(SoundEffect.SOUND_NICKELPICKUP)

                local rewardRng = startRng:RandomInt(100)
                local rewardSeedRng = startRng:RandomInt(1000)

                if rewardRng <= 39 then
                    local card = randomObjFromTable(specialCards)
                    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, card, Isaac.GetFreeNearPosition(bjPos, 50), Vector(0, 0), bjEnt)
                elseif rewardRng >= 40 and rewardRng <= 59 then
                    local card = Game():GetItemPool():GetCard(rewardSeedRng, true, true, false)
                    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, card, Isaac.GetFreeNearPosition(bjPos, 50), Vector(0, 0), bjEnt)
                    
                    local card = Game():GetItemPool():GetCard(rewardSeedRng+1, true, true, false)
                    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, card, Isaac.GetFreeNearPosition(bjPos, 50), Vector(0, 0), bjEnt)

                    -- local card = Game():GetItemPool():GetCard(rewardSeedRng-1, true, true, false)
                    -- Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, card, Isaac.GetFreeNearPosition(bjPos, 50), Vector(0, 0), bjEnt)
                elseif rewardRng >= 60 and rewardRng <= 74 then
                    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_PENNY, Isaac.GetFreeNearPosition(bjPos, 50), Vector(0, 0), bjEnt)
                    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_PENNY, Isaac.GetFreeNearPosition(bjPos, 50), Vector(0, 0), bjEnt)
                    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_LUCKYPENNY, Isaac.GetFreeNearPosition(bjPos, 50), Vector(0, 0), bjEnt)
                elseif rewardRng >= 75 and rewardRng <= 84 then
                    for i = 0, 1 do
                        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BOMB, BombSubType.BOMB_NORMAL, Isaac.GetFreeNearPosition(bjPos, 50), Vector(0, 0), bjEnt)
                        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_KEY, KeySubType.KEY_NORMAL, Isaac.GetFreeNearPosition(bjPos, 50), Vector(0, 0), bjEnt)
                    end
                elseif rewardRng >= 85 and rewardRng <= 89 then
                    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_DIME, Isaac.GetFreeNearPosition(bjPos, 50), Vector(0, 0), bjEnt)
                elseif rewardRng >= 90 and rewardRng <= 93 then
                    local rewardItem = Game():GetItemPool():GetCollectible(ItemPoolType.POOL_CRANE_GAME, true, rewardSeedRng, 0)
                    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, rewardItem, Isaac.GetFreeNearPosition(bjPos, 50), Vector(0, 0), bjEnt)
                elseif rewardRng == 94 then
                    bjEnt:Kill()
                    bjEnt:Remove()
                    bjEnt = nil
                    bjPos = nil
                    bjSprite = nil
                    return 
                elseif rewardRng >= 95 and rewardRng <= 96 then
                    local rewardTrinket = Game():GetItemPool():GetTrinket(false)
                    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TRINKET, rewardTrinket, Isaac.GetFreeNearPosition(bjPos, 50), Vector(0, 0), bjEnt)
                elseif rewardRng >= 97 and rewardRng <= 99 then
                    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_CHEST, 1, Isaac.GetFreeNearPosition(bjPos, 50), Vector(0, 0), bjEnt)
                end

            end

            if bjSprite:IsFinished("Prize") then
                bjSprite:SetAnimation("Idle", true)
                bjSprite:SetFrame(1)
                gameWon = false
            end
        end

    else
        -- print("yes nil")
        for i, entity in pairs(Isaac.GetRoomEntities()) do
            if entity.Type == 6 and entity.Variant == 72 then
                bjEnt = entity
                bjPos = entity.Position
                bjSprite = entity:GetSprite()
            end
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
        
        if rng:RandomInt(100) <= tonumber(bjDealerSpawnChance) then 
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
				Isaac.Spawn(bjDealerType, bjDealerVar, 0, slot.Position, Vector(0, 0), nil)
				slot:Remove()
			end

        end
    end

    bjEnt = nil
    bjPos = nil
    bjSprite = nil

end
blackjackDealerMod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, blackjackDealerMod.newRoom)

if ModConfigMenu then -- Mod config menu support
	ModConfigMenu.AddSetting("Blackjack Dealer",{ 
		Type = ModConfigMenu.OptionType.NUMBER,

		CurrentSetting = function()
			return bjDealerSpawnChance
		end,

		Display = function()
			return "Blackjack Dealer spawn chance: " .. tostring(bjDealerSpawnChance) .. "%"
		end,

		Minimum = 0,
		Maximum = 99,

		OnChange = function(currentNum)
			bjDealerSpawnChance = currentNum

            blackjackDealerMod:SaveData(bjDealerSpawnChance )
		end,

		Info = {
			"Percentage chance for Blackjack Dealer",
			"to spawn/replace a machine/beggar/shell game",
            "inside of an arcade."
		}
	})
end