-- Look at an entity (eg a barrel) and run this code
-- Requires 'volume3d' extension

if IsValid(CLIP) then CLIP:stop() end

local link = "https://www.youtube.com/watch?v=6IqKEeRS90A"

local service = medialib.load("media").guessService(link)
local mediaclip = service:load(link, {use3D = true, ent3D = LocalPlayer():GetEyeTrace().Entity})

CLIP = mediaclip
mediaclip:play()