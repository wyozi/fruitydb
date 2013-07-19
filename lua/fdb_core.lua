require("mysqloo")

local loaded = mysqloo ~= nil -- boolean returned by require() doesnt seem to be true

FDB = FDB or {}
FDB.Version = "0.5"

function FDB.Log(msg)
    MsgN("[FruityDB] " .. tostring(msg))
end
function FDB.Debug(msg)
    if FDB.DebugMode then
        FDB.Log(msg)
    end
end
function FDB.Error(msg)
    ErrorNoHalt("[FruityDB] " .. tostring(msg))
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
