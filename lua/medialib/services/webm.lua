local oop = medialib.load("oop")

local WebmService = oop.class("WebmService", "HTMLService")
WebmService.identifier = "webm"

local all_patterns = {"^https?://.*%.webm"}

function WebmService:parseUrl(url)
	for _,pattern in pairs(all_patterns) do
		local id = string.match(url, pattern)
		if id then
			return {id = id}
		end
	end
end

function WebmService:isValidUrl(url)
	return self:parseUrl(url) ~= nil
end

local player_url = "http://wyozi.github.io/gmod-medialib/webm.html?id=%s"
function WebmService:resolveUrl(url, callback)
	local urlData = self:parseUrl(url)
	local playerUrl = string.format(player_url, urlData.id)

	callback(playerUrl, {start = urlData.start})
end

function WebmService:directQuery(url, callback)
	callback(nil, {
		title = url:match("([^/]+)$")
	})
end

return WebmService