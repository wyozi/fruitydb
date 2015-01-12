FDB = FDB or {}
FDB.Version = "1.1"
FDB.ForceVersion = "sqlite"

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

do -- Load modules

    local submodules = {"connection", "queries" }

    for _,module in ipairs(submodules) do
        include("fdb_" .. module .. ".lua")
        FDB.Debug("Loading module " .. module)
    end
end

do -- Load database types
    local dbtypes = {"mysqloo", "tmysql4", "sqlite"}

    FDB.DatabaseTypes = {}
    FDB.RegisterDatabase = function(dbtype, tbl)
        FDB.DatabaseTypes[dbtype] = tbl
        setmetatable(tbl, FDB.dbmeta) -- Set dbmeta as the metatable
        tbl.__index = tbl -- tbl is to be used as a metatable as well

        FDB.Debug("Registered database type " .. dbtype)
    end

    for _,dbtype in ipairs(dbtypes) do
        FDB.Debug("Loading dbtype " .. dbtype)
        include("dbtypes/" .. dbtype.. ".lua")
    end
end

hook.Call("FDBModulesLoaded", GAMEMODE)