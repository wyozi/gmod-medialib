local oop = medialib.load("oop")

local SoundcloudService = oop.class("SoundcloudService", "BASSService")
SoundcloudService.identifier = "soundcloud"

local all_patterns = {
	"^https?://www.soundcloud.com/([A-Za-z0-9_%-]+/[A-Za-z0-9_%-]+)/?.*$",
	"^https?://soundcloud.com/([A-Za-z0-9_%-]+/[A-Za-z0-9_%-]+)/?.*$",
}

-- Support url that passes track id directly
local id_pattern = "^https?://api.soundcloud.com/tracks/(%d+)"

function SoundcloudService:parseUrl(url)
	for _,pattern in pairs(all_patterns) do
		local path = string.match(url, pattern)
		if path then
			return {path = path}
		end
	end

	local id = string.match(url, id_pattern)
	if id then
		return {id = id}
	end
end

function SoundcloudService:isValidUrl(url)
	return self:parseUrl(url) ~= nil
end

function SoundcloudService:resolveUrl(url, callback)
	local apiKey = medialib.SOUNDCLOUD_API_KEY
	if not apiKey then
		ErrorNoHalt("SoundCloud error: Missing SoundCloud API key")
		return
	end

	if type(apiKey) == "table" then
		apiKey = table.Random(apiKey)
	end

	local urlData = self:parseUrl(url)

	if urlData.id then
		-- id passed directly; nice, we can skip resolve.json
		callback(string.format("https://api.soundcloud.com/tracks/%s/stream?client_id=%s", urlData.id, apiKey), {})
	else
		http.Fetch(
			string.format(
				"https://api.soundcloud.com/resolve.json?url=http://soundcloud.com/%s&client_id=%s",
				urlData.path, apiKey
			),
			function(data)
				local jsonTable = util.JSONToTable(data)
				if not jsonTable then
					ErrorNoHalt("Failed to retrieve SC track id for " .. urlData.path .. ": empty JSON")
					return
				end

				local id = jsonTable.id
				callback(string.format("https://api.soundcloud.com/tracks/%s/stream?client_id=%s", id, apiKey), {})
			end)
	end
end

function SoundcloudService:directQuery(url, callback)
	local apiKey = medialib.SOUNDCLOUD_API_KEY
	if not apiKey then
		callback("Missing SoundCloud API key")
		return
	end

	if type(apiKey) == "table" then
		apiKey = table.Random(apiKey)
	end

	local urlData = self:parseUrl(url)

	local metaurl
	if urlData.path then
		metaurl = string.format(
			"https://api.soundcloud.com/resolve.json?url=http://soundcloud.com/%s&client_id=%s",
			urlData.path, apiKey
		)
	else
		metaurl = string.format("https://api.soundcloud.com/tracks/%s?client_id=%s", urlData.id, apiKey)
	end

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
