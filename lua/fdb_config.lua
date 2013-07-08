
-- To use FruityDB, you normally need to set FDB.Config table before ´Initialization´ hook would get called, so putting your database values to layout below this comment works fine.
-- To prevent leaking the values, the sensitive details are automatically cleared in memory after connecting to database. Therefore if you lose connection the map needs to change before
-- the database connection is reinstated.
--
-- Setting FDB.Unsafe to "true" allows reconnecting immediately on connection loss and connecting after ´Initialization´ hook, but can potentially be more unsecure.

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

-- Garry's Mod can automatically reload lua files when they are changed. Should we reconnect if FruityDB files get reloaded? Leave 'true' if in doubt.
FDB.DontReconnectOnReload = true