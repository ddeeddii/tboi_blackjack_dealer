local bj = {}
local hf = require('scripts.helpers')

function bj.newDeck()
    BDMod.deck = {2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14}
    hf.shuffle(BDMod.deck)
    BDMod.data.printDeckInfo = true
    BDMod.data.closeDeckInfoIn = game:GetFrameCount() + 60
end

-- Blackjack base implementation, inspired by https://gist.github.com/mjhea0/5680216
function bj.deal()
    local hand = {}

    if next(BDMod.deck) == nil then -- if deck is empty
        bj.newDeck()
    end

    hf.shuffle(BDMod.deck)
    for i = 0, 1 do
        local card = table.remove(BDMod.deck, 1)
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

function bj.hit(hand)
    if next(BDMod.deck) == nil then -- if BDMod.deck is empty
        bj.newDeck()
    end

    local card = table.remove(BDMod.deck, 1)
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

function bj.checkAces(hand, total) -- Check for soft aces
    hf.bdLog("ACE | Ace eval started")

    local softAce = false
    local aceValue = 0

    if total + 11 > 21 then
        softAce = true
        hf.bdLog("ACE | Ace is soft, " .. total + 11)
    else
        hf.bdLog("ACE | Ace is NOT soft, " .. total + 11)
    end

    for i, card in pairs(hand) do
        hf.bdLog("ACE | Card isnt ace")
         if card == "A" then
            hf.bdLog("ACE | Card is ace")

            if softAce and not hf.has_value(hand, "sA") then
                aceValue = aceValue + 1
                hand[i] = "sA"
                hf.bdLog("ACE | Ace more than and declared soft")
            elseif total < 11 then
                aceValue = aceValue + 11
                -- hand[i] = "hA"
                hf.bdLog("ACE | Ace less than 11")
            else
                aceValue = aceValue + 1
                -- hand[i] = "hA"
                hf.bdLog("ACE | Ace more than 11")
            end

            if card == "sA" then
                hf.bdLog("ACE | Soft ace")
            elseif card == "hA" then
                hf.bdLog("ACE | Hard ace")
            end
        end   

    end

    hf.bdLog("final aceval: " .. aceValue)
    return aceValue

end

function bj.getTotalInHand(hand, log, logReason)
    local total = 0

    if not BDMod then
        log = false
    end

    if log and BDMod and logReason ~= nil then
        hf.bdLog("TOTAL | ====== New total eval started ======")
        hf.bdLog("TOTAL |    Reason: " .. logReason)
        hf.bdLog("TOTAL |    " .. tostring(hand[1]) .. " " .. tostring(hand[2])  .. " " .. tostring(hand[3])  .. " " .. tostring(hand[4]) .. " " .. tostring(hand[5]))
    end

    if hand == BDMod.hands.dealer and not BDMod.data.dealerCardRevealed then

        -- DELAER HAND ONLY!

        if log and BDMod then
            hf.bdLog("TOTAL |    Dealer hand, card not revealed! ")
        end

        local card = hand[1]

        hf.bdLog("TOTAL | Starting evaluation of non-aces, current total: " .. total)

        if log and BDMod then
            hf.bdLog("TOTAL |     -- NEW CARD --")
            hf.bdLog("TOTAL |     Current total: " .. total)
            hf.bdLog("TOTAL |    Card: " .. card)
        end

        if card == "J" or card == "Q" or card == "K" then           
            total = total + 10
        end

        if card ~= "J" and card ~= "Q" and card ~= "K" and card ~= "A" and card ~= "sA" and card ~= "hA" then
            total = total + card
        end


        hf.bdLog("TOTAL |    Starting checkAces: " .. total)

        if hf.has_value(hand, "A") and not hf.has_value(hand, "sA") then
            bj.checkAces(hand, total, log)
            hf.bdLog("TOTAL |Checkaces finished.")
        end

        hf.bdLog("TOTAL |    Starting Ace eval, total: " .. total)

        if card == "sA" or card == "A" then
            hf.bdLog("TOTAL |       sA and hA eval started")
            if card == "sA" then
                hf.bdLog("TOTAL |       sA adds 1, card: " .. card)
                total = total + 1
            elseif card == "A" and total < 11 then
                hf.bdLog("TOTAL |       hA, adds 11, card: " .. card)
                total = total + 11
            else
                hf.bdLog("TOTAL |       x adds 1, card: " .. card)
                total = total + 1
            end
        end

        hf.bdLog("TOTAL |    Eval ended, total: " .. total)

        return total

        -- DEALER HAND ONLY
    else
    
        hf.bdLog("TOTAL |    Dealer hand w. card or / player hand ")
        hf.bdLog("TOTAL | Starting evaluation of non-aces, current total: " .. total)

        for i, card in pairs(hand) do

            if log and BDMod then
                hf.bdLog("TOTAL |     -- NEW CARD --")
                hf.bdLog("TOTAL |     Current total: " .. total)
                hf.bdLog("TOTAL |    Card: " .. card)
            end

            if card == "J" or card == "Q" or card == "K" then           
                total = total + 10
            end

            if card ~= "J" and card ~= "Q" and card ~= "K" and card ~= "A" and card ~= "sA" and card ~= "hA" then
                total = total + card
            end   

        end

        hf.bdLog("TOTAL |    Starting checkAces: " .. total)
        if hf.has_value(hand, "A") and not hf.has_value(hand, "sA") then
            bj.checkAces(hand, total, log)
            hf.bdLog("TOTAL |Checkaces finished.")
        end

        hf.bdLog("TOTAL |    Starting Ace eval, total: " .. total)
        for i, card in pairs(hand) do

            if card == "sA" or card == "A" then
                hf.bdLog("TOTAL |       sA and hA eval started")
                if card == "sA" then
                    hf.bdLog("TOTAL |       sA adds 1, card: " .. card)
                    total = total + 1
                elseif card == "A" and total < 11 then
                    hf.bdLog("TOTAL |       hA, adds 11, card: " .. card)
                    total = total + 11
                else
                    hf.bdLog("TOTAL |       x adds 1, card: " .. card)
                    total = total + 1
                end
            end

        end

        hf.bdLog("TOTAL |    Eval ended, total: " .. total)

        return total
    end
end

function bj.resetGame()
    BDMod.data.hitAmount = 0
    BDMod.data.dealerHitAmount = 0

    BDMod.hands.player = nil
    BDMod.hands.dealer = nil

    BDMod.data.arrowPos = 1
    BDMod.data.controlsDisabledMenu = true
    BDMod.data.dealerCardRevealed = false
    BDMod.data.lockControl = false
    BDMod.data.finishGame = false
    BDMod.data.winnerGot = false

    BDMod.data.standTime = 0
    BDMod.data.doStand = false
    BDMod.data.finishTime = nil
    BDMod.data.displayMenu = false

    BDMod.data.printDeckInfo = false
    BDMod.data.closeDeckInfoIn = 0

    BDMod.data.menuPlayer = nil
end

function bj.declareWinner(ph, dh)
    local winner = nil
    local winMsg = nil
    local playerTotal = bj.getTotalInHand(ph)
    local dealerTotal = bj.getTotalInHand(dh)

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
        hf.bdLog("ERR | Something weird has happened in the Blackjack Dealer mod. Please report this to the mod developer if you can")
        hf.bdLog("ERR | Details: DeclareWinner didnt find a win condition.")
    end

    if not BDMod.data.finishGame then
        bj.resetGame()
    end

    return winner, winMsg
end

return bj