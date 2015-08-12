local mediaregistry = medialib.module("mediaregistry")

local cache = setmetatable({}, {__mode = "v"})

function mediaregistry.add(media)
	table.insert(cache, media)
end

concommand.Add("medialib_stopall", function()
	for _,v in pairs(cache) do
		v:stop()
	end

	table.Empty(cache)
end)
