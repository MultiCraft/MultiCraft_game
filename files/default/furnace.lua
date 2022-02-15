local S = default.S

--
-- Formspecs
--

function default.get_furnace_active_formspec(fuel_percent, item_percent, fuel_empty)
	local fuel = fuel_empty and "3,2.5;1,1" or "3.1,2.6;0.75,0.75"
	return default.gui ..
		"item_image[0,-0.1;1,1;default:furnace_active]" ..
		"label[0.9,0.1;" .. S("Furnace") .. "]" ..
		"item_image[3,0.5;1,1;default:cell]" ..
		"list[context;src;3,0.5;1,1;]" ..
		"image[3,2.5;1,1;formspec_cell.png]" ..
		"list[context;fuel;3,2.5;1,1;]" ..
		"image[" .. fuel .. ";formspec_flame_outline.png]" ..
		"image[3,1.5;1,1;default_furnace_fire_bg.png^[lowpart:" ..
		fuel_percent .. ":default_furnace_fire_fg.png]" ..
		"image[4,1.5;1,1;default_arrow_bg.png^[lowpart:" ..
		item_percent ..":default_arrow_fg.png^[transformR270]" ..
		"item_image[4.925,1.425;1.2,1.2;default:cell]" ..
		"list[context;dst;5,1.5;1,1;]" ..
		"list[context;split;8,3.14;1,1;]" ..
		"listring[context;dst]" ..
		"listring[current_player;main]"
end

function default.get_furnace_inactive_formspec(fuel_empty)
	local fuel = fuel_empty and "3,2.5;1,1" or "3.1,2.6;0.75,0.75"
	return default.gui ..
		"item_image[0,-0.1;1,1;default:furnace]" ..
		"label[0.9,0.1;" .. S("Furnace") .. "]" ..
		"item_image[3,0.5;1,1;default:cell]" ..
		"list[context;src;3,0.5;1,1;]" ..
		"image[3,2.5;1,1;formspec_cell.png]" ..
		"list[context;fuel;3,2.5;1,1;]" ..
		"image[" .. fuel .. ";formspec_flame_outline.png]" ..
		"image[3,1.5;1,1;default_furnace_fire_bg.png]" ..
		"image[4,1.5;1,1;default_arrow_bg.png^[transformR270]" ..
		"item_image[4.925,1.425;1.2,1.2;default:cell]" ..
		"list[context;dst;5,1.5;1,1;]" ..
		"list[context;split;8,3.14;1,1;]" ..
		"listring[context;dst]" ..
		"listring[current_player;main]"
end

--
-- Node callback functions that are the same for active and inactive furnace
--

-- Drop all items in all inventory lists
local function after_dig_node(pos, _, oldmetadata)
	for _, items in pairs(oldmetadata.inventory) do
		for _, stack in ipairs(items) do
			if not stack:is_empty() then
				minetest.item_drop(stack, nil, pos)
			end
		end
	end
end

local function allow_metadata_inventory_put(pos, listname, _, stack, player)
	if minetest.is_protected(pos, player and player:get_player_name() or "") then
		return 0
	end
	if listname == "fuel" then
		local is_fuel = minetest.get_craft_result({method="fuel", width=1, items={stack}}).time ~= 0
		return is_fuel and stack:get_count() or 0
	elseif listname == "src" then
		local cookable = minetest.get_craft_result({method="cooking", width=1, items={stack}}).time ~= 0
		return cookable and stack:get_count() or 0
	elseif listname == "dst" then
		return 0
	elseif listname == "split" then
		return stack:get_count() / 2
	end
end

local function allow_metadata_inventory_move(pos, from_list, from_index, to_list, to_index, _, player)
	if to_list == "split" then
		return 1
	end
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local stack = inv:get_stack(from_list, from_index)
	return allow_metadata_inventory_put(pos, to_list, to_index, stack, player)
end

local function allow_metadata_inventory_take(pos, _, _, stack, player)
	if minetest.is_protected(pos, player and player:get_player_name() or "") then
		return 0
	end
	return stack:get_count()
end

local function swap_node(pos, name)
	local node = minetest.get_node(pos)
	if node.name == name then
		return
	end
	node.name = name
	minetest.swap_node(pos, node)
end

local function furnace_node_timer(pos, elapsed)
	--
	-- Initialize metadata
	--
	local meta = minetest.get_meta(pos)
	local fuel_time = meta:get_float("fuel_time") or 0
	local src_time = meta:get_float("src_time") or 0
	local fuel_totaltime = meta:get_float("fuel_totaltime") or 0

	local inv = meta:get_inventory()
	local srclist, fuellist
	local dst_full = false

	local cookable, cooked
	local fuel

	local update = true
	while elapsed > 0 and update do
		update = false

		srclist = inv:get_list("src")
		fuellist = inv:get_list("fuel")

		--
		-- Cooking
		--

		-- Check if we have cookable content
		local aftercooked
		cooked, aftercooked = minetest.get_craft_result({method = "cooking", width = 1, items = srclist or {}})
		cookable = cooked.time ~= 0

		local el = math.min(elapsed, fuel_totaltime - fuel_time)
		if cookable then -- fuel lasts long enough, adjust el to cooking duration
			el = math.min(el, cooked.time - src_time)
		end

		-- Check if we have enough fuel to burn
		if fuel_time < fuel_totaltime then
			-- The furnace is currently active and has enough fuel
			fuel_time = fuel_time + el
			-- If there is a cookable item then check if it is ready yet
			if cookable then
				src_time = src_time + el
				if src_time >= cooked.time then
					-- Place result in dst list if possible
					if inv:room_for_item("dst", cooked.item) then
						inv:add_item("dst", cooked.item)
						inv:set_stack("src", 1, aftercooked.items[1])
						src_time = src_time - cooked.time
						update = true
					else
						dst_full = true
					end
				else
					-- Item could not be cooked: probably missing fuel
					update = true
				end
			end
		else
			-- Furnace ran out of fuel
			if cookable then
				-- We need to get new fuel
				local afterfuel
				fuel, afterfuel = minetest.get_craft_result({method = "fuel", width = 1, items = fuellist or {}})

				if fuel.time == 0 then
					-- No valid fuel in fuel list
					fuel_totaltime = 0
					src_time = 0
				else
					-- Take fuel from fuel list
					inv:set_stack("fuel", 1, afterfuel.items[1])
					-- Put replacements in dst list or drop them on the furnace.
					local replacements = fuel.replacements
					if replacements[1] then
						local leftover = inv:add_item("dst", replacements[1])
						if not leftover:is_empty() then
							local above = vector.new(pos.x, pos.y + 1, pos.z)
							local drop_pos = minetest.find_node_near(above, 1, {"air"}) or above
							minetest.item_drop(replacements[1], nil, drop_pos)
						end
					end
					update = true
					fuel_totaltime = fuel.time + (fuel_totaltime - fuel_time)
				end
			else
				-- We don't need to get new fuel since there is no cookable item
				fuel_totaltime = 0
				src_time = 0
			end
			fuel_time = 0
		end

		elapsed = elapsed - el
	end

	if fuel and fuel_totaltime > fuel.time then
		fuel_totaltime = fuel.time
	end
	if srclist and srclist[1]:is_empty() then
		src_time = 0
	end

	--
	-- Update formspec, infotext and node
	--
	local formspec
	local item_state
	local item_percent = 0
	if cookable then
		item_percent = math.floor(src_time / cooked.time * 100)
		if dst_full then
			item_state = S("100% (output full)")
		else
			item_state = S("@1%", item_percent)
		end
	else
		if srclist and not srclist[1]:is_empty() then
			item_state = S("Not cookable")
		else
			item_state = S("Empty")
		end
	end

	local fuel_state = S("Empty")
	local active = false
	local result = false
	local fuel_empty = inv:is_empty("fuel")
	local src_empty = inv:is_empty("src")

	if fuel_totaltime ~= 0 then
		active = true
		local fuel_percent = 100 - math.floor(fuel_time / fuel_totaltime * 100)
		fuel_state = S("@1%", fuel_percent)
		formspec = default.get_furnace_active_formspec(fuel_percent, item_percent, fuel_empty)
		swap_node(pos, "default:furnace_active")
		-- make sure timer restarts automatically
		result = true
	else
		if fuellist and not fuellist[1]:is_empty() then
			fuel_state = S("@1%", 0)
		end
		formspec = default.get_furnace_inactive_formspec(fuel_empty)
		swap_node(pos, "default:furnace")
		-- stop timer on the inactive furnace
		minetest.get_node_timer(pos):stop()
	end

	local infotext
	if fuel_empty and src_empty then
		infotext = S("Furnace is empty")
	else
		infotext = active and S("Furnace active") or S("Furnace inactive")
		infotext = infotext .. "\n" .. S("Item: @1; Fuel: @2", item_state, fuel_state)
	end

	--
	-- Set meta values
	--
	meta:set_float("fuel_totaltime", fuel_totaltime)
	meta:set_float("fuel_time", fuel_time)
	meta:set_float("src_time", src_time)
	meta:set_string("formspec", formspec)
	meta:set_string("infotext", infotext)

	return result
end

--
-- Node definitions
--

minetest.register_node("default:furnace", {
	description = S("Furnace"),
	tiles = {
		"default_furnace_top.png",  "default_furnace_top.png",
		"default_furnace_side.png", "default_furnace_side.png",
		"default_furnace_side.png", "default_furnace_front.png"
	},
	paramtype2 = "facedir",
	groups = {cracky = 2},
	is_ground_content = false,
	sounds = default.node_sound_stone_defaults(),

	after_dig_node = after_dig_node,

	on_timer = furnace_node_timer,

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size("src", 1)
		inv:set_size("fuel", 1)
		inv:set_size("dst", 1)
		inv:set_size("split", 1)
		furnace_node_timer(pos, 0)
	end,

	on_metadata_inventory_move = function(pos)
		minetest.get_node_timer(pos):start(1.0)
	end,
	on_metadata_inventory_put = function(pos)
		-- start timer function, it will sort out whether furnace can burn or not.
		minetest.get_node_timer(pos):start(1.0)
	end,
	on_metadata_inventory_take = function(pos)
		-- check whether the furnace is empty or not.
		minetest.get_node_timer(pos):start(1.0)
	end,
	on_blast = function(pos)
		local drops = {}
		default.get_inventory_drops(pos, "src", drops)
		default.get_inventory_drops(pos, "fuel", drops)
		default.get_inventory_drops(pos, "dst", drops)
		drops[#drops+1] = "default:furnace"
		minetest.remove_node(pos)
		return drops
	end,

	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	allow_metadata_inventory_take = allow_metadata_inventory_take
})

minetest.register_node("default:furnace_active", {
	tiles = {
		"default_furnace_top.png",  "default_furnace_top.png",
		"default_furnace_side.png", "default_furnace_side.png",
		"default_furnace_side.png", "default_furnace_front_active.png"
	},
	paramtype2 = "facedir",
	light_source = 8,
	drop = "default:furnace",
	groups = {cracky = 2, not_in_creative_inventory = 1},
	is_ground_content = false,
	sounds = default.node_sound_stone_defaults(),

	on_timer = furnace_node_timer,

	after_dig_node = after_dig_node,

	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	allow_metadata_inventory_take = allow_metadata_inventory_take
})

minetest.register_craft({
	output = "default:furnace",
	recipe = {
		{"group:stone", "group:stone", "group:stone"},
		{"group:stone", "", "group:stone"},
		{"group:stone", "group:stone", "group:stone"}
	}
})
