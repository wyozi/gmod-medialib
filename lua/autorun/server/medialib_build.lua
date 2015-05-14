local pat_quote = "[\"\']"
local pat_negate_quote = "[^\"\']"
local pat_ws = "%s*"

local WSHandlers = {
	quotation = {
		_start = function(code, pointer) return string.find(code, "\"", pointer, true) end,
		_end = function(code, pointer)
			if string.sub(code, pointer, pointer) == "\"" then return pointer end

			local _, t = string.find(code, "[^\\]\"", pointer)
			if t then return t end
		end
	},
	multiline = {
		_start = function(code, pointer) return string.find(code, "[[", pointer, true) end,
		_end = function(code, pointer) return select(2, string.find(code, "]]", pointer, true)) end
	},
	comment_s = {
		_start = function(code, pointer) return string.find(code, "--", pointer, true) end,
		_end = function(code, pointer) return string.find(code, "[\10\13]", pointer) or #code end,
		skip = true
	},
	comment_multi = {
		_start = function(code, pointer) return string.find(code, "--[[", pointer, true) end,
		_end = function(code, pointer) return select(2, string.find(code, "]]", pointer, true)) end,
		skip = true
	},
}

local WS_STRIP_DISABLED = false

local function StripWhitespace(code)
	if WS_STRIP_DISABLED then return code end
	
	local verbose = false

	local stripped = {}
	local pointer = 1

	local function coltoline(col)
		local line, linecol = 1, 1

		local linestr = ""
		for i=1,#code do
			if i >= col then break end

			local c = code[i]
			if c == "\n" then
				line = line+1
				linecol = 1
				linestr = ""
			else
				linecol = linecol + 1
				linestr = linestr .. c
			end
		end

		return line, linecol, linestr
	end
	
	-- Adds code (aka you can get rid of ws here)
	local function AddCode(endp)
		local _code = string.sub(code, pointer, endp)
		_code = string.gsub(_code, "\t", "") -- remove tabs
		_code = string.gsub(_code, "[\10\13]", " ") -- replace newlines with spaces
		_code = string.gsub(_code, " ?%.%. ?", "..")
		_code = string.gsub(_code, " ?([=~><%-+,]) ?", "%1")
		_code = string.gsub(_code, " ?([{}%[%]%(%)]) ?", "%1")
		_code = string.gsub(_code, "  +", " ") -- replace space seq with single space
		table.insert(stripped, _code)
		
		pointer = endp+1
	end
	local function AddRaw(endp)
		table.insert(stripped, string.sub(code, pointer, endp))
		pointer = endp+1
	end
	
	local function nextstr()
		local found = {}
		for k,v in pairs(WSHandlers) do
			local f = v._start(code, pointer)
			if f then table.insert(found, {k = k, idx = f}) end
		end

		table.SortByMember(found, "idx", true)

		if found[1] then
			local idx = found[1].idx
			local handler = WSHandlers[found[1].k]
			local skip = WSHandlers[found[1].k].skip

			if skip then idx = idx - 1 end
			AddCode(idx)
			if skip then pointer = pointer + 1 end

			local f = handler._end(code, pointer)
			if not f then error("could not find matching end for " .. found[1].k .. ", which started from " .. string.format("%i:%i [%s]", coltoline(idx))) end
			if skip then
				pointer = f + 1
			else
				AddRaw(f)
			end

			if verbose then
				print("Handling wstag ", found[1].k, " which spans from ", string.format("%i:%i [%s]", coltoline(idx)), " to ", string.format("%i:%i [%s]", coltoline(f)), " >" .. string.sub(code, f, f) .. "<")
			end
			return true
		end

		return false
	end
	
	while nextstr() do end
	
	if pointer <= #code then
		AddCode(#code)	
	end
	
	return table.concat(stripped, "")
end

local function Build()
	local mlib_autorun = file.Read("autorun/medialib.lua", "LUA")
	mlib_autorun = string.gsub(mlib_autorun, "DISTRIBUTABLE = false", "DISTRIBUTABLE = true")
	mlib_autorun = StripWhitespace(mlib_autorun)

	local fragments = {mlib_autorun}
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
			code = file.Read("addons/gmod-medialib/lua/medialib/" .. name .. ".lua", "MOD")
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

				local package = string.format("medialib.FolderItems[%q] = %q", folder .. "/" .. file.name, StripWhitespace(source))
				table.insert(fragments, package)
			end
		end

		-- Add code as a fragment
		table.insert(fragments, "-- Module " .. name)

		-- Add module placeholder. Required because all files dont define a module
		table.insert(fragments, string.format("medialib.modulePlaceholder(%q)", name))
		
		table.insert(fragments, "do")
		table.insert(fragments, StripWhitespace(code))
		--indent(code, function(line) table.insert(fragments, line) end)
		table.insert(fragments, "end")

		loaded_modules[name] = true
	end
	ParseModule("__loader", file.Read("autorun/medialib_loader.lua", "LUA"))

	local concated = table.concat(fragments, "\n")

	--file.Write("medialib.txt", final)
	file.Write("medialib.txt", concated)
end

if SERVER then
	concommand.Add("medialib_build", function(ply) if IsValid(ply) then return end Build() end)

	local autobuild = CreateConVar("medialib_autobuild", "0", FCVAR_ARCHIVE)
	timer.Create("medialib_autobuild", 5, 0, function()
		if not autobuild:GetBool() then return end

		Build()
	end)
end