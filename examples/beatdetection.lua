-- Requires 'beatdetector' extension

if THEMEDIA then THEMEDIA:stop() end

local link = "http://puu.sh/gNA5J/57f8192725.mp3"
local service = medialib.load("media").guessService(link)

local mediaclip = service:load(link)
mediaclip:play()

THEMEDIA = mediaclip

local size = 10
local clr = Color(255, 255, 255)

mediaclip:runCommand(function()
	local bdetector = mediaclip:getBeatDetector()
	bdetector:addPeakListener("main", function(str)
		local h, s, v = ColorToHSV(clr)

		h = h + (math.random() > 0.5 and 1 or -1)*str*math.random(10, 50)
		s = 0.5
		v = 0.95

		clr = HSVToColor(h, s, v)

		size = size + str*2
	end)
end)

hook.Add("HUDPaint", "TheFlashingSquare", function()
	surface.SetDrawColor(clr)

	local x, y = 150, 150
	surface.DrawRect(x-size, y-size, size*2, size*2)

	size = size - FrameTime()*math.Clamp((size*0.1)^1.5, 1, 15)
end)
