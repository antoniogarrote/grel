#GRel

A small ruby library that makes it easy to store and query ruby objects stored in a RDF database like Stardog.

## Example:

```ruby
    g = graph.with_db("TEST").
        store([{:a => 1, :b => 1}, 
               {:a => 2, :b => 2}, 
               {:a =>15, :b => 1}, 
               {:a => 24, :b => 2}])
     
    nodes = g.where({:a => {:$gt => 10}, :b => 1}).all
     
    expect(nodes.length).to be_eql(1)
    expect(nodes.first[:a]).to be_eql(15)
```

## Author and contact:

Antonio Garrote (antoniogarrote@gmail.com)
