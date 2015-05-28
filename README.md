# orientdb-rest
A simple ruiby wrapper for the REST-API of OrientDB


OrientDB is still under heavy development. Any non-java binary-API-binding is therefor subject of constant changes.

OrientDB provides a high-level REST-HTTP-API as well. This is most likely robust.

This small wrapper is written to send date gathered by a Ruby-programm easily into an OrientDB-Database.

It's initialized by

```ruby
 r = REST::OrientDB.new database: 'hc_database'
```
the database has to exist, otherwise

```ruby
 r = REST::OrientDB.new database: 'h_database', connect: false
 r.create_database name: 'hc_database'
 r.connect
```

 The given datasetname is the working-database for all further operations.
 
 You can fetch a list of Classes  and some Properites by
 ``` ruby
    r.get_classes 'name', 'superClass' (, further attributes )
 ```
 
 
 Creation and removal of Classes is straightforward
 ```ruby
    r.create_class  classname
    r.delete_class  classname
 ```
 if a schema is used, Properties can retrieved, and created
 ```ruby
  r.create_properties( class_name: classname ) do
     {	symbol: { propertyType: 'STRING' },
	con_id: { propertyType: 'INTEGER' },
       details: { propertyType: 'LINK', linkedClass: 'Contracts' }
      }

  @r.get_class_properties class_name: classname 
 ```
 
 Documents can easily created, updated, removed and queried
 ```ruby
  r.create_document class_name: classname , attributes: {con_id: 345, symbol: 'EWQZ' }

 ```
  inserts a record in the classname-class 

 ```ruby
  r.update_documents class_name: classname , set: {con_id: 346 },
		      where: { symbol: 'EWQZ' } 

 ```
 updates the database in a rdmb-fashon

 ```ruby
  r.get_documents class_name: classname , where: {con_id: 345, symbol: 'EWQZ' }

 ```
 queries the database accordantly and

 ```ruby
  r.delete_documents class_name: classname , where: {con_id: 345, symbol: 'EWQZ' }

 ```
 completes the circle
 


At least - sql-commands can be executed as batch

 ```ruby

    r.execute  transaction: false do
         ## perform operations from the tutorial
	 sql_cmd = -> (command) { { type: "cmd", language: "sql", command: command } }

	[ sql_cmd[ "create class Person extends V" ] ,
	  sql_cmd[ "create class Car extends V" ],
	  sql_cmd[ "create class Owns extends E"],

	  sql_cmd[ "create property Owns.out LINK Person "],
	  sql_cmd[ "create property Owns.in LINK Car "],
	  sql_cmd[ "alter property Owns.out MANDATORY=true "],
	  sql_cmd[ "alter property Owns.in MANDATORY=true "],
	  sql_cmd[ "create index UniqueOwns on Owns(out,in) unique"],

	  { type: 'c', record: { '@class' => 'Person' , name: 'Lucas' } },
	  sql_cmd[ "create vertex Person set name = 'Luca'" ],
	  sql_cmd[ "create vertex Car set name = 'Ferrari Modena'"],
	  { type: 'c', record: { '@class' => 'Car' , name: 'Lancia Musa' } },


	  sql_cmd[ "create edge Owns from (select from Person where name='Luca') to (select from Car where name = 'Lancia Musa')" ],
	  sql_cmd[ "select name from ( select expand( out('Owns') ) from Person where name = 'Luca' )" ]
	 ]
       end

 ```
  returns the result of the last query. 


  The REST-API documentation can be found here: https://github.com/orientechnologies/orientdb-docs/wiki/OrientDB-REST
 
 
 
 
 
 

