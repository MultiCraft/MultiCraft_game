local vessels_shelf_formspec =
	default.gui ..
	"background[-0.2,-0.26;9.41,9.49;formspec_shelf.png]" ..
	"item_image[0,-0.1;1,1;vessels:shelf]" ..
	"label[0.9,0.1;" .. Sl("Potion Shelf") .. "]" ..
	"list[context;vessels;0,1;9,2;]" ..
	"list[context;split;8,3.14;1,1;]" ..
	"listring[context;vessels]" ..
	"listring[current_player;main]"

local function get_vessels_shelf_formspec(inv)
	local formspec = vessels_shelf_formspec
	local invlist = inv and inv:get_list("vessels")
	return formspec
end

minetest.register_node("vessels:shelf", {
	description = "Potion Shelf",
	tiles = {"default_wood.png", "default_wood.png", "default_wood.png",
		"default_wood.png", "vessels_shelf.png", "vessels_shelf.png"},
	paramtype2 = "facedir",
	is_ground_content = false,
	groups = {cracky = 2, choppy = 2, oddly_breakable_by_hand = 1, flammable = 3},
	sounds = default.node_sound_wood_defaults(),

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", get_vessels_shelf_formspec(nil))
		local inv = meta:get_inventory()
		inv:set_size("vessels", 9 * 2)
		inv:set_size("split", 1)
	end,
	can_dig = function(pos,player)
		local inv = minetest.get_meta(pos):get_inventory()
		return inv:is_empty("vessels")
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if minetest.get_item_group(stack:get_name(), "vessel") ~= 0 then
			if listname == "split" then
				return 1
			else
				return stack:get_count()
			end
		end
		return 0
	end,
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		if to_list == "split" then
			return 1
		end
		return count
	end,
	on_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", get_vessels_shelf_formspec(meta:get_inventory()))
	end,
	on_metadata_inventory_put = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", get_vessels_shelf_formspec(meta:get_inventory()))
	end,
	on_metadata_inventory_take = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", get_vessels_shelf_formspec(meta:get_inventory()))
	end,
	on_blast = function(pos)
		local drops = {}
		default.get_inventory_drops(pos, "vessels", drops)
		drops[#drops + 1] = "vessels:shelf"
		minetest.remove_node(pos)
		return drops
	end
})

minetest.register_craft({
	output = "vessels:shelf",
	recipe = {
		{"group:wood", "group:wood", "group:wood"},
		{"group:vessel", "group:vessel", "group:vessel"},
		{"group:wood", "group:wood", "group:wood"}
	}
})

minetest.register_node("vessels:glass_bottle", {
	description = "Empty Glass Bottle",
	drawtype = "plantlike",
	tiles = {"vessels_glass_bottle.png"},
	inventory_image = "vessels_glass_bottle.png",
	paramtype = "light",
	is_ground_content = false,
	walkable = false,
	selection_box = {
		type = "fixed",
		fixed = {-0.25, -0.5, -0.25, 0.25, 0.3, 0.25}
	},
	groups = {vessel = 1, dig_immediate = 3, attached_node = 1},
	sounds = default.node_sound_glass_defaults()
})

minetest.register_alias("potions:glass_bottle", "vessels:glass_bottle")

minetest.register_craft( {
	output = "vessels:glass_bottle 4",
	recipe = {
		{"", "", ""},
		{"default:glass", "", "default:glass"},
		{"", "default:glass", ""}
	}
})

minetest.register_craft({
	type = "fuel",
	recipe = "vessels:shelf",
	burntime = 30
})
