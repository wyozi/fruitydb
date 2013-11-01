-- Prints database calls and debug information to server console.
CreateConVar("fruitydb_debug", "0", FCVAR_ARCHIVE)

function FDB.IsDebug()
	return GetConVarNumber("fruitydb_debug") == 1
end