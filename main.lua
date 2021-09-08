---@diagnostic disable

local blackjackDealerMod = RegisterMod("Blackjack Dealer", 1)

local game = Game()

local playerHand
local dealerHand
local deck = {2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14}
--                                         J   Q   K   A                             J   Q   K   A                                 J   Q   K   A                              J   Q   K   A

local function bjPrint(text)
    Isaac.DebugString("BJ| " .. tostring(text))
end

local function shuffle(tbl) -- Credit: https://gist.github.com/Uradamus/10323382
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
    end

-- Blackjack base implementation, heavily "inspired" by https://gist.github.com/mjhea0/5680216
local function deal(deck)
    local hand = {}
    for i = 0, 1 do
        print("dealing deck " .. i)
        shuffle(deck)
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

    for i, card in pairs(hand) do

        bjPrint(card)
        if card == "J" or card == "Q" or card == "K" or card == "A" then
            bjPrint("card delcared as special")
            if card == "A" then
                bjPrint("card declared as ace")
                if total >= 11 then
                    bjPrint("ace adds 1")
                    total = total + 1
                else
                    bjPrint("ace adds 11")
                    total = total + 11
                end                
            else
                bjPrint("special card adds 10")
                total = total + 10
            end
        elseif card ~= "J" or card ~= "Q" or card ~= "K" or card ~= "A" then
            bjPrint("card declared as non-special")
            total = total + card
        end   
    end

    return total
end

local function resetGame()
    playerHand = nil
    dealerHand = nil
    deck = {2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14}
end

local function hasBlackjack(playerHand, dealerHand)
    local pWithBlackjack
    if getTotalInHand(playerHand) == 21 then -- Player has Blackjack
        pWithBlackjack = "player"
    elseif getTotalInHand(dealerHand) == 21 then -- Dealer has Blackjack
        pWithBlackjack = "dealer"
    else
        pWithBlackjack = nil
    end
        return pWithBlackjack
end

local function declareWinner(playerHand, dealerHand)
    local winner = nil
    if getTotalInHand(playerHand) == 21 then -- Player has Blackjack
        winner = "player"
        bjPrint("The player has won the game! (Blackjack)")
        print("The player has won the game! (Blackjack)")
    elseif getTotalInHand(dealerHand) == 21 then -- Dealer has Blackjack
        winner = "dealer"
        bjPrint("The dealer has won the game! (Blackjack)")
        print("The dealer has won the game!(Blackjack)")
    elseif getTotalInHand(playerHand) > 21 then -- Player bust
        winner = "dealer"
        bjPrint("The dealer has won the game! (Player bust)")
        print("The dealer has won the game! (Player bust)")
    elseif getTotalInHand(dealerHand) > 21 then -- Dealer bust
        winner = "player"
        bjPrint("The player has won the game! (Dealer bust)")
        print("The player has won the game!(Dealer bust)")
    elseif getTotalInHand(playerHand) < getTotalInHand(dealerHand) then -- Dealer has more value
        winner = "dealer"
        bjPrint("The dealer has won the game! (More value)")
        print("The dealer has won the game!(More value)")
    elseif getTotalInHand(playerHand) > getTotalInHand(dealerHand) then -- Player has more value
        winner = "player"
        bjPrint("The player has won the game! (More value)")
        print("The player has won the game! (More value)")
    end
end

function blackjackDealerMod:onRender()

    if game:GetFrameCount() == 1 then
        local waitForKeyPress = false
        hitAmount = 0
        dealerHitAmount = 0
        resetGame()
    end

    if playerHand == nil and Input.IsButtonTriggered(Keyboard.KEY_Z, 0) then
        print("Welcome to Blackjack!")
        playerHand = deal(deck)
        dealerHand = deal(deck)
        print("The dealer shows: " .. tostring(dealerHand[1]))
        print("You have: " .. tostring(playerHand[1]) .. " and " .. tostring(playerHand[2]) .. " for a total of " .. tostring(getTotalInHand(playerHand)))
        if hasBlackjack(playerHand, dealerHand) == "player" then
            print("You've won with blackjack.")
        elseif hasBlackjack(playerHand, dealerHand) == "dealer" then
            print("The dealer has won with blackjack.")
        end
        print("Do you wish to hit (Press H) or stand (Press J)?")
        waitForKeyPress = true
    end

    if waitForKeyPress and Input.IsButtonTriggered(Keyboard.KEY_H, 0) then
        waitForKeyPress = false
        print("--- You hit. ---")
        hitAmount = hitAmount + 1
        hit(playerHand)
        if hitAmount == 1 then
            print("You have: " .. tostring(playerHand[1]) .. " and " .. tostring(playerHand[2]) .. " and " .. tostring(playerHand[3]) .. " for a total of " .. tostring(getTotalInHand(playerHand)))
        elseif hitAmount == 2 then
            print("You have: " .. tostring(playerHand[1]) .. " and " .. tostring(playerHand[2]) .. " and " .. tostring(playerHand[3]) .. " and " .. tostring(playerHand[4]) .. " for a total of " .. tostring(getTotalInHand(playerHand)))
        elseif hitAmount == 3 then
            print("You have: " .. tostring(playerHand[1]) .. " and " .. tostring(playerHand[2]) .. " and " .. tostring(playerHand[3]) .. " and " .. tostring(playerHand[4]) .. " and " .. tostring(playerHand[5]) .. " for a total of " .. tostring(getTotalInHand(playerHand)))
        elseif hitAmount == 4 then
            print("You have: " .. tostring(playerHand[1]) .. " and " .. tostring(playerHand[2]) .. " and " .. tostring(playerHand[3]) .. " and " .. tostring(playerHand[4]) .. " and " .. tostring(playerHand[5]) .. " and " .. tostring(playerHand[6]) .. " for a total of " .. tostring(getTotalInHand(playerHand)))
        elseif hitAmount == 5 then
            print("You have: " .. tostring(playerHand[1]) .. " and " .. tostring(playerHand[2]) .. " and " .. tostring(playerHand[3]) .. " and " .. tostring(playerHand[4]) .. " and " .. tostring(playerHand[5]) .. " and " .. tostring(playerHand[6]) .. " and " .. tostring(playerHand[7]) .. " for a total of " .. tostring(getTotalInHand(playerHand)))
        elseif hitAmount == 6 then
            print("You have: " .. tostring(playerHand[1]) .. " and " .. tostring(playerHand[2]) .. " and " .. tostring(playerHand[3]) .. " and " .. tostring(playerHand[4]) .. " and " .. tostring(playerHand[5]) .. " and " .. tostring(playerHand[6]) .. " and " .. tostring(playerHand[7]) .. " and " .. tostring(playerHand[7]) .. " for a total of " .. tostring(getTotalInHand(playerHand)))
        else
            print("You have a total of " .. tostring(getTotalInHand(playerHand)))
        end
       
        if getTotalInHand(playerHand) > 21 then
            print("You busted.")
        else 
            print("Do you wish to hit (Press H) or stand (Press J)?")
            waitForKeyPress = true
        end

    end
        
    if waitForKeyPress and Input.IsButtonTriggered(Keyboard.KEY_J, 0) then
        waitForKeyPress = false
        print("--- You stand ---")
        print("The dealer reveals his cards: " .. tostring(dealerHand[1]) .. " and " .. tostring(dealerHand[2]) .. " for a total of " .. tostring(getTotalInHand(dealerHand)))
        while getTotalInHand(dealerHand) < 17 do
            print("--- The dealer hits ---")
            hit(dealerHand)
            dealerHitAmount = dealerHitAmount + 1
            if dealerHitAmount == 1 then
                print("The dealer hits, his current cards are: " .. tostring(dealerHand[1]) .. " and " .. tostring(dealerHand[2]) .. " and " .. tostring(dealerHand[3]) .. " for a total of " .. tostring(getTotalInHand(dealerHand)))
            elseif dealerHitAmount == 2 then
                print("The dealer hits, his current cards are: " .. tostring(dealerHand[1]) .. " and " .. tostring(dealerHand[2]) .. " and " .. tostring(dealerHand[3]) .. " and " .. tostring(dealerHand[4]) .. " for a total of " .. tostring(getTotalInHand(dealerHand)))
            elseif dealerHitAmount == 3 then
                print("The dealer hits, his current cards are: " .. tostring(dealerHand[1]) .. " and " .. tostring(dealerHand[2]) .. " and " .. tostring(dealerHand[3]) .. " and " .. tostring(dealerHand[4]) .. " and " .. tostring(dealerHand[5]) .. " for a total of " .. tostring(getTotalInHand(dealerHand)))
            elseif dealerHitAmount == 4 then
                print("The dealer hits, his current cards are: " .. tostring(dealerHand[1]) .. " and " .. tostring(dealerHand[2]) .. " and " .. tostring(dealerHand[3]) .. " and " .. tostring(dealerHand[4]) .. " and " .. tostring(dealerHand[5]) .. " and " .. tostring(dealerHand[6]) .. " for a total of " .. tostring(getTotalInHand(dealerHand)))
            else
                print("The dealer hits. Total of his cards is: " .. tostring(getTotalInHand(dealerHand)))
            end

            if getTotalInHand(dealerHand) > 21 then
                print("The dealer busts.")
            end
        end
        declareWinner(playerHand, dealerHand)

    end

end

blackjackDealerMod:AddCallback(ModCallbacks.MC_POST_RENDER, blackjackDealerMod.onRender)


