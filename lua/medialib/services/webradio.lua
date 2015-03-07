local oop = medialib.load("oop")
local WebRadioService = oop.class("WebRadioService", "BASSService")

local all_patterns = {
	"^https?://(.*)%.pls"
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

function WebRadioService:load(url)
	local media = oop.class("BASSMedia")()

	media:openUrl(url)

	return media
end

function WebRadioService:query(url, callback)
	callback(nil, {
		title = url:match("([^/]+)$") -- the filename is the best we can get (unless we parse pls?)
	})
end

medialib.load("media").RegisterService("webradio", WebRadioService)