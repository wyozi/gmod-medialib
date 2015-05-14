local oop = medialib.load("oop")
local WebRadioService = oop.class("WebRadioService", "BASSService")

local all_patterns = {
	"^https?://(.*)%.pls",
	"^https?://(.*)%.m3u"
}

function WebRadioService:parseUrl(url)
	for _,pattern in pairs(all_patterns) do
		local id = string.match(url, pattern)
		if id then
			return {id = id}
		end
	end
end

function WebRadioService:isValidUrl(url)
	return self:parseUrl(url) ~= nil
end

function WebRadioService:resolveUrl(url, callback)
	callback(url, {})
end

local shoutcastmeta = medialib.load("shoutcastmeta")
function WebRadioService:query(url, callback)
	local function EmitBasicMeta()
		callback(nil, {
			title = url:match("([^/]+)$") -- the filename is the best we can get (unless we parse pls?)
		})
	end

	-- Use shoutcastmeta extension if available
	if shoutcastmeta then
		shoutcastmeta.fetch(url, function(err, data)
			if err then
				EmitBasicMeta()
				return
			end

			callback(nil, data)
		end)
		return
	end

	EmitBasicMeta()	
end

medialib.load("media").registerService("webradio", WebRadioService)