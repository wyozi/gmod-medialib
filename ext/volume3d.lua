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

local volume3d = medialib.module("volume3d")

function volume3d.startBASSThink(clip, params)
	if params.fadeMax then
		clip.chan:Set3DFadeDistance(0, params.fadeMax)	
	end

	if params.pos then
		clip.chan:SetPos(params.pos)
	elseif params.ent then
		local hookId = "MediaLib.3DThink." .. clip:hashCode()
		hook.Add("Think", hookId, function()
			-- Stop hook if chan is invalid
			if not clip:isValid() then
				hook.Remove("Think", hookId)
				return
			end

			-- Stop media if entity is invalid
			if not IsValid(params.ent) then
				clip:stop()
				return
			end

			-- Update pos
			clip.chan:SetPos(params.ent:GetPos())
		end)
	end
end
function volume3d.startHTMLThink(clip, params)
	local hookId = "MediaLib.3DThink." .. clip:hashCode()
	hook.Add("Think", hookId, function()
		-- Stop hook if chan is invalid
		if not clip:isValid() then
			hook.Remove("Think", hookId)
			return
		end

		local pos
		if params.pos then
			pos = params.pos
		elseif params.ent then
			-- Stop media if entity is invalid
			if not IsValid(params.ent) then
				clip:stop()
				return
			end
			pos = params.ent:GetPos()
		end

		if not pos then return end

		local eyep = LocalPlayer():EyePos()
		local dist = eyep:Distance(pos)

		local fadeMax = params.fadeMax or 1024
		local fadeFrac = (dist / fadeMax)

		local vol = 1/((fadeFrac+1)^7)
		vol = math.Clamp(vol, 0, 1)

		-- Set the internal volume so that users can still set relative volume
		clip.internalVolume = vol
		clip:applyVolume()
	end)
end

function volume3d.startThink(clip, params)
	if clip:getBaseService() == "bass" then
		volume3d.startBASSThink(clip, params)
	elseif clip:getBaseService() == "html" then
		volume3d.startHTMLThink(clip, params)
	end
end