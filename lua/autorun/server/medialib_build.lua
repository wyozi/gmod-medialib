local pat_quote = "[\"\']"
local pat_negate_quote = "[^\"\']"
local pat_ws = "%s*"

local function Build()
	local base = file.Read("autorun/medialib.lua", "LUA")

	local fragments = {base}
	local loaded_modules = {}

	local function indent(code, cb)
		for line in string.gmatch(code, "[^\r\n]+") do
			cb(string.format("\t%s", line))
		end
	end

	local function ParseModule(name, code)
		if loaded_modules[name] then return end

		-- Load module code if not provided
		if not code then
			code = file.Read("medialib/" .. name .. ".lua", "LUA")
		end

		-- If module code still not found, it's probably an extension
		if not code then
			local is_extension = file.Exists("addons/gmod-medialib/ext/" .. name .. ".lua", "MOD")
			if not is_extension then
				print("[MediaLib-Build] Warning: trying to parse inexistent module '" .. name .. "'")
			end
			return
		end

		local function CheckModuleDeps(code)
			for mod in string.gfind(code, "medialib%.load%(" .. pat_ws .. pat_quote .."(" .. pat_negate_quote .. "*)" .. pat_quote .. pat_ws .. "%)") do
				ParseModule(mod)
			end
		end

		-- Go through code seaching for module loads
		CheckModuleDeps(code)

		-- Go through code searching for folderIterators
		for folder in string.gfind(code, "medialib%.folderIterator%(" .. pat_ws .. pat_quote .."(" .. pat_negate_quote .. "*)" .. pat_quote .. pat_ws .. "%)") do
			
			for _, file in medialib.folderIterator(folder) do
				local source = file:read():Replace("\r", "")
				CheckModuleDeps(source)

				local package = string.format("medialib.FolderItems[%q] = %q", folder .. "/" .. file.name, source)
				table.insert(fragments, package)
			end
		end

		-- Add code as a fragment
		table.insert(fragments, "-- Module " .. name)

		-- Add module placeholder. Required because all files dont define a module
		table.insert(fragments, string.format("medialib.modulePlaceholder(%q)", name))
		
		table.insert(fragments, "do")
		indent(code, function(line) table.insert(fragments, line) end)
		table.insert(fragments, "end")

		loaded_modules[name] = true
	end
	ParseModule("__loader", file.Read("autorun/medialib_loader.lua", "LUA"))

	file.Write("medialib.txt", table.concat(fragments, "\n"))
end

if SERVER then
	concommand.Add("medialib_build", function(ply) if IsValid(ply) then return end Build() end)

	local autobuild = CreateConVar("medialib_autobuild", "0", FCVAR_ARCHIVE)
	timer.Create("medialib_autobuild", 5, 0, function()
		if not autobuild:GetBool() then return end

		Build()
	end)
end