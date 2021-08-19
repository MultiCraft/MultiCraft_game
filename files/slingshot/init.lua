
slingshot = {}
slingshot.modname = core.get_current_modname()
slingshot.modpath = core.get_modpath(slingshot.modname)

function slingshot.log(lvl, msg)
	if not msg then
		msg = lvl
		lvl = nil
	end

	if not msg and not lvl then
		lvl = "error"
		msg = "no log arguments supplied"
	end

	msg = "[" .. slingshot.modname .. "] " .. msg
	if lvl == "debug" then
		if not slingshot.debug then return end

		msg = "[DEBUG] " .. msg
		lvl = nil
	end

	if not lvl then
		core.log(msg)
	else
		core.log(lvl, msg)
	end
end


local scripts = {
	"settings",
	"api",
	"weapons",
}

for index, script in ipairs(scripts) do
	dofile(slingshot.modpath .. "/" .. script .. ".lua")
end
