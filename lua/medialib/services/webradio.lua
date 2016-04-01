local oop = medialib.load("oop")
local WebRadioService = oop.class("WebRadioService", "BASSService")
WebRadioService.identifier = "webradio"

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

function WebRadioService:directQuery(url, callback)
	callback(nil, {
		title = url:match("([^/]+)$") -- the filename is the best we can get (unless we parse pls?)
	})
end

return WebRadioService