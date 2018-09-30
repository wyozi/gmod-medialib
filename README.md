## gmod-medialib

Media library for Garry's Mod.

### Workaround as of 2018/09/30

Awesomium (the embedded web browser) in Garry's Mod doesn't work with Youtube. To fix this you need to use the `chromium` branch for Garry's Mod. See https://github.com/wyozi/gmod-medialib/issues/64 for details.

### Setup

1. Copy ```dist/medialib.lua``` into your addon/gamemode
2. Make sure it is available to clients via `AddCSLuaFile`
3. Include it where-ever you need it. See best-practises below:
	- `local medialib = include("the/path/to/medialib.lua")` if you only use it in one file
	- `MyGlobalTable.medialib = include("the/path/to/medialib.lua")` if you use it multiple times (you need to refer to medialib as `MyGlobalTable.medialib` or localize it if you do this)

### Configuration

Medialib offers some configuration options that can be set by setting members of the imported medialib object.

```lua
-- Example library import
local medialib = include("medialib.lua")

-- SoundCloud API key. Required for SoundCloud service
-- Can also be a table in which case a random key is picked for each query.
medialib.SOUNDCLOUD_API_KEY = "my-key-here"

-- The maximum number of HTML panel instances in the HTML pool
-- Set this to a sensible number (1-5) if you spawn a lot of HTML medias
medialib.MAX_HTMLPOOL_INSTANCES = 0
```

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

-- Draw video
hook.Add("HUDPaint", "DrawVideo", function()
	local w = 500
	local h = w * (9/16)

	mediaclip:draw(0, 0, w, h)

	surface.SetDrawColor(255, 255, 255)
	surface.DrawRect(0, h, w, 25)

	-- Request metadata. 'meta' will be nil if metadata is still being fetched.
	-- Note: this is a clientside shortcut to Service#query. You should use Service#query on serverside.
	local meta = mediaclip:lookupMetadata()

	local title, duration = tostring(meta and meta.title),
							(meta and meta.duration) or 0

	draw.SimpleText(title, "DermaDefaultBold", 5, h+3, Color(0, 0, 0))

	local timeStr = string.format("%.1f / %.1f", mediaclip:getTime(), duration)
	draw.SimpleText(timeStr, "DermaDefaultBold", w - 5, h+3, Color(0, 0, 0), TEXT_ALIGN_RIGHT)
end)
```

See ```examples/``` for more elaborate examples.

### Resource usage
- __Server ⇋ Client__

>Medialib provides no means of communication between server and client. This means that to for example synchronize video between clients, you must handle networking the media URL and the media start time yourself.
>
> For this purpose you might find my [NetTable](https://github.com/wyozi/gmod-nettable) library useful, but medialib itself contains no networking code.

- __Client__

> On clientside medialib uses either HTML Awesomium panels or BASS sound objects for playback.
>
> HTML panels are relatively expensive way to playback videos, but having one or two of them should work fine.
> BASS sound objects (which are used for webaudio and webradio) are pretty cheap. There should be no problem having many of them playing at the same time if needed.
>
> In a nutshell you should use mp3 or ogg files when possible, as they are way cheaper for media playback, but for things like media players that must accept Youtube links HTML media works fine.
> If there can be arbitrary amount of player controlled jukeboxes on the map, you might want to add some limitations so eg. more than two cannot play simultaneously.

- __Shared (server and client)__

> Both server and client have the ability to query for video metadata.
>
> This is not instant, as HTTP queries used for majority of services take their time, but querying for metadata is pretty cheap as long as you don't do it in a Think hook or similar.



### API

Method | Description | Notes
---|---|---
```medialib.load("media").guessService(url, [opts])``` | Returns a ```Service``` object based on the URL. Returns ```nil``` if there is no service for the URL. | [Note](# "opts is an optional table. If the table exists and contains field 'whitelist', only services that are in the whitelist are checked for validity.")
```Service:load(url, options)``` | Creates a ```Media``` object using the URL
```Service:query(url, callback)``` | Queries for metadata about video (eg. ```title``` and ```duration```)
```Media:on(name, listener)``` | Adds an event listener. See below for a list of events
```Media:isValid()``` | Returns a boolean indicating whether media is valid | [Note](# "Invalid media does not mean that media has stopped. For example media is usually invalid during loading phase.")
```Media:getServiceBase()``` | Returns the media service type, which is one of the following: "html", "bass"
```Media:getService()``` | Returns the service from which this media was loaded
```Media:getUrl()``` | Returns the original url passed to ```Service:load```, from which this media was loaded
```Media:lookupMetadata()``` | Returns metadata if it's cached. Otherwise queries service for metadata and returns nil. | [Note](# "Should be called repeatedly; this will return nil until metadata *is* available. Return value is usually identical to metadata returned from Service:query, but Media is allowed to replace/add values derived from the Mediaclip itself (eg. more accurate duration or more up-to-date title)")
```Media:play()``` | Plays media. A ```playing``` event is emitted when media starts playing.
```Media:pause()``` | Pause media. A ```paused``` event is emitted when media pauses.
```Media:stop()``` | Pause media. A ```stopped``` event is emitted when media stops.
```Media:getState()``` | Returns state of media, which is one of the following: "error", "loading", "buffering", "playing", "paused", "stopped" | [Note](# "Not supported by all services.")
```Media:isPlaying()``` | Returns a boolean indicating whether media is playing. Uses ```getState()```.
```Media:setVolume(vol)``` | Sets volume. ```vol``` must be a float in the range of 0 and 1.
```Media:getVolume()``` | Returns the volume (a float in the range of 0 and 1).
```Media:setQuality(qual)``` | Sets quality. ```qual``` must be one of the following: "low", "medium", "high", "veryhigh" | [Note](# "Not guaranteed to use equivalent quality on all services. Not supported by all services.")
```Media:getTime()``` | Returns the elapsed time
```Media:seek(time)``` | Seeks to specified time. | [Note](# "Not guaranteed to hop to the exact time. Not supported by all services.")
```Media:sync(time, errorMargin)``` | Seeks to given time, if the elapsed time differs from it too much (more than errorMargin) | [Note](# "Sync does not work on invalid or not playing media. Media can be synchronized at most once per five seconds.")
```Media:runCommand(fn)``` | Runs a command after media has loaded or immediately if it is already loaded |

### Events

__Media__

Event name | Parameters | Description
---|---|---
```playing``` | | Called when media starts playing
```paused``` | | Called when media is paused
```buffering``` | | Called when media is buffering. A ```playing``` event is emitted when buffering stops.
```ended``` | ```{ stopped = bool }``` | Called when media ends. `stopped` is true if ended by call to `clip:stop()`
```destroyed``` | | Called when media is destroyed/invalidated. ```isValid()``` will return false after this
```error``` | ```errorId``` ```errorDesc``` | Called when media fails to play. ```errorId``` is short error identifier. ```errorDesc``` is a longer string type description.

### Hooks

Medialib calls some hooks. You can use Garry's Mod's ```hook.Add``` to hook them and modify extend medialib's functionality.

__Medialib_ProcessOpts__(_Media_ mediaObj, _table_ opts)
Called before media is loaded but after it is created with the options passed to ```Service:load(url, options)```. You can use this hook to add new methods to the media object or set variables. Maybe even queue some things with ```Media:runCommand(fn)```.

__Medialib_ExtendQuery__(_string_ url, _CallbackChainObj_ cbchain)
Can be used to add additional data to queried data. Because data querying requires callbacks and medialib doesn't have promises, it uses really hardcore callback chainer, which can be found from ```servicebase.lua```.
