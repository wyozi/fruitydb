
FDB.dbmeta = FDB.dbmeta or {}
local dbmeta = FDB.dbmeta

function FDB.Connect(host, name, password, db, port, socket)
    local dbtbl = {}
    setmetatable(dbtbl, {__index = FDB.dbmeta})
    local conn, err = dbtbl:Connect(host, name, password, db, port, socket)
    if not conn then
        return false, err
    end
    return dbtbl
end