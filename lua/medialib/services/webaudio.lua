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

function WebAudioService:resolveUrl(url, callback)
	callback(url, {})
end

local id3parser = medialib.load("id3parser")
local mp3duration = medialib.load("mp3duration")
function WebAudioService:query(url, callback)
	-- If it's an mp3 we can use the included ID3/MP3-duration parser to try and parse some data
	if string.EndsWith(url, ".mp3") and (id3parser or mp3duration) then
		http.Fetch(url, function(data)
			local title, duration

			if id3parser then
				local parsed = id3parser.readtags_data(data)
				if parsed and parsed.title then
					title = parsed.title
					if parsed.artist then title = parsed.artist .. " - " .. title end

					-- Some soundfiles have duration as a string containing milliseconds
					if parsed.length then
						local length = tonumber(parsed.length)
						if length then duration = length / 1000 end
					end
				end
			end

			if mp3duration then
				duration = mp3duration.estimate_data(data) or duration
			end

			callback(nil, {
				title = title or url:match("([^/]+)$"),
				duration = duration
			})
		end)
		return
	end

	callback(nil, {
		title = url:match("([^/]+)$")
	})
end

medialib.load("media").registerService("webaudio", WebAudioService)