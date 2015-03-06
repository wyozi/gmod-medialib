local oop = medialib.load("oop")

local UstreamService = oop.class("UstreamService", "HTMLService")

local all_patterns = {
	"https?://www.ustream.tv/channel/([A-Za-z0-9_%-]+)",
	"https?://ustream.tv/channel/([A-Za-z0-9_%-]+)"
}

function UstreamService:parseUrl(url)
	for _,pattern in pairs(all_patterns) do
		local id = string.match(url, pattern)
		if id then
			return {id = id}
		end
	end
end

function UstreamService:isValidUrl(url)
	return self:parseUrl(url) ~= nil
end

local player_url = "http://wyozi.github.io/gmod-medialib/ustream.html?id=%s"
function UstreamService:load(url)
	local media = oop.class("HTMLMedia")()

	-- For ustream we need to query metadata to get the embed id
	self:query(url, function(err, data)
		media:openUrl(string.format(player_url, data.embed_id))
	end)

	return media
end

function UstreamService:query(url, callback)
	local urlData = self:parseUrl(url)
	local metaurl = string.format("http://api.ustream.tv/json/channel/%s/getInfo", urlData.id)

	http.Fetch(metaurl, function(result, size)
		if size == 0 then
			callback("http body size = 0")
			return
		end

		local data = {}
		data.id = urlData.id

		local jsontbl = util.JSONToTable(result)

		if jsontbl then
			data.embed_id = jsontbl.results.id
			data.title = jsontbl.results.title
		else
			data.title = "ERROR"
		end

		callback(nil, data)
	end)
end

medialib.load("media").RegisterService("ustream", UstreamService)