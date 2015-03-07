local oop = medialib.load("oop")

local VimeoService = oop.class("VimeoService", "HTMLService")

local all_patterns = {
	"https?://www.vimeo.com/([0-9]+)",
	"https?://vimeo.com/([0-9]+)"
}

function VimeoService:parseUrl(url)
	for _,pattern in pairs(all_patterns) do
		local id = string.match(url, pattern)
		if id then
			return {id = id}
		end
	end
end

function VimeoService:isValidUrl(url)
	return self:parseUrl(url) ~= nil
end

local player_url = "http://wyozi.github.io/gmod-medialib/vimeo.html?id=%s"
function VimeoService:load(url)
	local media = oop.class("HTMLMedia")()

	local urlData = self:parseUrl(url)
	local playerUrl = string.format(player_url, urlData.id)

	media:openUrl(playerUrl)

	return media
end

function VimeoService:query(url, callback)
	local urlData = self:parseUrl(url)
	local metaurl = string.format("http://vimeo.com/api/v2/video/%s.json", urlData.id)

	http.Fetch(metaurl, function(result, size)
		if size == 0 then
			callback("http body size = 0")
			return
		end

		local data = {}
		data.id = urlData.id

		local jsontbl = util.JSONToTable(result)

		if jsontbl then
			data.title = jsontbl[1].title
			data.duration = jsontbl[1].duration
		else
			data.title = "ERROR"
		end

		callback(nil, data)
	end)
end

medialib.load("media").RegisterService("vimeo", VimeoService)