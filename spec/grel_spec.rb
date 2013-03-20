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
    expect(results["@context"]).not_to be_nil

    expect(results["@id"]).not_to be_nil
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
    rescue ValidationError
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
    rescue ValidationError
      false
    end

    expect(result).to be_false

    results = mg.where({:lives => {}}).all
    expect(results).to be_empty
    
    mg.retract_validation(:lives, :@range, :Country)

    result = begin
      mg.without_reasoning.store({:@id => "p2", :name => "person2", :lives => {:@id => "c2", :name => "Country2"}})
      true
    rescue ValidationError
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
    rescue ValidationError
      false
    end

    expect(result).to be_false

    result = begin
      mg.store({:born => Date.parse("1982-05-01")})
      true
    rescue ValidationError
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
    rescue ValidationError
      false
    end

    expect(result).to be_false

    result = begin
      mg.store({:id => 'abs', :@type  => [:Developer, :Person]})
      true
    rescue ValidationError
      false
    end

    expect(result).to be_true

    results = mg.where({}).all
    expect(results).not_to be_empty
  end

  it "should be possible to assert validations in relationships between classes" do
    mg = graph.with_db(DB).with_validations(true)

    mg.validate(:Supervisor, :@some, [:supervises, :Employee])

    result = begin
               mg.store({:@id => 'a', :@type  => :Supervisor})
               true
             rescue ValidationError
               false
             end

    expect(result).to be_false

    result = begin
               mg.store({:@id => 'a', :@type  => :Supervisor, :supervises => {:@type => :Employee}})
               true
             rescue ValidationError
               false
             end

    expect(result).to be_true

    results = mg.where({}).all
    expect(results).not_to be_empty
  end

  it "Should be possible to assert validation in all relationships for a class" do
    mg = graph.with_db(DB).with_validations(true)

    mg.validate(:Supervisor, :@all, [:supervises, :Employee])

    result = begin
               mg.store({:@id => 'a', 
                          :@type  => :Supervisor, 
                          :supervises => [{:@type => :Employee},
                                          {:@type => :Supervisor}]})
               true
             rescue ValidationError
               false
             end

    expect(result).to be_false

    result = begin
               mg.store({:@id => 'a', :@type  => :Supervisor, 
                          :supervises => [{:@type => :Employee},
                                          {:@type => [:Supervisor,:Employee]}]})
               true
             rescue ValidationError
               false
             end

    expect(result).to be_true

    results = mg.where({}).all
    expect(results).not_to be_empty
  end
end
