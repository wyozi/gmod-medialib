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

local player_url = "http://wyozi.github.io/gmod-medialib/youtube.html?id=%s"
--player_url = "http://localhost:8080/youtube.html?rand=" .. math.random() .. "&id=%s"

function YoutubeService:load(url, opts)
	local media = oop.class("HTMLMedia")()

	local urlData = self:parseUrl(url)
	local playerUrl = string.format(player_url, urlData.id)

	media:openUrl(playerUrl)

	if urlData.start and (not opts or not opts.dontSeek) then media:seek(urlData.start) end

	return media
end

function YoutubeService:query(url, callback)
	local urlData = self:parseUrl(url)
	local metaurl = string.format("http://gdata.youtube.com/feeds/api/videos/%s?alt=json", urlData.id)

	http.Fetch(metaurl, function(result, size)
		if size == 0 then
			callback("http body size = 0")
			return
		end

		local data = {}
		data.id = urlData.id

		local jsontbl = util.JSONToTable(result)

		if jsontbl and jsontbl.entry then
			local entry = jsontbl.entry
			data.title = entry["title"]["$t"]
			data.duration = tonumber(entry["media$group"]["yt$duration"]["seconds"])
		else
			callback(result)
			return
		end

		callback(nil, data)
	end, function(err) callback("HTTP: " .. err) end)
end

medialib.load("media").registerService("youtube", YoutubeService)