function FDB.IsConnected()
    return FDB.db ~= nil
end
function FDB.Connect(host, name, password, db, port, socket)
    host = host or "localhost"
    port = port or 3306

    local db = mysqloo.connect( host, name, password, db, port, socket or "" )

    function db:onConnected()
        FDB.db = db
    end

    function db:onConnectionFailed( err )
        FDB.Error( "Connection to database failed! Error: " .. tostring(err) )
    end

    db:connect()
    db:wait()

    return FDB.IsConnected()
end
function FDB.RawDB()
    if not FDB.IsConnected() then
        if FDB.Unsafe then
            local config = FDB.Config
            FDB.Connect(config.host, config.name, config.password, config.database, config.port)
            return FDB.db
        end
        FDB.Error("Database not connected!")
        return nil
    end
    return FDB.db
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
