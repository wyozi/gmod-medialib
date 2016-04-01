local oop = medialib.load("oop")
local WebAudioService = oop.class("WebAudioService", "BASSService")
WebAudioService.identifier = "webaudio"

local all_patterns = {
	"^https?://(.*)%.mp3",
	"^https?://(.*)%.ogg",
}

function WebAudioService:parseUrl(url)
	for _,pattern in pairs(all_patterns) do
		local id = string.match(url, pattern)
		if id then
			return {id = id}
		end
	end
end

function WebAudioService:isValidUrl(url)
	return self:parseUrl(url) ~= nil
end

function WebAudioService:resolveUrl(url, callback)
	callback(url, {})
end

function WebAudioService:directQuery(url, callback)
	callback(nil, {
		title = url:match("([^/]+)$")
	})
end

return WebAudioService