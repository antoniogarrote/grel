module GRel

  class Base

    include Stardog

    attr_accessor :connection, :last_query_context
    attr_reader :db_name, :schema_graph

    def initialize(endpoint, options) 
      @options = options
      @endpoint = endpoint
      @connection = stardog(endpoint,options)
      @validations = options[:validate] || false
      @dbs = @connection.list_dbs.body["databases"]
      @reasoning = false
      self
    end

    def with_reasoning(reasoning="QL")
      @reasoning = true
      @connection = stardog(@endpoint,@options.merge(:reasoning => reasoning))
      @connection.offline_db(@db_name)
      @connection.set_db_options(@db_name, "icv.reasoning.type" => reasoning)
      @connection.online_db(@db_name, 'WAIT')
      self
    end

    def without_reasoning
      @reasoning = false
      @connection = stardog(@endpoint,@options)
      self
    end

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


    def where(query)
      @last_query_context = QL::QueryContext.new(self)
      @last_query_context.register_query(query)
      @last_query_context = QL.to_query(query, @last_query_context)
      self
    end

    def union(query)
      union_context = QL::QueryContext.new(self)
      union_context.register_query(query)
      union_context =  QL.to_query(query, union_context)

      @last_query_context.union(union_context)
      self
    end

    def limit(limit)
      @last_query_context.limit = limit
      self
    end

    def offset(offset)
      @last_query_context.offset = offset
      self
    end

    def order(order)
      @last_query_context.order = order
      self
    end

    def run
      @last_query_context.run
    end

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

    def retract_definition(*args)
      unless(args.length == 3 && !args.first.is_a?(Array))
        args = args.inject([]) {|a,i| a += i }
      end
      additional_triples = []

      triples = QL.to_turtle(args + additional_triples, true)
      GRel::Debugger.debug "REMOVING FROM SCHEMA #{@schema_graph}"
      GRel::Debugger.debug triples
      GRel::Debugger.debug "IN"
      GRel::Debugger.debug @db_name
      @connection.remove(@db_name, triples, @schema_graph, "text/turtle")
      self
    end

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

    def first(options = {})
      all(options).first
    end

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

    def with_validations(state = true)
      @validations = state
      @connection.offline_db(@db_name)
      @connection.set_db_options(@db_name, "icv.enabled" => @validations)
      @connection.online_db(@db_name, 'WAIT')

      self
    end

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
