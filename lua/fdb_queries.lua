
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
        elseif t == "table" then handler = "to" end
        if not handler then error("Couldn't find object handler for " .. t) end
        return FDB.PlaceholderVariables[handler](param)
    end,
    ["to"] = FDB.CreateTableHandler("o"),
    ["tb"] = FDB.CreateTableHandler("b")
}

-- TODO get rid of db requirement (is required for db:escape)

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
    return self:Query(_, _, "DELETE FROM %b WHERE %l;", sqltable, FDB.ParseQuery(condition, ...))
end
