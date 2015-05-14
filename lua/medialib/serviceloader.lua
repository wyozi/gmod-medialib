medialib.load("servicebase")

medialib.load("service_html")
medialib.load("service_bass")

-- Load the actual service files
for _,file in medialib.folderIterator("services") do
	if medialib.DEBUG then
		print("[MediaLib] Registering service " .. file.name)
	end
	if SERVER then file:addcs() end
	file:load()
end