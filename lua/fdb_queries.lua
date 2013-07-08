
FDB.ParamChar = "%" -- must be 1 char

FDB.SpecifierHandlers = {
    ["s"] = function(db, param)
        return "'" .. (db:escape(param) or "") .. "'"
    end,
    ["i"] = function(db, param)
        return tonumber(param) or error("Unable to convert " .. param .. " to number")
    end,
    ["d"] = function(db, param)
        return tonumber(param) or error("Unable to convert " .. param .. " to number")
    end
}

function FDB.ParseQuery(query, ...)

    local db = FDB.RawDB()
    if not db then
        return
    end

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
            FDB.Log("Warning! Undefined specifier in " .. query .. ": " .. specifier .. ". Ignoring and thus possibly corrupting something..")
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

function FDB.SlowQuery(success, query, ...)

    local fquery = FDB.ParseQuery(query, ...)
    local db = FDB.RawDB()

    if not fquery or not db then return end

    FDB.Debug("Starting query " .. fquery)

    local query = db:query(fquery)
    function query:onSuccess(data)
       if success then
          success(data)
       end
       FDB.Debug("Query succeeded! #data " .. #data)
    end

    function query:onError(err, sql)
        FDB.Log("Query failed! SQL: " .. sql .. ". Err: " .. err)
    end

    query:start()

    return query

end

function FDB.InstaQuery(query, ...)
    local result

    local query = FDB.SlowQuery(function(data)
        result = data
    end, query, ...)
    if not query then return end

    query:wait()
    return result
end

function FDB.InstaQueryFirstRow(query, ...)
    local res = FDB.InstaQuery(query, ...)
    if res then
        return res[1]
    end
    return nil
end