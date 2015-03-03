## gmod-medialib

Media library for Garry's Mod.

```lua
local yt = medialib.load("media").Service("youtube")

local mediaclip = yt:load("https://www.youtube.com/watch?v=u24e43iW9KE")

local frame = vgui.Create("DFrame")
frame:SetSize(800, 520)

do
	local video = frame:Add("DPanel")
	video:SetPos(0, 25)
	video:SetSize(800, 450)
	video.Paint = function(_, w, h)
		mediaclip:draw(0, 0, w, h)
	end
end

do
	local play = frame:Add("DButton")
	play:SetPos(50, 480)
	play:SetSize(100, 30)
	play:SetText("Play")
	play.DoClick = function() mediaclip:play() end
end

frame.OnClose = function()
	mediaclip:stop()
end

frame:MakePopup()
```