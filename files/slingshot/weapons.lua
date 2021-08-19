-- Registrations for slinghot mod


local S = core.get_translator(slingshot.modname)

local textures = {
	rubber_band = "rubber_band",
	wood = "wood",
	iron = "iron",
}
if slingshot.old_textures then
	for k, v in pairs(textures) do
		textures[k] = v .. "-old"
	end
end


local rubber_available = core.registered_items["technic:rubber"] ~= nil
local latex_available = core.registered_items["technic:raw_latex"] ~= nil

if rubber_available or latex_available then
	core.register_craftitem("slingshot:rubber_band", {
		description = S("Rubber Band"),
		inventory_image = "slingshot_" .. textures.rubber_band .. ".png",
	})
end

if rubber_available then
	core.register_craft({
		output = "slingshot:rubber_band 6",
		type = "shapeless",
		recipe = {"technic:rubber"},
	})
end

if latex_available then
	core.register_craft({
		output = "slingshot:rubber_band 2",
		recipe = {
			{"technic:raw_latex", "technic:raw_latex", ""},
			{"technic:raw_latex", "", "technic:raw_latex"},
			{"", "technic:raw_latex", "technic:raw_latex"},
		}
	})
end


-- A wooden slingshot
slingshot.register("wood", {
	description = S("Wooden Slingshot"),
	image = "slingshot_" .. textures.wood .. ".png",
	damage_groups = {fleshy=1},
	velocity = 15,
	wear_rate = 500,
})
for _, a in ipairs({slingshot.modname .. ":wooden", "wood_slingshot", "wooden_slingshot"}) do
	core.register_alias(a, slingshot.modname .. ":wood")
end

local ing_1 = "group:stick"
local ing_2 = ""
if core.registered_items["slingshot:rubber_band"] then
	ing_2 = "slingshot:rubber_band"
end

core.register_craft({
	output = slingshot.modname .. ":wood",
	recipe = {
		{ing_1, ing_2, ing_1},
		{"", ing_1, ""},
		{"", ing_1, ""},
	}
})


-- A stronger iron slingshot
slingshot.register("iron", {
	description = S("Steel Slingshot"),
	image = "slingshot_" .. textures.iron .. ".png",
	damage_groups = {fleshy=3},
	velocity = 19,
	wear_rate = 250,
})
for _, a in ipairs({slingshot.modname .. ":slingshot", "iron_slingshot"}) do
	core.register_alias(a, slingshot.modname .. ":iron")
end

if core.registered_items["default:steel_ingot"] then
	ing_1 = "default:steel_ingot"

	core.register_craft({
		output = slingshot.modname .. ":iron",
		recipe = {
			{ing_1, ing_2, ing_1},
			{"", ing_1, ""},
			{"", ing_1, ""},
		}
	})
end
