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
```ruby
    g.where(:@type => :Developer, :citizen => {}).all 
    # [ {:@id => '@id(abs)', :name => 'Abhinay', ...
    #    :citizen => {:@id => '@(in)', :name => 'India', ... }},
    #   {:@id => '@id(thattommyhall)', :name => 'Tom', ...
    #    :citizen => {:@id => '@(uk)', :name => 'United Kingdom' ... }},
    #   {:@id => '@id(antoniogarrote)', :name => 'Antonio', ... 
    #    :citizen => {:@id => '@(es)', :name => 'Spain', ... }} ]
```
Relationships between objects can be specified in inverse order using a key starting with *$inv*.
```ruby
    g.where(:@type => :Country, :$inv_citizen => {:name => "Abhinay"}).all
    # [ {:@id => '@id(in)', :name => 'India', ...'} ]
```
Filters can be applied to properties to select valid objects:
```ruby
    g.where(:@type => :Country, :population => {:$gt => 100}).all
    # [ {:@id => '@id(in)', :name => 'India', :population => 1200, ...'} ]
    g.where(:@type => :Country, :population => {:$or => [{:$lt => 50},{:$gt => 1000}]}).all
    # [ {:@id => '@id(in)', :name => 'India', :population => 1200, ...'},
    #   {:@id => '@id(es)', :name => 'Spain', :population => 43, ...} ]
```

Different optional patterns can be joined in a single query using the method *union*.
```ruby
    g.where(:@type => :Country).union(:@type => :Developer).all
    # returns all objects
```

If more than one object matches a property, the final set of matching objects will be returned in an array.
```ruby
    g.store(:@id     => 'abs',
            :citizen => '@id(uk)').

      where(:name => 'Abhinay', :citizen => {}).all
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
    # [{:@id => 'id(antoniogarrote)', :citizen => {'@id' => 'id(es)', :capital => 'Madrid', ... }, ...}]
```


An example using the *@domain* and *@range* declarations.
```ruby
    g.define(:citizen, :@domain, :Citizen)   
    g.define(:citizen, :@range, :State)   

    g.with_reasoning.where(:@type => :Citizen, :citizen => {:@type => :State}).all
    # [{:@id => 'id(antoniogarrote)', :citizen => {'@id' => 'id(es)', :capital => 'Madrid', ... }, ...},
    #  {:@id => 'id(thattommyhall)',  :citizen => {'@id' => 'id(uk)', :capital => 'Madrid', ... }, ...}
    #  ... ]
```



## Author and contact:

Antonio Garrote (antoniogarrote@gmail.com)
