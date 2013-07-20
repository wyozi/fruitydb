require("mysqloo")

local loaded = mysqloo ~= nil -- boolean returned by require() doesnt seem to be true

FDB = FDB or {}
FDB.Version = "0.5"

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
        FDB.Log(msg, "debug")
    end
end
function FDB.Error(msg)
    ErrorNoHalt("[FruityDB] " .. tostring(msg) .. "\n")
end
function FDB.Warn(msg)
    FDB.Error(msg)
end

if not loaded then
    FDB.Error("Failed to load MysqlOO!")
else

    FDB.Log("Loading FruityDB version " .. tostring(FDB.Version))

    include("fdb_config.lua") -- This must be loaded first always so might as well load it here

    hook.Call("FDBConfigLoaded", GAMEMODE)

    local submodules = {"connection", "queries" }

    for _,module in ipairs(submodules) do
        include("fdb_" .. module .. ".lua")
        FDB.Debug("Loading module " .. module)
    end

    hook.Call("FDBModulesLoaded", GAMEMODE)

end
