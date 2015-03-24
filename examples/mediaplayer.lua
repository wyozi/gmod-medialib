local link = "https://www.youtube.com/watch?v=u24e43iW9KE"

-- Get the service that should be used for this link
local service = medialib.load("media").GuessService(link)

-- Create a mediaclip (load HTML panel, call sound.PlayURL etc happens here) using that service
local mediaclip = service:load(link)

local frame = vgui.Create("DFrame")
frame:SetSize(800, 520)

-- Query media title (eg youtube video title)
service:query(link, function(err, data)
	local title = string.format("%s [%d]", data.title or "unknown", data.duration or -1)
	frame:SetTitle(err or title)
end)

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
	play:SetPos(10, 483)
	play:SetSize(80, 30)
	play:SetText("Play")
	play.DoClick = function() mediaclip:play() end
end

do
	local pause = frame:Add("DButton")
	pause:SetPos(100, 483)
	pause:SetSize(80, 30)
	pause:SetText("Pause")
	pause.DoClick = function() mediaclip:pause() end
end

do
	local volume = frame:Add("Slider")
	volume:SetPos(550, 483)
	volume:SetWide(250)
	volume:SetMin(0)
	volume:SetMax(1.0)
	volume:SetValue(0.5)
	volume:SetDecimals(2)
	volume.OnValueChanged = function(_, val)
		mediaclip:setVolume(val)	
	end
end

frame.OnClose = function()
	mediaclip:stop()
end

frame:MakePopup()