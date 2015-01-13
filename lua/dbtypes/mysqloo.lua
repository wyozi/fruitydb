pcall(require, "mysqloo")

local mysqloo_loaded = mysqloo ~= nil -- Checking the result of "require" doesn't seem to work

local DATABASE = {}

DATABASE.KEYWORD_AUTOINCREMENT = "auto_increment"
DATABASE.QUERY_LISTTABLES = "show tables;"

function DATABASE.IsAvailable() -- Can this database type be used at all?
	return mysqloo_loaded
end

function DATABASE:IsConnected()
	return self.db ~= nil
end

function DATABASE:RawDB()
	if not self:IsConnected() then
		self:Connect(self.Config)
		return self.db
	end
	return self.db
end

function DATABASE:Connect(details)
	if not details.name or not details.password or not details.database then
		return false, "MysqlOO connection requires name, password and database"
	end
	local db = mysqloo.connect( details.host or "localhost",
								details.user or details.username or details.name,
								details.password,
								details.database,
								details.port or 3306,
								details.socket or "")
	self.db = db

	function db:onConnected()
		self.db = db
	end

	local toerr
	function db:onConnectionFailed( err )
		toerr = err
		self.db = nil
	end

	db:connect()
	db:wait()

	return self:IsConnected(), toerr
end

function DATABASE:RawQuery(onSuccess, onError, query, ...)

	local db = self:RawDB()
	if not db then
		FDB.Error("RawDB not available!")
	end

	local fquery = FDB.ParseQuery(query, ...)
	if not fquery then
		FDB.Warn("Query not executed: fquery is nil")
		return
	end

	if FDB.IsDebug() then -- We double check for debug mode here because string operations are expensive-ish
		FDB.Debug(query .. " parsed to " .. fquery)
		FDB.Debug("Starting query " .. fquery)
	end

	local fdbself = self -- store self here, because we cant access 'self' from onSuccess

	local query = db:query(fquery)
	function query:onSuccess(data)
		fdbself.LastAffectedRows = query:affectedRows()
		fdbself.LastAutoIncrement = query:lastInsert()
		fdbself.LastRowCount = #data

		if FDB.IsDebug() then -- We double check for debug mode here because string operations are expensive-ish
			FDB.Debug("Query succeeded! AffectedRows " .. tostring(fdbself:GetAffectedRows()) .. " InsertedId " .. tostring(fdbself:GetInsertedId()) ..
			" RowCount " .. tostring(fdbself:GetRowCount()))
		end
		if onSuccess then
			onSuccess(data)
		end
	end

	function query:onError(err, sql)
		-- TODO check for "Mysql server has gone away" error, in which case a reconnect is needed
		FDB.Warn("Query failed! SQL: " .. sql .. ". Err: " .. err)
		if onError then
			onError(err, sql)
		end
	end

	query:start()

	return query
end

function DATABASE:Wait(queryobj)
	if not queryobj then return false end

	queryobj:wait()
	return true
end

function DATABASE:GetInsertedId()
	return self.LastAutoIncrement
end

function DATABASE:GetAffectedRows()
	return self.LastAffectedRows or 0
end

function DATABASE:GetRowCount()
	return self.LastRowCount
end

-- Transaction stuff

-- TODO, we could fake transactions by adding queries to a table until commit/fallback
function DATABASE:StartTransaction()
	return self:BlockingQuery("START TRANSACTION;") ~= false
end

function DATABASE:Commit()
	return self:BlockingQuery("COMMIT;") ~= false
end

function DATABASE:Rollback()
	return self:BlockingQuery("ROLLBACK;") ~= false
end

FDB.RegisterDatabase("mysqloo", DATABASE)
