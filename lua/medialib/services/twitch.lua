local oop = medialib.load("oop")

local TwitchService = oop.class("TwitchService", "HTMLService")

local all_patterns = {
	"https?://www.twitch.tv/([A-Za-z0-9_%-]+)",
	"https?://twitch.tv/([A-Za-z0-9_%-]+)"
}

function TwitchService:parseUrl(url)
	for _,pattern in pairs(all_patterns) do
		local id = string.match(url, pattern)
		if id then
			return {id = id}
		end
	end
end

function TwitchService:isValidUrl(url)
	return self:parseUrl(url) ~= nil
end

local player_url = "http://wyozi.github.io/gmod-medialib/twitch.html?channel=%s"
function TwitchService:load(url)
	local media = oop.class("HTMLMedia")()

	local urlData = self:parseUrl(url)
	local playerUrl = string.format(player_url, urlData.id)

	media:openUrl(playerUrl)

	return media
end

function TwitchService:query(url, callback)
	local urlData = self:parseUrl(url)
	local metaurl = string.format("https://api.twitch.tv/kraken/channels/%s", urlData.id)

	http.Fetch(metaurl, function(result, size)
		if size == 0 then
			callback("http body size = 0")
			return
		end

		local data = {}
		data.id = urlData.id

		local jsontbl = util.JSONToTable(result)

		if jsontbl then
			data.title = jsontbl.display_name .. ": " .. jsontbl.status
		else
			data.title = "ERROR"
		end

		callback(nil, data)
	end)
end

medialib.load("media").RegisterService("twitch", TwitchService)