local MAJOR, MINOR = "libFilters", 6
local libFilters, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not libFilters then return end	--the same or newer version of this lib is already loaded into memory 
--thanks to Seerah for the previous lines and library

local _

--some constants for your filters
LAF_BAGS = 1
LAF_BANK = 2
LAF_GUILDBANK = 3
LAF_STORE = 4
LAF_DECONSTRUCTION = 5
LAF_GUILDSTORE = 6
LAF_MAIL = 7
LAF_TRADE = 8

libFilters.filters = {
	[LAF_BAGS] = {},
	[LAF_BANK] = {},
	[LAF_GUILDBANK] = {},
	[LAF_STORE] = {},
	[LAF_DECONSTRUCTION] = {},
	[LAF_GUILDSTORE] = {},
	[LAF_MAIL] = {},
	[LAF_TRADE] = {}
}
local filters = libFilters.filters

libFilters.LAFtoFragment = {}
local LAFtoFragment = libFilters.LAFtoFragment

--look-up map to find out which filter the id belongs to
libFilters.idToFilter = {}
local idToFilter = libFilters.idToFilter

--generally used to figure out which inventory to update
local function GetInventoryType( filterType )
	local inventoryType = 0
	if(filterType == LAF_BAGS or filterType == LAF_MAIL or filterType == LAF_TRADE or filterType == LAF_STORE or filterType == LAF_GUILDSTORE) then
		inventoryType = INVENTORY_BACKPACK
	elseif(filterType == LAF_BANK) then 
		inventoryType = INVENTORY_BANK
	elseif(filterType == LAF_GUILDBANK) then 
		inventoryType = INVENTORY_GUILD_BANK
	end	
	return inventoryType
end

--LAF_BAGS
--LAF_BANK
--LAF_GUILDBANK
--NOTE THAT THESE FILTERS ARE VOLATILE - AS SOON AS AN INVENTORY'S APPLIED LAYOUT IS CHANGE THIS
--WILL BE OVERWRITTEN AND VANISH!
local function SetInventoryFilter( filterType )
	local inventoryType = GetInventoryType(filterType)
	if(inventoryType == 0) then return end --fail quietly, but keep the filter registered

	--I was originally trying to use BACKPACK_DEFAULT_LAYOUT_FRAGMENT.layoutData.additionalFilter,
	--but that was not working.  Looked back on my AdvancedFilters and noticed that I had already
	--solved that problem.  TLDR: Don't use BACKPACK_DEFAULT_LAYOUT_FRAGMENT for filtering!
	local currentFilter
	if(PLAYER_INVENTORY and PLAYER_INVENTORY.appliedLayout) then
		currentFilter = PLAYER_INVENTORY.appliedLayout.additionalFilter
	end

	PLAYER_INVENTORY.inventories[inventoryType].additionalFilter = 
		function(slot)
			local result = true
			--use filter list
			for _,v in pairs(filters[filterType]) do
				if(v) then
					result = result and v(slot)
				end
			end
			--handle already existing filters
			if(currentFilter) then
				result = result and currentFilter(slot)
			end
			return result
		end
end

--LAF_STORE
--LAF_GUILDSTORE
--LAF_MAIL
--LAF_TRADE
local function SetFilterByFragment( filterType )
	LAFtoFragment[filterType].layoutData.additionalFilter = 
		function(slot)
			local result = true
			for _,v in pairs(filters[filterType]) do
				if(v) then 
					result = result and v(slot)
				end
			end
			return result
		end
end

--LAF_DECONSTRUCTION
--this one doesn't set the filter, but it IS the filter
--since this is a PreHook using ZO_PreHook, a return of true means don't add
local function DeconstructionFilter( self, bagId, slotIndex, ... )
	for _,v in pairs(filters[LAF_DECONSTRUCTION]) do
		if(v and not v(bagId, slotIndex)) then
			return true
		end
	end
end

local function UpdateFilteredList( filterType )
	--deconstruction is the only weird case, i think
	if(filterType == LAF_DECONSTRUCTION) then
		if(GetCraftingInteractionType() > 0) then
			SMITHING.deconstructionPanel.inventory:PerformFullRefresh()
		end
	else
		PLAYER_INVENTORY:UpdateList(GetInventoryType(filterType))
	end
end

--filterCallback must be a function with parameter (slot) and return true/false
function libFilters:RegisterFilter( filterId, filterType, filterCallback )
	--lazily initialize the add-on
	if(not self.IS_INITIALIZED) then self:InitializeLibFilters() end
	--fail silently if the id isn't free or type out of range or if anything is nil
	if(not filterId or idToFilter[filterId] or filterType < 1 or filterType > #filters
		or not filterCallback or not filterType) then
		d("ERROR: " .. filterId .. " is already in use!")
		return
	end

	local thisFilter = filters[filterType]
	idToFilter[filterId] = filterType
	thisFilter[filterId] = filterCallback

	if(filterType == LAF_BAGS or filterType == LAF_BANK or filterType == LAF_GUILDBANK) then
		SetInventoryFilter(filterType)

	elseif(filterType == LAF_STORE or filterType == LAF_GUILDSTORE or filterType == LAF_MAIL or filterType == LAF_TRADE) then
		SetFilterByFragment(filterType)

	elseif(filterType == LAF_DECONSTRUCTION) then
		--do nothing because this is filtered with a different method

	end

	UpdateFilteredList(filterType)
end

function libFilters:UnregisterFilter( filterId )
	--lazily initialize the add-on
	if(not self.IS_INITIALIZED) then self:InitializeLibFilters() end
	if(not filterId or not self:IsFilterRegistered(filterId)) then return end --fail quietly

	local filterType = idToFilter[filterId]
	filters[filterType][filterId] = nil
	idToFilter[filterId] = nil
	UpdateFilteredList(filterType)
end

function libFilters:IsFilterRegistered( filterId )
	if(filterId and idToFilter[filterId]) then
		return true
	else
		return false
	end
end

function libFilters:InventoryTypeToLAF( inventoryType )
	if(inventoryType == INVENTORY_BACKPACK) then
		return LAF_BAGS
	elseif(inventoryType == INVENTORY_BANK) then
		return LAF_BANK
	elseif(inventoryType == INVENTORY_GUILD_BANK) then
		return LAF_GUILDBANK
	end
 
	return 0
end

function libFilters:BagIdToLAF( badId )
	if(bagId == BAG_BACKPACK) then
		return LAF_BAGS
	elseif(bagId == BAG_BANK) then
		return LAF_BANK
	elseif(bagId == BAG_GUILDBANK) then
		return LAF_GUILDBANK
	end

	return 0
end

function libFilters:InitializeLibFilters()
	if self.IS_INITIALIZED then return end
	self.IS_INITIALIZED = true
	local defaultAdditionalMail = BACKPACK_MAIL_LAYOUT_FRAGMENT.layoutData.additionalFilter
	local defaultAdditionalTrade = BACKPACK_PLAYER_TRADE_LAYOUT_FRAGMENT.layoutData.additionalFilter
	local defaultAdditionalStore = BACKPACK_STORE_LAYOUT_FRAGMENT.layoutData.additionalFilter
	local defaultAdditionalGuildStore = BACKPACK_TRADING_HOUSE_LAYOUT_FRAGMENT.layoutData.additionalFilter

	LAFtoFragment = {
		[LAF_STORE] = BACKPACK_STORE_LAYOUT_FRAGMENT,
		[LAF_GUILDSTORE] = BACKPACK_TRADING_HOUSE_LAYOUT_FRAGMENT,
		[LAF_MAIL] = BACKPACK_MAIL_LAYOUT_FRAGMENT,
		[LAF_TRADE] = BACKPACK_PLAYER_TRADE_LAYOUT_FRAGMENT
	}

	if(not libFilters:IsFilterRegistered("LAF_ZO_defaultAdditionalMail")) then 
		self:RegisterFilter("LAF_ZO_defaultAdditionalMail", LAF_MAIL, defaultAdditionalMail)
	end
	if(not libFilters:IsFilterRegistered("LAF_ZO_defaultAdditionalTrade")) then 
		self:RegisterFilter("LAF_ZO_defaultAdditionalTrade", LAF_TRADE, defaultAdditionalTrade)
	end
	if(not libFilters:IsFilterRegistered("LAF_ZO_defaultAdditionalStore")) then 
		self:RegisterFilter("LAF_ZO_defaultAdditionalStore", LAF_STORE, defaultAdditionalStore)
	end
	if(not libFilters:IsFilterRegistered("LAF_ZO_defaultAdditionalGuildStore")) then 
		self:RegisterFilter("LAF_ZO_defaultAdditionalGuildStore", LAF_GUILDSTORE, defaultAdditionalGuildStore)
	end
	if(not libFilters:IsFilterRegistered("LAF_Store_AlwaysTrue")) then 
		self:RegisterFilter("LAF_Store_AlwaysTrue", LAF_STORE, function(slot) return true end)
	end
	if(not libFilters:IsFilterRegistered("LAF_GuildStore_AlwaysTrue")) then 
		self:RegisterFilter("LAF_GuildStore_AlwaysTrue", LAF_GUILDSTORE, function(slot) return true end)
	end

	ZO_PreHook(SMITHING.deconstructionPanel.inventory, "AddItemData", DeconstructionFilter)

end

--here is a handful of examples and tests!  these may expand in the future.

-- function test( filterType )
-- 	if(not filterType) then return end
-- 	libFilters:RegisterFilter("test", filterType, function(slot)
--         local _,_,value = GetItemInfo(slot.bagId, slot.slotIndex)
--         return value > 20
--     end)
-- end

-- function testDecon()
-- 	libFilters:RegisterFilter("test", LAF_DECONSTRUCTION, function(bagId, slotIndex)
--         local _,_,value = GetItemInfo(bagId, slotIndex)
--         return value > 20
--     end)
-- end

-- function untest()
-- 	libFilters:UnregisterFilter("test")
-- end