FDB = FDB or {}
FDB.Version = "2.0"

function FDB.Log(msg, tag)
    -- Again, this if structure looks a bit overcomplicated but it's to ensure as little string manipulations with as little code obfuscation
    -- as possible
    if tag then
        MsgN("[FruityDB " .. tag .. "] " .. msg)
    else
        MsgN("[FruityDB] " .. msg)
    end
end
function FDB.Debug(msg)
    if FDB.IsDebug() then
        FDB.Log(msg, "Debug")
    end
end
function FDB.Error(msg)
    ErrorNoHalt("[FruityDB] " .. tostring(msg) .. "\n")
end
function FDB.Warn(msg)
    FDB.Log(msg, "WARNING")
end

FDB.Log("Loading FruityDB version " .. tostring(FDB.Version))

include("fdb_config.lua") -- This must be loaded first always so might as well load it here

hook.Call("FDBConfigLoaded", GAMEMODE)

do
    include("fdb_connection.lua")
    include("fdb_queries.lua")
    include("fdb_persistentply.lua")
end

do -- Load database types

    -- Really awkward place for this but..
    local function conn__tostring(self)
    	return string.format("FruityDB connection: %s", self.Provider)
    end

    local dbtypes = {"mysqloo", "tmysql4", "sqlite"}

    FDB.DatabaseTypes = {}
    FDB.RegisterDatabase = function(dbtype, tbl)
        FDB.DatabaseTypes[dbtype] = tbl
        
        setmetatable(tbl, FDB.dbmeta)
        tbl.__index = tbl
        tbl.__tostring = conn__tostring

        FDB.Debug("Registered database type " .. dbtype)
    end

    for _,dbtype in ipairs(dbtypes) do
        FDB.Debug("Loading dbtype " .. dbtype)
        include("dbtypes/" .. dbtype.. ".lua")
    end
end

hook.Call("FDBModulesLoaded", GAMEMODE)
