medialib.load("servicebase")

medialib.load("service_html")
medialib.load("service_bass")

local media = medialib.load("media")

-- Load the actual service files
for _,file in medialib.folderIterator("services") do
	if medialib.DEBUG then
		print("[MediaLib] Registering service " .. file.name)
	end
	if SERVER then file:addcs() end
	local status, err = pcall(function() return file:load() end)
	if status then
		media.registerService(err.identifier, err)
	else
		print("[MediaLib] Failed to load service ", file, ": ", err)
	end
end