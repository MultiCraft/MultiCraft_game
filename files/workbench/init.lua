workbench = {}

-- Nodes allowed to be cut
-- Only the regular, solid blocks without metas or explosivity can be cut
workbench.nodes = {}
for node, def in pairs(minetest.registered_nodes) do
	if (def.drawtype == "normal" or def.drawtype:sub(1,5) == "glass" or def.drawtype:sub(1,8) == "allfaces") and
	   (def.tiles and type(def.tiles[1]) == "string") and
		not def.on_rightclick and
		not def.allow_metadata_inventory_put and
		not def.on_metadata_inventory_put and
		not (def.groups.not_in_creative_inventory == 1) and
		not (def.groups.not_cuttable) and
		not def.groups.colorglass and
		not def.mesecons
	then
		workbench.nodes[node] = true
	end
end

local valid_block = {}
for _, v in pairs(workbench.nodes) do
	valid_block[v] = true
end

-- Nodeboxes definitions
workbench.defs = {
	-- Name		  Yield   X  Y   Z  W   H  L
	{"micropanel",	8,	{ 0, 0,  0, 16, 1, 8  }},
	{"microslab",	4,	{ 0, 0,  0, 16, 1, 16 }},
	{"thinstair",	4,	{ 0, 7,  0, 16, 1, 8   },
						{ 0, 15, 8, 16, 1, 8  }},
	{"cube",		4,	{ 0, 0,  0, 8,  8, 8  }},
	{"panel",		4,	{ 0, 0,  0, 16, 8, 8  }},
	{"slab",		2,	{ 0, 0,  0, 16, 8, 16 }},
	{"doublepanel",	2,	{ 0, 0,  0, 16, 8, 8   },
						{ 0, 8,  8, 16, 8, 8  }},
	{"halfstair",	2,	{ 0, 0,  0, 8,  8, 16  },
						{ 0, 8,  8, 8,  8, 8  }},
	{"outerstair",	1,	{ 0, 0,  0, 16, 8, 16  },
						{ 0, 8,  8, 8,  8, 8  }},
	{"innerstair",	1,	{ 0, 0,  0, 16, 8, 16  },
						{ 0, 8,  8, 16, 8, 8   },
						{ 0, 8,  0, 8,  8, 8  }},
	{"stair",		1,	{ 0, 0,  0, 16, 8, 16  },
						{ 0, 8,  8, 16, 8, 8  }},
	{"slope",		2						   }
}

local repairable_tools = {"pick", "axe", "shovel", "sword", "hoe", "armor", "shield"}

-- Tools allowed to be repaired
function workbench:repairable(stack)
	for _, t in pairs(repairable_tools) do
		if stack:find(t) then
			return true
		end
	end
end

function workbench:get_output(inv, input, name)
	local output = {}
	for i = 1, #self.defs do
		local nbox = self.defs[i]
		local count = math.min(nbox[2] * input:get_count(), input:get_stack_max())
		local item = "stairs:" .. nbox[1] .. "_" .. name:gsub(":", "_")
		output[#output+1] = item .. " " .. count
	end
	inv:set_list("forms", output)
end

-- Thanks to kaeza for this function
local function pixelbox(size, boxes)
	local fixed = {}
	for i, box in pairs(boxes) do
		local x, y, z, w, h, l = unpack(box)
		fixed[i] = {
			(x / size) - 0.5,
			(y / size) - 0.5,
			(z / size) - 0.5,
			((x + w) / size) - 0.5,
			((y + h) / size) - 0.5,
			((z + l) / size) - 0.5
		}
	end
	return {type = "fixed", fixed = fixed}
end

-- You can't place 'image' on top of 'item_image'
minetest.register_craftitem("workbench:saw", {
	inventory_image = "workbench_saw.png",
	groups = {not_in_creative_inventory = 1}
})

-- Workbench formspec
local workbench_fs = [[
	background[-0.2,-0.26;9.41,9.49;formspec_workbench_crafting.png]

	item_image[0,-0.1;1,1;workbench:workbench]
	label[0.9,0.1;]] .. Sl("Workbench") .. [[]

	image_button[0.2,0.8;1.5,1.5;blank.png;creating;;true;false;formspec_item_pressed.png]
	item_image[0.25,0.85;1.5,1.5;stairs:stair_default_wood]
	item_image[0.25,0.95;1.4,1.4;workbench:saw]
	tooltip[creating;]] .. Sl("Сutting") .. [[;#000;#FFF]

	image_button[0.2,2.15;1.5,1.5;blank.png;anvil;;true;false;formspec_item_pressed.png]
	image[0.25,2.2;1.5,1.5;workbench_anvil.png]
	tooltip[anvil;]] .. Sl("Anvil") .. [[;#000;#FFF]

	list[current_player;craft;2,0.5;3,3;]
	list[current_player;craftpreview;7,1.505;1,1;]

	image_button[6.95,3.09;1.1,1.1;blank.png;craftguide;;true;false;formspec_item_pressed.png]
	image[7,3.14;1,1;craftguide_book.png]
	tooltip[craftguide;]] .. Sl("Crafting Guide") .. [[;#000;#FFF]
]]

-- Creating formspec
local creating_fs = [[
	background[-0.2,-0.26;9.41,9.49;formspec_workbench_creating.png]

	item_image[0,-0.1;1,1;workbench:workbench]
	label[0.1,0.7;]] .. Sl("< Back") .. [[]
	image_button[-0.1,-0.2;1.2,1.2;blank.png;back;;true;false;formspec_item_pressed.png]

	item_image[0.1,1.15;1.75,1.75;workbench:saw]
	list[context;craft;2,1.505;1,1;]
	list[context;forms;4.01,0.51;4,3;]
]]

-- Repair formspec
local repair_fs = [[
	background[-0.2,-0.26;9.41,9.49;formspec_workbench_anvil.png]

	item_image[0,-0.1;1,1;workbench:workbench]
	label[0.1,0.7;]] .. Sl("< Back") .. [[]
	image_button[-0.1,-0.2;1.2,1.2;blank.png;back;;true;false;formspec_item_pressed.png]

	image[0.1,1.15;1.75,1.75;workbench_anvil.png]
	item_image[2,2.5;1,1;default:pick_stone]
	list[context;tool;2,1.5;1,1;]
	item_image[6,2.5;1,1;workbench:hammer]
	list[context;hammer;6,1.5;1,1;]
]]

local formspecs = {
	workbench_fs,
	creating_fs,
	repair_fs
}

function workbench:set_formspec(meta, id)
	meta:set_string("formspec",
		default.gui ..
		"list[context;split;8,3.14;1,1;]" ..
		formspecs[id])
end

function workbench.construct(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()

	inv:set_size("tool", 1)
	inv:set_size("craft", 1)
	inv:set_size("hammer", 1)
	inv:set_size("split", 1)
	inv:set_size("forms", 4*3)

	meta:set_string("infotext", Sl("Workbench"))
	meta:set_string("version", "5")
	workbench:set_formspec(meta, 1)
end

function workbench.fields(pos, _, fields, sender)
	local meta = minetest.get_meta(pos)
	local id = fields.back and 1 or fields.creating and 2 or fields.anvil and 3
	if fields.craftguide then
		sfinv.open_page(sender, "craftguide:craftguide")
		return
	end
	if not id then
		if pos and sender then
			local inv = sender:get_inventory()
			if inv then
				for i, stack in ipairs(inv:get_list("craft")) do
					minetest.item_drop(stack, nil, pos)
					stack:clear()
					inv:set_stack("craft", i, stack)
				end
			end
			inv = meta:get_inventory()
			if inv then
				for _, name in pairs({"craft", "tool", "hammer"}) do
					local stack = inv:get_stack(name, 1)
					minetest.item_drop(stack, nil, pos)
					stack:clear()
					inv:set_stack(name, 1, stack)
				end
				for i, stack in pairs(inv:get_list("forms")) do
					stack:clear()
					inv:set_stack("forms", i, stack)
				end
			end
		end
		return
	end

	workbench:set_formspec(meta, id)
end

function workbench.timer(pos)
	local timer = minetest.get_node_timer(pos)
	local inv = minetest.get_meta(pos):get_inventory()
	local tool = inv:get_stack("tool", 1)
	local hammer = inv:get_stack("hammer", 1)

	if tool:is_empty() or hammer:is_empty() or tool:get_wear() == 0 then
		timer:stop()
		return
	end

	-- Tool's wearing range: 0-65535; 0 = new condition
	tool:add_wear(-500)
	hammer:add_wear(700)

	inv:set_stack("tool", 1, tool)
	inv:set_stack("hammer", 1, hammer)
	return true
end

function workbench.put(pos, listname, _, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	local stackname = stack:get_name()
	if (listname == "tool" and stack:get_wear() > 0 and
		workbench:repairable(stackname)) or
		(listname == "craft" and valid_block[stackname]) or
		(listname == "hammer" and stackname == "workbench:hammer") then
		return stack:get_count()
	end
	if listname == "split" then
		return stack:get_count() / 2
	end
	return 0
end

function workbench.move()
	return 0
end

function workbench.on_put(pos, listname, _, stack)
	local inv = minetest.get_meta(pos):get_inventory()
	if listname == "craft" then
		local input = inv:get_stack("craft", 1)
		workbench:get_output(inv, input, stack:get_name())
	elseif listname == "tool" or listname == "hammer" then
		local timer = minetest.get_node_timer(pos)
		timer:start(0.5)
	end
end

function workbench.on_take(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	local inv = minetest.get_meta(pos):get_inventory()
	local input = inv:get_stack("craft", 1)
	local inputname = input:get_name()
	local stackname = stack:get_name()
	if listname == "craft" then
		if stackname == inputname and valid_block[stackname] then
			workbench:get_output(inv, input, stackname)
		else
			inv:set_list("forms", {})
		end
	elseif listname == "forms" then
		local fromstack = inv:get_stack(listname, index)
		if not fromstack:is_empty() and fromstack:get_name() ~= stackname then
			local player_inv = player:get_inventory()
			if player_inv:room_for_item("main", fromstack) then
				player_inv:add_item("main", fromstack)
			end
		end

		input:take_item(math.ceil(stack:get_count() / workbench.defs[index][2]))
		inv:set_stack("craft", 1, input)
		workbench:get_output(inv, input, inputname)
	end
end

minetest.register_node("workbench:workbench", {
	description = "Workbench",
	paramtype = "light",
	paramtype2 = "facedir",
	groups = {cracky = 2, choppy = 2, oddly_breakable_by_hand = 1, flammable = 2},
	sounds = default.node_sound_wood_defaults(),
	tiles = {"workbench_top.png", "workbench_top.png",
		 "workbench_sides.png", "workbench_sides.png",
		 "workbench_front.png", "workbench_front.png"},
	on_timer = workbench.timer,
	on_construct = workbench.construct,
	on_receive_fields = workbench.fields,
	on_metadata_inventory_put = workbench.on_put,
	on_metadata_inventory_take = workbench.on_take,
	allow_metadata_inventory_put = workbench.put,
	allow_metadata_inventory_move = workbench.move
})

minetest.register_lbm({
	label = "Workbench updater",
	name = "workbench:updater_v5",
	nodenames = "workbench:workbench",
	action = function(pos)
		if minetest.get_meta(pos):get_string("version") ~= "5" then
			construct(pos)
		end
	end
})

for i = 1, #workbench.defs do
	local d = workbench.defs[i]
	for node in pairs(workbench.nodes) do
		local def = minetest.registered_nodes[node]
		local groups, tiles, mesh, collision_box = {}, {}, {}, {}
		local drawtype = "nodebox"

		if not d[3] then
			drawtype = "mesh"
			mesh = "workbench_slope.obj"
			collision_box = {
				type = "fixed",
				fixed = {
					{-0.5, -0.5,    -0.5,    0.5, -0.1875, 0.5},
					{-0.5, -0.1875, -0.1875, 0.5,  0.1875, 0.5},
					{-0.5,  0.1875,  0.1875, 0.5,  0.5,    0.5}
				},
			}
		end

		groups.stairs = 1

		for k, v in pairs(def.groups) do
			if k ~= "wood" and k ~= "stone" and k ~= "wool" and k ~= "level" then
				groups[k] = v
			end
		end

		if def.tiles then
			if #def.tiles > 1 and (def.drawtype:sub(1,5) ~= "glass") then
				tiles = def.tiles
			else
				tiles = {def.tiles[1]}
			end
		else
			tiles = {def.tiles[1]}
		end

		if def.drop ~= "" then
			drop = "stairs:"..d[1].."_"..node:gsub(":", "_")
		else
			drop = ""
		end

		minetest.register_node(":stairs:"..d[1].."_"..node:gsub(":", "_"), {
			description = def.description.." " ..Sl(d[1]:gsub("^%l", string.upper)),
			drawtype = drawtype,
			tiles = tiles,
			mesh = mesh,
			paramtype = "light",
			paramtype2 = "facedir",
			drop = drop,
			groups = groups,
			light_source = def.light_source / 2,
			sunlight_propagates = true,
			walkable = def.walkable,
			is_ground_content = false,
			sounds = def.sounds,
			use_texture_alpha = def.use_texture_alpha,
			on_place = minetest.rotate_node,
			node_box = pixelbox(16, {unpack(d, 3)}),
			collision_box = collision_box
		})
	end
end

--
-- Craft items
--

minetest.register_tool("workbench:hammer", {
	description = "Hammer",
	inventory_image = "workbench_hammer.png",
	tool_capabilities = {
		full_punch_interval = 1.5,
		max_drop_level = 0,
		damage_groups = {fleshy = 6}
	},
	sound = {breaks = "default_tool_breaks"}
})

minetest.register_craft({
	output = "workbench:workbench",
	recipe = {
		{"group:wood", "group:wood"},
		{"group:wood", "group:wood"}
	}
})

minetest.register_craft({
	output = "workbench:hammer",
	recipe = {
		{"default:steel_ingot", "default:stick", "default:steel_ingot"},
		{"", "default:stick", ""},
		{"", "default:stick", ""}
	}
})

minetest.register_craft({
	type = "fuel",
	recipe = "workbench:workbench",
	burntime = 30
})
