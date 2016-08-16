-- Some Youtube playlist utility functions
-- Cannot be used as is, but may be useful to someone.

local API_KEY = "AIzaSyBmQHvMSiOTrmBKJ0FFJ2LmNtc4YHyUJaQ"

local function queryYoutubePlaylist(plsid, callback)
	local url =
		"https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&fields=items(snippet(resourceId(kind%2CvideoId)%2Ctitle))&key=" .. API_KEY .. "&playlistId=" .. plsid

	http.Fetch(url, function(body)
		local t = util.JSONToTable(body)

		local videos = {}
		for _,vid in pairs(t.items) do
			table.insert(videos, {id = vid.snippet.resourceId.videoId})
		end

		callback(nil, {
			videos = videos
		})
	end)
end

local plsPatterns = {
	"https?://www.youtube.com/watch%?v=.*&list=([^&]+)",
	"https?://www.youtube.com/playlist%?list=([^&]+)"
}

local function matchPlaylistId(url)
	for _,patt in pairs(plsPatterns) do
		local id = url:match(patt)
		if id then return id end
	end
end
local function isPlaylistUrl(url)
	return not not matchPlaylistId(url)
end