local S = mesecon.S

local vadd, vequals, vmultiply = vector.add, vector.equals, vector.multiply

local specs = {
	normal = {
		offname = "mesecons_pistons:piston_normal_off",
		onname = "mesecons_pistons:piston_normal_on",
		pusher = "mesecons_pistons:piston_pusher_normal"
	},
	sticky = {
		offname = "mesecons_pistons:piston_sticky_off",
		onname = "mesecons_pistons:piston_sticky_on",
		pusher = "mesecons_pistons:piston_pusher_sticky",
		sticky = true
	}
}

local function get_pistonspec_name(name, part)
	if part then
		for spec_name, spec in pairs(specs) do
			if name == spec[part] then
				return spec_name, part
			end
		end
		return
	end
	for spec_name, spec in pairs(specs) do
		for spart, value in pairs(spec) do
			if name == value then
				return spec_name, spart
			end
		end
	end
end

local function get_pistonspec(name, part)
	return specs[get_pistonspec_name(name, part)]
end

local max_push = mesecon.setting("piston_max_push", 10)
local max_pull = mesecon.setting("piston_max_pull", 10)

-- Get mesecon rules of pistons
local table_copy, table_remove = table.copy, table.remove
local function piston_get_rules(node)
	local dir = minetest.facedir_to_dir(node.param2)
	for k, v in pairs(dir) do
		if v ~= 0 then
			dir = {k, -v}
			break
		end
	end
	local rules = table_copy(mesecon.rules.default)
	for i, rule in pairs(rules) do
		if rule[dir[1]] == dir[2] then
			table_remove(rules, i)
		end
	end
	return rules
end

local function piston_remove_pusher(pos, node, check_falling)
	local pistonspec = get_pistonspec(node.name, "onname")
	local dir = vmultiply(minetest.facedir_to_dir(node.param2), -1)
	local pusherpos = vadd(pos, dir)
	local pushername = minetest.get_node(pusherpos).name

	-- make sure there actually is a pusher (for compatibility reasons mainly)
	if pushername ~= pistonspec.pusher then
		return
	end

	minetest.remove_node(pusherpos)
	minetest.sound_play("piston_retract", {
		pos = pos,
		max_hear_distance = 20,
		gain = 0.3
	})

	if check_falling then
		minetest.check_for_falling(pusherpos)
	end
end

local function piston_after_dig(pos, node)
	piston_remove_pusher(pos, node, true)
end

local function piston_on(pos, node)
	local pistonspec = get_pistonspec(node.name, "offname")
	if not pistonspec then -- it may be called asynchronously now, don’t crash if something goes wrong
		return
	end
	local dir = vmultiply(minetest.facedir_to_dir(node.param2), -1)
	local pusher_pos = vadd(pos, dir)
	local success, stack, oldstack = mesecon.mvps_push(pusher_pos, dir, max_push)
	if not success then
		return
	end
	minetest.swap_node(pos, {param2 = node.param2, name = pistonspec.onname})
	minetest.set_node(pusher_pos, {param2 = node.param2, name = pistonspec.pusher})
	minetest.sound_play("piston_extend", {
		pos = pos,
		max_hear_distance = 20,
		gain = 0.3
	})
	mesecon.mvps_process_stack(stack)
	mesecon.mvps_move_objects(pusher_pos, dir, oldstack)
end

local function piston_off(pos, node)
	local pistonspec = get_pistonspec(node.name, "onname")
	if not pistonspec then
		return
	end
	minetest.swap_node(pos, {param2 = node.param2, name = pistonspec.offname})
	piston_remove_pusher(pos, node, not pistonspec.sticky)

	if not pistonspec.sticky then
		return
	end
	local dir = minetest.facedir_to_dir(node.param2)
	local pullpos = vadd(pos, vmultiply(dir, -2))
	local success, _, oldstack = mesecon.mvps_pull_single(pullpos, dir, max_pull)
	if success then
		mesecon.mvps_move_objects(pullpos, vmultiply(dir, -1), oldstack, -1)
	end
end

-- not on/off as power state may change faster than the piston state
mesecon.queue:add_function("piston_switch", function(pos)
	local node = mesecon.get_node_force(pos)
	if mesecon.is_powered(pos) then
		piston_on(pos, node)
	else
		piston_off(pos, node)
	end
end)

local piston_on_delayed, piston_off_delayed
local delay = mesecon.setting("piston_delay", 0.15)
if delay > 0 then
	local function piston_switch_delayed(pos)
		mesecon.queue:add_action(pos, "piston_switch", {}, delay, "piston_switch")
	end
	piston_on_delayed = piston_switch_delayed
	piston_off_delayed = piston_switch_delayed
else
	piston_on_delayed = piston_on
	piston_off_delayed = piston_off
end

local orientations = {
	[0] = { 4,  8},
		  {13, 17},
		  {10,  6},
		  {20, 15}
}

local deg = math.deg
local function piston_orientate(pos, placer)
	if not placer then
		return
	end
	local pitch = deg(placer:get_look_vertical())
	local node = minetest.get_node(pos)
	if pitch > 55 then
		node.param2 = orientations[node.param2][1]
	elseif pitch < -55 then
		node.param2 = orientations[node.param2][2]
	else
		return
	end
	minetest.swap_node(pos, node)
	-- minetest.after, because on_placenode for unoriented piston must be processed first
	minetest.after(0, mesecon.on_placenode, pos, node)
end

local rotations = {
	{0, 16, 20, 12},
	{2, 14, 22, 18},
	{1,  5, 23,  9},
	{3, 11, 21,  7},
	{4, 13, 10, 19},
	{6, 15,  8, 17}
}

local function get_rotation(param2)
	for a = 1, #rotations do
		for f = 1, #rotations[a] do
			if rotations[a][f] == param2 then
				return a, f
			end
		end
	end
end

local function rotate(param2, mode)
	local axis, face = get_rotation(param2)
	if mode == screwdriver.ROTATE_FACE then
		face = face + 1
		if face > 4 then
			face = 1
		end
	elseif mode == screwdriver.ROTATE_AXIS then
		axis = axis + 1
		if axis > 6 then
			axis = 1
		end
		face = 1
	else
		return param2
	end
	return rotations[axis][face]
end

local function piston_rotate(pos, node, _, mode)
	node.param2 = rotate(node.param2, mode)
	minetest.swap_node(pos, node)
	mesecon.execute_autoconnect_hooks_now(pos, node)
	return true
end

local function piston_rotate_on(pos, node, player, mode)
	local pistonspec = get_pistonspec(node.name, "onname")
	local dir = vmultiply(minetest.facedir_to_dir(node.param2), -1)
	local pusher_pos = vadd(dir, pos)
	local pusher_node = minetest.get_node(pusher_pos)
	if pusher_node.name ~= pistonspec.pusher then
		return piston_rotate(pos, node, nil, mode)
	end
	if mode == screwdriver.ROTATE_FACE then
		piston_rotate(pusher_pos, pusher_node, nil, mode)
		return piston_rotate(pos, node, nil, mode)
	elseif mode ~= screwdriver.ROTATE_AXIS then
		return false
	end
	local player_name = player and player:is_player() and player:get_player_name() or ""
	local ok, dir_after, pusher_pos_after
	for _ = 1, 5 do
		node.param2 = rotate(node.param2, mode)
		dir_after = vmultiply(minetest.facedir_to_dir(node.param2), -1)
		pusher_pos_after = vadd(dir_after, pos)
		local pusher_pos_after_node_name = minetest.get_node(pusher_pos_after).name
		local pusher_pos_after_node_def = minetest.registered_nodes[pusher_pos_after_node_name]
		if pusher_pos_after_node_def and pusher_pos_after_node_def.buildable_to and
				not minetest.is_protected(pusher_pos_after, player_name) then
			ok = true
			break
		end
	end
	if not ok then
		return false
	end
	pusher_node.param2 = node.param2
	minetest.remove_node(pusher_pos)
	minetest.set_node(pusher_pos_after, pusher_node)
	minetest.swap_node(pos, node)
	mesecon.execute_autoconnect_hooks_now(pos, node)
	return true
end

local function piston_rotate_pusher(pos, node, player, mode)
	local pistonspec = get_pistonspec(node.name, "pusher")
	local piston_pos = vadd(pos, minetest.facedir_to_dir(node.param2))
	local piston_node = minetest.get_node(piston_pos)
	if piston_node.name ~= pistonspec.onname then
		minetest.remove_node(pos) -- Make it possible to remove alone pushers.
		return false
	end
	return piston_rotate_on(piston_pos, piston_node, player, mode)
end


-- Boxes:

local pt = 3/16 -- pusher thickness

local piston_pusher_box = {
	type = "fixed",
	fixed = {
		{-2/16, -2/16, -.5 + pt, 2/16, 2/16, .5 + pt},
		{-.5, -.5, -.5, .5, .5, -.5 + pt}
	}
}

local piston_on_box = {
	type = "fixed",
	fixed = {
		{-.5, -.5, -.5 + pt, .5, .5, .5}
	}
}


-- Normal (non-sticky) Pistons:
-- offstate
minetest.register_node("mesecons_pistons:piston_normal_off", {
	description = S("Piston"),
	tiles = {
		"mesecons_piston_side.png^[transformFY",
		"mesecons_piston_side.png",
		"mesecons_piston_side.png^[transformR90",
		"mesecons_piston_side.png^[transformR270",
		"mesecons_piston_back.png",
		"mesecons_piston_pusher_front.png"
	},
	wield_cube = "mesecons_piston_back.png",
	groups = {cracky = 3},
	stack_max = 1,
	paramtype2 = "facedir",
	is_ground_content = false,
	after_place_node = piston_orientate,
	sounds = default.node_sound_wood_defaults(),
	mesecons = {effector={
		action_on = piston_on_delayed,
		rules = piston_get_rules
	}},
	on_rotate = piston_rotate,
	on_blast = mesecon.on_blastnode
})

-- onstate
minetest.register_node("mesecons_pistons:piston_normal_on", {
	drawtype = "nodebox",
	tiles = {
		"mesecons_piston_side.png^[transformFY",
		"mesecons_piston_side.png",
		"mesecons_piston_side.png^[transformR90",
		"mesecons_piston_side.png^[transformR270",
		"mesecons_piston_back.png",
		"mesecons_piston_on_front.png"
	},
	groups = {cracky = 3, not_in_creative_inventory = 1},
	paramtype = "light",
	paramtype2 = "facedir",
	is_ground_content = false,
	drop = "mesecons_pistons:piston_normal_off",
	after_dig_node = piston_after_dig,
	node_box = piston_on_box,
	selection_box = piston_on_box,
	sounds = default.node_sound_wood_defaults(),
	mesecons = {effector={
		action_off = piston_off_delayed,
		rules = piston_get_rules
	}},
	on_rotate = piston_rotate_on,
	on_blast = mesecon.on_blastnode
})

-- pusher
minetest.register_node("mesecons_pistons:piston_pusher_normal", {
	drawtype = "nodebox",
	tiles = {
		"mesecons_piston_side.png^[transformFY",
		"mesecons_piston_side.png",
		"mesecons_piston_side.png^[transformR90",
		"mesecons_piston_side.png^[transformR270",
		"mesecons_piston_back.png",
		"mesecons_piston_pusher_front.png"
	},
	groups = {not_in_creative_inventory = 1},
	paramtype = "light",
	paramtype2 = "facedir",
	is_ground_content = false,
	diggable = false,
	selection_box = piston_pusher_box,
	node_box = piston_pusher_box,
	on_rotate = piston_rotate_pusher,
	drop = "",
	sounds = default.node_sound_wood_defaults()
})

-- Sticky ones
-- offstate
minetest.register_node("mesecons_pistons:piston_sticky_off", {
	description = S("Sticky Piston"),
	tiles = {
		"mesecons_piston_side.png^[transformFY",
		"mesecons_piston_side.png",
		"mesecons_piston_side.png^[transformR90",
		"mesecons_piston_side.png^[transformR270",
		"mesecons_piston_back.png",
		"mesecons_piston_pusher_front_sticky.png"
	},
	wield_cube = "mesecons_piston_back.png",
	groups = {cracky = 3},
	stack_max = 1,
	paramtype2 = "facedir",
	is_ground_content = false,
	after_place_node = piston_orientate,
	sounds = default.node_sound_wood_defaults(),
	mesecons = {effector={
		action_on = piston_on_delayed,
		rules = piston_get_rules
	}},
	on_rotate = piston_rotate,
	on_blast = mesecon.on_blastnode
})

-- onstate
minetest.register_node("mesecons_pistons:piston_sticky_on", {
	drawtype = "nodebox",
	tiles = {
		"mesecons_piston_side.png^[transformFY",
		"mesecons_piston_side.png",
		"mesecons_piston_side.png^[transformR90",
		"mesecons_piston_side.png^[transformR270",
		"mesecons_piston_back.png",
		"mesecons_piston_on_front.png"
	},
	groups = {cracky = 3, not_in_creative_inventory = 1},
	paramtype = "light",
	paramtype2 = "facedir",
	is_ground_content = false,
	drop = "mesecons_pistons:piston_sticky_off",
	after_dig_node = piston_after_dig,
	node_box = piston_on_box,
	selection_box = piston_on_box,
	sounds = default.node_sound_wood_defaults(),
	mesecons = {effector={
		action_off = piston_off_delayed,
		rules = piston_get_rules
	}},
	on_rotate = piston_rotate_on,
	on_blast = mesecon.on_blastnode
})

-- pusher
minetest.register_node("mesecons_pistons:piston_pusher_sticky", {
	drawtype = "nodebox",
	tiles = {
		"mesecons_piston_side.png^[transformFY",
		"mesecons_piston_side.png",
		"mesecons_piston_side.png^[transformR90",
		"mesecons_piston_side.png^[transformR270",
		"mesecons_piston_back.png",
		"mesecons_piston_pusher_front_sticky.png"
	},
	groups = {not_in_creative_inventory = 1},
	paramtype = "light",
	paramtype2 = "facedir",
	is_ground_content = false,
	diggable = false,
	selection_box = piston_pusher_box,
	node_box = piston_pusher_box,
	on_rotate = piston_rotate_pusher,
	drop = "",
	sounds = default.node_sound_wood_defaults()
})


-- Register pushers as stoppers if they would be seperated from the piston
local function piston_pusher_get_stopper(node, _, stack, stackid)
	if (stack[stackid + 1]
	and stack[stackid + 1].node.name   == get_pistonspec(node.name, "pusher").onname
	and stack[stackid + 1].node.param2 == node.param2)
	or (stack[stackid - 1]
	and stack[stackid - 1].node.name   == get_pistonspec(node.name, "pusher").onname
	and stack[stackid - 1].node.param2 == node.param2) then
		return false
	end
	return true
end

mesecon.register_mvps_stopper("mesecons_pistons:piston_pusher_normal", piston_pusher_get_stopper)
mesecon.register_mvps_stopper("mesecons_pistons:piston_pusher_sticky", piston_pusher_get_stopper)

local function piston_get_stopper(node, _, stack, stackid)
	local pistonspec = get_pistonspec(node.name, "onname")
	local dir = vmultiply(minetest.facedir_to_dir(node.param2), -1)
	local pusherpos  = vadd(stack[stackid].pos, dir)
	local pushernode = minetest.get_node(pusherpos)
	if pistonspec.pusher == pushernode.name then
		for _, s in pairs(stack) do
			if vequals(s.pos, pusherpos) -- pusher is also to be pushed
			and s.node.param2 == node.param2 then
				return false
			end
		end
	end
	return true
end

mesecon.register_mvps_stopper("mesecons_pistons:piston_normal_on", piston_get_stopper)
mesecon.register_mvps_stopper("mesecons_pistons:piston_sticky_on", piston_get_stopper)


-- craft recipes
minetest.register_craft({
	output = "mesecons_pistons:piston_normal_off 2",
	recipe = {
		{"group:wood", "group:wood", "group:wood"},
		{"default:cobble", "default:steel_ingot", "default:cobble"},
		{"default:cobble", "mesecons:wire_00000000_off", "default:cobble"}
	}
})

minetest.register_craft({
	output = "mesecons_pistons:piston_sticky_off",
	recipe = {
		{"bluestone_materials:glue"},
		{"mesecons_pistons:piston_normal_off"}
	}
})
