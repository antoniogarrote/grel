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
end
