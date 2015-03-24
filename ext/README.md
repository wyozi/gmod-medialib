Extensions are medialib modules that are experimental in nature or not needed by majority of users.

To use them, place them in one of the following folders:

Folder | When to use
---|---
```garrysmod/addons/medialib/lua/medialib/``` | if you use medialib as an addon
```garrysmod/addons/[youraddon]]/lua/medialib/``` | if you use ```dist/medialib.lua``` as part of your addon (```medialib``` folder needs to be created)
```garrysmod/gamemodes/[yourgamemode]/gamemode/medialib/``` | if you use ```dist/medialib.lua``` as part of your gamemode (```medialib``` folder needs to be created)

If correctly placed, the extension will automatically load and add wanted functionality.