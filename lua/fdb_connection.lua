
-- The table that contains dbtype agnostic functions. This table is filled in fdb_queries.lua
FDB.dbmeta = {}
FDB.dbmeta.__index = FDB.dbmeta -- dbmeta is used as a metatable so might as well do this here

-- Connection object will be a table structure like this:
-- On top: dbtbl -- a table that contains connection specific information, such as MysqlOO handle (if using MysqlOO)
-- In middle: dbtype table -- a metatable containing database specific functions, registered/loaded from dbtypes/
-- In bottom: queries table -- a metatable containing database agnostic functions, such as BlockingQuery, Insert etc..

-- A connection that uses the new API
function FDB.NewConnect(dbtype, details)
	details = details or {}
	
	local dbtype_tbl = FDB.DatabaseTypes[dbtype]
	if not dbtype_tbl then
		FDB.Error("Trying to open a db connection using unexpected dbtype " .. dbtype)
		return
	end
	if not dbtype_tbl.IsAvailable() then
		FDB.Error("Trying to open a db connection using unavailable dbtype " .. dbtype)
		return
	end

	local dbtbl = {}

	dbtbl.Provider = dbtype
	dbtbl.Config = details

	setmetatable(dbtbl, dbtype_tbl) -- FDB.dbmeta should be the metatable of dbtype_tbl, which was set in fdb_core in dbtype
	-- register function, so it's not required to set queries table as a metatable here

	local conn, err = dbtbl:Connect(details)
	if not conn then
		FDB.Error( "Connection to database failed! Error: " .. tostring(err) )
		return false, err
	end
	FDB.Debug( "Connected to database!" )
	return dbtbl
end

-- A helper function for old API connections
function FDB.DeprecatedConnect(host, name, password, db, port, socket)
	FDB.Warn("Using Deprecated FDB API! Check github.com/wyozi/FruityDB for more information.")
	return FDB.NewConnect("mysqloo", {
		host = host,
		name = name,
		password = password,
		database = db,
		port = port,
		socket = socket
	})
end

-- A function that checks arguments and passes them forward to FDB.NewConnect or FDB.DeprecatedConnect depending on argument types
function FDB.Connect(host, name, password, db, port, socket)
	-- FDB.Connect was used in old version of FDB using signature similar to that of FDB.DeprecatedConnect,
	-- thus we need to check if that's still the case and possibly use the deprecated API function

	if type(name) == "table" or not name then -- Second argument a table; we're using new FDB API!
		return FDB.NewConnect(host, name) -- dbtype, details
	end
	return FDB.DeprecatedConnect(host, name, password, db, port, socket)
end
