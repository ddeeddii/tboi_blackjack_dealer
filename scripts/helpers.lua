local hf = {}

---@param text string
function hf.bdLog(text)
    if BDMod.enableLogs then
        Isaac.DebugString(game:GetFrameCount() .. " BJ| " .. tostring(text))
        print("BJ| " .. tostring(text))
    end
end

---@param rng RNG
---@param min number
---@param max number
---@return number
function hf.randint(rng, min, max)
    if min > max then
        error("Min greater than Max!")
        return rng:RandomInt(max)
    else
        return min + (rng:RandomInt(max - min + 1))
    end
end

---@param soundName string
function hf.playSound(soundName)
    local sfxm = SFXManager()
    sfxm:Play(soundName)
end

---@param tbl table
---@return table
function hf.shuffle(tbl) -- https://gist.github.com/Uradamus/10323382
    for i = #tbl, 2, -1 do
        local j = hf.randint(BDMod.rng, 1, i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end


---@param tab table
---@param val any
---@return boolean
function hf.has_value (tab, val)
    for _, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

return hf