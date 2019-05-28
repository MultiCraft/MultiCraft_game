
sethome = {}

local homes_file = minetest.get_worldpath() .. "/homes"
local homepos = {}

local function loadhomes()
	local input = io.open(homes_file, "r")
	if not input then
		return -- no longer an error
	end

	-- Iterate over all stored positions in the format "x y z player" for each line
	for pos, name in input:read("*a"):gmatch("(%S+ %S+ %S+)%s([%w_-]+)[\r\n]") do
		homepos[name] = minetest.string_to_pos(pos)
	end
	input:close()
end

loadhomes()

sethome.set = function(name, pos)
	local player = minetest.get_player_by_name(name)
	if not player or not pos then
		return false
	end
	player:set_attribute("sethome:home", minetest.pos_to_string(pos))

	-- remove `name` from the old storage file
	local data = {}
	local output = io.open(homes_file, "w")
	if output then
		homepos[name] = nil
		for i, v in pairs(homepos) do
			table.insert(data, string.format("%.1f %.1f %.1f %s\n", v.x, v.y, v.z, i))
		end
		output:write(table.concat(data))
		io.close(output)
		return true
	end
	return true -- if the file doesn't exist - don't return an error.
end

sethome.get = function(name)
	local player = minetest.get_player_by_name(name)
	local pos = minetest.string_to_pos(player:get_attribute("sethome:home"))
	if pos then
		return pos
	end

	-- fetch old entry from storage table
	pos = homepos[name]
	if pos then
		return vector.new(pos)
	else
		return nil
	end
end

sethome.go = function(name)
	local pos = sethome.get(name)
	local player = minetest.get_player_by_name(name)
	if player and pos then
		player:set_pos(pos)
		return true
	end
	return false
end

minetest.register_chatcommand("home", {
	description = "Teleport you to your home point",
	func = function(name)
		if sethome.go(name) then
			return true, "Teleported to home!"
		end
		return false, "Set a home using /sethome"
	end,
})

minetest.register_chatcommand("sethome", {
	description = "Set your home point",
	func = function(name)
		name = name or "" -- fallback to blank name if nil
		local player = minetest.get_player_by_name(name)
		if player and sethome.set(name, player:get_pos()) then
			return true, "Home set!"
		end
		return false, "Player not found!"
	end,
})

minetest.register_chatcommand("home set", {
	description = "Set your home point",
	func = function(name)
		name = name or "" -- fallback to blank name if nil
		local player = minetest.get_player_by_name(name)
		if player and sethome.set(name, player:get_pos()) then
			return true, "Home set!"
		end
		return false, "Player not found!"
	end,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if not player or not player:is_player() then
		return
	end
	local player_name = player:get_player_name()
	if fields.sethome_set then
		sethome.set(player_name, player:get_pos())
		minetest.chat_send_player(player_name, "Home set!")
	elseif fields.sethome_go then
		if sethome.go(player_name) then
			sethome.go(player_name)
			minetest.chat_send_player(player_name, "Teleported to home!")
		else
			minetest.chat_send_player(player_name, "Home is not set!")
		end
	end
end)
