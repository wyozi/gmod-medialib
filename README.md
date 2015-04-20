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

-- Query metadata. Instead of 'mediaclip' we use 'service' here.
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

### API

Method | Description | Notes
---|---|---
```medialib.load("media").guessService(url)``` | Returns a ```Service``` object based on the URL. Returns ```nil``` if there is no service for the URL.
```Service:load(url, options)``` | Creates a ```Media``` object using the URL
```Service:query(url, callback)``` | Queries for metadata about video (eg. ```title``` and ```duration```)
```Media:on(name, listener)``` | Adds an event listener. See below for a list of events
```Media:isValid()``` | Returns a boolean indicating whether media is valid | [Note](# "Invalid media does not mean that media has stopped. For example media is usually invalid during loading phase.")
```Media:getServiceBase()``` | Returns the media service type, which is one of the following: "html", "bass"
```Media:getService()``` | Returns the service from which this media was loaded
```Media:getUrl()``` | Returns the original url passed to ```Service:load```, from which this media was loaded
```Media:play()``` | Plays media. A ```playing``` event is emitted when media starts playing.
```Media:pause()``` | Pause media. A ```paused``` event is emitted when media pauses.
```Media:stop()``` | Pause media. A ```stopped``` event is emitted when media stops.
```Media:getState()``` | Returns state of media, which is one of the following: "error", "loading", "buffering", "playing", "paused", "stopped" | [Note](# "Not supported by all services.")
```Media:isPlaying()``` | Returns a boolean indicating whether media is playing. Uses ```getState()```.
```Media:setVolume(vol)``` | Sets volume. ```vol``` must be a float between 0 and 1.
```Media:setQuality(qual)``` | Sets quality. ```qual``` must be one of the following: "low", "medium", "high", "veryhigh" | [Note](# "Not guaranteed to use equivalent quality on all services. Not supported by all services.")
```Media:getTime()``` | Returns the elapsed time
```Media:seek(time)``` | Seeks to specified time. | [Note](# "Not guaranteed to hop to the exact time. Not supported by all services.")
```Media:sync(time, errorMargin)``` | Seeks to given time, if the elapsed time differs from it too much (more than errorMargin) | [Note](# "Sync does not work on invalid or not playing media. Media can be synchronized at most once per five seconds.")

### Events

__Media__

Event name | Parameters | Description
---|---|---
```playing``` | | Called when media starts playing
```paused``` | | Called when media is paused
```buffering``` | | Called when media is buffering. A ```playing``` event is emitted when buffering stops.
```ended``` | | Called when media ends