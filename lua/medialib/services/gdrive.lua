local oop = medialib.load("oop")

local GDriveService = oop.class("GDriveService", "HTMLService")
GDriveService.identifier = "GDrive"

local all_patterns = {"^https?://drive.google.com/file/d/([^/]*)/edit"}

function GDriveService:parseUrl(url)
	for _,pattern in pairs(all_patterns) do
		local id = string.match(url, pattern)
		if id then
			return {id = id}
		end
	end
end

function GDriveService:isValidUrl(url)
	return self:parseUrl(url) ~= nil
end

local function urlencode(str)
   if (str) then
      str = string.gsub (str, "\n", "\r\n")
      str = string.gsub (str, "([^%w ])",
         function (c) return string.format ("%%%02X", string.byte(c)) end)
      str = string.gsub (str, " ", "+")
   end
   return str    
end

local player_url = "https://wyozi.github.io/gmod-medialib/mp4.html?id=%s"
local gdrive_stream_url = "https://drive.google.com/uc?export=download&confirm=yTib&id=%s"
function GDriveService:resolveUrl(url, callback)
	local urlData = self:parseUrl(url)
	local playerUrl = string.format(player_url, urlencode(string.format(gdrive_stream_url, urlData.id)))

	callback(playerUrl, {start = urlData.start})
end

function GDriveService:directQuery(url, callback)
	callback(nil, {
		title = url:match("([^/]+)$")
	})
end

function GDriveService:hasReliablePlaybackEvents(media)
	return true
end

return GDriveService