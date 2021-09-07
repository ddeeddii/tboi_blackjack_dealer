---@diagnostic disable

local blackjackDealer = RegisterMod("Blackjack Dealer", 1)

local game = Game()

local playerHand
local dealerHand
local deck = {2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14} * 4
--                                         J   Q   K   A

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
    for i = 0, 2 do
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
    for card in pairs(hand) do
        if card == "J" or card == "Q" or card == "K" then
            total = total + 10
        elseif card == "A" then

            if total >= 11 then
                total = total + 1
            else
                total = total + 11
            end

        else
            total = total + card  
        end
    end

    return total
end

local function resetGame()
    playerHand = {}
    dealerHand = {}
    deck = {2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14} * 4
end

local function declareWinner(playerHand, dealerHand)
    local winner
    if total(playerHand) == 21 then -- Player has Blackjack
        winner = "player"
    elseif total(dealerHand) == 21 then -- Dealer has Blackjack
        winner = "dealer"
    elseif total(playerHand) > 21 then -- Player bust
        winner = "dealer"
    elseif total(dealerHand) > 21 then -- Dealer bust
        winner = "player"
    elseif total(playerHand) < total(dealerHand) then -- Dealer has more value
        winner = "dealer"
    elseif total(playerHand) > total(dealerHand) then -- Player has more value
        winner = "player"
    end
    return winner
end



