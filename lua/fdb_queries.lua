
-- A symbol that precedes 'placeholder' variables in query
FDB.ParamChar = "%" -- must be a single char

-- The placeholder variables that can be used in a query
FDB.SpecifierHandlers = {
    ["s"] = function(db, param)
        return "'" .. (db:escape(param) or "") .. "'"
    end,
    ["i"] = function(db, param)
        return tonumber(param) or error("Unable to convert " .. param .. " to number")
    end,
    ["d"] = function(db, param)
        return tonumber(param) or error("Unable to convert " .. param .. " to number")
    end,
    ["l"] = function(db, param) -- Literal
        return tostring(param)
    end,
    ["b"] = function(db, param) -- Backticks
        return "`" .. tostring(param) .. "`"
    end,
    ["t"] = function(db, param) -- List of things that need to be escaped
        if type(param) ~= "table" then error("Passed param is not table") end
        local s = "("
        local widx = 0
        for k,v in pairs(param) do
            if widx > 0 then
                s = s .. ", "
            end
            local handler
            if type(v) == "string" then handler = "s"
            elseif type(v) == "number" then handler = "d"
            elseif type(v) == "table" then handler = "t"
            end

            if not handler then
                error("Couldn't find list handler for " .. type(v))
                return
            end

            s = s .. FDB.SpecifierHandlers[handler](db, v)
            widx = widx + 1
        end
        s = s .. ")"
        return s 
    end,
    ["a"] = function(db, param) -- Array of arguments. NOT ESCAPED!!
        if type(param) ~= "table" then error("Passed param is not table") end
        local s = "("
        local widx = 0
        for k,v in pairs(param) do
            if widx > 0 then
                s = s .. ", "
            end
            s = s .. FDB.SpecifierHandlers["b"](db, v)
            widx = widx + 1
        end
        s = s .. ")"
        return s 
    end
}

-- TODO get rid of db requirement (is required for db:escape)

function FDB.ParseQuery(db, query, ...)

    local params = {... }

    local finalQueryTbl = {}

    local nthSpecifier = 1

    local errored

    local _, matches = query:gsub( "([^%" .. FDB.ParamChar .. "]*)%" .. FDB.ParamChar .. "([%.%d]*[%a])([^%" .. FDB.ParamChar .. "]*)", function( prefix, tag, postfix )
        if prefix and prefix ~= "" then
            table.insert(finalQueryTbl, prefix)
        end

        local specifier = tag:sub( -1, -1 )
        local sphandler = FDB.SpecifierHandlers[specifier]

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
    local fquery = FDB.ParseQuery(db, query, ...)
    FDB.Debug(query .. " parsed to " .. fquery)

    if not fquery or not db then return end

    FDB.Debug("Starting query " .. fquery)

    local query = db:query(fquery)
    function query:onSuccess(data)
       FDB.Debug("Query succeeded! #data " .. #data)
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
    self:Query(_, _, "INSERT INTO %b %a VALUES %t;", sqltable, keys, values)
end

function dbmeta:Delete(sqltable, condition, ...)
    self:Query(_, _, "DELETE FROM %b WHERE %l;", sqltable, FDB.ParseQuery(self:RawDB(), condition, ...))
end