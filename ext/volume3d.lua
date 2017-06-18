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

local cvar_debugobs = CreateConVar("medialib_vol3d_debugobstacle", "0")

local trQuery, trResult = {}, {}
trQuery.output = trResult
trQuery.mask = MASK_SOLID_BRUSHONLY
local function getObstacleMultiplier(pos)
	local eyepos = LocalPlayer():EyePos()
	local debug = cvar_debugobs:GetBool()

	local normal = (eyepos - pos):GetNormalized()
	local crs_right = normal:Cross(Vector(0, 0, 1))
	local crs_up = -normal:Cross(crs_right)

	--debugoverlay.Line(pos, pos+crs_right*100, 0.1, Color(0, 255, 0))
	--debugoverlay.Line(pos, pos+crs_up*100, 0.1, Color(255, 0, 0))

	local traces = 8
	local hitWall = 0

	local circleRadius = 20

	for i=1, traces do
		local rad = math.pi*2 * (i/traces)

		local start = pos + math.cos(rad)*circleRadius*crs_right + math.sin(rad)*circleRadius*crs_up
		trQuery.start = start
		trQuery.endpos = eyepos
		local tr = util.TraceLine(trQuery)

		if tr.Hit then hitWall = hitWall+1 end

		if debug then debugoverlay.Line(start, eyepos, 0.1, tr.Hit and Color(255, 0, 0) or Color(255, 127, 0)) end
	end

	local frac = hitWall/traces

	return math.Remap(1 - frac, 0, 1, 0.3, 1), frac == 1 and 1.2 or 1
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

		local vol = 0
		if fadeFrac < 1 then
			local obsVolMul, obsFadeMul = getObstacleMultiplier(pos)

			if clip.attenuationType == "linear" then
				vol = (1 - fadeFrac)
			else
				vol = 1/((fadeFrac+1)^7)
			end

			vol = vol * obsVolMul
			vol = math.Clamp(vol, 0, 1)
		end

		-- Set the internal volume so that users can still set relative volume
		clip.internalVolume = math.Approach(clip.internalVolume or 0, vol, FrameTime() * 2)
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
	function media:set3DAttenuationType(type)
		self.attenuationType = type
	end

	if opts.pos3D then media:set3DPos(opts.pos3D) end
	if opts.ent3D then media:set3DEnt(opts.ent3D) end
	if opts.attenuationType then media:set3DAttenuationType(opts.attenuationType) end

	media:runCommand(function()
		startThink(media)
	end)
end)
