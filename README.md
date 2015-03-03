## gmod-medialib

Media library for Garry's Mod.

```lua
local yt = medialib.load("media").Service("youtube")

local mediaclip = yt:load("https://www.youtube.com/watch?v=bqrQqoXjNfE")

hook.Add("HUDPaint", "DrawMedia", function()
	mediaclip:draw(0, 0, 1280, 720)
end)
```