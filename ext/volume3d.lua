-- Makes audio seem like it is coming from a 3D source.
--    For BASS the native '3d' option is used
--    For HTML 3d volume is simulated manually
--
-- To use, pass "use3D = true" in 'opts' to service:load(url, opts)
-- You also need to pass either a 'pos3D' or 'ent3D' in opts
--    'pos3D = Vector(0, 0, 0)' - a static position
--    'ent3D = Entity(12)'      - a dynamically updating position (ent:GetPos() is used)
--                                if entity is removed, the mediaclip will also be removed
--
-- You can optionally pass 'fadeMax3D = 1000' to set the maximum fade distance

local function startBASSThink(clip)
	if clip.fadeMax3D then
		clip.chan:Set3DFadeDistance(0, clip.fadeMax3D)
	end

	if clip.pos3D then
		clip.chan:SetPos(clip.pos3D)
	elseif clip.ent3D then
		local hookId = "MediaLib.3DThink." .. clip:hashCode()
		hook.Add("Think", hookId, function()
			-- Stop hook if chan is invalid
			if not clip:isValid() then
				hook.Remove("Think", hookId)
				return
			end

			-- Stop media if entity is invalid
			if not IsValid(clip.ent3D) then
				clip:stop()
				return
			end

			-- Update pos
			clip.chan:SetPos(clip.ent3D:GetPos())
		end)
	end
end
local function startHTMLThink(clip)
	local hookId = "MediaLib.3DThink." .. clip:hashCode()
	hook.Add("Think", hookId, function()
		-- Stop hook if chan is invalid
		if not clip:isValid() then
			hook.Remove("Think", hookId)
			return
		end

		local pos
		if clip.pos3D then
			pos = clip.pos3D
		elseif clip.ent3D then
			-- Stop media if entity is invalid
			if not IsValid(clip.ent3D) then
				clip:stop()
				return
			end
			pos = clip.ent3D:GetPos()
		end

		if not pos then return end

		local eyep = LocalPlayer():EyePos()
		local dist = eyep:Distance(pos)

		local fadeMax = clip.fadeMax3D or 1024
		local fadeFrac = (dist / fadeMax)

		local vol = 1/((fadeFrac+1)^7)
		vol = math.Clamp(vol, 0, 1)

		-- Set the internal volume so that users can still set relative volume
		clip.internalVolume = vol
		clip:applyVolume()
	end)
end

local function startThink(clip)
	if clip:getBaseService() == "bass" then
		startBASSThink(clip)
	elseif clip:getBaseService() == "html" then
		startHTMLThink(clip)
	end
end

hook.Add("Medialib_ProcessOpts", "Medialib_Volume3d", function(media, opts)
	if not opts.use3D then return end

	media.is3D = true

	if media:getBaseService() == "bass" then
		table.insert(media.bassPlayOptions, "3d")
	end

	function media:set3DPos(pos)
		self.pos3D = pos
		self.ent3D = nil
	end
	function media:set3DEnt(ent)
		self.pos3D = nil
		self.ent3D = ent
	end
	function media:set3DFadeMax(fademax)
		self.fadeMax3D = fademax
		if IsValid(self.chan) and self:getBaseService() == "bass" then
			self.chan:Set3DFadeDistance(0, fademax)
		end
	end

	if opts.pos3D then media:set3DPos(opts.pos3D) end
	if opts.ent3D then media:set3DEnt(opts.ent3D) end

	media:runCommand(function()
		startThink(media)
	end)
end)
