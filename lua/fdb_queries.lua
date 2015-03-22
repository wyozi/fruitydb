
-- A symbol that precedes 'placeholder' variables in query
FDB.ParamChar = "%" -- must be a single char

-- A helper function for placeholder variables
function FDB.CreateTableHandler(handler)
    return function(param) -- Table of objects
        if type(param) ~= "table" then error("Passed param is not table") end
        local param_table = {}
        for k,v in pairs(param) do
            table.insert(param_table, FDB.PlaceholderVariables[handler](v))
        end
        return "(" .. table.concat(param_table, ",") .. ")"
    end
end

-- Escape a string. Also adds single quotations around your queries. Uses Garry's Mod's built-in escape function
function FDB.EscapeString(str)
    return sql.SQLStr(str)
end

-- The variables that can be used in a query in place of data
FDB.PlaceholderVariables = {
    ["s"] = function(param)
        return (FDB.EscapeString(param) or "")
    end,
    ["i"] = function(param)
        return tonumber(param) or error("Unable to convert " .. tostring(param) .. " to number")
    end,
    ["d"] = function(param)
        return tonumber(param) or error("Unable to convert " .. tostring(param) .. " to number")
    end,
    ["l"] = function(param) -- Literal
        return tostring(param)
    end,
    ["b"] = function(param) -- Backticks
        return "`" .. tostring(param) .. "`"
    end,
    ["o"] = function(param) -- Object
        local t = type(param)
        local handler

        if t == "string" then handler = "s"
        elseif t == "number" then handler = "d"
        elseif t == "table" then handler = "to"
        elseif t == "Player" then handler = "p"
        end

        if not handler then error("Couldn't find object handler for " .. t) end
        return FDB.PlaceholderVariables[handler](param)
    end,
    ["p"] = function(param)
        local pply = FDB.PersistentPlayer(param)
        if not pply then
            error("Unable to convert " .. tostring(param) .. " to persistent player")
        end

        return pply:SteamID64()
    end,
    ["to"] = FDB.CreateTableHandler("o"),
    ["tb"] = FDB.CreateTableHandler("b")
}

function FDB.ParseQuery(query, ...)
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

            local status, err = pcall(sphandler, param)
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

--- FruityDB supports two kinds of parameters passed to db:Query
--    (obsolete) db:Query(onSuccessCb, onErrorCb, query, ...)
--    (current)  db:Query(query, {...}, onSuccessCb, onErrorCb)
--  where '...' is vararg of the parameters to replace in query.
-- Both can be used, but the first one is deprecated and might disappear in the future.
--
-- Database types use [onSuccess, onError, parsedQuery]
function dbmeta:Query(param1, param2, param3, ...)
    
    local function FormatQuery(query, ...)
        local fquery = FDB.ParseQuery(query, ...)
        if not fquery then
            FDB.Warn("Query not executed: fquery is nil")
            return
        end

        if FDB.IsDebug() then -- We double check for debug mode here because string operations are expensive-ish
            FDB.Debug(query .. " parsed to " .. fquery)
            FDB.Debug("Starting query " .. fquery)
        end

        return fquery
    end

    -- Obsolete query type
    if type(param1) == "function" or param1 == nil then
        local fquery = FormatQuery(param3, ...)
        if not fquery then return end

        return self:RawQuery(param1, param2, param3, ...)

    -- Current query type
    else
        local fquery = FormatQuery(param1, unpack(param2 or {}))
        if not fquery then return end

        return self:RawQuery(param3, select(1, ...), fquery)
    end
end

--- Run query and return results as a table. Is blocking.
-- On error: returns false, [errormsg]
function dbmeta:BQuery(query, ...)
    local _res, _err

    local query = self:Query(query, {...}, function(res)
        _res = res
    end, function(err)
        _err = err
    end)

    -- We check for error here already, in case something already failed
    if _err then
        return false, _err
    end

    -- If db provider supports waiting for query, it returns true from Wait() method
    local waited = false
    if self:Wait(query) then
        waited = true
    end

    if not waited then
        return false, "Database provider does not support waiting query to complete. Use non-blocking queries"
    end

    if _err then
        return false, _err
    end

    return _res
end
dbmeta.BlockingQuery = dbmeta.BQuery

--- Run query and return the first row. Is blocking.
-- On error: returns false, [errormsg]
function dbmeta:BQueryFirstRow(query, ...)
    local res, err = self:BlockingQuery(query, ...)
    if res then
        return res[1]
    end
    return false, err
end

--- Run query and return the first row.
function dbmeta:QueryFirstRow(query, params, onSuccess, onError)
    return self:Query(query, params, function(data)
        onSuccess(data[1])
    end, onError)
end

--- Run query and return the first field of the first row. Is blocking.
-- On error: returns false, [errormsg]
function dbmeta:BQueryFirstField(query, ...)
    local res, err = self:BlockingQuery(query, ...)
    if res then
        local firstrow = res[1]
        if firstrow then
            local fkey = table.GetFirstKey(firstrow)
            return firstrow[fkey]
        end
    end
    return false, err
end

--- Run query and return the first row.
function dbmeta:QueryFirstField(query, params, onSuccess, onError)
    return self:QueryFirstRow(query, params, function(row)
        local field = nil
        if row then
            local key = table.GetFirstKey(row)
            if key then
                field = row[key]
            end
        end

        onSuccess(field)
    end, onError)
end

--- Inserts data to table. Datamap supports string values
-- Example datamap (in lua):
-- { name = "John", age = 19 }
function dbmeta:Insert(sqltable, datamap, onSuccess, onError)
    local keys, values = {}, {}
    table.foreach(datamap, function(k, v)
        table.insert(keys, k)
        table.insert(values, v)
    end)

    -- Modify arguments passed to onSuccess
    -- from [data] to [affectedRows, insertedId, data]
    local cb
    if onSuccess then
        cb = function(data)
            local rows = self:GetAffectedRows()
            local id = self:GetInsertedId()
            onSuccess(rows, id, data)
        end
    end

    return self:Query("INSERT INTO %b %tb VALUES %to;", {sqltable, keys, values}, cb, onError)
end

function dbmeta:Update(sqltable, datamap, condition, ...)
    local data_placeholders = {}
    local data_params = {}
    table.foreach(datamap, function(k, v)
        table.insert(data_placeholders, "%b = %o")
        table.insert(data_params, k)
        table.insert(data_params, v)
    end)

    local params = {}
    params[#params+1] = sqltable
    table.Add(params, data_params)
    params[#params+1] = FDB.ParseQuery(condition, ...)

    return self:Query("UPDATE %b SET " .. table.concat(data_placeholders, ",") .. " WHERE %l;", params)
end

function dbmeta:Delete(sqltable, condition, ...)
    return self:Query("DELETE FROM %b WHERE %l;", {sqltable, FDB.ParseQuery(condition, ...)})
end
