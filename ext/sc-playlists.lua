-- Some SoundCloud playlist utility functions
-- Cannot be used as is, but may be useful to someone.

local API_KEY = "54b083f616aca3497e9e45b70c2892f5"

local function queryPlaylist(id, cb)
	http.Fetch("http://api.soundcloud.com/playlists/" .. id .. "?representation=id&client_id=" .. API_KEY, function(body)
		local t = util.JSONToTable(body)

		local trackIds = {}
		for _,tr in pairs(t.tracks) do
			table.insert(trackIds, tr.id)
		end

		cb(nil, {
			title = t.title,
			trackIds = trackIds
		})
	end)
end

local pls_pattern = "^https?://soundcloud.com/([A-Za-z0-9_%-]+)/sets/([A-Za-z0-9_%-]+)/?.*$"
local function isPlaylistUrl(url)
	return not not string.match(url, pls_pattern)
end
local function queryPlaylistUrl(url, cb)
	local user, plsName = string.match(url, pls_pattern)
	http.Fetch("http://api.soundcloud.com/resolve?url=https://soundcloud.com/" .. user .. "/sets/" .. plsName .. "&client_id=" .. API_KEY, function(body)
		local t = util.JSONToTable(body)

		if not t then
			cb("nil json table") return
		end

		if t.errors then
			cb(tostring(t.errors[1].error)) return
		end

		local firstTrackId = (t.tracks[1] and t.tracks[1].id)
		cb(nil, "scpls://" .. t.id .. "@" .. firstTrackId)
	end)
end