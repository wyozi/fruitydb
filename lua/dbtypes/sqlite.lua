local DATABASE = {}

function DATABASE.IsAvailable() -- Can this database type be used at all?
	return true
end

function DATABASE:IsConnected()
	return true
end

function DATABASE:Connect(host, name, password, dba, port, socket)
	return true
end

-- A query that does not block. onSuccess is called if query is succesfully executed and onError if we get an error
function DATABASE:Query(onSuccess, onError, query, ...)

	local fquery = FDB.ParseQuery(query, ...)
	if not fquery then
		FDB.Warn("Query not executed: fquery is nil")
		return
	end

	if FDB.IsDebug() then -- We double check for debug mode here because string operations are expensive-ish
		FDB.Debug(query .. " parsed to " .. fquery)
		FDB.Debug("Starting query " .. fquery)
	end

	local slquery = sql.Query(fquery)
	if slquery ~= false then
		slquery = slquery or {}
		if FDB.IsDebug() then -- We double check for debug mode here because string operations are expensive-ish
			FDB.Debug("Query succeeded!")
		end
		local laid = sql.QueryValue("SELECT last_insert_rowid()")
		self.LastAutoIncrement = tonumber(laid) 
		local affected = sql.QueryValue("SELECT changes()")
		self.LastAffectedRows = tonumber(affected) 
		if onSuccess then
			onSuccess(slquery)
		end
	else
		local err = sql.LastError()
		FDB.Warn("Query failed! SQL: " .. fquery .. ". Err: " .. err)
		if onError then
			onError(err, fquery)
		end
	end

	return {
		wait = function() end -- Workaround for blocking queries, sqlite queries block by default so we don't actually need to do anything here
	}
end

function DATABASE:GetInsertedId()
	return self.LastAutoIncrement
end

function DATABASE:GetAffectedRows()
	return self.LastAffectedRows or 0
end

-- TODO, we could fake transactions by adding queries to a table until commit/fallback

FDB.RegisterDatabase("sqlite", DATABASE)