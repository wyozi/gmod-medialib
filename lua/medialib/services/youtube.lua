local oop = medialib.load("oop")

local YoutubeService = oop.class("YoutubeService", "HTMLService")
YoutubeService.identifier = "youtube"

local raw_patterns = {
	"^https?://[A-Za-z0-9%.%-]*%.?youtu%.be/([A-Za-z0-9_%-]+)",
	"^https?://[A-Za-z0-9%.%-]*%.?youtube%.com/watch%?.*v=([A-Za-z0-9_%-]+)",
	"^https?://[A-Za-z0-9%.%-]*%.?youtube%.com/v/([A-Za-z0-9_%-]+)",
}
local all_patterns = {}

-- Appends time modifier patterns to each pattern
for _, p in pairs(raw_patterns) do
	local function with_sep(sep)
		table.insert(all_patterns, p .. sep .. "t=(%d+)m(%d+)s")
		table.insert(all_patterns, p .. sep .. "t=(%d+)s?")
	end

	-- We probably support more separators than youtube itself, but that does not matter
	with_sep("#")
	with_sep("&")
	with_sep("?")

	table.insert(all_patterns, p)
end

function YoutubeService:parseUrl(url)
	for _,pattern in pairs(all_patterns) do
		local id, time1, time2 = string.match(url, pattern)
		if id then
			local time_sec
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

local player_url = "http://wyozi.github.io/gmod-medialib/youtube.html?id=%s"
function YoutubeService:resolveUrl(url, callback)
	local urlData = self:parseUrl(url)
	local playerUrl = string.format(player_url, urlData.id)

	callback(playerUrl, {start = urlData.start})
end

-- http://en.wikipedia.org/wiki/ISO_8601#Durations
-- Cheers wiox :))
local function PTToSeconds(str)
	local h = str:match("(%d+)H") or 0
	local m = str:match("(%d+)M") or 0
	local s = str:match("(%d+)S") or 0
	return h*(60*60) + m*60 + s
end

local DEFAULT_API_KEY = "AIzaSyBmQHvMSiOTrmBKJ0FFJ2LmNtc4YHyUJaQ"

function YoutubeService:directQuery(url, callback)
	local apiKey = medialib.YOUTUBE_API_KEY or DEFAULT_API_KEY

	local urlData = self:parseUrl(url)
	local metaurl = string.format(
		"https://www.googleapis.com/youtube/v3/videos?part=snippet%%2CcontentDetails&id=%s&key=%s",
		urlData.id, apiKey
	)

	http.Fetch(metaurl, function(result, size)
		if size == 0 then
			callback("http body size = 0")
			return
		end

		local data = {}
		data.id = urlData.id

		local jsontbl = util.JSONToTable(result)

		if jsontbl and jsontbl.items then
			local item = jsontbl.items[1]
			if not item then
				callback("No video id found")
				return
			end

			data.title = item.snippet.title

			local live = item.snippet.liveBroadcastContent == "live"
			if live then
				data.live = true
			else
				data.duration = tonumber(PTToSeconds(item.contentDetails.duration))
			end
			data.raw = item
		else
			callback(result)
			return
		end

		callback(nil, data)
	end, function(err) callback("HTTP: " .. err) end)
end

function YoutubeService:hasReliablePlaybackEvents()
	return true
end

return YoutubeService
