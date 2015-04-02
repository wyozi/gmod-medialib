## gmod-medialib

Media library for Garry's Mod.

### Setup
Easiest way to add gmod-medialib to your project is to copy ```dist/medialib.lua``` into your addon/gamemode. Make sure it is shared (```AddCSLuaFile``` on server and ```include``` on both server and client)

### Example

```lua
-- If existing global reference exists, remove them
if IsValid(CLIP) then CLIP:stop() end

local link = "https://www.youtube.com/watch?v=6IqKEeRS90A"

-- Get the service that this link uses (eg. youtube, twitch, vimeo, webaudio)
local service = medialib.load("media").guessService(link)

-- Create a mediaclip from the link
local mediaclip = service:load(link)

-- Store global reference for debugging purposes
CLIP = mediaclip

-- Play media
mediaclip:play()

-- Query metadata. Note: 'mediaclip' instance is not used here.
local meta
service:query(link, function(err, data)
	-- 'err' is non-nil if there's an error. It should be checked here, but
	-- because this is an example we're lazy.
	if data then meta = data end
end)

-- Draw video
hook.Add("HUDPaint", "DrawVideo", function()
	local w = 500 
	local h = w * (9/16)
	
	mediaclip:draw(0, 0, w, h)
	
	surface.SetDrawColor(255, 255, 255)
	surface.DrawRect(0, h, w, 25)
	
	-- 'meta' is fetched asynchronously, so we need to check if it exists
	local title, duration = tostring(meta and meta.title), 
							(meta and meta.duration) or 0
	
	draw.SimpleText(title, "DermaDefaultBold", 5, h+3, Color(0, 0, 0))
	
	local timeStr = string.format("%.1f / %.1f", mediaclip:getTime(), duration)
	draw.SimpleText(timeStr, "DermaDefaultBold", w - 5, h+3, Color(0, 0, 0), TEXT_ALIGN_RIGHT)
end)
```

See ```examples/``` for more elaborate examples.