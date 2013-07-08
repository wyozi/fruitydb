
-- To use FruityDB, you normally need to set FDB.Config table before Initialization step. Putting your database values to layout below works fine.
-- To prevent leaking the values, they are automatically cleared in memory after connecting to database. Therefore if you lose connection the map needs to change before
-- the database connection is reinstated.
--
-- Setting FDB.Unsafe to "true" allows immediate reconnection, but can potentially be more unsecure.

FDB.Config = {
    host = "localhost",
    name = "root",
    password = "",
    database = "test",
    port = 3306
}

-- If Unsafe is enabled, database settings are retained in memory so reconnecting to database is possible without map change.
-- However it can potentially be much more unsecure so be sure you know what you're doing.
FDB.Unsafe = true

-- Prints database calls to server console.
FDB.DebugMode = true