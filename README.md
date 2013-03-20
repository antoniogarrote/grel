#GRel

A small ruby library that makes it easy to store and query ruby objects stored in a RDF database like Stardog.

## Initialization
```ruby
    require 'grel'
 
    include GRel

    g = graph.with_db(DB)
```
## Data loading:

Data is loaded as arrays of nested hashes.
Two special properties *:@id* and *:@type* are used to identify the identity of the node and its types.
Identity must be unique, type can be multiple.
If no *:@id* property is provided for an object, an identity will be generated.

```ruby
    g.store(:name    => 'Abhinay',
            :surname => 'Mehta',
            :@type   => :Developer,
            :@id     => 'abs').

      store(:name    => 'Tom',
            :surname => 'Hall',
            :@type   => :Developer,
            :@id     => 'thattommyhall').

      store(:name       => 'India',
            :@type      => :Country,
            :population => 1200,
            :capital    => 'New Delhi',
            :@id        => 'in').

      store(:name       => 'United Kingdom',
            :@type      => :Country,
            :population => 62,
            :capital    => 'London',
            :@id        => 'uk').

      # Storing relationships
      store(:@id     => 'abs',
            :citizen => '@id(in)').

      store(:@id     => 'thattommyhall',
            :citizen => '@id(uk)').

      # Storing nested objects
      store(:@id     => 'antoniogarrote',
            :name    => 'Antonio',
            :@type   => :Developer,
            :citizen => {:name       => 'Spain',
                         :@type      => :Country,
                         :population => 43,
                         :capital    => 'Madrid',
                         :@id        => 'es'})             
```

## Querying:

Queries can be performed using the *where* and passing a hash with a pattern for the nodes to be retrieved, and chaining it with the *all* methods.
```ruby
    g.where(:@type => :Developer).all 
    # [ {:@id => '@id(abs)', :name => 'Abhinay', :citizen => '@(in)'},
    #   {:@id => '@id(thattommyhall)', :name => 'Tom', :citizen => '@(uk)'},
    #   {:@id => '@id(antoniogarrote)', :name => 'Antonio', :citizen => '@(es)'} ]
```

Nested objects can be retrieved specifying an empty hash for the property.
By default, the method *all* will return an array with all the objects in the recovered, including objects nested in other objects properties. 
If our query returns a graph with no cycles and we want to return only the top level objects that or not linked from other objects properties, we can pass the option *:unlinked => true* to the message.
```ruby
    g.where(:@type => :Developer, :citizen => {}).all(:unlinked => true)
    # [ {:@id => '@id(abs)', :name => 'Abhinay', ...
    #    :citizen => {:@id => '@(in)', :name => 'India', ... }},
    #   {:@id => '@id(thattommyhall)', :name => 'Tom', ...
    #    :citizen => {:@id => '@(uk)', :name => 'United Kingdom' ... }},
    #   {:@id => '@id(antoniogarrote)', :name => 'Antonio', ... 
    #    :citizen => {:@id => '@(es)', :name => 'Spain', ... }} ]
```
Relationships between objects can be specified in inverse order using a key starting with *$inv*.
```ruby
    g.where(:@type => :Country, :$inv_citizen => {:name => "Abhinay"}).all(:unlinked => true)
    # [ {:@id => '@id(in)', :name => 'India', ...'} ]
```
Filters can be applied to properties to select valid objects:
```ruby
    g.where(:@type => :Country, :population => {:$gt => 100}).all
    # [ {:@id => '@id(in)', :name => 'India', :population => 1200, ...'} ]
    g.where(:@type => :Country, :population => {:$or => [{:$lt => 50},{:$gt => 1000}]}).all
    # [ {:@id => '@id(in)', :name => 'India', :population => 1200, ...'},
    #   {:@id => '@id(es)', :name => 'Spain', :population => 43, ...} ]
    g.where(:@type => :Country, :name => {:$like => /.+a.+/}).all
    # [ {:@id => '@id(es)', :name => 'Spain', :population => 43, ...} ]
```
Valid filters are: *$and*, *$or*, *$lt*, *$lteq*, *$gt*, *$gteq*, *$eq*, *$in* and *$like*.


Different optional patterns can be joined in a single query using the method *union*.
```ruby
    g.where(:@type => :Country).union(:@type => :Developer).all
    # returns all objects
```

If more than one object matches a property, the final set of matching objects will be returned in an array.
```ruby
    g.store(:@id     => 'abs',
            :citizen => '@id(uk)').

      where(:name => 'Abhinay', :citizen => {}).all(:unlinked => true)
    # [ {:@id => '@id(abs)', :name => 'Abhinay', ...
    #    :citizen => [{:@id => '@(in)', :name => 'India', ... },
    #                 {:@id => '@(uk)', :name => 'United Kingdom', ..}]} ],
   
```

# Inference

Schema information can be added using the *define* method and assertions like *@subclass*, *@subproperty*, *@domain*, *@range*.

```ruby
    # All developers are People
    g.define(:Developer, :@subclass, :Person)   
```

If inference is enabled for a connection using the *with_reasoning* method, queries will return additional results.
```ruby
    # No reasoning
    g.where(:@type => :Person).all
    # []

    # With reasoning
    g.with_reasoning.where(:@type => :Person).all
    # [{:@id => 'id(abs)', :@type => :Developer, ...},
    #  {:@id => 'id(thattommyhall)', :@type => :Developer, ...},
    #  {:@id => 'id(antoniogarrote)', :@type => :Developer, ...}]
```

An example using the *@subproperty* declaration.
```ruby
    g.define(:citizen, :@subproperty, :bornin)   

    g.with_reasoning.where(:bornin => {:@type => :Country, :capital => 'Madrid'}).all
    # [{:@id => 'id(antoniogarrote)', :citizen => {:@id => 'id(es)', :capital => 'Madrid', ... }, ...}]
```


An example using the *@domain* and *@range* declarations.
```ruby
    g.define(:citizen, :@domain, :Citizen)   
    g.define(:citizen, :@range, :State)   

    g.with_reasoning.where(:@type => :Citizen, :citizen => {:@type => :State}).all
    # [{:@id => 'id(antoniogarrote)', :citizen => {:@id => 'id(es)', :capital => 'Madrid', ... }, ...},
    #  {:@id => 'id(thattommyhall)',  :citizen => {:@id => 'id(uk)', :capital => 'Madrid', ... }, ...}
    #  ... ]
```

Schema definitions can be removed using the method *retract_definition*.

An example using the *@domain* and *@range* declarations.
```ruby
    g.define(:citizen, :@domain, :Citizen)   
    g.define(:citizen, :@range, :State)   

    g.with_reasoning.where(:@type => :Citizen, :citizen => {:@type => :State}).all
    # [{:@id => 'id(antoniogarrote)', :citizen => {:@id => 'id(es)', :capital => 'Madrid', ... }, ...},
    #  {:@id => 'id(thattommyhall)',  :citizen => {:@id => 'id(uk)', :capital => 'Madrid', ... }, ...}
    #  ... ]

    g.retract_definition(:citizen, :@range, :State).where(:@type => :Citizen, :citizen => {:@type => :State}).all
    # [ ]
```

Inference can be disabled sending the *without_reasoning* message.

# Validations

Reasoning support can also be used to validate the objects you insert in the graph. In this case, your schema definitions are interpreted not to infere new knowledge but to check that the structure of the objects inserted match the schema.

Validations can be introduced in the graph using the *validate* message that receives an assertion with the *@subclass*, *@subproperty*, *@domain* or *@range* properties.

Validations are turned on/off using the *with_validations* and *without_validations* messages.

If a validation is violated, an exception will be raised. If validations are turned on and there's already invalid data in the graph, no further insertions will succeed.

Validations can also be removed using the *retract_validation* message.

```ruby
    g = graph.with_db(DB) # new graph

    g.with_validations.validate(:citizen, :@domain, :State)   

    g.store(:@id => 'id(malditogeek)', :citizen => {:@id => 'id(ar)', :capital => 'Buenos Aires'}, ...)

    # An exception is raised due to validation violation

    g.store(:@id => 'ar', :capital => 'Buenos Aires', :@type => :State, :name => 'Argentina').
      store(:@id => 'id(malditogeek)', :citizen => '@id(ar)')
    # After adding the @type for Argentina, the insertion does not raise any exception.
```

Validations and inference can be used together to infere additional infromation that will make data valid according to the defined validations:

```ruby
    g = graph.with_db(DB) # new graph

    g.with_validations.validate(:citizen, :@domain, :State)   

    g.store(:@id => 'id(malditogeek)', :citizen => {:@id => 'id(ar)', :capital => 'Buenos Aires'}, ...)

    # An exception is raised due to validation violation

    g.with_reasoning.define(:citizen, :@domain, :State).
      store(:@id => 'id(malditogeek)', :citizen => {:@id => 'id(ar)', :capital => 'Buenos Aires'}, ...)
    # Data is valid using reasoning since the @type :State for Argentina can be inferred.

    g.where(:@type => :Citizen, :citizen => {:@type => :State}).all
    # [{:@id => 'id(malditogeek)', :citizen => {:@id => 'id(ar)', :capital => 'Buenos Aires', ... }, ...}]

    g.without_reasoning # graph is invalid now, no further operations can be committed.

    g.without_validations # graph is again valid since no validations will be checked.
```
Some examples of validations are:

 - Data types in range, using the corresponding class *Date*, *Float*, *Fixnum*, *TrueClass*/*FalseClass*:

```ruby
    g = graph.with_db(DB) # new graph

    g.with_validations.validate(:born, :@domain, Date) # born must have a Date value

    g.store(:@id => 'antoniogarrote', :born => "1982-05-01", ...)

    # An exception is raised due to validation violation, :born has a string value not a date vaue

    g.store(:@id => 'antoniogarrote', :born => Date.parse("1982-05-01"), ...)

    # No validation error is raised
```

 - Subclass / Superclass relationships

```ruby
    g = graph.with_db(DB) # new graph

    g.with_validations.validate(:Developer, :@subclass, :Person) # all Developers must be human!

    g.store(:@id => 'abhinay', :@type => :Developer, ...)

    # An exception is raised due to validation violation, :Person @type is missing

    g.store(:@id => 'abhinay', :@type => [:Developer, :Person], ...)

    # No validation error is raised
```

 - Participation constraints

```ruby
    g = graph.with_db(DB)

    g.with_validations.validate(:Supervisor, :@some, [:supervises, :Employee])

    g.store(:@type  => :Supervisor)

    # An exception is raised, Supervisors must supervise employees
    
    g.store(:@type  => :Supervisor, :supervises => {:@type => :Employee})

    # No validation error is raised
```

```ruby
    g = graph.with_db(DB)

    g.with_validations.validate(:Supervisor, :@all, [:supervises, :Employee])

    g.store(:@type  => :Supervisor, 
            :supervises => [{:@id => 'a', :@type => :Employee},
                            {:@id => 'b', :@type => :Assistant}])

    # An exception is raised, all objectes supervised by a Supervisor must belong to
    # the Employee class
    
    g.store(:@type  => :Supervisor, 
            :supervises => [{:@id => 'a', :@type => :Employee},
                            {:@id => 'b', :@type => [:Assistant, :Employee]}])


    # No validation error is raised
```

The details about how to use validations can be found in the Stardog documentation related to ICV (Integrity Constraints Validations) for the data base (http://stardog.com/docs/sdp/#validation).

## Author and contact:

Antonio Garrote (antoniogarrote@gmail.com)
