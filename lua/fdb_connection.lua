
local dbmeta = {}
FDB.dbmeta = dbmeta

function dbmeta:IsConnected()
    return self.db ~= nil
end
function FDB.IsConnected()
    return FDB.latestdb and FDB.latestdb:IsConnected()
end

function dbmeta:RawDB()
    if not self.IsConnected() then
        local config = FDB.Config
        FDB.Connect(config.host, config.name, config.password, config.database, config.port)
        return FDB.db
    end
    return FDB.db
end
function dbmeta:Connect(host, name, password, db, port, socket)
    host = host or "localhost"
    port = port or 3306

    local db = mysqloo.connect( host, name, password, db, port, socket or "" )

    function db:onConnected()
        FDB.latestdb = self
        self.db = db
    end

    local toerr
    function db:onConnectionFailed( err )
        toerr = err
        FDB.Error( "Connection to database failed! Error: " .. tostring(err) )
    end

    db:connect()
    db:wait()

    return self:IsConnected(), toerr
end

function FDB.Connect(host, name, password, db, port, socket)
    local dbtbl = {}
    setmetatable(dbtbl, {__index = FDB.dbmeta})
    local conn, err = dbtbl:Connect(host, name, password, db, port, socket)
    if not conn then
        return false, err
    end
    return dbtbl
end

hook.Add("Initialize", "FDB_Connect", function()
    if not FDB.ConnectOnInitialize then
        FDB.Debug("Initialize hook called but not connecting because of FDB.ConnectOnInitialize") -- Useful if some dev ever forgets this
        return
    end
    if FDB.Config then
        FDB.Debug("Connecting to database")
        local config = FDB.Config
        local status = FDB.Connect(config.host, config.name, config.password, config.database, config.port, config.socket)
        FDB.Debug("DB Connection succeeded: " .. tostring(status))

        if not FDB.Unsafe then -- We're not running Unsafe mode so we need to remove Config here to prevent leaking it by "ulx luarun" for example
            FDB.Config = nil
        end

    elseif not FDB.Unsafe then
       FDB.Error("To connect to database you need to set FDB.Config table at the beginning. See fdb_config.lua for more information!")
    end
end)
