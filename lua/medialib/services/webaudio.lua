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

local id3parser = medialib.load("id3parser")
function WebAudioService:query(url, callback)
	local function BareInformation()
		callback(nil, {
			title = url:match("([^/]+)$")
		})
	end

	-- If it's an mp3 we can use the included ID3 parser to try and parse some data
	if string.EndsWith(url, ".mp3") and id3parser then
		http.Fetch(url, function(data)
			local parsed = id3parser.readtags_data(data)
			if parsed.title then
				local title = parsed.title
				if parsed.artist then title = parsed.artist .. " - " .. title end

				local duration

				-- Some soundfiles have duration as a string containing milliseconds
				if parsed.length then
					local length = tonumber(parsed.length)
					if length then duration = length / 1000 end
				end

				callback(nil, {
					title = title,
					duration = duration
				})
			else
				BareInformation()
			end
		end)
		return
	end

	BareInformation()
end

medialib.load("media").RegisterService("webaudio", WebAudioService)