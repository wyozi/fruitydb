
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