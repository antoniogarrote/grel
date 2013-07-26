require File.join(File.dirname(__FILE__), "helper")

include GRel
include Stardog

describe "graph#store" do
  DB = "testgraph"

  before(:each) do
    @conn = stardog("http://localhost:5822/", :user => "admin", :password => "admin")
    @conn.drop_db(DB) if @conn.list_dbs.body["databases"].include?(DB)
  end

  after(:each) do
    @conn.drop_db(DB)
    @conn = nil
  end


  it "shold be possible to store data in the Stardog DB" do

    graph.
      with_db(DB).
      store([{:@id => "@id(1)", :a => 1}, {:@id => "@id(2)", :b => 2}])

    results = @conn.query(DB, "select ?s ?p ?o where { ?s ?p ?o}")

    expect(results.body["results"]["bindings"].length).to be_eql(2)
  end

end

describe "graph query" do
  DB = "testgraph"

  before(:each) do
    @conn = stardog("http://localhost:5822/", :user => "admin", :password => "admin")
    @conn.drop_db(DB) if @conn.list_dbs.body["databases"].include?(DB)
  end

  after(:each) do
    @conn.drop_db(DB)
    @conn = nil
  end

  it "should be possible to execute a plain SPARQL query built using the QL" do
    mg = graph.
      with_db(DB).
      store([{:a => 1, :c => 3}, {:b => 2, :d => 4, :float => 1.0, :literal => "hey", :date => Date.today, :time => Time.now, :true => true, :false => false, :nil => nil}])

    results = mg.where({:b => 2}).run
    puts "results"
    puts results
    #expect(results["@context"]).not_to be_nil

    expect(results.first["@id"]).not_to be_nil
  end

  it "should be possible to turn on validations for the database" do
    g = graph.with_db(DB)
    result = @conn.db_options(DB)
    expect(result.body["icv.enabled"]).to be_eql(false)


    g.with_validations(true)    
    result = @conn.db_options(DB)
    expect(result.body["icv.enabled"]).to be_eql(true)
  end

  it "should prevent insertions and raise an exception is a validation is violated" do
    mg = graph.with_db(DB).with_validations(true)

    mg.validate(:lives, :@range, :Country)

    result = begin
      mg.without_reasoning.store({:@id => "p2", :name => "person2", :lives => {:@id => "c2", :name => "Country2"}})
      true
    rescue Exception
      false
    end

    expect(result).to be_false

    results = mg.where({:lives => {}}).all
    expect(results).to be_empty
    
    mg.store({:@id => "p3", :name => "person3", :lives => {:@id => "c3", :name => "Country3", :@type => :Country}})

    results = mg.where({:lives => {}}).all    
    expect(results).not_to be_empty
  end

  it "should be possible to retract validations" do
    mg = graph.with_db(DB).with_validations(true)

    mg.validate(:lives, :@range, :Country)

    result = begin
      mg.without_reasoning.store({:@id => "p2", :name => "person2", :lives => {:@id => "c2", :name => "Country2"}})
      true
    rescue Exception
      false
    end

    expect(result).to be_false

    results = mg.where({:lives => {}}).all
    expect(results).to be_empty
    
    mg.retract_validation(:lives, :@range, :Country)

    result = begin
      mg.without_reasoning.store({:@id => "p2", :name => "person2", :lives => {:@id => "c2", :name => "Country2"}})
      true
    rescue Exception
      false
    end

    expect(result).to be_true

    results = mg.where({:lives => {}}).all    
    expect(results).not_to be_empty
  end

  it "should be possible to validate data types" do
    mg = graph.with_db(DB).with_validations(true)

    mg.validate(:born, :@range, Date)

    result = begin
      mg.store({:born => "1982-05-01"})
      true
    rescue Exception
      false
    end

    expect(result).to be_false

    result = begin
      mg.store({:born => Date.parse("1982-05-01")})
      true
    rescue Exception
      false
    end

    expect(result).to be_true

    results = mg.where({:born => :_}).all
    expect(results).not_to be_empty
  end

  it "Should be possible to validate subclass/superclass relationships" do
    mg = graph.with_db(DB).with_validations(true)

    mg.validate(:Developer, :@subclass, :Person)

    result = begin
      mg.store({:id => 'abs', :@type  => :Developer})
      true
    rescue Exception
      false
    end

    expect(result).to be_false

    result = begin
      mg.store({:id => 'abs', :@type  => [:Developer, :Person]})
      true
    rescue Exception
      false
    end

    expect(result).to be_true

    results = mg.where({}).all
    expect(results).not_to be_empty
  end

  #it "should be possible to assert validations in relationships between classes" do
  #  mg = graph.with_db(DB).with_validations(true)
  # 
  #  mg.validate(:Supervisor, :@some, [:supervises, :Employee])
  # 
  #  result = begin
  #             mg.store({:@id => 'a', :@type  => :Supervisor})
  #             true
  #           rescue Exception
  #             false
  #           end
  # 
  #  expect(result).to be_false
  # 
  #  result = begin
  #             mg.store({:@id => 'a', :@type  => :Supervisor, :supervises => {:@type => :Employee}})
  #             true
  #           rescue Exception
  #             false
  #           end
  # 
  #  expect(result).to be_true
  # 
  #  results = mg.where({}).all
  #  expect(results).not_to be_empty
  #end

  it "Should be possible to assert validation in all relationships for a class" do
    mg = graph.with_db(DB).with_validations(true)

    mg.validate(:Supervisor, :@all, [:supervises, :Employee])

    result = begin
               mg.store({:@id => 'a', 
                          :@type  => :Supervisor, 
                          :supervises => [{:@type => :Employee},
                                          {:@type => :Supervisor}]})
               true
             rescue Exception
               false
             end

    expect(result).to be_false

    result = begin
               mg.store({:@id => 'a', :@type  => :Supervisor, 
                          :supervises => [{:@type => :Employee},
                                          {:@type => [:Supervisor,:Employee]}]})
               true
             rescue Exception
               false
             end

    expect(result).to be_true

    results = mg.where({}).all
    expect(results).not_to be_empty
  end

  it "should be possible to remove data from the graph" do
    g = graph.with_db(DB).
      store(:name => "a", :age => 12).
      store(:name => "b", :age => 54).
      store(:name => "c", :age => 20)

    nodes = g.where({}).all
    expect(nodes.map{|n| n[:age]}.sort).to be_eql([12,20,54])

    g.where(:age => {:$lt => 18}).remove

    nodes = g.where({}).all
    expect(nodes.map{|n| n[:age]}.sort).to be_eql([20,54])
  end

  it "should be possible to remove particular triples from the graph" do
    g = graph.with_db(DB)

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

      store(:@id     => 'abs',
            :citizen => '@id(uk)').

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

    nodes = g.where(:@id => 'es').all
    expect(nodes.first[:population]).to be_eql(43)
    
    g.remove(:@id => 'es', :population => 43)

    nodes = g.where(:@id => 'es').all
    expect(nodes.first[:population]).to be_nil
  end

  it "should be possible to run tuple queries" do
    g = graph.with_db(DB)

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

      store(:@id     => 'abs',
            :citizen => '@id(uk)').

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

    tuples = g.where(:@id => :_id, :population => :_population, :capital => 'Madrid').tuples

    expect(tuples.length).to be_eql(1)
    expect(tuples.first[:id]).to be_eql("@id(es)")
    expect(tuples.first[:population]).to be_eql(43)

    tuples = g.where(:@id => :_id, :name => :_name, :citizen => { :name => 'Spain', :capital => :_capital }).tuples
    expect(tuples.length).to be_eql(1)
    expect(tuples.first[:id]).to be_eql("@id(antoniogarrote)")
    expect(tuples.first[:name]).to be_eql("Antonio")
    expect(tuples.first[:capital]).to be_eql("Madrid")
  end

  it "should be possible to run unlink graph nodes" do
    g = graph.with_db(DB)

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

      store(:@id     => 'abs',
            :citizen => '@id(uk)').

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

    g.unlink(["abs", "thattommyhall"])

    results= g.where({:citizen => {}}).all(:unlinked => true)

    expect(results.length).to be_eql(1)
    expect(results.first[:name]).to be_eql("Antonio")
  end

  it "should be possible to add rules to the database" do
    g = graph.with_db(DB)
    g.with_reasoning.rules([[:hasParent, "?x1", "?x2"], [:hasBrother, "?x2", "?x3"]]  => [:hasUncle, "?x1","?x3"])

    g.store(:name => 'Antonio', :hasParent => { 
              :name => 'Juliana', :hasParent => {
                :name => 'Leonor', :hasBrother => {
                  :name => 'Santiago'
                } 
              } 
            })
 
  
    tuples = g.where(:name => :_nephew, :hasUncle => {:name => :_uncle}).tuples
    expect(tuples.length).to be_eql(1)
    expect(tuples.first[:uncle]).to be_eql("Santiago")
    expect(tuples.first[:nephew]).to be_eql("Juliana")

    g.with_reasoning.rules([[:hasUncle, "?x1", "?x2"], [:hasParent, "?x3", "?x1"]]  => [:hasUncle, "?x3","?x2"])

    tuples = g.where(:name => :_nephew, :hasUncle => {:name => :_uncle}).tuples
    expect(tuples.length).to be_eql(2)
    nephews = []
    tuples.each do |t|
      expect(t[:uncle]).to be_eql("Santiago")
      nephews << t[:nephew]
    end
    expect(nephews.sort).to be_eql(["Antonio","Juliana"])

    tuples = g.without_reasoning.where(:name => :_niece, :hasUncle => {:name => :_uncle}).tuples
    expect(tuples.length).to be_eql(0)
  end
end
