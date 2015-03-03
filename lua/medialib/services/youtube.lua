local oop = medialib.load("oop")

local YoutubeService = oop.class("YoutubeService", "HTMLService")

local raw_patterns = {
	"^https?://[A-Za-z0-9%.%-]*%.?youtu%.be/([A-Za-z0-9_%-]+)",
	"^https?://[A-Za-z0-9%.%-]*%.?youtube%.com/watch%?.*v=([A-Za-z0-9_%-]+)",
	"^https?://[A-Za-z0-9%.%-]*%.?youtube%.com/v/([A-Za-z0-9_%-]+)",
}

local all_patterns = {}

-- Appends time modifier patterns to each pattern
for k,p in pairs(raw_patterns) do
	local hash_letter = "#"
	if k == 1 then
		hash_letter = "?"
	end
	table.insert(all_patterns, p .. hash_letter .. "t=(%d+)m(%d+)s")
	table.insert(all_patterns, p .. hash_letter .. "t=(%d+)s?")
	table.insert(all_patterns, p)
end

function YoutubeService:parseUrl(url)
	for _,pattern in pairs(all_patterns) do
		local id, time1, time2 = string.match(url, pattern)
		if id then
			local time_sec = 0
			if time1 and time2 then
				time_sec = tonumber(time1)*60 + tonumber(time2)
			else
				time_sec = tonumber(time1)
			end

			return {
				id = id,
				start = time_sec
			}
		end
	end
end

function YoutubeService:isValidUrl(url)
	return self:parseUrl(url) ~= nil
end

function YoutubeService:load(url)
	local media = oop.class("HTMLMedia")()

	local urlData = self:parseUrl(url)
	local playerUrl = "http://wyozi.github.io/gmod-medialib/youtube.html?id=" .. urlData.id

	media:openUrl(playerUrl)

	return media
end

medialib.load("media").RegisterService("youtube", YoutubeService)