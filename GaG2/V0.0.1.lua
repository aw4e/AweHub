if _G._menuCleanup then pcall(_G._menuCleanup) end

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui    = game:GetService("CoreGui")

local AweHub = loadstring(game:HttpGet("https://raw.githubusercontent.com/aw4e/AweHub/dev/UI.lua"))()

if type(require) ~= "function" then
    AweHub:MakeNotify({
        Title   = "Executor Error",
        Content = "Does not support: require()",
        Delay   = 10,
    })
    error("Executor does not support require()", 0)
end

local p  = Players.LocalPlayer
local pg = p.PlayerGui

local SellValueData = require(game.ReplicatedStorage.SharedModules.SellValueData)
local MutationData  = require(game.ReplicatedStorage.SharedModules.MutationData)
local Net           = require(game.ReplicatedStorage.SharedModules.Networking)


local SEND_DELAY  = 10   -- server enforces 10s between SendBatch calls
local BATCH_SIZE  = 20
local SIZE_MULT   = 1.0
local KNEE        = 5.0
local TAIL_EXP    = 1.5
local DEFAULT_EXP = 2.5

local EXP_OVERRIDES = {
    Mushroom = 1.9,
    Bamboo   = 1.75,
}

local SINGLE_HARVEST = {
    Sunflower    = true,
    Mushroom     = true,
    Bamboo       = true,
    Beanstalk    = true,
    ["Thorn Rose"] = true,
}

local KG_COLOR = Color3.fromRGB(80, 255, 120)

local BASE_WEIGHTS = {
    ["Acorn"]           = 1.5,
    ["Apple"]           = 1.5,
    ["Baby Cactus"]     = 1.5,
    ["Banana"]          = 1.5,
    ["Beanstalk"]       = 1.5,
    ["Blueberry"]       = 1.15,
    ["Briar Rose"]      = 9,
    ["Cactus"]          = 1.5,
    ["Cherry"]          = 1.5,
    ["Coconut"]         = 1.5,
    ["Corn"]            = 3,
    ["Dragon Fruit"]    = 3,
    ["Dragon's Breath"] = 7.5,
    ["Ghost Pepper"]    = 7.5,
    ["Glow Mushroom"]   = 7,
    ["Grape"]           = 2,
    ["Green Bean"]      = 0.5,
    ["Horned Melon"]    = 1.125,
    ["Hypnobloom"]      = 9,
    ["Lotus"]           = 1.5,
    ["Mango"]           = 3,
    ["Moon Bloom"]      = 5,
    ["Mushroom"]        = 5,
    ["Pinetree"]        = 1.5,
    ["Poison Apple"]    = 2.25,
    ["Poison Ivy"]      = 2.1,
    ["Pomegranate"]     = 1.5,
    ["Romanesco"]       = 1.5,
    ["Strawberry"]      = 1,
    ["Sunflower"]       = 6,
    ["Thorn Rose"]      = 1.5,
    ["Tomato"]          = 0.9,
    ["Venom Spitter"]   = 9,
    ["Venus Fly Trap"]  = 3,
    ["Pineapple"]       = 1.5,
    ["Bamboo"]          = 1.5,
}

local FRUIT_RARITY = {
    Carrot           = "Common",
    Strawberry       = "Common",
    Blueberry        = "Common",
    Tomato           = "Uncommon",
    Apple            = "Uncommon",
    Tulip            = "Uncommon",
    Corn             = "Rare",
    Bamboo           = "Rare",
    Cactus           = "Rare",
    Pineapple        = "Rare",
    ["Baby Cactus"]  = "Rare",
    ["Horned Melon"] = "Rare",
    ["Briar Rose"]   = "Rare",
    Hypnobloom       = "Rare",
    Mushroom         = "Epic",
    ["Green Bean"]   = "Epic",
    Banana           = "Epic",
    Mango            = "Epic",
    Grape            = "Epic",
    Coconut          = "Epic",
    ["Glow Mushroom"]= "Epic",
    Gold             = "Legendary",
    ["Dragon Fruit"] = "Legendary",
    Sunflower        = "Legendary",
    ["Poison Ivy"]   = "Legendary",
    Acorn            = "Legendary",
    Cherry           = "Legendary",
    ["Ghost Pepper"] = "Mythic",
    ["Poison Apple"] = "Mythic",
    ["Venom Spitter"]= "Mythic",
    Romanesco        = "Mythic",
    ["Venus Fly Trap"]= "Mythic",
    Pomegranate      = "Mythic",
    Mega             = "Mythic",
    Rainbow          = "Mythic",
    ["Dragon's Breath"]= "Super",
    ["Moon Bloom"]   = "Super",
}

local RARITY_NAMES = {
    "Common",
    "Uncommon",
    "Rare",
    "Epic",
    "Legendary",
    "Mythic",
    "Super",
}

local MUTATION_COLORS = {
    Gold       = Color3.fromRGB(255, 215,   0),
    Rainbow    = Color3.fromRGB(255, 120, 255),
    Electric   = Color3.fromRGB(  0, 200, 255),
    Frozen     = Color3.fromRGB(150, 230, 255),
    Bloodlit   = Color3.fromRGB(230,  50,  50),
    Chained    = Color3.fromRGB(200, 200, 200),
    Starstruck = Color3.fromRGB(255, 240, 100),
    Aurora     = Color3.fromRGB(180, 100, 255),
}

local MUT_NAMES = {
    "None",
    "Gold",
    "Rainbow",
    "Electric",
    "Frozen",
    "Bloodlit",
    "Chained",
    "Starstruck",
    "Aurora",
}


local stockMults = {}
local lastT      = 0
local mutCache   = {}

local allConns       = {}
local espConns       = {}
local espTags        = {}
local espRefreshFns  = {}
local espActive      = false
local espCfg         = {
    weightMode = "Below",
    weightKg   = math.huge,
}

local hudConn  = nil
local totalLbl = nil
local cachedFi = nil

local collectRunning       = false
local collectAllRunning    = false
local autoCollectDropRunning = false
local autoDropRunning      = false
local autoDropAllRunning   = false
local autoSellRunning      = false
local autoSellAllRunning   = false

local collectedSet = {}
local dropBusy     = false

local lagConns  = {}
local stored    = {}
local proximityConns = {}
local lagRunning = false
local lagStore  = Instance.new("Folder")
lagStore.Name   = "_LagStore"
lagStore.Parent = p

local FULL_DESTROY_SEEDS = {}


local function track(c)
    if c then table.insert(allConns, c) end
end

local function notify(title, content, delay)
    pcall(function()
        AweHub:MakeNotify({
            Title       = title,
            Description = "",
            Content     = tostring(content or ""),
            Delay       = delay or 4,
        })
    end)
end

local function fmt(n)
    n = tonumber(n) or 0
    if n >= 1e9 then
        return string.format("$%.2fB", n / 1e9)
    elseif n >= 1e6 then
        return string.format("$%.2fM", n / 1e6)
    elseif n >= 1e3 then
        return string.format("$%.1fK", n / 1e3)
    else
        return string.format("$%d", n)
    end
end


local function applyStock(snap)
    local e = snap and snap.entries
    if type(e) ~= "table" then return end

    for name, entry in pairs(e) do
        if type(entry) == "table" and type(entry.multiplier) == "number" then
            stockMults[name] = entry.multiplier
        end
    end

    for k in next, mutCache do
        mutCache[k] = nil
    end

    lastT = 0
    for _, fn in ipairs(espRefreshFns) do
        pcall(fn)
    end
end

pcall(function()
    local ok, snap = pcall(Net.FruitStock.Request.Fire, Net.FruitStock.Request)
    if ok and type(snap) == "table" then
        applyStock(snap)
    end
end)

pcall(function()
    track(Net.FruitStock.Snapshot.OnClientEvent:Connect(applyStock))
end)


local function getMutMult(mutation)
    if mutation == "" then return 1 end

    local cached = mutCache[mutation]
    if cached ~= nil then return cached end

    local ok, raw = pcall(MutationData.ReturnPriceMultiplier, mutation)
    cached = (ok and type(raw) == "number") and raw or 1
    mutCache[mutation] = cached
    return cached
end

local friendsBonus = 1 + (p:GetAttribute("Friends") or 0) * 0.1

pcall(function()
    p:GetAttributeChangedSignal("Friends"):Connect(function()
        friendsBonus = 1 + (p:GetAttribute("Friends") or 0) * 0.1
    end)
end)

local function calcPrice(name, sizeMulti, mutation, decayAlpha)
    local base = SellValueData[name] or 0
    local exp  = EXP_OVERRIDES[name] or DEFAULT_EXP

    local s
    if sizeMulti <= KNEE then
        s = sizeMulti ^ exp
    else
        s = KNEE ^ exp * (sizeMulti / KNEE) ^ math.min(TAIL_EXP, exp)
    end

    local m = getMutMult(mutation or "")
    if SINGLE_HARVEST[name] and m > 1 then
        m = 1 + (m - 1) * 0.15
    end

    local decay = (type(decayAlpha) == "number" and decayAlpha > 0)
        and (1 - math.clamp(decayAlpha, 0, 1) * 0.8)
        or 1

    return math.floor(base * s * SIZE_MULT * m * decay * friendsBonus * (stockMults[name] or 1))
end

local function getWeight(fruitName, sizeMulti)
    local w = (BASE_WEIGHTS[fruitName] or 1) * (sizeMulti or 1)
    return math.floor(w * 100 + 0.5) / 100
end


local function getBackpackFruits()
    local bp = p:FindFirstChild("Backpack")
    local out, seen = {}, {}

    local function scan(c)
        if not c then return end
        for _, v in ipairs(c:GetChildren()) do
            local isFP = v:IsA("Configuration") and v:GetAttribute("FruitProxy") == true
            local isFT = v:IsA("Tool") and v:GetAttribute("HarvestedFruit") == true
            if isFP or isFT then
                local id = v:GetAttribute("Id")
                if id and not seen[id] then
                    seen[id] = true
                    local name = v:GetAttribute("FruitName") or v.Name
                    local sm   = v:GetAttribute("SizeMultiplier") or 1
                    local mut  = v:GetAttribute("Mutation") or ""
                    local decay = v:GetAttribute("DecayAlpha") or 0
                    table.insert(out, {
                        id       = id,
                        name     = name,
                        weight   = v:GetAttribute("Weight") or 0,
                        sm       = sm,
                        mutation = mut,
                        decay    = decay,
                        price    = calcPrice(name, sm, mut, decay),
                        rarity   = FRUIT_RARITY[name] or "Common",
                    })
                end
            end
        end
    end

    scan(bp)
    if p.Character then scan(p.Character) end
    return out
end


local function findMyPlot()
    local g = workspace:FindFirstChild("Gardens")
    if not g then return nil end

    local pid = p:GetAttribute("PlotId")
    if pid then
        local pl = g:FindFirstChild("Plot" .. tostring(pid))
        if pl then return pl end
    end

    for _, pl in ipairs(g:GetChildren()) do
        if pl:GetAttribute("OwnerUserId") == p.UserId then
            return pl
        end
    end
end

local function findMyPlots()
    local g = workspace:FindFirstChild("Gardens")
    if not g then return {} end
    local out = {}
    for _, pl in ipairs(g:GetChildren()) do
        local uid   = pl:GetAttribute("OwnerUserId")
        local owner = pl:GetAttribute("Owner")
        if uid == p.UserId or owner == p.Name then
            table.insert(out, pl)
        end
    end
    return out
end

local function fruitPassHarvest(fruit)
    local name = fruit:GetAttribute("CorePartName") or fruit.Name
    local sm   = fruit:GetAttribute("SizeMulti") or fruit:GetAttribute("SizeMultiplier") or 1
    return passFilter({
        name     = name,
        weight   = fruit:GetAttribute("Weight") or getWeight(name, sm),
        price    = 0,
        rarity   = FRUIT_RARITY[name] or "Common",
        mutation = fruit:GetAttribute("Mutation") or "",
    }, harvestCfg)
end

local function setFruitPrompt(fruit, enabled)
    for _, d in ipairs(fruit:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Name == "HarvestPrompt" then
            d.Enabled = enabled
        end
    end
end

local function setPlotHarvestEnabled(enabled)
    for _, plot in ipairs(findMyPlots()) do
        local plants = plot:FindFirstChild("Plants")
        if not plants then continue end
        for _, plant in ipairs(plants:GetChildren()) do
            local ff = plant:FindFirstChild("Fruits")
            if ff then
                for _, fruit in ipairs(ff:GetChildren()) do
                    if enabled or fruitPassHarvest(fruit) then
                        setFruitPrompt(fruit, enabled)
                    end
                end
            end
        end
    end
end

local function watchHarvestPrompt(ff)
    table.insert(proximityConns, ff.ChildAdded:Connect(function(fruit)
        task.wait(0.15)
        if fruitPassHarvest(fruit) then
            setFruitPrompt(fruit, false)
        end
    end))
end

local function startDisableHarvest()
    for _, c in ipairs(proximityConns) do pcall(function() c:Disconnect() end) end
    proximityConns = {}
    setPlotHarvestEnabled(false)
    for _, plot in ipairs(findMyPlots()) do
        local plants = plot:FindFirstChild("Plants")
        if not plants then continue end
        for _, plant in ipairs(plants:GetChildren()) do
            local ff = plant:FindFirstChild("Fruits")
            if ff then watchHarvestPrompt(ff) end
        end
        table.insert(proximityConns, plants.ChildAdded:Connect(function(pp)
            task.wait(0.2)
            local ff = pp:FindFirstChild("Fruits")
            if ff then watchHarvestPrompt(ff) end
        end))
    end
end

local function stopDisableHarvest()
    for _, c in ipairs(proximityConns) do pcall(function() c:Disconnect() end) end
    proximityConns = {}
    setPlotHarvestEnabled(true)
end


local PASS_ALL = {
    weightKg      = math.huge,
    moneyThreshStr = "",
    onlyRarities  = {},
    onlyMuts      = {},
    onlyTypes     = {},
}

local function passFilter(f, cfg)
    -- Weight check
    local wkg = cfg.weightKg or math.huge
    if wkg < math.huge then
        local ok = (cfg.weightMode == "Above")
            and (f.weight >= wkg)
            or  (f.weight <= wkg)
        if not ok then return false end
    end

    -- Money threshold check
    local mts = cfg.moneyThreshStr
    if mts and mts ~= "" then
        local n = tonumber(mts)
        if not n or n == 0 then return false end
        local dot  = mts:find("%.")
        local step = dot and 10 ^ -(#mts - dot) or 1
        local lo, hi = n * 1e6, (n + step) * 1e6
        if f.price < lo or f.price >= hi then return false end
    end

    -- Rarity check
    if next(cfg.onlyRarities) ~= nil then
        if not cfg.onlyRarities[f.rarity or "Common"] then
            return false
        end
    end

    -- Mutation check
    if next(cfg.onlyMuts) ~= nil then
        local mutKey = (not f.mutation or f.mutation == "")
            and "None"
            or  f.mutation
        if not cfg.onlyMuts[mutKey] then return false end
    end

    -- Fruit type check
    if next(cfg.onlyTypes) ~= nil then
        if not cfg.onlyTypes[f.name] then return false end
    end

    return true
end


local function ensureItemLabel(cell, textSize)
    local lbl = cell:FindFirstChild("_ItemPrice")
    if lbl then
        if lbl.TextSize ~= textSize then
            lbl.TextSize = textSize
        end
        return lbl
    end

    lbl = Instance.new("TextLabel")
    lbl.Name                   = "_ItemPrice"
    lbl.Size                   = UDim2.new(1, -2, 0, textSize * 2 + 2)
    lbl.Position               = UDim2.new(0, 1, 0, 1)
    lbl.BackgroundTransparency = 1
    lbl.TextWrapped            = false

    if cachedFi then
        lbl.Font = cachedFi.Font
        pcall(function() lbl.FontFace = cachedFi.FontFace end)
    end

    lbl.TextSize       = textSize
    lbl.TextColor3     = KG_COLOR
    lbl.TextXAlignment = Enum.TextXAlignment.Right
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.RichText       = true
    lbl.ZIndex         = cell.ZIndex + 3
    lbl.Parent         = cell

    local s = Instance.new("UIStroke", lbl)
    s.Color        = Color3.new(0, 0, 0)
    s.Thickness    = 1.5
    s.Transparency = 0.15

    return lbl
end

local function stampCells(container, priceByWeight, textSize)
    for _, cell in ipairs(container:GetChildren()) do
        if cell:IsA("GuiObject") then
            local nameL  = cell:FindFirstChild("ToolName")
            local countL = cell:FindFirstChild("ToolCount")
            if nameL then
                local lbl = ensureItemLabel(cell, textSize)
                local wStr = countL and countL.Text:match("([%d%.]+)")
                local txt  = ""

                if wStr then
                    local key  = nameL.Text .. "\0" .. string.format("%.2f", tonumber(wStr) or 0)
                    local pr   = priceByWeight[key]
                    local mult = stockMults[nameL.Text]
                    local ms   = ""

                    if mult and mult ~= 1 then
                        ms = string.format(
                            '\n<font color="rgb(255,210,60)">x%.2f</font>',
                            mult
                        )
                    end

                    txt = pr and (fmt(pr) .. ms) or ""
                end

                if lbl.Text ~= txt then
                    lbl.Text = txt
                end
            end
        end
    end
end

local function startHUD()
    if hudConn then return end

    local bg = pg:WaitForChild("BackpackGui", 10)
    if not bg then return end

    local bp2 = bg:WaitForChild("Backpack")
    local inv = bp2:WaitForChild("Inventory")
    local fi  = inv:WaitForChild("FruitInventory")
    cachedFi  = fi
    local sf  = inv:FindFirstChild("ScrollingFrame")
    local hb  = bp2:FindFirstChild("HotBar") or bp2:FindFirstChild("Hotbar")

    for _, nm in ipairs({"_PriceTotalInject", "_PriceInject"}) do
        local x = fi:FindFirstChild(nm)
        if x then x:Destroy() end
    end
    task.wait()

    -- Total price label
    totalLbl = Instance.new("TextLabel")
    totalLbl.Name                   = "_PriceTotalInject"
    totalLbl.BackgroundTransparency = 1
    totalLbl.Font                   = fi.Font
    totalLbl.TextSize               = fi.TextSize
    pcall(function() totalLbl.FontFace = fi.FontFace end)
    totalLbl.TextColor3     = KG_COLOR
    totalLbl.TextXAlignment = Enum.TextXAlignment.Left
    totalLbl.TextYAlignment = Enum.TextYAlignment.Center
    totalLbl.Size           = UDim2.new(0, 260, 1, 0)
    totalLbl.ZIndex         = fi.ZIndex + 1
    totalLbl.Text           = ""
    totalLbl.Position       = UDim2.new(
        0,
        (fi.TextBounds.X > 10 and fi.TextBounds.X or 175) + 10,
        0, 0
    )
    totalLbl.Parent = fi

    local s = Instance.new("UIStroke", totalLbl)
    s.Color        = Color3.new(0, 0, 0)
    s.Thickness    = 1.5
    s.Transparency = 0.15

    pcall(function()
        track(fi:GetPropertyChangedSignal("TextBounds"):Connect(function()
            if not (totalLbl and totalLbl.Parent) then return end
            local bx = fi.TextBounds.X
            if bx > 10 then
                totalLbl.Position = UDim2.new(0, bx + 10, 0, 0)
            end
        end))
    end)

    pcall(function()
        local bp0 = p:WaitForChild("Backpack", 5)
        if bp0 then
            track(bp0.ChildAdded:Connect(function()   lastT = 0 end))
            track(bp0.ChildRemoved:Connect(function() lastT = 0 end))
        end
    end)

    local priceByWeight = {}

    hudConn = RunService.Heartbeat:Connect(function()
        if tick() - lastT < 1.5 then return end
        lastT = tick()

        pcall(function()
            local bp = p:FindFirstChild("Backpack")
            if not bp then return end

            for k in next, priceByWeight do
                priceByWeight[k] = nil
            end

            local total = 0

            local function scanContainer(c)
                for _, v in ipairs(c:GetChildren()) do
                    if v:GetAttribute("HarvestedFruit") then
                        local name  = v:GetAttribute("FruitName") or v.Name
                        local price = calcPrice(
                            name,
                            v:GetAttribute("SizeMultiplier") or 1,
                            v:GetAttribute("Mutation") or "",
                            v:GetAttribute("DecayAlpha") or 0
                        )
                        total = total + price

                        local w   = v:GetAttribute("Weight") or 0
                        local key = name .. "\0" .. string.format("%.2f", math.floor(w * 100 + 0.5) / 100)
                        if not priceByWeight[key] then
                            priceByWeight[key] = price
                        end
                    end
                end
            end

            scanContainer(bp)
            if p.Character then scanContainer(p.Character) end

            if totalLbl and totalLbl.Parent then
                local txt = total == 0 and "" or fmt(total)
                if totalLbl.Text ~= txt then
                    totalLbl.Text = txt
                end
            end

            local ugf = sf and sf:FindFirstChild("UIGridFrame")
            if ugf then stampCells(ugf, priceByWeight, 14) end
            if hb  then stampCells(hb,  priceByWeight, 11) end
        end)
    end)

    track(hudConn)
end

local function stopHUD()
    if hudConn then
        hudConn:Disconnect()
        hudConn = nil
    end

    if totalLbl and totalLbl.Parent then
        totalLbl:Destroy()
        totalLbl = nil
    end

    pcall(function()
        local bg = pg:FindFirstChild("BackpackGui")
        if not bg then return end

        local bp2 = bg.Backpack
        local ugf = bp2.Inventory.ScrollingFrame:FindFirstChild("UIGridFrame")
        local hb  = bp2:FindFirstChild("HotBar") or bp2:FindFirstChild("Hotbar")

        for _, cont in ipairs({ugf, hb}) do
            if cont then
                for _, cell in ipairs(cont:GetChildren()) do
                    local l = cell:FindFirstChild("_ItemPrice")
                    if l then l:Destroy() end
                end
            end
        end
    end)
end


local function makeMutColorHex(mut)
    local c = mut and MUTATION_COLORS[mut]
    if not c then return nil end
    return string.format(
        "rgb(%d,%d,%d)",
        math.floor(c.R * 255),
        math.floor(c.G * 255),
        math.floor(c.B * 255)
    )
end

local function buildESPText(name, weight, sm, mut)
    local kgStr = weight
        and string.format('<font color="rgb(80,255,120)">[%.2fkg]</font>', weight)
        or ""

    local stockMult = stockMults[name] or 1
    local smStr = stockMult ~= 1
        and string.format(" [%.2fx]", stockMult)
        or ""

    local price     = calcPrice(name, sm or 1, mut or "", 0)
    local priceStr  = string.format(' <font color="rgb(255,220,80)">%s</font>', fmt(price))

    local mutStr = ""
    if mut and mut ~= "" then
        local mc = makeMutColorHex(mut)
        mutStr = mc
            and string.format(' <font color="%s">[%s]</font>', mc, mut)
            or  (" [" .. mut .. "]")
    end

    return name .. " " .. kgStr .. smStr .. priceStr .. mutStr
end

local function attachESP(fruitModel)
    if espTags[fruitModel] then return end

    local attachTo = fruitModel:FindFirstChildWhichIsA("BasePart")
    if fruitModel:IsA("BasePart") then
        attachTo = fruitModel
    end
    if not attachTo then
        for _, d in ipairs(fruitModel:GetDescendants()) do
            if d:IsA("BasePart") then
                attachTo = d
                break
            end
        end
    end
    if not attachTo then return end

    local name   = fruitModel:GetAttribute("CorePartName") or fruitModel.Name
    local sm     = fruitModel:GetAttribute("SizeMulti") or fruitModel:GetAttribute("SizeMultiplier") or 1
    local mut    = fruitModel:GetAttribute("Mutation") or ""
    local weight = fruitModel:GetAttribute("Weight") or getWeight(name, sm)

    -- Weight filter
    if espCfg.weightKg < math.huge then
        local pass = (espCfg.weightMode == "Above")
            and (weight >= espCfg.weightKg)
            or  (weight <= espCfg.weightKg)
        if not pass then return end
    end

    -- Billboard
    local bb = Instance.new("BillboardGui")
    bb.Name           = "_FruitESP"
    bb.Adornee        = attachTo
    bb.Size           = UDim2.fromOffset(220, 36)
    bb.StudsOffset    = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop    = true
    bb.LightInfluence = 0
    bb.Parent         = CoreGui

    -- Label
    local lbl = Instance.new("TextLabel", bb)
    lbl.Size                   = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 14
    lbl.TextColor3             = Color3.fromRGB(255, 255, 255)
    lbl.TextXAlignment         = Enum.TextXAlignment.Center
    lbl.TextYAlignment         = Enum.TextYAlignment.Center
    lbl.RichText               = true
    lbl.TextWrapped            = false
    lbl.Text                   = buildESPText(name, weight, sm, mut ~= "" and mut or nil)

    local stroke = Instance.new("UIStroke", lbl)
    stroke.Color        = Color3.new(0, 0, 0)
    stroke.Thickness    = 1.5
    stroke.Transparency = 0.1

    espTags[fruitModel] = bb

    -- Refresh function
    local function refreshFruitLabel()
        if not lbl.Parent then return end
        local sm2 = fruitModel:GetAttribute("SizeMulti") or fruitModel:GetAttribute("SizeMultiplier") or 1
        local m2  = fruitModel:GetAttribute("Mutation") or ""
        local w2  = fruitModel:GetAttribute("Weight") or getWeight(name, sm2)
        lbl.Text  = buildESPText(name, w2, sm2, m2 ~= "" and m2 or nil)
    end

    table.insert(espRefreshFns, refreshFruitLabel)

    -- Attribute change listener
    table.insert(espConns, fruitModel.AttributeChanged:Connect(function(attr)
        if attr == "Mutation" or attr == "SizeMulti" or attr == "SizeMultiplier" or attr == "Weight" then
            refreshFruitLabel()
        end
    end))

    -- Cleanup on remove
    fruitModel.AncestryChanged:Connect(function()
        if not fruitModel.Parent then
            if bb and bb.Parent then bb:Destroy() end
            espTags[fruitModel] = nil
            for i, fn in ipairs(espRefreshFns) do
                if fn == refreshFruitLabel then
                    table.remove(espRefreshFns, i)
                    break
                end
            end
        end
    end)
end

local function scanGardenForESP()
    local g = workspace:FindFirstChild("Gardens")
    if not g then return end

    for _, plot in ipairs(g:GetChildren()) do
        local plants = plot:FindFirstChild("Plants")
        if plants then
            for _, plant in ipairs(plants:GetChildren()) do
                local ff = plant:FindFirstChild("Fruits")
                if ff then
                    for _, fruit in ipairs(ff:GetChildren()) do
                        pcall(attachESP, fruit)
                    end
                    table.insert(espConns, ff.ChildAdded:Connect(function(fr)
                        task.wait(0.1)
                        pcall(attachESP, fr)
                    end))
                end
            end
            table.insert(espConns, plants.ChildAdded:Connect(function(plant2)
                task.wait(0.2)
                local ff2 = plant2:FindFirstChild("Fruits")
                if ff2 then
                    for _, fr in ipairs(ff2:GetChildren()) do
                        pcall(attachESP, fr)
                    end
                    table.insert(espConns, ff2.ChildAdded:Connect(function(fr)
                        task.wait(0.1)
                        pcall(attachESP, fr)
                    end))
                end
            end))
        end
    end
end

local function stopFruitESP()
    for _, c in ipairs(espConns) do
        pcall(function() c:Disconnect() end)
    end
    espConns = {}

    for model, bb in pairs(espTags) do
        if bb and bb.Parent then bb:Destroy() end
        espTags[model] = nil
    end
end


local harvestCfg = {
    weightMode   = "Below",
    weightKg     = math.huge,
    onlyTypes    = {},
    onlyRarities = {},
    onlyMuts     = {},
}

local collectCfg = {
    onlyMuts     = {},
    onlyTypes    = {},
    onlyRarities = {},
    weightMode   = "Below",
    weightKg     = math.huge,
}

local function collectNow(cfgOvr)
    local cfg  = cfgOvr or collectCfg
    local plot = findMyPlot()
    if not plot then return 0 end

    local plants = plot:FindFirstChild("Plants")
    if not plants then return 0 end

    local n = 0
    for _, plant in ipairs(plants:GetChildren()) do
        local ff = plant:FindFirstChild("Fruits")
        if ff then
            for _, fruit in ipairs(ff:GetChildren()) do
                local age    = fruit:GetAttribute("Age") or 0
                local maxAge = fruit:GetAttribute("MaxAge") or 999
                local fid    = fruit:GetAttribute("FruitId")
                local pid    = fruit:GetAttribute("PlantId")
                local cname  = fruit:GetAttribute("CorePartName") or ""

                local fakeFruit = {
                    name     = cname,
                    weight   = 0,
                    price    = 0,
                    rarity   = FRUIT_RARITY[cname] or "Common",
                    mutation = fruit:GetAttribute("Mutation") or "",
                }

                if age >= maxAge and fid and pid and not collectedSet[fid] and passFilter(fakeFruit, cfg) then
                    collectedSet[fid] = true
                    pcall(function() Net.Garden.CollectFruit:Fire(pid, fid) end)
                    n += 1
                    task.wait(0.15)
                end
            end
        end
    end
    return n
end

local function startAutoCollect()
    collectRunning = true
    collectedSet   = {}
    task.spawn(function()
        while collectRunning do
            pcall(collectNow)
            task.wait(0.1)
        end
    end)
end

local function stopAutoCollect()
    collectRunning = false
    collectedSet   = {}
end

local function startAutoCollectAll()
    collectAllRunning = true
    task.spawn(function()
        while collectAllRunning do
            pcall(collectNow, PASS_ALL)
            task.wait(0.1)
        end
    end)
end

local function stopAutoCollectAll()
    collectAllRunning = false
end


local function collectDropItems()
    local char = p.Character
    if not char then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    local di = workspace:FindFirstChild("DroppedItems")
    if not di then return end

    for _, item in ipairs(di:GetChildren()) do
        if not autoCollectDropRunning then break end

        local pa = item:FindFirstChild("PromptAnchor")
        if pa and pa:IsA("BasePart") then
            local prompt = pa:FindFirstChildOfClass("ProximityPrompt")
            if prompt then
                hum:MoveTo(pa.Position)
                local t = tick()
                while autoCollectDropRunning
                    and (hrp.Position - pa.Position).Magnitude > 6
                    and tick() - t < 20
                do
                    task.wait(0.2)
                end
                if (hrp.Position - pa.Position).Magnitude <= 8 then
                    pcall(function() fireproximityprompt(prompt) end)
                    task.wait(0.3)
                end
            end
        end
    end
end

local function startAutoCollectDrop()
    autoCollectDropRunning = true
    task.spawn(function()
        while autoCollectDropRunning do
            pcall(collectDropItems)
            task.wait(1)
        end
    end)
end

local function stopAutoCollectDrop()
    autoCollectDropRunning = false
end


local giftCfg = {
    target         = "",
    moneyThreshStr = "",
}

local function doSendItems(items, totalPrice, typeInfo)
    task.spawn(function()
        local ok1, userId = pcall(function()
            return Net.Mailbox.LookupPlayer:Fire(giftCfg.target)
        end)

        if not ok1 or type(userId) ~= "number" or userId <= 0 then
            notify("Gift", "Player not found: " .. giftCfg.target, 4)
            return
        end

        local sent    = 0
        local failed  = 0
        local lastMsg = nil

        for i = 1, #items, BATCH_SIZE do
            local chunk = {}
            for j = i, math.min(i + BATCH_SIZE - 1, #items) do
                table.insert(chunk, items[j])
            end

            local ok2, success, msg = pcall(function()
                return Net.Mailbox.SendBatch:Fire(userId, chunk, "")
            end)

            if ok2 and success == true then
                sent += #chunk
            else
                -- Retry once after full cooldown
                task.wait(SEND_DELAY)
                local ok3, success2, msg2 = pcall(function()
                    return Net.Mailbox.SendBatch:Fire(userId, chunk, "")
                end)

                if ok3 and success2 == true then
                    sent += #chunk
                else
                    failed += #chunk
                    lastMsg = tostring(msg2 or msg or success2 or success or "SendBatch rejected")
                end
            end

            -- Wait full cooldown before next batch
            if i + BATCH_SIZE <= #items then
                task.wait(SEND_DELAY)
            end
        end

        -- Build notification
        local lines = {}

        -- Header
        if failed > 0 then
            table.insert(lines, string.format("✅ %d sent  ❌ %d failed", sent, failed))
        else
            table.insert(lines, string.format("✅ %d/%d sent", sent, #items))
        end

        table.insert(lines, string.format("To: %s  |  Value: %s", giftCfg.target, fmt(totalPrice)))
        table.insert(lines, "")

        -- Fruit breakdown
        local sorted = {}
        for name, info in pairs(typeInfo) do
            table.insert(sorted, { name = name, info = info })
        end
        table.sort(sorted, function(a, b) return a.info.total > b.info.total end)

        local shown = 0
        for _, entry in ipairs(sorted) do
            if shown >= 6 then break end
            local name = entry.name
            local info = entry.info
            local smStr = info.sm and string.format(" [%.2fx]", info.sm) or ""
            table.insert(lines, string.format("  %s x%d%s  →  %s", name, info.count, smStr, fmt(info.total)))
            shown += 1
        end

        if #sorted > shown then
            table.insert(lines, string.format("  +%d more...", #sorted - shown))
        end

        if failed > 0 and lastMsg then
            table.insert(lines, "")
            table.insert(lines, "Error: " .. lastMsg)
        end

        notify("Gift Done", table.concat(lines, "\n"), 8)
    end)
end

local function sendGift()
    if giftCfg.target == "" then
        notify("Gift", "Target username is empty!", 3)
        return
    end

    local budgetN = tonumber(giftCfg.moneyThreshStr)
    if not budgetN or budgetN <= 0 then
        notify("Gift", "Money Threshold is empty or 0", 3)
        return
    end

    local cap    = budgetN * 1e6
    local fruits = getBackpackFruits()
    local items     = {}
    local totalPrice = 0
    local typeInfo   = {}

    -- Sort by price descending so we send highest value first
    table.sort(fruits, function(a, b) return a.price > b.price end)

    for _, f in ipairs(fruits) do
        if totalPrice >= cap then break end

        local price = calcPrice(f.name, f.sm or 1, f.mutation or "", f.decay or 0)
        table.insert(items, {
            Category = "HarvestedFruits",
            ItemKey  = f.id,
            Count    = 1,
        })
        totalPrice += price

        if not typeInfo[f.name] then
            typeInfo[f.name] = {
                count = 0,
                total = 0,
                sm    = stockMults[f.name],
            }
        end
        typeInfo[f.name].count += 1
        typeInfo[f.name].total += price
    end

    if #items == 0 then
        notify("Gift", "No fruits in inventory", 3)
        return
    end

    doSendItems(items, totalPrice, typeInfo)
end

local function sendGiftAll()
    if giftCfg.target == "" then
        notify("Gift", "Target username is empty!", 3)
        return
    end

    local fruits = getBackpackFruits()
    local items     = {}
    local totalPrice = 0
    local typeInfo   = {}

    for _, f in ipairs(fruits) do
        local price = calcPrice(f.name, f.sm or 1, f.mutation or "", f.decay or 0)
        table.insert(items, {
            Category = "HarvestedFruits",
            ItemKey  = f.id,
            Count    = 1,
        })
        totalPrice += price

        if not typeInfo[f.name] then
            typeInfo[f.name] = {
                count = 0,
                total = 0,
                sm    = stockMults[f.name],
            }
        end
        typeInfo[f.name].count += 1
        typeInfo[f.name].total += price
    end

    if #items == 0 then
        notify("Gift", "No fruits in inventory", 3)
        return
    end

    doSendItems(items, totalPrice, typeInfo)
end


local dropCfg = {
    weightMode   = "Below",
    weightKg     = math.huge,
    onlyMuts     = {},
    onlyTypes    = {},
    onlyRarities = {},
    autoDrop     = false,
    autoInterval = 0.1,
}

local function dropFiltered(cfgOvr)
    if dropBusy then return 0 end
    dropBusy = true

    local cfg     = cfgOvr or dropCfg
    local fruits  = getBackpackFruits()
    local targets = {}

    for _, f in ipairs(fruits) do
        if passFilter(f, cfg) then
            table.insert(targets, f)
        end
    end

    -- Promote FruitProxy → Tool
    local bp = p:FindFirstChild("Backpack")
    for _, f in ipairs(targets) do
        pcall(function()
            if bp then
                for _, v in ipairs(bp:GetChildren()) do
                    if v:GetAttribute("Id") == f.id and v:IsA("Configuration") then
                        Net.Backpack.PromoteFruit:Fire(f.id)
                        task.wait(0.1)
                        break
                    end
                end
            end
        end)
    end

    -- Wait for Tools to appear
    local t0   = tick()
    local ready = {}

    while tick() - t0 < 5 do
        ready = {}
        local count = 0

        if bp then
            for _, v in ipairs(bp:GetChildren()) do
                if v:IsA("Tool") then
                    local id = v:GetAttribute("Id")
                    for _, f in ipairs(targets) do
                        if f.id == id then
                            ready[id] = v
                            count += 1
                            break
                        end
                    end
                end
            end
        end

        if count >= #targets then break end
        task.wait(0.1)
    end

    -- Drop each fruit
    local n = 0
    for _, f in ipairs(targets) do
        pcall(function()
            local tool = ready[f.id]
            if not tool and bp then
                for _, v in ipairs(bp:GetChildren()) do
                    if v:IsA("Tool") and v:GetAttribute("Id") == f.id then
                        tool = v
                        break
                    end
                end
            end

            if tool and tool:IsA("Tool") and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum:UnequipTools() end

                tool.Parent = p.Character
                task.wait(0.15)

                Net.DroppedItem.RequestDrop:Fire("HarvestedFruits", f.id)
                task.wait(0.3)

                if hum then hum:UnequipTools() end
            end
        end)
        n += 1
        task.wait(0.1)
    end

    dropBusy = false
    return n
end

local function startAutoDrop()
    autoDropRunning = true
    task.spawn(function()
        while autoDropRunning do
            pcall(dropFiltered)
            task.wait(dropCfg.autoInterval)
        end
    end)
end

local function stopAutoDrop()
    autoDropRunning = false
end

local function startAutoDropAll()
    autoDropAllRunning = true
    task.spawn(function()
        while autoDropAllRunning do
            pcall(dropFiltered, PASS_ALL)
            task.wait(dropCfg.autoInterval)
        end
    end)
end

local function stopAutoDropAll()
    autoDropAllRunning = false
end


local sellCfg = {
    weightMode   = "Below",
    weightKg     = math.huge,
    onlyMuts     = {},
    onlyTypes    = {},
    onlyRarities = {},
    autoInterval = 0.1,
}

local function sellFiltered()
    local ok, r = pcall(function()
        return Net.NPCS.SellAll:Fire()
    end)
    return (ok and type(r) == "table") and (r.FruitCount or 0) or 0
end

local function startAutoSell()
    autoSellRunning = true
    task.spawn(function()
        while autoSellRunning do
            pcall(sellFiltered)
            task.wait(sellCfg.autoInterval)
        end
    end)
end

local function stopAutoSell()
    autoSellRunning = false
end

local function startAutoSellAll()
    autoSellAllRunning = true
    task.spawn(function()
        while autoSellAllRunning do
            pcall(function()
                local ok, r = pcall(function()
                    return Net.NPCS.SellAll:Fire()
                end)
                if ok and type(r) == "table" then
                    notify(
                        "Sell All ✅",
                        string.format("Sold %d | %s", r.FruitCount or 0, fmt(r.TotalSellValue or 0)),
                        3
                    )
                end
            end)
            task.wait(sellCfg.autoInterval)
        end
    end)
end

local function stopAutoSellAll()
    autoSellAllRunning = false
end



local KEEP = {
    Fruits              = true,
    FruitSpawnLocations = true,
}

local function getOrMakeFolder(parent, name)
    local f = parent:FindFirstChild(name)
    if not f then
        f = Instance.new("Folder")
        f.Name   = name
        f.Parent = parent
    end
    return f
end

local function hideChild(child, origParent, bucket)
    child.Parent = bucket
    table.insert(stored, { child = child, plant = origParent })
end

local function cleanPlant(plant, plotBucket)
    local seedName    = plant:GetAttribute("SeedName")
    local fullHide    = seedName and FULL_DESTROY_SEEDS[seedName]
    local plantBucket = getOrMakeFolder(plotBucket, plant.Name)

    for _, child in ipairs(plant:GetChildren()) do
        if child.Name == "_LagStore" then continue end
        if fullHide or not KEEP[child.Name] then
            hideChild(child, plant, plantBucket)
        end
    end
end

local function stopLag()
    lagRunning = false
    for _, c in ipairs(lagConns) do pcall(function() c:Disconnect() end) end
    lagConns = {}

    for _, entry in ipairs(stored) do
        pcall(function()
            if entry.plant and entry.plant.Parent then
                entry.child.Parent = entry.plant
            else
                entry.child:Destroy()
            end
        end)
    end
    stored = {}
end

local function startLag()
    stopLag()
    lagRunning = true
    for _, plot in ipairs(workspace.Gardens:GetChildren()) do
        local plants = plot:FindFirstChild("Plants")
        if plants then
            local plotBucket = getOrMakeFolder(lagStore, plot.Name)
            for _, plant in ipairs(plants:GetChildren()) do
                cleanPlant(plant, plotBucket)
            end
            table.insert(lagConns, plants.ChildAdded:Connect(function(pp)
                task.wait(0.1)
                cleanPlant(pp, getOrMakeFolder(lagStore, plot.Name))
            end))
        end
    end
end

local function getSeedNames()
    local out, seen = {}, {}
    for _, plot in ipairs(workspace.Gardens:GetChildren()) do
        local plants = plot:FindFirstChild("Plants")
        if plants then
            for _, plant in ipairs(plants:GetChildren()) do
                local sn = plant:GetAttribute("SeedName")
                if sn and not seen[sn] then
                    seen[sn] = true
                    table.insert(out, sn)
                end
            end
        end
    end
    table.sort(out)
    return out
end


local function computeInfoStats()
    local plotCount, plotMaxKg, plotTotalValue = 0, 0, 0
    local plotByRarity = {}
    local g = workspace:FindFirstChild("Gardens")

    if g then
        for _, plot in ipairs(g:GetChildren()) do
            local plants = plot:FindFirstChild("Plants")
            if plants then
                for _, plant in ipairs(plants:GetChildren()) do
                    local ff = plant:FindFirstChild("Fruits")
                    if ff then
                        for _, fruit in ipairs(ff:GetChildren()) do
                            local n2   = fruit:GetAttribute("CorePartName") or fruit.Name
                            local sm2  = fruit:GetAttribute("SizeMulti") or fruit:GetAttribute("SizeMultiplier") or 1
                            local mut2 = fruit:GetAttribute("Mutation") or ""
                            local w    = fruit:GetAttribute("Weight") or getWeight(n2, sm2)
                            local price = calcPrice(n2, sm2, mut2, 0)
                            local rarity = FRUIT_RARITY[n2] or "Common"

                            plotCount += 1
                            plotTotalValue += price
                            if w > plotMaxKg then plotMaxKg = w end

                            plotByRarity[rarity] = (plotByRarity[rarity] or 0) + 1
                        end
                    end
                end
            end
        end
    end

    local fruits       = getBackpackFruits()
    local invMaxKg     = 0
    local invTotal     = 0
    local invByRarity  = {}

    for _, f in ipairs(fruits) do
        if f.weight > invMaxKg then invMaxKg = f.weight end
        invTotal += f.price
        invByRarity[f.rarity] = (invByRarity[f.rarity] or 0) + 1
    end

    return {
        plotCount      = plotCount,
        plotMaxKg      = plotMaxKg,
        plotTotalValue = plotTotalValue,
        plotByRarity   = plotByRarity,
        invCount       = #fruits,
        invMaxKg       = invMaxKg,
        invTotal       = invTotal,
        invByRarity    = invByRarity,
    }
end


local function doCleanup()
    for _, c in ipairs(allConns) do
        pcall(function() c:Disconnect() end)
    end
    allConns = {}

    stopHUD()
    stopLag()
    stopFruitESP()
    stopDisableHarvest()
    stopAutoCollect()
    stopAutoCollectAll()
    stopAutoCollectDrop()
    stopAutoSell()
    stopAutoSellAll()
    stopAutoDrop()
    stopAutoDropAll()
end

_G._menuCleanup = doCleanup


local Window = AweHub:Window({
    Title  = "Awe Hub",
    Footer = "Grow a Gardens 2 | By 0xAw4e",
    Color  = Color3.fromRGB(255, 165, 0),
})

local Tabs = {
    Info    = Window:AddTab({ Name = "Info",    Icon = "stat"    }),
    Main    = Window:AddTab({ Name = "Main",    Icon = "menu"    }),
    Collect = Window:AddTab({ Name = "Collect", Icon = "bag"     }),
    Gift    = Window:AddTab({ Name = "Gift",    Icon = "payment" }),
    Sell    = Window:AddTab({ Name = "Sell",    Icon = "cart"    }),
    Drop    = Window:AddTab({ Name = "Drop",    Icon = "alert"   }),
}


local function buildRarityStr(byRarity)
    local parts = {}
    for _, r in ipairs(RARITY_NAMES) do
        local count = byRarity[r]
        if count and count > 0 then
            table.insert(parts, r .. ": " .. count)
        end
    end
    return #parts > 0 and table.concat(parts, " | ") or "None"
end

local InfoSection    = Tabs.Info:AddSection("Garden", true)
local InfoGarden     = InfoSection:AddParagraph({ Title = "Garden", Content = "Loading..." })
local InfoInventory  = Tabs.Info:AddSection("Inventory", true)
local InfoInv        = InfoInventory:AddParagraph({ Title = "Inventory", Content = "Loading..." })

task.spawn(function()
    while true do
        task.wait(3)
        pcall(function()
            local s = computeInfoStats()

            -- Garden stats
            local gardenLines = {
                string.format("Fruits: %d  |  Max: %.2f kg", s.plotCount, s.plotMaxKg),
                string.format("Value: %s", fmt(s.plotTotalValue)),
                "",
                buildRarityStr(s.plotByRarity),
            }
            InfoGarden:SetContent(table.concat(gardenLines, "\n"))

            -- Inventory stats
            local invLines = {
                string.format("Fruits: %d  |  Max: %.2f kg", s.invCount, s.invMaxKg),
                string.format("Value: %s", fmt(s.invTotal)),
                "",
                buildRarityStr(s.invByRarity),
            }
            InfoInv:SetContent(table.concat(invLines, "\n"))
        end)
    end
end)


local function addUnifiedFilters(section, cfg, pfx)
    local fruitNames = {}
    for name in pairs(SellValueData) do
        table.insert(fruitNames, name)
    end
    table.sort(fruitNames)
    if #fruitNames == 0 then fruitNames = {"(no data)"} end

    section:AddDropdown({
        Title   = "Select Fruit",
        Options = fruitNames,
        Multi   = true,
        Default = {},
        Callback = function(opts)
            for k in pairs(cfg.onlyTypes) do cfg.onlyTypes[k] = nil end
            for _, n in ipairs(opts) do cfg.onlyTypes[n] = true end
        end,
    }, pfx .. "Fruit")

    section:AddDropdown({
        Title   = "Select Rarity",
        Options = RARITY_NAMES,
        Multi   = true,
        Default = {},
        Callback = function(opts)
            for k in pairs(cfg.onlyRarities) do cfg.onlyRarities[k] = nil end
            for _, n in ipairs(opts) do cfg.onlyRarities[n] = true end
        end,
    }, pfx .. "Rarity")

    section:AddDropdown({
        Title   = "Select Mutation",
        Options = MUT_NAMES,
        Multi   = true,
        Default = {},
        Callback = function(opts)
            for k in pairs(cfg.onlyMuts) do cfg.onlyMuts[k] = nil end
            for _, n in ipairs(opts) do cfg.onlyMuts[n] = true end
        end,
    }, pfx .. "Mutation")

    section:AddDropdown({
        Title    = "Threshold Mode",
        Options  = {"Below", "Above"},
        Default  = "Below",
        Multi    = false,
        Callback = function(v) cfg.weightMode = v end,
    }, pfx .. "ThreshMode")

    section:AddInput({
        Title    = "Weight Threshold",
        Content  = "e.g.: 100",
        Default  = "",
        Callback = function(v)
            local n = tonumber(v)
            cfg.weightKg = n and n or math.huge
        end,
    }, pfx .. "WeightKg")
end


local InvSection = Tabs.Main:AddSection("Inventory", true)
InvSection:AddToggle({
    Title    = "ESP Inventory",
    Default  = false,
    Callback = function(v)
        if v then startHUD() else stopHUD() end
    end,
}, "ESPInventory")

local FruitESPSection = Tabs.Main:AddSection("ESP Fruit", true)
FruitESPSection:AddToggle({
    Title    = "ESP Fruit",
    Default  = false,
    Callback = function(v)
        espActive = v
        if v then scanGardenForESP() else stopFruitESP() end
    end,
}, "FruitESP")

FruitESPSection:AddDropdown({
    Title    = "Threshold Mode",
    Options  = {"Below", "Above"},
    Default  = "Below",
    Multi    = false,
    Callback = function(v)
        espCfg.weightMode = v
        if espActive then stopFruitESP(); scanGardenForESP() end
    end,
}, "ESPThreshMode")

FruitESPSection:AddInput({
    Title    = "Weight Threshold (kg)",
    Content  = "e.g.: 100  (empty = all)",
    Default  = "",
    Callback = function(v)
        local n = tonumber(v)
        espCfg.weightKg = n and n or math.huge
        if espActive then stopFruitESP(); scanGardenForESP() end
    end,
}, "ESPWeightKg")

local HarvestSection = Tabs.Main:AddSection("Harvest", true)
addUnifiedFilters(HarvestSection, harvestCfg, "Harvest")
HarvestSection:AddToggle({
    Title    = "Disable Harvest Prompt",
    Default  = false,
    Callback = function(v)
        if v then startDisableHarvest() else stopDisableHarvest() end
    end,
}, "DisableHarvestPrompt")

-- Anti-Lag
local LagSection = Tabs.Main:AddSection("Anti-Lag", true)
local seedNames  = getSeedNames()

local LagDropdown = LagSection:AddDropdown({
    Title    = "Full Destroy Seeds",
    Options  = #seedNames > 0 and seedNames or {"(no plants found)"},
    Multi    = true,
    Default  = {},
    Callback = function(opts)
        for k in pairs(FULL_DESTROY_SEEDS) do FULL_DESTROY_SEEDS[k] = nil end
        for _, name in ipairs(opts) do
            FULL_DESTROY_SEEDS[name] = true
        end
        if lagRunning then startLag() end
    end,
}, "FullDestroySeeds")

LagSection:AddButton({
    Title    = "Refresh Seed List",
    Callback = function()
        local fresh = getSeedNames()
        LagDropdown:SetValues(#fresh > 0 and fresh or {"(no plants found)"})
        notify("Anti-Lag", "Refreshed — " .. #fresh .. " seed(s)", 2)
    end,
})

LagSection:AddToggle({
    Title    = "Reduce Lag",
    Default  = false,
    Callback = function(v)
        if v then startLag() else stopLag() end
    end,
}, "ReduceLag")



local CollectFilterSection = Tabs.Collect:AddSection("Filter", true)
addUnifiedFilters(CollectFilterSection, collectCfg, "Collect")

local CollectActionSection = Tabs.Collect:AddSection("Action", true)

CollectActionSection:AddToggle({
    Title    = "Auto Collect Fruit",
    Default  = false,
    Callback = function(v)
        if v then startAutoCollect() else stopAutoCollect() end
    end,
}, "AutoCollect")

CollectActionSection:AddToggle({
    Title    = "Auto Collect Fruit All",
    Default  = false,
    Callback = function(v)
        if v then startAutoCollectAll() else stopAutoCollectAll() end
    end,
}, "AutoCollectAll")

CollectActionSection:AddToggle({
    Title    = "Auto Collect Drop Item",
    Default  = false,
    Callback = function(v)
        if v then startAutoCollectDrop() else stopAutoCollectDrop() end
    end,
}, "AutoCollectDrop")

CollectActionSection:AddButton({
    Title    = "Collect Now",
    Callback = function()
        local n = collectNow()
        notify("Collect", n .. " fruits harvested", 3)
    end,
})


local GiftSection = Tabs.Gift:AddSection("Gift", true)

GiftSection:AddInput({
    Title    = "Target Username",
    Content  = "e.g.: 0xSubi",
    Default  = "",
    Callback = function(v) giftCfg.target = v end,
}, "GiftTarget")

GiftSection:AddInput({
    Title    = "Money Threshold (M)",
    Content  = "e.g.: 1000 = 1B",
    Default  = "",
    Callback = function(v) giftCfg.moneyThreshStr = v end,
}, "GiftMoneyThresh")

GiftSection:AddButton({
    Title       = "Send Gift",
    Callback    = sendGift,
    SubTitle    = "Send All",
    SubCallback = sendGiftAll,
})


local SellFilterSection = Tabs.Sell:AddSection("Filter", true)
addUnifiedFilters(SellFilterSection, sellCfg, "Sell")

local SellActionSection = Tabs.Sell:AddSection("Action", true)

SellActionSection:AddButton({
    Title    = "Preview Sell",
    Callback = function()
        local ok, r = pcall(function()
            return Net.NPCS.PreviewSellAll:Fire()
        end)
        if ok and type(r) == "table" then
            notify("Preview", string.format(
                "%d fruits | %s (sell) / %s (base)",
                r.FruitCount or 0,
                fmt(r.TotalSellValue or 0),
                fmt(r.TotalValue or 0)
            ), 6)
        end
    end,
})

SellActionSection:AddToggle({
    Title    = "Auto Sell Fruit",
    Default  = false,
    Callback = function(v)
        if v then startAutoSell() else stopAutoSell() end
    end,
}, "AutoSell")

SellActionSection:AddToggle({
    Title    = "Auto Sell Fruit All",
    Default  = false,
    Callback = function(v)
        if v then startAutoSellAll() else stopAutoSellAll() end
    end,
}, "AutoSellAll")

SellActionSection:AddButton({
    Title       = "Sell Fruit",
    Callback    = function() task.spawn(sellFiltered) end,
    SubTitle    = "Sell All",
    SubCallback = function()
        local ok, r = pcall(function()
            return Net.NPCS.SellAll:Fire()
        end)
        if ok and type(r) == "table" then
            notify("Sell All ✅", string.format(
                "Sold %d | %s",
                r.FruitCount or 0,
                fmt(r.TotalSellValue or r.SellPrice or 0)
            ), 4)
        else
            notify("Sell All", tostring(r), 4)
        end
    end,
})


local DropFilterSection = Tabs.Drop:AddSection("Filter", true)
addUnifiedFilters(DropFilterSection, dropCfg, "Drop")

local DropActionSection = Tabs.Drop:AddSection("Action", true)

DropActionSection:AddToggle({
    Title    = "Auto Drop Fruit",
    Default  = false,
    Callback = function(v)
        if v then startAutoDrop() else stopAutoDrop() end
    end,
}, "AutoDrop")

DropActionSection:AddToggle({
    Title    = "Auto Drop Fruit All",
    Default  = false,
    Callback = function(v)
        if v then startAutoDropAll() else stopAutoDropAll() end
    end,
}, "AutoDropAll")

DropActionSection:AddButton({
    Title    = "Drop Now",
    Callback = function() task.spawn(dropFiltered) end,
})
