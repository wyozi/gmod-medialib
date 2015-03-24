## gmod-medialib

Media library for Garry's Mod.

### Setup
Easiest way to add gmod-medialib to your project is to copy ```dist/medialib.lua``` into your addon/gamemode. Make sure it is shared (```AddCSLuaFile``` on server and ```include``` on both server and client)

### Example

```lua
local link = "https://www.youtube.com/watch?v=6IqKEeRS90A"

-- Get the service that this link uses (eg. youtube, twitch, vimeo, webaudio)
local service = medialib.load("media").GuessService(link)

-- Create a mediaclip from the link
local mediaclip = service:load(link)

-- Play media
mediaclip:play()
```

See ```examples/``` for more elaborate examples.