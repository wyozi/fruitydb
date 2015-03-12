local persistentply_meta = {}
persistentply_meta.__index = persistentply_meta

function persistentply_meta:Get()
	for _,ply in pairs(player.GetAll()) do
		if ply:SteamID64() == self.id then
			return ply
		end
	end
end

function persistentply_meta:SteamID()
	return util.SteamIDFrom64(self.id)
end
function persistentply_meta:SteamID64()
	return self.id
end


local function Create(steamid64)
	return setmetatable({id = steamid64}, persistentply_meta)
end

function FDB.PersistentPlayer(obj)
	if type(obj) == "string" then
		-- SteamID 32
		if obj:match("^STEAM_%d:%d:%d+$") then
			return Create(util.SteamIDTo64(obj))
		-- SteamID 64
		elseif obj:match("^%d+$") then
			return Create(obj)
		end
	elseif type(obj) == "Player" and IsValid(obj) then
		return Create(obj:SteamID64())
	end

	FDB.Error("PersistentPlayer error: given 'obj' must be Player or SteamID String")
end
