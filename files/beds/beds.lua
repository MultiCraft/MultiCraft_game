beds.box = {-0.5, -0.5, -0.5, 0.5, 0.06, 1.5}

function beds.dyeing(pos, _, clicker, itemstack)
	local itemname = itemstack:get_name()
	if itemname:find("dye:") then
		minetest.swap_node(pos, {
			name = "beds:bed_" .. itemname:split(":")[2],
			param2 = minetest.get_node(pos).param2
		})

		if not (creative and creative.is_enabled_for and
				creative.is_enabled_for(clicker:get_player_name())) then
			itemstack:take_item()
		end

		return true
	end
	return false
end


beds.register_bed("beds:bed", {
	description = "Bed",
	inventory_image = "beds_bed_inv.png",
	wield_image = "beds_bed_inv.png",
	tiles = {"beds_bed.png^beds_bed_red.png"},
	mesh = "beds_bed.obj",
	selectionbox = beds.box,
	collisionbox = beds.box,
	recipe = {
		{"group:wool", "group:wool", "group:wool"},
		{"group:wood", "group:wood", "group:wood"}
	},

	on_rightclick = beds.dyeing
})

minetest.register_craft({
	type = "fuel",
	recipe = "beds:bed_bottom",
	burntime = 12
})

minetest.register_alias("beds:bed_bottom", "beds:bed")
minetest.register_alias("beds:bed_top", "air")