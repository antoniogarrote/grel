require File.join(File.dirname(__FILE__), "helper")

include GRel
include Stardog

describe "QL to_triples" do
 
  it "should transform into RDF literals simple types" do
    expect(QL.to_triples("hey")).to be_eql('"hey"')
    expect(QL.to_triples(1)).to be_eql('"1"^^<http://www.w3.org/2001/XMLSchema#integer>')
    expect(QL.to_triples(1.0)).to be_eql('"1.0"^^<http://www.w3.org/2001/XMLSchema#float>')
 
    expect(QL.to_triples(Date.today).index("#date")).not_to be_nil
    expect(QL.to_triples(Date.today).index("T")).not_to be_nil
 
    expect(QL.to_triples(Time.now).index("#date")).not_to be_nil
    expect(QL.to_triples(Time.now).index("T")).not_to be_nil
  end
 
  it "should transform arrays of simple objects into arrays of triples" do
    data = [:a, :b, 1,
            :a, :d, 2]
    result = QL.to_triples(data)
    expect(result).to be_eql([[":a", ":b", "\"1\"^^<http://www.w3.org/2001/XMLSchema#integer>"], 
                              [":a", ":d", "\"2\"^^<http://www.w3.org/2001/XMLSchema#integer>"]])
  end
 
  it "should transform basic hashes" do
    data = {:@id => "@id(a)", :b => 1, :c => 4.0}
    result = QL.to_triples(data)
 
    expect(result).to be_eql([["<http://grel.org/ids/id/a>", ":b", "\"1\"^^<http://www.w3.org/2001/XMLSchema#integer>"], 
                              ["<http://grel.org/ids/id/a>", ":c", "\"4.0\"^^<http://www.w3.org/2001/XMLSchema#float>"]])
  end

  it "should handle arrays in object position" do
    data = {:a => 1, :b => [1,2,3]}
    result = QL.to_triples(data)
    expect(result.length).to be_eql(4)


    data = {:a => 1, :b => [{:c => "a"}, {:c => "b"}]}
    result = QL.to_triples(data)
    expect(result.length).to be_eql(5)
  end

#  no more blank nodes, yeah!
#  it "should generate blank ids for hashes without @ids" do
#    data = {:b => 1, :c => 4.0}
# 
#    result = QL.to_triples(data)
#    a = result.first.first.blank_id
# 
#    result = QL.to_triples(data)
#    b = result.first.first.blank_id
#    
#    expect(a).not_to be_eql(b)
#  end
 
  it "should generate triples for nested hashes" do
    data = {
      :@id => "@id(a)",
      :b   => 1,
      :c   => {
        :@id => "@id(b)",
        :b => 2
      }
    }
 
    result = QL.to_triples(data)
    expect(result.length).to be_eql(3)
    assertion = result.detect{|(a,b,c)| b == ":c"}
    expect(assertion.first).to be_eql("<http://grel.org/ids/id/a>")
    expect(assertion.last).to be_eql("<http://grel.org/ids/id/b>")
  end
 
  it "should generate triples for arrays of hashes" do
    data = [
            {:p => 1},
            {:p => 2},
            {:p => 3}
           ]
 
    result = QL.to_triples(data)
 
    expect(result.length).to be_eql(3)
  end
end
 
 
describe "QL to turtle" do
 
  it "should generate valid turtle" do 
    data = [
            {:p => 1},
            {:p => 2},
            {:p => 3}
           ]
 
    result = QL.to_turtle(data)
 
    expect(result).not_to be_nil
  end
end


describe "QL to query" do
  
  it "should transform a simple hash into a query context" do
    context = QL.to_query({})
 
    expect(context.to_sparql.index("DESCRIBE ?S_mg_0 WHERE { ?S_mg_0 ?P_mg_0 ?O_mg_0 }")).not_to be_nil
 
    context = QL.to_query({a: 1})
 
    expect(context.to_sparql.index("DESCRIBE ?S_mg_0 WHERE { ?S_mg_0 :a \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> }")).not_to be_nil
 
    context = QL.to_query({a: 1, b: {c: 1}})
 
    expect(context.to_sparql.index("DESCRIBE ?S_mg_0 ?S_mg_1 WHERE { ?S_mg_1 :c \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> . ?S_mg_0 :a \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> . ?S_mg_0 :b ?S_mg_1 }")).not_to be_nil
  end
 
  it "should support to query for unknown properties" do
    context = QL.to_query({:a => :_, :_x => 1})
    expect(context.to_sparql.index("DESCRIBE ?S_mg_0 WHERE { ?S_mg_0 :a ?X__1 . ?S_mg_0 ?X_x_2 \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> }")).not_to be_nil
  end
 
  it "should support filters for values" do
    context = QL.to_query({:a => 1, :b => {:$neq => 3}})
    expect(context.to_sparql.index("DESCRIBE ?S_mg_0 WHERE { ?S_mg_0 :a \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> . ?S_mg_0 :b ?P_0_0 . FILTER((?P_0_0 != \"3\"^^<http://www.w3.org/2001/XMLSchema#integer>))")).not_to be_nil
  end
 
  it "should support inverse properties" do
    context = QL.to_query({:a => 1, :$inv_c => {}})
    expect(context.to_sparql.index("DESCRIBE ?S_mg_0 WHERE { ?S_mg_1 ?P_mg_1 ?O_mg_1 . ?S_mg_0 :a \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> . ?S_mg_1 :c ?S_mg_0 }")).not_to be_nil
  end

  it "should support arrays of && conditions" do
    context = QL.to_query({:a => 1, :c => {:$and => [{:$lt => 5}, {:$not => {:$eq => 2}}]}})
    expect(context.to_sparql.index("DESCRIBE ?S_mg_0 WHERE { ?S_mg_0 :a \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> . ?S_mg_0 :c ?P_0_0 . FILTER(((?P_0_0 < \"5\"^^<http://www.w3.org/2001/XMLSchema#integer>)&&!((?P_0_0 = \"2\"^^<http://www.w3.org/2001/XMLSchema#integer>)))) }")).not_to be_nil
  end

  it "should support arrays of || conditions" do
    context = QL.to_query({:a => 1, :c => {:$or => [{:$lt => 5}, {:$not => {:$eq => 2}}]}})
    expect(context.to_sparql.index("DESCRIBE ?S_mg_0 WHERE { ?S_mg_0 :a \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> . ?S_mg_0 :c ?P_0_0 . FILTER(((?P_0_0 < \"5\"^^<http://www.w3.org/2001/XMLSchema#integer>)||!((?P_0_0 = \"2\"^^<http://www.w3.org/2001/XMLSchema#integer>)))) }")).not_to be_nil
  end

  it "should support optional parts in the pattern" do
    context = QL.to_query({:a => 1, :b => 2, :$optional => {:c => 3, :d => 4}})

    expect(context.to_sparql.index("DESCRIBE ?S_mg_0 WHERE { ?S_mg_0 :a \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> . ?S_mg_0 :b \"2\"^^<http://www.w3.org/2001/XMLSchema#integer> OPTIONAL { ?S_mg_0 :c \"3\"^^<http://www.w3.org/2001/XMLSchema#integer> . ?S_mg_0 :d \"4\"^^<http://www.w3.org/2001/XMLSchema#integer> } }")).not_to be_nil

    context = QL.to_query(:a => 1, :b => 2, :$optional => {:f => {:g => 1} })
    expect(context.to_sparql.index("DESCRIBE ?S_mg_0 ?S_mg_2 WHERE { ?S_mg_0 :a \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> . ?S_mg_0 :b \"2\"^^<http://www.w3.org/2001/XMLSchema#integer> OPTIONAL { ?S_mg_2 :g \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> . ?S_mg_0 :f ?S_mg_2 } }")).not_to be_nil

    context = QL.to_query(:a => 1, :$optional => [{:f => 3}, {:g => 4}])
    expect(context.to_sparql.index("DESCRIBE ?S_mg_0 WHERE { ?S_mg_0 :a \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> OPTIONAL { ?S_mg_0 :f \"3\"^^<http://www.w3.org/2001/XMLSchema#integer> } OPTIONAL { ?S_mg_0 :g \"4\"^^<http://www.w3.org/2001/XMLSchema#integer> } }")).not_to be_nil
  end

  it "should support union of queries" do
    context = QL.to_query(:a => 1).union(QL.to_query(:a => 2))
    expect(context.to_sparql.index("DESCRIBE ?S_mg_0 WHERE { { ?S_mg_0 :a \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> } UNION { ?S_mg_0 :a \"2\"^^<http://www.w3.org/2001/XMLSchema#integer> } }")).not_to be_nil
  end

end


 describe "QL from bindings" do
   DB = "testgraph"
  
   before(:each) do
     @conn = stardog("http://localhost:5822/", :user => "admin", :password => "admin")
     @conn.drop_db(DB) if @conn.list_dbs.body["databases"].include?(DB)
   end
  
   after(:each) do
     @conn.drop_db(DB)
     @conn = nil
   end
  
  it "should transform query results back into objects" do
    incoming = {:a => 1, :c => 3, :@id => "@id(hey)", :time => Time.now, :true => true, :nil => nil}
    mg = graph.
      with_db(DB).
      store([incoming])
  
    results = mg.where({:@id => "@id(hey)"}).run
    
    nodes = QL.from_bindings_to_nodes(results, mg.last_query_context)

    expect(nodes[0].delete(:time).class).to be_eql(Time)
    incoming.delete(:time)

    incoming.keys.each do |k|
      expect(incoming[k]).to be_eql(nodes[0][k])
    end
  
    ########
    incoming = {:a => 2, :c =>4}
    mg.store(incoming)
  
    results = mg.where({:a => 2}).run
    nodes = QL.from_bindings_to_nodes(results, mg.last_query_context)
    expect(nodes[0][:@id]).not_to be_nil
    expect(nodes[0][:a]).to be_eql(2)

    ########
    incoming = {:a => 3, :c => {:f => 1}, :@id => "@id(hey2)"}
    mg.store(incoming)
  
    results = mg.where({:a => 3, :c => {}}).run

    nodes = QL.from_bindings_to_nodes(results, mg.last_query_context)
    expect(nodes.first[:c][:f]).to be_eql(1)

    results = mg.where({:_p => 3}).run

    nodes = QL.from_bindings_to_nodes(results, mg.last_query_context)
    nodes.each do |node|
      expect(node.values).to include(3)
    end
  end

  it "should support retrieval of results with filters" do
    incoming = [{:a => 1, :c => 3}, {:a => 2, :c => 4}]
    mg = graph.
      with_db(DB).
      store(incoming)

    results = mg.where({:a => {:$neq => 1}}).run    
    nodes = QL.from_bindings_to_nodes(results, mg.last_query_context)

    expect(nodes.first[:a]).to be_eql(2)
    expect(nodes.first[:c]).to be_eql(4)

    results = mg.where({:a => {:$not => {:$lt => 2}}}).run    
    nodes = QL.from_bindings_to_nodes(results, mg.last_query_context)

    expect(nodes.first[:a]).to be_eql(2)

    results = mg.where({:a => {:$not => {:$not => {:$lt => 2}}}}).run    
    nodes = QL.from_bindings_to_nodes(results, mg.last_query_context)

    expect(nodes.first[:a]).to be_eql(1)
  end

  it "should support like filters" do
    incoming = [{:a => "ola"}, {:a => "hello"}]
    mg = graph.
      with_db(DB).
      store(incoming)

    results = mg.where({:a => {:$like => /h?ola/}}).run    
    nodes = QL.from_bindings_to_nodes(results, mg.last_query_context)

    expect(nodes.first[:a]).to be_eql("ola")
  end

  it "should support inverse properties queries" do
    incoming = [{:a => 1, :b => {:c => 2}}]

    mg = graph.
      with_db(DB).
      store(incoming)

    results = mg.where({:$inv_b => {:a => 1}}).run    

    nodes = QL.from_bindings_to_nodes(results, mg.last_query_context)
    expect(nodes.first[:c]).to be_eql(2)
  end

  it "should support && and || conditions" do
    incoming = [{:a => 1}, {:a => 2}, {:a =>15}, {:a => 24}]

    mg = graph.
      with_db(DB).
      store(incoming)

    results = mg.where({:a => {:$and => [{:gt => 10}, {:gt => 20}]}}).run    

    nodes = QL.from_bindings_to_nodes(results, mg.last_query_context)
    expect(nodes.first[:a]).to be_eql(24)

    results = mg.where({:a => {:$or => [{:gt => 10}, {:gt => 20}]}}).run    

    nodes = QL.from_bindings_to_nodes(results, mg.last_query_context)
    expect(nodes.length).to be_eql(2)
    expect(nodes.map{|n| n[:a] }.inject(0){|ac,i| ac + i}).to be_eql(39)
  end
  
  it "should handle optional properties" do
    incoming = [{:a => 1, :b => 2, :c => 1}, 
                {:a => 1,          :c => 2}, 
                {:a => 2, :b => 2, :c => 3},
                {:a => 2,          :c => 4},
                {:a => 3, :b => 3, :c => 5}]


    mg = graph.
      with_db(DB).
      store(incoming)

    results = mg.where(:$optional => [{:a => 1},{:b => 2}]).run    
    nodes = QL.from_bindings_to_nodes(results, mg.last_query_context)
    expect(nodes.length).to be_eql(5)

    results = mg.where(:a =>1, :b => 2).run    
    nodes = QL.from_bindings_to_nodes(results, mg.last_query_context)
    expect(nodes.length).to be_eql(1)
  end

  it "should handle arrays of properties" do
    incoming = [{:a =>1, :b => [{:c => 1},{:c => 2}]}]
    mg = graph.
      with_db(DB).
      store(incoming)
 
    results = mg.where(:$optional => [{:a => 1},{:b => 2}]).run    
    nodes = QL.from_bindings_to_nodes(results, mg.last_query_context)
    expect(nodes.detect{|n| n[:b] }[:b].length).to be_eql(2)
    nodes.detect{|n| n[:b] }[:b].each do |n|
      expect(n[:c]).not_to be_nil
    end
    #expect(nodes.length).to be_eql(5)
  end

  it "should handle union patterns in queries" do
    incoming = [{:a =>1},{:a => 3},{:a => 2}]

    mg = graph.
      with_db(DB).
      store(incoming)

    results = mg.where(:a => 1).union(:a => 2).run
    puts results.inspect
    nodes = QL.from_bindings_to_nodes(results, mg.last_query_context)
    puts nodes.inspect
    nodes.each do |n|
      expect(n[:a] == 1 || n[:a] == 2).to be_true
    end

    results = mg.where({}).run
    nodes = QL.from_bindings_to_nodes(results, mg.last_query_context)
    expect(nodes.length).to be_eql(3)
  end

  it "should handle relations between nodes" do
    mg = graph.
      with_db(DB).
      store(:name    => 'Abhinay',
            :surname => 'Mehta',
            :type    => 'Hacker',
            :@id     => 'abs').

      store(:name    => 'Tom',
            :surname => 'Hall',
            :type    => 'Hacker',
            :@id     => 'thattommyhall').

      store(:name       => 'India',
            :type       => 'Country',
            :population => 1200,
            :capital    => 'New Delhi',
            :@id        => 'in').

      store(:name       => 'United Kingdom',
            :type       => 'Country',
            :population => 62,
            :capital    => 'London',
            :@id        => 'uk').

      store(:@id     => 'abs',
            :citizen => '@id(in)').

      store(:@id     => 'thattommyhall',
            :citizen => '@id(uk)')


    nodes = mg.where(:type => 'Hacker').all
    mapping = nodes.inject({}){|a,i| a[i[:name]] = i[:citizen]; a}
    expect(nodes.length).to be_eql(2)
    expect(mapping["Abhinay"]).to be_eql("@id(in)")
    expect(mapping["Tom"]).to be_eql("@id(uk)")


    nodes= mg.where(:type => 'Hacker', :citizen => {}).all
    expect(nodes.length).to be_eql(2)
    mapping = nodes.inject({}){|a,i| a[i[:name]] = i[:citizen]; a}
    expect(mapping["Abhinay"][:name]).to be_eql("India")
    expect(mapping["Tom"][:name]).to be_eql("United Kingdom")


    nodes = mg.where(:type => 'Hacker', :citizen => {:name => "India"}).all
    expect(nodes.length).to be_eql(1)
    mapping = nodes.inject({}){|a,i| a[i[:name]] = i[:citizen]; a}
    expect(mapping["Abhinay"][:name]).to be_eql("India")
    expect(mapping["Tom"]).to be_nil

    nodes = mg.where(:type => 'Country', :$inv_citizen => {:name => "Abhinay"}).all
    expect(nodes.length).to be_eql(1)
    expect(nodes.first[:name]).to be_eql("India")

    nodes = mg.where(:type => 'Country', :population => {:$gt => 100}).all
    expect(nodes.length).to be_eql(1)
    expect(nodes.first[:name]).to be_eql("India")

    nodes = mg.where(:type => 'Country', :population => {:$lt => 100}).all
    expect(nodes.length).to be_eql(1)
    expect(nodes.first[:name]).to be_eql("United Kingdom")

    nodes = mg.where(:type => 'Country', :population => {:$or => [{:$lt => 100},{:$gt => 1000}]}).all
    expect(nodes.length).to be_eql(2)
    
    nodes = mg.where(:type => 'Country').union(:type => 'Hacker').all
    mapping = nodes.inject("Country" => 0, "Hacker" => 0){|a,i| a[i[:type]] += 1; a}
    expect(mapping["Country"]).to be_eql(2)
    expect(mapping["Hacker"]).to be_eql(2)

    # Abs is now an UK citizen
    mg.store(:@id     => 'abs',
             :citizen => '@id(uk)')


    #results = @conn.query(DB,'PREFIX : <http://grel.org/vocabulary#> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> PREFIX rdfs: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> PREFIX xsd: <http://www.w3.org/2001/XMLSchema#> PREFIX fn: <http://www.w3.org/2005/xpath-functions#> DESCRIBE ?S_mg_0 ?S_mg_1 WHERE { ?S_mg_0 :name "Abhinay" . ?S_mg_0 :citizen ?S_mg_1 }', :describe => true)

    # results = @conn.query(DB,'PREFIX : <http://grel.org/vocabulary#> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> PREFIX rdfs: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> PREFIX xsd: <http://www.w3.org/2001/XMLSchema#> PREFIX fn: <http://www.w3.org/2005/xpath-functions#> SELECT distinct ?S_mg_1 ?S_mg_0 WHERE { ?S_mg_0 :name "Abhinay" . ?S_mg_0 :citizen ?S_mg_1 }')


    #    results = @conn.query(DB,'PREFIX : <http://grel.org/vocabulary#> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> PREFIX rdfs: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> PREFIX xsd: <http://www.w3.org/2001/XMLSchema#> PREFIX fn: <http://www.w3.org/2005/xpath-functions#> SELECT ?S ?P ?O WHERE { ?S ?P ?O }')

    #puts results.inspect
    
    nodes = mg.where(:name => 'Abhinay', :citizen => {}).all
    expect(nodes.length).to be_eql(1)
    abs = nodes.detect{|n| n[:name] == 'Abhinay' }
    expect(abs[:citizen].length).to be_eql(2)


    # results = mg.where(:type => 'Hacker').limit(4).offset(0).run
    # nodes = QL.from_bindings_to_nodes(results, mg.last_query_context)
    # puts "-- A"
    # puts nodes
    #  
    # nodes = mg.where(:type => 'Hacker').limit(4).offset(4).all
    # puts "-- B"
    # puts nodes
  end
end

#  /posts
#   
#   
#  select y p o 
#  { x a Post
#    x p o }
#   
#  { id : x
#    p1  : o1
#    p2  : o2 
#    ...
#    pn : on }
#   
#  { name: Ana, age: 33 }
