FruityDB
========

A library to make database calls more fun

## Usage

```lua
local db, err = FDB.Connect("sqlite" --[[can be "mysqloo" or "tmysql4" also]], {
    -- There are not needed when using sqlite
    host = "localhost",
    user = "root",
    password = "",
    database = "the_db",
    port = 3306, -- mysql port
    socket = "" -- unix socket for mysql
})
if not db then error("db connection failed: " .. err) end

-- Query
db:Query("SELECT * FROM table", _, function(data)
    PrintTable(data)
end)

-- Helper functions
db:QueryFirstRow("SELECT * FROM table", _, PrintTable)
db:QueryFirstField("SELECT * FROM table", _, print)

-- Error handling
db:Query("SELEC * FROM table", _, _, function(err, sql)
    print("SQL Error: ", err)
    print("When running query: ", sql)
end)

-- Escaping parameters
db:Query("SELECT * FROM table WHERE groupid = %d AND name = %s", {42, "John"})

-- Placeholder variables:
-- %d and %i = number
-- %s        = string
-- %l        = literal  (don't use with user input)
-- %b        = backticked string (don't use with user input)
-- %o        = object (escapes based on type; supports number, string and table)
-- %to       = table of objects (parses into a SQL list)
-- %tb       = table of backticked strings (parses into a SQL list)
-- GMod type specific placeholder variables:
-- %p        = Player (stored as steamid, so works over server restarts)

-- Insertion
db:Insert("table", {
    groupid = 36,
    name = "Mike"
}, function(affectedRowCount, insertedId)
    -- Print the AUTOINCREMENTed row id
    print("Added row with id ", insertedId)
end)

-- Simple updating (read as "set `groupid` to 24 on `table` where `name` equals 'Mike'")
db:Update("table", {groupid = 24}, "name = %s", "Mike")

-- Deletion
db:Delete("table", "groupid = %d AND name = %s", 24, "Mike")

```

## GMod specific placeholder variables
FDB comes with type variables that map to some common Garry's Mod types. To use them, your database table schema needs to be as following:

- For ```%p``` the column needs to be of SQL type ```BIGINT```