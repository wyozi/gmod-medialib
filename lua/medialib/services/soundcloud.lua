local oop = medialib.load("oop")

local SoundcloudService = oop.class("SoundcloudService", "BASSService")
SoundcloudService.identifier = "soundcloud"

local all_patterns = {
	"^https?://www.soundcloud.com/([A-Za-z0-9_%-]+/[A-Za-z0-9_%-]+)/?.*$",
	"^https?://soundcloud.com/([A-Za-z0-9_%-]+/[A-Za-z0-9_%-]+)/?.*$",
}

function SoundcloudService:parseUrl(url)
	for _,pattern in pairs(all_patterns) do
		local id = string.match(url, pattern)
		if id then
			return {id = id}
		end
	end
end

function SoundcloudService:isValidUrl(url)
	return self:parseUrl(url) ~= nil
end

local API_KEY = "54b083f616aca3497e9e45b70c2892f5"
function SoundcloudService:resolveUrl(url, callback)
	local urlData = self:parseUrl(url)

	http.Fetch(
		string.format("https://api.soundcloud.com/resolve.json?url=http://soundcloud.com/%s&client_id=%s", urlData.id, API_KEY),
		function(data)
			local sound_id = util.JSONToTable(data).id
			callback(string.format("https://api.soundcloud.com/tracks/%s/stream?client_id=%s", sound_id, API_KEY), {})
		end)
end

function SoundcloudService:directQuery(url, callback)
	local urlData = self:parseUrl(url)
	local metaurl = string.format("http://api.soundcloud.com/resolve.json?url=http://soundcloud.com/%s&client_id=%s", urlData.id, API_KEY)

	http.Fetch(metaurl, function(result, size)
		if size == 0 then
			callback("http body size = 0")
			return
		end

		local entry = util.JSONToTable(result)

		if entry.errors then
			local msg = entry.errors[1].error_message or "error"

			local translated = msg
			if string.StartWith(msg, "404") then
				translated = "Invalid id"
			end

			callback(translated)
			return
		end

		callback(nil, {
			title = entry.title,
			duration = tonumber(entry.duration) / 1000
		})
	end, function(err) callback("HTTP: " .. err) end)
end

return SoundcloudService
