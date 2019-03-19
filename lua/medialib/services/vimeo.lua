local oop = medialib.load("oop")

local VimeoService = oop.class("VimeoService", "HTMLService")
VimeoService.identifier = "vimeo"

local all_patterns = {
	"https?://www.vimeo.com/([0-9]+)",
	"https?://vimeo.com/([0-9]+)",
	"https?://www.vimeo.com/channels/staffpicks/([0-9]+)",
	"https?://vimeo.com/channels/staffpicks/([0-9]+)",
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
function VimeoService:resolveUrl(url, callback)
	local urlData = self:parseUrl(url)
	local playerUrl = string.format(player_url, urlData.id)

	callback(playerUrl, {start = urlData.start})
end

function VimeoService:directQuery(url, callback)
	local urlData = self:parseUrl(url)
	local metaurl = string.format("http://vimeo.com/api/v2/video/%s.json", urlData.id)

	http.Fetch(metaurl, function(result, size, _headers, httpcode)
		if size == 0 then
			callback("http body size = 0")
			return
		end

		if httpcode == 404 then
			callback("Invalid id")
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
	end, function(err) callback("HTTP: " .. err) end)
end

function VimeoService:hasReliablePlaybackEvents()
	return true
end

return VimeoService
