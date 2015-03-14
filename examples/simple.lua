local db = FDB.Connect("sqlite")

db:Query("CREATE TABLE test(id INTEGER PRIMARY KEY, name TEXT, label TEXT, age INT)")

local function Insert(name, label, age)
	db:Insert("test", {
		name = name,
		label = label,
		age = age
	}, function(rows, id)
		print("Added '" .. name .. "' with id ", id)
	end)

end

local function PrintSQLState()
	db:Query("SELECT * FROM test", {}, PrintTable)
end

Insert("Mike", "the Chef", 23)
Insert("John", "the Explorer", 21)

PrintSQLState()

db:Query("DROP TABLE test")