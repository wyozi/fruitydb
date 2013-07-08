require("mysqloo")

local loaded = mysqloo ~= nil -- boolean returned by require() doesnt seem to be true

local ConnectionlessDev = true -- allows reloading without reconnecting. Suggested for initial dev phase

if ConnectionlessDev then
    FDB = FDB or {}
else
    FDB = {}
end
FDB.Version = "1.00"

function FDB.Log(msg)
    MsgN("[FruityDB] " .. tostring(msg))
end
function FDB.Debug(msg)
    if FDB.DebugMode then
        FDB.Log(msg)
    end
end
function FDB.Error(msg)
    Error("[FruityDB] " .. tostring(msg))
end

if not loaded then
    FDB.Error("Failed to load MysqlOO!")
else

    FDB.Log("Loading FruityDB version " .. tostring(FDB.Version))

    local submodules = {"config", "connection", "queries" }

    for _,module in ipairs(submodules) do
        include("fdb_" .. module .. ".lua")
        FDB.Debug("Loading module " .. module)
    end

end