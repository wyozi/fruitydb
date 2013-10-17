-- Prints database calls and debug information to server console.
CreateConVar("fruitydb_debug", "0")

function FDB.IsDebug()
	return GetConVarNumber("fruitydb_debug") == 1
end