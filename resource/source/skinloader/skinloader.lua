local _env = env
_G.setfenv(1, _G)

setmetatable(STRINGS.NAMES, {
    __index = function()
        return ""
    end
})
local function Proxy(name)
    local _fn = rawget(_G, name)
    local proxy = function(item, ...)
        if item and item:start_with_that_prefix() then
            item = item:trip_that_prefix()
        end
        return _fn(item, ...)
    end
    rawset(_G, name, proxy)
end
Proxy("GetColorForItem")
Proxy("GetSkinDescription")
Proxy("GetSkinName")
Proxy("GetSkinInvIconName")
Proxy("GetModifiedRarityStringForItem")
local inv_replica = require("components/inventoryitem_replica")
local _SetImage = inv_replica.SetImage
function inv_replica.SetImage(self, item)
    if item and item:start_with_that_prefix() then
        item = item:trip_that_prefix()
    end
    _SetImage(self, item)
end
if _G.TheNet:GetIsClient() then
    require("characterutil")
    local _SetSkinnedOvalPortraitTexture = SetSkinnedOvalPortraitTexture
    function SetSkinnedOvalPortraitTexture(image_widget, character, skin)
        if skin and skin:start_with_that_prefix() then
            return
        end
        return _SetSkinnedOvalPortraitTexture(image_widget, character, skin)
    end
end
SKIN_RARITY_COLORS["ModMade"]   = { 72 / 255, 208 / 255, 208 / 255, 1 } --#48D0D0
SKIN_RARITY_COLORS["ModLocked"] = { 186 / 255, 7 / 255, 98 / 255, 1 }   --#BA0762
MODSKINANNOUNCEMENT_COLOR       = { 64 / 255, 219 / 255, 234 / 255, 1 }
local modded_order              = { ModMade = 31, ModLocked = 32 }
local _oldCompareRarities       = CompareRarities
CompareRarities                 = function(a, b)
    local rarity1 = GetRarityForItem(a)
    local rarity2 = GetRarityForItem(b)

    if modded_order[rarity1] or modded_order[rarity2] then
        local rarity1_sort = modded_order[rarity1] and modded_order[rarity1] or 1
        local rarity2_sort = modded_order[rarity2] and modded_order[rarity2] or 1

        return rarity1_sort < rarity2_sort
    end
    return _oldCompareRarities(a, b)
end
local function RegisterNoneSkin(skin_id, base_prefab)
    if not PREFAB_SKINS[base_prefab] then PREFAB_SKINS[base_prefab] = {} end
    if not PREFAB_SKINS_IDS[base_prefab] then PREFAB_SKINS_IDS[base_prefab] = {} end
    if not PREFAB_SKINS_IDS[base_prefab][skin_id] then
        local key = #PREFAB_SKINS[base_prefab] + 1
        PREFAB_SKINS[base_prefab][key] = skin_id
        PREFAB_SKINS_IDS[base_prefab][skin_id] = key
    end
end
local function ReplaceSkin(skin_id, new_skin_id, base_prefab)
    if base_prefab and PREFAB_SKINS[base_prefab] then
        if PREFAB_SKINS_IDS[base_prefab][skin_id] then
            local index = PREFAB_SKINS_IDS[base_prefab][skin_id]
            PREFAB_SKINS_IDS[base_prefab][skin_id] = nil
            PREFAB_SKINS_IDS[base_prefab][new_skin_id] = index
            PREFAB_SKINS[base_prefab][index] = new_skin_id
        end
    end
end
--=================================


local VIGNETTE_ASSETS = {}
--=================================
local SKINS = {}
_env.IsAddedSkin = function(skin_id)
    return SKINS[skin_id] ~= nil
end

local function registerSkin(skin_id, data)
    local _skin_id = skin_id and skin_id:trip_that_prefix()
    local c = TheInventory:CheckOwnership(_skin_id)
    if not c then
        ReplaceSkin(_skin_id, skin_id, data.base_prefab)
    end
    SKINS[skin_id] = true
    return
end

local SKIN_AFFINITY_INFO = require("skin_affinity_info")

--=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
local function is_type_loading(data)
    return data.type == "loading"
end

local function is_type_feet(data)
    return data.type == "body" or data.type == "hand" or data.type == "legs" or
            data.type == "feet"
end
function is_type_emoji(data)
    return data.type == "emoji"
end

local function register_string(tbl, skin)
    if STRINGS[tbl][skin] == nil then
        local skinname = skin:sub(4, #skin)
        if STRINGS[tbl][skinname] == nil then
            STRINGS[tbl][skin] = STRINGS[tbl].MS_DEFAULT
        else
            STRINGS[tbl][skin] = STRINGS[tbl][skinname]
        end
    end
end

local function wrap_default_string(skin_id, data)
    if data.type == "base" or is_type_feet(data) then
        local affinity = data.affinity ~= nil and data.affinity or data.base_prefab or ""
        if affinity then
            if not SKIN_AFFINITY_INFO[affinity] then SKIN_AFFINITY_INFO[affinity] = {} end
            table.insert(SKIN_AFFINITY_INFO[affinity], skin_id)
        end
        register_string("SKIN_QUOTES", skin_id)
    end
    register_string("SKIN_NAMES", skin_id)
    register_string("SKIN_DESCRIPTIONS", skin_id)
end

local function wrap_skin_data(skin_id, data)
    if data.skin_tags == nil then data.skin_tags = {} end

    if not table.contains(data.skin_tags, "MODDED") then
        table.insert(data.skin_tags, "MODDED")
    end
    if is_type_feet(data) then
        if not table.contains(data.skin_tags, "CLOTHING") then
            table.insert(data.skin_tags, "CLOTHING")
        end
        if not table.contains(data.skin_tags, "CLOTHING_" .. string.upper(data.type)) then
            table.insert(data.skin_tags, "CLOTHING_" .. string.upper(data.type))
        end
    elseif is_type_loading(data) and not table.contains(data.skin_tags, "LOADING") then
        table.insert(data.skin_tags, "LOADING")
    elseif is_type_emoji(data) and not table.contains(data.skin_tags, "EMOJI") then
        table.insert(data.skin_tags, "EMOJI")
    end
    data.rarity = "ModMade"
    data.rarity_modifier = "Modded"
    data.skip_item_gen = true
    data.skip_giftable_gen = true
    return skin_id, data
end

local function registerClothing(skin_id, data)
    CLOTHING[skin_id] = {
        type = data.type,
        skin_tags = data.skin_tags or nil,
        symbol_overrides = data.symbol_overrides or nil,
        symbol_hides = data.symbol_hides or nil,
        build_name_override = data.build_name_override or nil,
        rarity_modifier = "Modded",
        rarity = data.rarity,
        symbol_overrides_skinny = data.symbol_overrides_skinny or nil,
        symbol_overrides_mighty = data.symbol_overrides_mighty or nil,
        symbol_overrides_stage2 = data.symbol_overrides_stage2 or nil,
        symbol_overrides_stage3 = data.symbol_overrides_stage3 or nil,
        symbol_overrides_stage4 = data.symbol_overrides_stage4 or nil,
        symbol_overrides_powerup = data.symbol_overrides_powerup or nil,
        legs_cuff_size = data.legs_cuff_size or 1,
        feet_cuff_size = data.feet_cuff_size or 1,
        has_leg_boot = data.has_leg_boot or false,
        has_nub = data.has_nub or false,
        torso_tuck = data.torso_tuck or nil,
        symbol_in_base_hides = data.symbol_in_base_hides or nil,
        symbol_overrides_by_character = data.symbol_overrides_by_character or nil,
        release_group = data.release_group or 999,
    }
end

local function registerMiscItems(skin_id, data)
    MISC_ITEMS[skin_id] = {
        type = "loading",
        skin_tags = data.skin_tags,
        rarity = data.rarity,
        rarity_modifier = "Modded",
        release_group = data.release_group or 999,
    }
    local itemstate = Profile:GetCustomizationItemState(GetTypeForItem(skin_id), skin_id)
    if itemstate == nil then
        Profile:SetCustomizationItemState(GetTypeForItem(skin_id), skin_id, true)
    end
end

local function registerMiscOrEmoji(skin_id, data)
    SafeSkins[skin_id] = true
    MISC_ITEMS[skin_id] = {
        type = "emoji",
        skin_tags = data.skin_tags,
        rarity = data.rarity,
        rarity_modifier = "Modded",
        release_group = data.release_group or 999,
    }
    EMOJI_ITEMS[skin_id] = {
        rarity = data.rarity,
        rarity_modifier = "Modded",
        input_name = data.input_name or "UNKNOWN",
        type = "emoji",
        skin_tags = data.skin_tags,
        data =
        {
            item_type = skin_id,
            requires_validation = true,
            utf8_str = data.utf8_str,
        },
        release_group = data.release_group or 999,
    }
end

--=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
function _env.initializeModMain()
    local ModdedCurios = _env._ModdedCurios

    for skin_id, data in pairs(ModdedCurios) do
        skin_id, data = wrap_skin_data(skin_id, data)
        ModdedCurios[skin_id] = data
        wrap_default_string(skin_id, data)
        registerSkin(skin_id, data)

        for _, asset in pairs(data.assets or {}) do
            table.insert(_env.Assets, asset)
            if is_type_loading(data) and (asset.type == "IMAGE" or asset.type == "ATLAS") then
                table.insert(VIGNETTE_ASSETS, asset)
            end
        end

        if is_type_feet(data) then
            registerClothing(skin_id, data)
        elseif is_type_loading(data) then
            registerMiscItems(skin_id, data)
        elseif is_type_emoji(data) then
            registerMiscOrEmoji(skin_id, data)
        end
    end
end

local _CreatePrefabSkin = CreatePrefabSkin
CreatePrefabSkin = function(skin_id, data)
    if skin_id and skin_id:start_with_that_prefix() and skin_id:sub(#skin_id - 4, #skin_id) ~= "_none" then
        skin_id, data = wrap_skin_data(skin_id, data)
        wrap_default_string(skin_id, data)
        registerSkin(skin_id, data)
        if data.type ~= "base" then
            local clear_fn = rawget(_G, data.base_prefab .. "_" .. "clear" .. "_fn")
            if not clear_fn then
                rawset(_G, data.base_prefab .. "_" .. "clear" .. "_fn",
                        function(_inst) basic_clear_fn(_inst, _inst.prefab) end)
            end

            if (data.init_fn) then
                rawset(_G, skin_id .. "_" .. "init" .. "_fn", data.init_fn)
            end
        end
    elseif skin_id and skin_id:start_with_that_prefix() and skin_id:sub(#skin_id - 4, #skin_id) == "_none" then
        RegisterNoneSkin(skin_id, data.base_prefab)
    end
    return _CreatePrefabSkin(skin_id, data)
end
--=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
local ProxySet = { rep = {}, pst = {} }
local function fns_call(name, fn, pst)
    local _fn = InventoryProxy[name]
    local replace = function() end
    if pst then
        replace = function(self, ...)
            local args = { _fn(self, ...) }
            local out = { fn(unpack(args)) }
            if next(out) then
                return unpack(out)
            end
            return unpack(args)
        end
    else
        replace = function(self, ...)
            local out = { fn(...) }
            if next(out) then
                return unpack(out)
            end
            return _fn(self, ...)
        end
    end
    InventoryProxy[name] = replace
end
local function checkClientOwnedSkins(skin_id)
    if _env.IsAddedSkin(skin_id) then
        return true
    end
end
ProxySet.rep.CheckOwnership = function(skin_id, user_id)
    return _env.IsAddedSkin(skin_id) and checkClientOwnedSkins(skin_id, user_id) or nil
end
ProxySet.rep.CheckClientOwnership = function(user_id, skin_id) return ProxySet.rep.CheckOwnership(skin_id, user_id) end
ProxySet.rep.CheckOwnershipGetLatest = function(skin_id)
    if _env.IsAddedSkin(skin_id) then
        return checkClientOwnedSkins(skin_id), 0
    end
end
ProxySet.rep.GetOwnedItemCount = function(skin_id)
    return _env.IsAddedSkin(skin_id) and 1 or nil
end
ProxySet.pst.GetFullInventory = function(inv, ...)
    for skin, _ in pairs(SKINS) do
        if checkClientOwnedSkins(skin) then
            table.insert(inv, {
                item_type = skin,
                item_id = "0",
                modified_time = -2147483647
            })
        end
    end
    return inv
end
local _SetItemOpened = InventoryProxy.SetItemOpened
InventoryProxy.SetItemOpened = function(self, item_id, ...)
    if not _env.IsAddedSkin(item_id) then
        return _SetItemOpened(self, item_id, ...)
    end
end
for name, fn in pairs(ProxySet.rep) do fns_call(name, fn) end
for name, fn in pairs(ProxySet.pst) do fns_call(name, fn, true) end
local SKIN_BUILDS = {}
local function ApplySkin(_inst, name, skin)
    _inst.skinname = skin
    _inst.moddedskinname = skin
    local isGemPrefab, _, realprefab = name:find("^gemprefab_(.+)_%d+$")
    if isGemPrefab then
        name = realprefab
    end
    local _fn
    if (skin) then
        _fn = rawget(_G, skin .. "_" .. "init" .. "_fn") or
                rawget(_G, name .. "_" .. "init" .. "_fn")
    else
        _fn = rawget(_G, name .. "_clear_fn")
    end
    if not _fn then
        local def_build = _inst.AnimState:GetBuild()
        rawset(_G, name .. "_" .. "init" .. "_fn",
                function(__inst, build_name) basic_init_fn(__inst, build_name, def_build) end)
        _fn = rawget(_G, name .. "_" .. (skin and "init" or "clear") .. "_fn")
    end
    local build_name = (Prefabs[skin] ~= nil and Prefabs[skin].build_name_override) or skin

    if SKIN_BUILDS[_inst.AnimState] then
        SKIN_BUILDS[_inst.AnimState]:set(build_name or "")
    end
    _fn(_inst, build_name)
end
local _ReskinEntity = Sim.ReskinEntity
function Sim:ReskinEntity(targetGUID, currentskin, skin, idkwhat, userid, ...)
    _ReskinEntity(self, targetGUID, currentskin, skin, idkwhat, userid, ...)
    local inst = Ents[targetGUID]
    if inst == nil then return end
    if not table.contains(JoinArrays(DST_CHARACTERLIST, MODCHARACTERLIST), inst.prefab) then
        ApplySkin(inst, inst.prefab, skin or nil)
    elseif skin == nil then
        if SKIN_BUILDS[inst.AnimState] then
            SKIN_BUILDS[inst.AnimState]:set("")
        end
    end
end
local _SpawnPrefab = SpawnPrefab
function SpawnPrefab(name, skin, ...)
    local ent = _SpawnPrefab(name, skin, ...)
    if ent and skin and skin:start_with_that_prefix() then
        name = name:gsub("_placer", "")
        ApplySkin(ent, name, skin)
    end
    return ent
end
