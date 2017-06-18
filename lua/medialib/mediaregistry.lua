local mediaregistry = medialib.module("mediaregistry")

local cache = setmetatable({}, {__mode = "v"})

function mediaregistry.add(media)
	table.insert(cache, media)
end
function mediaregistry.get()
	return cache
end

concommand.Add("medialib_listall", function()
	hook.Run("MediaLib_ListAll")
end)
hook.Add("MediaLib_ListAll", "MediaLib_" .. medialib.INSTANCE, function()
	print("Media for medialib version " .. medialib.INSTANCE .. ":")
	for _,v in pairs(cache) do
		print(v:getDebugInfo())
	end
end)

concommand.Add("medialib_stopall", function()
	hook.Run("MediaLib_StopAll")
end)
hook.Add("MediaLib_StopAll", "MediaLib_" .. medialib.INSTANCE, function()
	for _,v in pairs(cache) do
		v:stop()
	end

	table.Empty(cache)
end)

local cvar_debug = CreateConVar("medialib_debugmedia", "0")
hook.Add("HUDPaint", "MediaLib_G_DebugMedia", function()
	if not cvar_debug:GetBool() then return end
	local counter = {0}
	hook.Run("MediaLib_DebugPaint", counter)
end)

hook.Add("MediaLib_DebugPaint", "MediaLib_" .. medialib.INSTANCE, function(counter)
	local i = counter[1]
	for _,media in pairs(cache) do
		local t = string.format("#%d %s", i, media:getDebugInfo())
		draw.SimpleText(t, "DermaDefault", 10, 10 + i*15)

		i=i+1
	end
	counter[1] = i
end)