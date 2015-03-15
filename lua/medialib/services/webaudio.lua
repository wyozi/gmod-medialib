local oop = medialib.load("oop")
local WebAudioService = oop.class("WebAudioService", "BASSService")

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

function WebAudioService:load(url)
	local media = oop.class("BASSMedia")()

	media:openUrl(url)

	return media
end

function WebAudioService:query(url, callback)
	callback(nil, {
		title = url:match("([^/]+)$") -- the filename is the best we can get (unless we parse pls?)
	})
end

medialib.load("media").RegisterService("webaudio", WebAudioService)