medialib.load("servicebase")

medialib.load("service_html")
medialib.load("service_bass")

-- AddCSLuaFile all services
if SERVER then
	for _,fname in pairs(file.Find("medialib/services/*", "LUA")) do
		AddCSLuaFile("medialib/services/" .. fname)
	end
end

-- Load the actual service files
for _,file in medialib.folderIterator("services") do
	if medialib.DEBUG then
		print("[MediaLib] Registering service " .. file.name)
	end
	file:load()
end