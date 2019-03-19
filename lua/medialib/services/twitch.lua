local oop = medialib.load("oop")

local TwitchService = oop.class("TwitchService", "HTMLService")
TwitchService.identifier = "twitch"

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

local player_url = "https://wyozi.github.io/gmod-medialib/twitch.html?channel=%s"
function TwitchService:resolveUrl(url, callback)
	local urlData = self:parseUrl(url)
	local playerUrl = string.format(player_url, urlData.id)

	callback(playerUrl, {start = urlData.start})
end

local CLIENT_ID = "4cryixome326gh0x0j0fkulahsbdvx"

local function nameToId(name, callback)
	http.Fetch("https://api.twitch.tv/kraken/users?login=" .. name, function(b)
		local obj = util.JSONToTable(b)
		if not obj then
			callback("malformed response JSON")
			return
		end

		callback(nil, obj.users[1]._id)
	end, function()
		callback("failed HTTP request")
	end, {
		Accept = "application/vnd.twitchtv.v5+json",
		["Client-ID"] = CLIENT_ID
	})
end

local function metaQuery(id, callback)
	http.Fetch("https://api.twitch.tv/kraken/channels/" .. id, function(b)
		local obj = util.JSONToTable(b)
		if not obj then
			callback("malformed response JSON")
			return
		end

		callback(nil, obj)
	end, function()
		callback("failed HTTP request")
	end, {
		Accept = "application/vnd.twitchtv.v5+json",
		["Client-ID"] = CLIENT_ID
	})
end

function TwitchService:directQuery(url, callback)
	local urlData = self:parseUrl(url)

	nameToId(urlData.id, function(err, id)
		if err then
			callback(err)
			return
		end

		metaQuery(id, function(metaErr, meta)
			if metaErr then
				callback(metaErr)
				return
			end

			local data = {}
			data.id = urlData.id

			if meta.error then
				callback(meta.message)
				return
			else
				data.title = meta.display_name .. ": " .. meta.status
			end

			callback(nil, data)
		end)
	end)
end

return TwitchService