
-- A symbol that precedes 'placeholder' variables in query
FDB.ParamChar = "%" -- must be a single char

-- A helper function for placeholder variables
function FDB.CreateTableHandler(handler)
    return function(db, param) -- Table of objects
        if type(param) ~= "table" then error("Passed param is not table") end
        local s = "("
        local widx = 0
        for k,v in pairs(param) do
            if widx > 0 then
                s = s .. ", "
            end
            s = s .. FDB.PlaceholderVariables[handler](db, v)
            widx = widx + 1
        end
        s = s .. ")"
        return s 
    end
end

-- The variables that can be used in a query in place of data
FDB.PlaceholderVariables = {
    ["s"] = function(db, param)
        return "'" .. (db:escape(param) or "") .. "'"
    end,
    ["i"] = function(db, param)
        return tonumber(param) or error("Unable to convert " .. tostring(param) .. " to number")
    end,
    ["d"] = function(db, param)
        return tonumber(param) or error("Unable to convert " .. tostring(param) .. " to number")
    end,
    ["l"] = function(db, param) -- Literal
        return tostring(param)
    end,
    ["b"] = function(db, param) -- Backticks
        return "`" .. tostring(param) .. "`"
    end,
    ["o"] = function(db, param) -- Object
        local t = type(param)
        local handler
        if t == "string" then handler = "s"
        elseif t == "number" then handler = "d"
        elseif t == "table" then handler = "t" end
        if not handler then error("Couldn't find object handler for " .. t) end
        return FDB.PlaceholderVariables[handler](db, param)
    end,
    ["to"] = FDB.CreateTableHandler("o"),
    ["tb"] = FDB.CreateTableHandler("b")
}

-- TODO get rid of db requirement (is required for db:escape)

function FDB.ParseQuery(db, query, ...)

    local params = {... }

    local finalQueryTbl = {}

    local nthSpecifier = 1

    local errored

    local _, matches = query:gsub( "([^%" .. FDB.ParamChar .. "]*)%" .. FDB.ParamChar .. "([%a]+)([^%" .. FDB.ParamChar .. "]*)", function( prefix, tag, postfix )
        if prefix and prefix ~= "" then
            table.insert(finalQueryTbl, prefix)
        end

        local specifier = tag
        local sphandler = FDB.PlaceholderVariables[specifier]

        if sphandler then
            local param = params[nthSpecifier]

            local status, err = pcall(sphandler, db, param)
            if not status then
                errored = "Error while processing \"" .. query .. "\"'s sp " .. specifier .. " with param \"" .. tostring(param) .. "\": " .. err
                return
            end

            --FDB.Debug(specifier .. " of " .. param .. " turned into " .. err)

            table.insert(finalQueryTbl, err)
            nthSpecifier = nthSpecifier + 1
        else
            FDB.Warn("Warning! Undefined specifier in " .. query .. ": " .. specifier .. ". Ignoring and thus possibly corrupting something..")
        end

        if postfix and postfix ~= "" then
            table.insert(finalQueryTbl, postfix)
        end
    end)

    if errored then FDB.Error(errored) return end

    if matches == 0 then
       finalQueryTbl = {query}
    end

    return table.concat(finalQueryTbl, "")
end

local dbmeta = FDB.dbmeta

-- A query that does not block. onSuccess is called if query is succesfully executed and onError if we get an error
function dbmeta:Query(onSuccess, onError, query, ...)

    local db = self:RawDB()
    if not db then
        FDB.Error("RawDB not available!")
    end

    local fquery = FDB.ParseQuery(db, query, ...)
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
        FDB.Warn("Query failed! SQL: " .. sql .. ". Err: " .. err)
        if onError then
            onError(err, sql)
        end
    end

    query:start()

    return query

end

-- A query that blocks until we got a result
function dbmeta:BlockingQuery(query, ...)
    local result

    local err

    local query = self:Query(function(data) -- onSuccess
        result = data
    end,
    function(nerr) err = nerr end, -- onError
    query, ...)

    if not query then return end

    query:wait()

    if err then
        return false, err
    end

    return result
end

-- A query that blocks until we got some kind of result and then returns with either the result or nil
function dbmeta:BQueryFirstRow(query, ...)
    local res, err = self:BlockingQuery(query, ...)
    if res then
        return res[1]
    end
    return false, err
end

function dbmeta:BQueryFirstField(query, ...)
    local res, err = self:BlockingQuery(query, ...)
    if res then
        local firstrow = res[1]
        local fkey = table.GetFirstKey(firstrow)
        return firstrow[fkey]
    end
    return false, err
end

function dbmeta:Insert(sqltable, datamap)
    local keys, values = {}, {}
    table.foreach(datamap, function(k, v)
        table.insert(keys, k)
        table.insert(values, v)
    end)
    return self:Query(_, _, "INSERT INTO %b %tb VALUES %to;", sqltable, keys, values)
end

function dbmeta:Delete(sqltable, condition, ...)
    return self:Query(_, _, "DELETE FROM %b WHERE %l;", sqltable, FDB.ParseQuery(self:RawDB(), condition, ...))
end

function dbmeta:GetInsertedId()
    return self.LastAutoIncrement
end

function dbmeta:GetAffectedRows()
    return self.LastAffectedRows or 0
end

function dbmeta:GetRowCount()
    return self.LastRowCount
end

-- Transaction stuff

function dbmeta:StartTransaction()
    return self:BlockingQuery("START TRANSACTION;") ~= false
end

function dbmeta:Commit()
    return self:BlockingQuery("COMMIT;") ~= false
end

function dbmeta:Rollback()
    return self:BlockingQuery("ROLLBACK;") ~= false
end