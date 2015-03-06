local oop = medialib.load("oop")

local DailyMotionService = oop.class("DailyMotionService", "HTMLService")

local all_patterns = {
	"https?://www.dailymotion.com/video/([A-Za-z0-9_%-]+)",
	"https?://dailymotion.com/video/([A-Za-z0-9_%-]+)"
}

function DailyMotionService:parseUrl(url)
	for _,pattern in pairs(all_patterns) do
		local id = string.match(url, pattern)
		if id then
			return {id = id}
		end
	end
end

function DailyMotionService:isValidUrl(url)
	return self:parseUrl(url) ~= nil
end

local player_url = "http://wyozi.github.io/gmod-medialib/dailymotion.html?id=%s"
player_url = "http://localhost:8081/dailymotion.html?id=%s"
function DailyMotionService:load(url)
	local media = oop.class("HTMLMedia")()

	local urlData = self:parseUrl(url)
	local playerUrl = string.format(player_url, urlData.id)

	media:openUrl(playerUrl)

	return media
end
-- https://api.dailymotion.com/video/x2isgrj_if-frank-underwood-was-your-coworker_fun
function DailyMotionService:query(url, callback)
	local urlData = self:parseUrl(url)
	local metaurl = string.format("http://api.dailymotion.com/video/%s", urlData.id)

	http.Fetch(metaurl, function(result, size)
		if size == 0 then
			callback("http body size = 0")
			return
		end

		local data = {}
		data.id = urlData.id

		local jsontbl = util.JSONToTable(result)

		if jsontbl then
			data.title = jsontbl.title
		else
			data.title = "ERROR"
		end

		callback(nil, data)
	end)
end

medialib.load("media").RegisterService("dailymotion", DailyMotionService)