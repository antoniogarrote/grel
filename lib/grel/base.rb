module GRel

  # Base class for the graph of ruby objects stored in Stardog
  class Base

    include Stardog

    attr_accessor :connection, :last_query_context
    attr_reader :db_name, :schema_graph

    # Builds the graph with the provided connection string and options.
    # - endpoint : connection string. localhost:5822 by default.
    # - options: hash of options:
    #    + user : user name for authentication
    #    + password : password for authentication
    #    + validate : should validate integrity constraints
    #    + db : name of the db to use
    # Returns the newly built graph object.
    def initialize(endpoint, options) 
      @options = options
      @endpoint = endpoint
      @connection = stardog(endpoint,options)
      @validations = options[:validate] || false
      @dbs = @connection.list_dbs.body["databases"]
      @reasoning = false
      self
    end

    # Turns on reasoning in queries.
    # The type of reasoning must be provided as an argument.
    # By default 'QL' is provided.
    # Reasoning will remain turned on for all operations in the graph until it is
    # explicitely turned off with the *without_reasoning* message.
    # It returns the current graph object.
    def with_reasoning(reasoning="QL")
      @reasoning = true
      @connection = stardog(@endpoint,@options.merge(:reasoning => reasoning))
      @connection.offline_db(@db_name)
      @connection.set_db_options(@db_name, "icv.reasoning.type" => reasoning)
      @connection.online_db(@db_name, 'WAIT')
      self
    end

    # Turns off reasoning in queries.
    # Reasoning will remain turned off until enabled again with the *with_reasoning* message.
    # It returns the current graph object.
    def without_reasoning
      @reasoning = false
      @connection = stardog(@endpoint,@options)
      self
    end

    # Sets the current Stardog database this graph is connected to.
    # It accepts the name of the database as an argument.
    # If an optional block is provided, operations in the block
    # will be executed in the provided database and the old database 
    # will be restored afterwards.
    # It returns the current graph object.
    def with_db(db_name)
      ensure_db(db_name) do
        old_db_name = @db_name
        @db_name = db_name
        @schema_graph = "#{db_name}:schema"
        if block_given?
          yield
          @db_name = old_db_name
        end
      end
      self
    end


    # Stores a graph of ruby objects encoded as a nested collection of hashes in a database.
    # Arguments:
    #  - data : objects to be stored.
    #  - db_name : optional database where this objects will be stored.
    # It returns the current graph object.
    # if a validation fails, a ValidationError will be raised.
    def store(data, db_name=nil)
      if(db_name)
        with_db(db_name) do
          store(data)
        end
      else
        GRel::Debugger.debug "STORING"
        GRel::Debugger.debug QL.to_turtle(data)
        GRel::Debugger.debug "IN"
        GRel::Debugger.debug @db_name
        @connection.add(@db_name, QL.to_turtle(data), nil, "text/turtle")
      end
      self
    rescue Stardog::ICVException => ex
      raise ValidationError.new("Error storing objects in the graph. A Validation has failed.", ex)
    end


    # Builds a query for the graph of objects.
    # The query is expressed as a pattern of nested hashes that will be matched agains the data
    # stored in the graph.
    # Wildcard values and filters can also be added to the query.
    # It returns the current graph object.
    def where(query)
      @last_query_context = QL::QueryContext.new(self)
      @last_query_context.register_query(query)
      @last_query_context = QL.to_query(query, @last_query_context)
      self
    end

    # Adds another pattern to the current query being defined.
    # It accepts a query pattern hash identical to the one accepted by the
    # *where* method.
    # It returns the current graph object.
    def union(query)
      union_context = QL::QueryContext.new(self)
      union_context.register_query(query)
      union_context =  QL.to_query(query, union_context)

      @last_query_context.union(union_context)
      self
    end

    # Limits how many triples will be returned from the server.
    # The limit refers to triples, not nodes in the graph.
    # It returns the current graph object.
    def limit(limit)
      @last_query_context.limit = limit
      self
    end

    # Skip the first offset number of triples in the response returned from
    # the server.
    # The offset refers to triples, not nodes in the graph.
    # It returns the current graph object.
    def offset(offset)
      @last_query_context.offset = offset
      self
    end
    
#    def order(order)
#      @last_query_context.order = order
#      self
#    end

    # Exceutes the current query returning the raw response from the server
    # It returns the a list of JSON-LD linked objects.
    def run
      @last_query_context.run
    end

    # Defines schema meta data that will be used in the processing of queries
    # if reasoning is activated.
    # It accepts a list of definitions as an argument.
    # Valid definitions are:
    #  - @subclass definitions
    #  - @subproperty definitions
    #  - @domain definitions
    #  - @range defintions
    #  - @cardinality definitions
    # It returns the current graph object.
    def define(*args)
      unless(args.length == 3 && !args.first.is_a?(Array))
        args = args.inject([]) {|a,i| a += i; a }
      end

      args = parse_schema_axioms(args)

      triples = QL.to_turtle(args, true)
      GRel::Debugger.debug "STORING IN SCHEMA #{@schema_graph}"
      GRel::Debugger.debug triples
      GRel::Debugger.debug "IN"
      GRel::Debugger.debug @db_name
      @connection.add(@db_name, triples, @schema_graph, "text/turtle")
      self
    end

    # Drop definition statements from the schema meta data.
    # It accepts statements equivalent to the ones provided to the *define* method.
    # It returns the current graph object.
    def retract_definition(*args)
      unless(args.length == 3 && !args.first.is_a?(Array))
        args = args.inject([]) {|a,i| a += i }
      end

      args = parse_schema_axioms(args)

      triples = QL.to_turtle(args, true)
      GRel::Debugger.debug "REMOVING FROM SCHEMA #{@schema_graph}"
      GRel::Debugger.debug triples
      GRel::Debugger.debug "IN"
      GRel::Debugger.debug @db_name
      @connection.remove(@db_name, triples, @schema_graph, "text/turtle")
      self
    end

    # Adds a validation statement to the graph.
    # Validations will be checked in every *store* operation if validations are activated.
    # A ValidationError exception will be raised if a validation fails.
    # It accepts a list of definitions as an argument.
    # Valid definitions are:
    #  - @subclass definitions
    #  - @subproperty definitions
    #  - @domain definitions
    #  - @range defintions
    #  - @cardinality definitions
    # It returns the current graph object.
    def validate(*args)
      unless(args.detect{|e| !e.is_a?(Array)})
        args = args.inject([]) {|a,i| a += i; a }
      end

      args = parse_schema_axioms(args)
      additional_triples = []      
      found = args.each_slice(3).detect{|(s,p,o)|  p == :@range && o.is_a?(Class)}
      if(found)
        additional_triples += [found.first, :@type, :"<http://www.w3.org/2002/07/owl#DatatypeProperty>"]
      end


      triples = QL.to_turtle(args + additional_triples, true)
      GRel::Debugger.debug "STORING IN VALIDATIONS #{@schema_graph}"
      GRel::Debugger.debug triples
      GRel::Debugger.debug "IN"
      GRel::Debugger.debug @db_name
      @connection.add_icv(@db_name, triples, "text/turtle")
      self
    end

    # Removes a validation from the graph.
    # It accepts a list of validation statements equivalent to the ones accepted by the *validate* method.
    # It returns the current graph object.
    def retract_validation(*args)
      unless(args.length == 3 && !args.first.is_a?(Array))
        args = args.inject([]) {|a,i| a += i }
      end
      triples = QL.to_turtle(args, true)
      GRel::Debugger.debug "REMOVING FROM SCHEMA #{@schema_graph}"
      GRel::Debugger.debug triples
      GRel::Debugger.debug "IN"
      GRel::Debugger.debug @db_name
      @connection.remove_icv(@db_name, triples, "text/turtle")
      self
    end

    # Removes data from the graph of objects.
    # If no arguments are provided, the nodes returned from the last executed query will
    # be removed from the graph.
    # If a graph of objects are provided, the equivalent statements will be removed instead.
    # It returns the current graph object.
    def remove(data = nil, options = {})
      if data
        GRel::Debugger.debug "REMMOVING"
        GRel::Debugger.debug QL.to_turtle(data)
        GRel::Debugger.debug "IN"
        GRel::Debugger.debug @db_name
        @connection.remove(@db_name, QL.to_turtle(data), nil, "text/turtle")
      else
        args = {:describe => true}
        args = {:accept => "application/rdf+xml"}

        sparql = @last_query_context.to_sparql_describe
        triples = @connection.query(@db_name,sparql, args).body

        @connection.remove(@db_name, triples, nil, "application/rdf+xml")
      end
      self
    end

    # Executes the current defined query and returns a list of matching noes from the graph.
    # Nodes will be correctly linked in the returned list.
    # if the option *:unlinked* is provided with true value, only the top level nodes that has not incoming links
    # will be returned.
    def all(options = {})
      unlinked = options[:unlinked] || false

      results = run
      nodes = QL.from_bindings_to_nodes(results, @last_query_context, :unlinked => unlinked)
      nodes
      #sets = @last_query_context.query_keys
      #nodes.select do |node|
      #  valid = false
      #  c = 0
      #  while(!valid && c<sets.length)
      #    sets_keys, sets_query = sets[c]
      #    valid = (sets_keys.empty?) || sets_keys.inject(true) do |ac,k|
      #      value = nil
      #      if (sets_query[k].is_a?(Hash) || (sets_query[k].is_a?(Symbol)))
      #        value = ac && node[k]
      #      end
      #      if(value.nil? && @reasoning == true)
      #        value = ac && node.values.include?(sets_query[k])
      #      end
      #      if (value.nil? && sets_query[k].is_a?(String) && sets_query[k].index("@id("))
      #        value = ac && node[k]
      #      end
      #      if(value.nil?)
      #         ac && node[k] == sets_query[k]
      #      else
      #        value
      #      end
      #    end
      #    c += 1
      #  end
      #  valid
      #end
    end

    # Executes the current defined query returning a list of hashes where pairs key,value
    # are bound to the tuple variables in the query hash and retrived values for those variables.
    def tuples
      results = run_tuples(@last_query_context.to_sparql_select)
      results["results"]["bindings"].map do |h|
        h.keys.each do |k|
          h[k.to_sym] = QL.from_tuple_binding(h[k])
          h.delete(k)
        end
        h
      end
    end

    # Returns only the first node from the list of retrieved nodes in an all query.
    def first(options = {})
      all(options).first
    end

    # Executes a raw SPARQL DESCRIBE query for the current defined query.
    # It returns the results of the query without any other processing.
    def query(query, options = {})
      GRel::Debugger.debug "QUERYING DESCRIBE..."
      GRel::Debugger.debug query
      GRel::Debugger.debug "** LIMIT #{@last_query_context.limit}" if @last_query_context.limit
      GRel::Debugger.debug "** OFFSET #{@last_query_context.offset}" if @last_query_context.offset
      GRel::Debugger.debug "----------------------"
      args = {:describe => true}
      args[:accept] = options[:accept] if options[:accept]
      args[:offset] = @last_query_context.offset if @last_query_context.offset
      args[:limit] = @last_query_context.limit if @last_query_context.limit
      @connection.query(@db_name,query, args).body
    end

    # Executes a raw SPARQL SELECT query for the current defined query.
    # It returns the results of the query without any other processing.
    def run_tuples(query, options = {})
      GRel::Debugger.debug "QUERYING SELECT..."
      GRel::Debugger.debug query
      GRel::Debugger.debug "** LIMIT #{@last_query_context.limit}" if @last_query_context.limit
      GRel::Debugger.debug "** OFFSET #{@last_query_context.offset}" if @last_query_context.offset
      GRel::Debugger.debug "----------------------"
      args = {}
      args[:accept] = options[:accept] if options[:accept]
      args[:offset] = @last_query_context.offset if @last_query_context.offset
      args[:limit] = @last_query_context.limit if @last_query_context.limit
      @connection.query(@db_name,query, args).body
    end

    # It turns on validations for any insertion in the graph.
    # Validations will remain turned on until they are disabled using the *without_validations* message.
    # It returns the current graph.
    def with_validations(state = true)
      @validations = state
      @connection.offline_db(@db_name)
      @connection.set_db_options(@db_name, "icv.enabled" => @validations)
      @connection.online_db(@db_name, 'WAIT')

      self
    end

    # It disables validations for any insertion in the graph.
    # Validations will remain turned off until they are enabled again using the *with_validations* message.
    # It returns the current graph.
    def without_validations
      with_validations(false)
    end

    private

    def ensure_db(db_name)
      unless(@dbs.include?(db_name))
        @connection.create_db(db_name, :options => { "reasoning.schema.graphs" => "#{db_name}:schema" })
        @connection.with_validations(@validations) if @validations == true
        @dbs << db_name
      end
      yield if block_given?
    end

    def parse_schema_axioms(args)
      unfolded = []
      args.each_slice(3) do |(s,p,o)|
        if(p == :@range && o.is_a?(Class))
          unfolded += [s, :@type, :"<http://www.w3.org/2002/07/owl#DatatypeProperty>"]
        elsif(p == :@range)
          unfolded += [s, :@type, :"<http://www.w3.org/2002/07/owl#ObjectProperty>"]
        end

        if(p == :@some)
          restriction = BlankId.new
          unfolded += [s, :@subclass, restriction]
          unfolded += [restriction, :@type, :"<http://www.w3.org/2002/07/owl#Restriction>"]
          unfolded += [restriction, :"<http://www.w3.org/2002/07/owl#onProperty>", o.first]
          unfolded += [restriction, :@some,o.last]
        elsif(p == :@all)
          restriction = BlankId.new
          unfolded += [s, :@subclass, restriction]
          unfolded += [restriction, :@type, :"<http://www.w3.org/2002/07/owl#Restriction>"]
          unfolded += [restriction, :"<http://www.w3.org/2002/07/owl#onProperty>", o.first]
          unfolded += [restriction, :@all,o.last]
        elsif(p == :@cardinality)
          property = o[:property]
          klass    = o[:class]
          exact    = o[:exact]
          min      = o[:min]
          max      = o[:max]
          if klass.nil?
            if(exact)
              restriction = BlankId.new
              unfolded += [s, :@subclass, restriction]
              unfolded += [restriction, :@type, :"<http://www.w3.org/2002/07/owl#Restriction>"]
              unfolded += [restriction, :"<http://www.w3.org/2002/07/owl#onProperty>", property]
              unfolded += [restriction, :"<http://www.w3.org/2002/07/owl#cardinality>", NonNegativeInteger.new(exact)]
            else
              if(min)
                restriction = BlankId.new
                unfolded += [s, :@subclass, restriction]
                unfolded += [restriction, :@type, :"<http://www.w3.org/2002/07/owl#Restriction>"]
                unfolded += [restriction, :"<http://www.w3.org/2002/07/owl#onProperty>", property]
                unfolded += [restriction, :"<http://www.w3.org/2002/07/owl#minCardinality>", NonNegativeInteger.new(min)] 
              end
              if(max)
                restriction = BlankId.new
                unfolded += [s, :@subclass, restriction]
                unfolded += [restriction, :@type, :"<http://www.w3.org/2002/07/owl#Restriction>"]
                unfolded += [restriction, :"<http://www.w3.org/2002/07/owl#onProperty>", property]
                unfolded += [restriction, :"<http://www.w3.org/2002/07/owl#maxCardinality>", NonNegativeInteger.new(max)]
              end
            end
          else
            if(exact)
              restriction = BlankId.new
              unfolded += [s, :@subclass, restriction]
              unfolded += [restriction, :@type, :"<http://www.w3.org/2002/07/owl#Restriction>"]
              unfolded += [restriction, :"<http://www.w3.org/2002/07/owl#onProperty>", property]
              unfolded += [restriction, :"<http://www.w3.org/2002/07/owl#qualifiedCardinality>", NonNegativeInteger.new(exact)]
              unfolded += [restriction, :"<http://www.w3.org/2002/07/owl#onClass>", klass] 
            else
              if(min)
                restriction = BlankId.new
                unfolded += [s, :@subclass, restriction]
                unfolded += [restriction, :@type, :"<http://www.w3.org/2002/07/owl#Restriction>"]
                unfolded += [restriction, :"<http://www.w3.org/2002/07/owl#onProperty>", property]
                unfolded += [restriction, :"<http://www.w3.org/2002/07/owl#minQualifiedCardinality>", NonNegativeInteger.new(min)] 
                unfolded += [restriction, :"<http://www.w3.org/2002/07/owl#onClass>", klass] 
              end
              if(max)
                restriction = BlankId.new
                unfolded += [s, :@subclass, restriction]
                unfolded += [restriction, :@type, :"<http://www.w3.org/2002/07/owl#Restriction>"]
                unfolded += [restriction, :"<http://www.w3.org/2002/07/owl#onProperty>", property]
                unfolded += [restriction, :"<http://www.w3.org/2002/07/owl#maxQualifiedCardinality>", NonNegativeInteger.new(max)] 
                unfolded += [restriction, :"<http://www.w3.org/2002/07/owl#onClass>", klass] 
              end
            end
          end
        else
          unfolded += [s,p,o]
        end
      end

      unfolded
    end

  end # end of Base class
end # end of Grel module
