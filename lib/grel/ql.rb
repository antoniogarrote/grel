module GRel
  module QL

    def self.to_rules(obj,context={})
      if(obj.is_a?(String) && obj[0..0] == "?")
        var_name = obj[1..-1]
        axiom = "<swrl:Variable rdf:about=\"http://www.w3.org/2003/11/swrl##{obj[1..-1]}\"></swrl:Variable>"
        context[var_name] = axiom
        "http://www.w3.org/2003/11/swrl##{obj[1..-1]}"
      elsif(obj.is_a?(Symbol))
        "##{obj}"
      elsif(obj.is_a?(Array))
        if(obj.first.is_a?(Symbol))
          elem = obj.first
          if(elem.to_s[0] == "$")
            pred = case elem
                   when :$lt
                     "<swrl:BuiltinAtom><swrl:builtin rdf:resource=\"http://www.w3.org/2003/11/swrlb#lessThan\"/><swrl:arguments ><rdf:List>ARGS</rdf:List></swrl:arguments></swrl:BuiltinAtom>"
                   when :$gt
                     "<swrl:BuiltinAtom><swrl:builtin rdf:resource=\"http://www.w3.org/2003/11/swrlb#greaterThan\"/><swrl:arguments ><rdf:List>ARGS</rdf:List></swrl:arguments></swrl:BuiltinAtom>"
                   when :$lte
                     "<swrl:BuiltinAtom><swrl:builtin rdf:resource=\"http://www.w3.org/2003/11/swrlb#lessThanOrEqual\"/><swrl:arguments ><rdf:List>ARGS</rdf:List></swrl:arguments></swrl:BuiltinAtom>"              
                   when :$gte
                     "<swrl:BuiltinAtom><swrl:builtin rdf:resource=\"http://www.w3.org/2003/11/swrlb#greaterThanOrEqual\"/><swrl:arguments ><rdf:List>ARGS</rdf:List></swrl:arguments></swrl:BuiltinAtom>"              
                   when :$eq
                     "<swrl:BuiltinAtom><swrl:builtin rdf:resource=\"http://www.w3.org/2003/11/swrlb#equal\"/><swrl:arguments ><rdf:List>ARGS</rdf:List></swrl:arguments></swrl:BuiltinAtom>"              
                   when :$neq
                     "<swrl:BuiltinAtom><swrl:builtin rdf:resource=\"http://www.w3.org/2003/11/swrlb#notEqual\"/><swrl:arguments ><rdf:List>ARGS</rdf:List></swrl:arguments></swrl:BuiltinAtom>"              
                   end

            args = []
            
            if(obj[1].is_a?(String) && obj[1][0] == "?")
              args << "<rdf:first rdf:resource=\"#{GRel::QL.to_rules(obj[1], context)}\" />"
            else
              args << GRel::QL.to_rules(obj[1],context).gsub("swrl:argumentn","rdf:first")
            end

            if(obj[2].is_a?(String) && obj[2][0] == "?")
              args << "<rdf:rest><rdf:List><rdf:first rdf:resource=\"#{GRel::QL.to_rules(obj[2],context)}\"/><rdf:rest rdf:resource=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#nil\"/></rdf:List></rdf:rest>"
            else
              args << "<rdf:rest><rdf:List>#{GRel::QL.to_rules(obj[2],context).gsub("swrl:argumentn","rdf:first")}<rdf:rest rdf:resource=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#nil\"/></rdf:List></rdf:rest>"
            end

            pred.gsub(">ARGS<",">#{args.join}<")
          elsif(elem.to_s.capitalize == elem.to_s)  # is a class atom
            pred = "<swrl:classAtom><swrl:classPredicate rdf:resource=\"#{GRel::QL.to_rules(elem,context)}\" />"
            pred += "<swrl:argument1 rdf:resource=\"#{GRel::QL.to_rules(obj[1],context)}\" />"
            pred + "</swrl:classAtom>"
          elsif(elem.to_s.capitalize != elem.to_s) # is a property axiom
            is_data = obj[1..-1].detect{|e| !e.is_a?(String) || ( e.is_a?(String) && e[0] != "?" && e.index("@id") != 0 ) }
            if(is_data) # data property
              pred = "<swrl:DatavaluedPropertyAtom>"
              pred += "<swrl:propertyPredicate rdf:resource=\"http://grel.org/vocabulary#{GRel::QL.to_rules(elem,context)}\"/>"
              if(obj[1].is_a?(String) && (obj[1][0] == "?" || obj[1].index("@id")==0))
                pred += "<swrl:argument1 rdf:resource=\"#{GRel::QL.to_rules(obj[1], context)}\" />"
              else
                pred +=  GRel::QL.to_rules(obj[1], context).gsub("argumentn","argument1")
              end
              if(obj[2].is_a?(String) && (obj[2][0] == "?" || obj[2].index("@id")==0))
                pred += "<swrl:argument1 rdf:resource=\"#{GRel::QL.to_rules(obj[2], context)}\" />"
              else
                pred +=  GRel::QL.to_rules(obj[2], context).gsub("argumentn","argument2")               
              end
              pred + "</swrl:DatavaluedPropertyAtom>"
            else # individual property
              pred = "<swrl:IndividualPropertyAtom>"
              pred += "<swrl:propertyPredicate rdf:resource=\"http://grel.org/vocabulary#{GRel::QL.to_rules(elem,context)}\"/>"
              pred += "<swrl:argument1 rdf:resource=\"#{GRel::QL.to_rules(obj[1],context)}\" />"
              pred += "<swrl:argument2 rdf:resource=\"#{GRel::QL.to_rules(obj[2],context)}\" />"
              pred + "</swrl:IndividualPropertyAtom>"
              is_object = obj[1..-1].detect{|e| !e.is_a?(String) && ( e.is_a?(String) && e.index("@id") != 0 ) }
              unless(is_object)               
                pred = "<swrl:DatavaluedPropertyAtom>"
                pred += "<swrl:propertyPredicate rdf:resource=\"http://grel.org/vocabulary#{GRel::QL.to_rules(elem,context)}\"/>"
                pred += "<swrl:argument1 rdf:resource=\"#{GRel::QL.to_rules(obj[1],context)}\" />"
                pred += "<swrl:argument2 rdf:resource=\"#{GRel::QL.to_rules(obj[2],context)}\" />"
                pred + "</swrl:DatavaluedPropertyAtom>"
              end
            end
          else
            raise Exception.new("Unkown rule axiom #{obj.inspect}")
          end
        elsif(obj.first.is_a?(Array))
          obj.map{|ax| GRel::QL.to_rules(ax,context)}.join("")
        else
          raise Exception.new("Unkown rule axiom #{obj.inspect}")
        end
      elsif(obj.is_a?(String) && obj.index("@id")==0) # is a IRI
        GRel::QL::to_id(obj).gsub("<","").gsub(">","")
      elsif(obj.is_a?(String)) # is a IRI
        "<swrl:argumentn rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">#{obj}</swrl:argumentn>"
      elsif(obj == true || obj == false)
        "<swrl:argumentn rdf:datatype=\"http://www.w3.org/2001/XMLSchema#boolean\">#{obj}</swrl:argumentn>"
      elsif(obj.is_a?(Float))
        "<swrl:argumentn rdf:datatype=\"http://www.w3.org/2001/XMLSchema#float\">#{obj}</swrl:argumentn>"
      elsif(obj.is_a?(Numeric))
        "<swrl:argumentn rdf:datatype=\"http://www.w3.org/2001/XMLSchema#integer\">#{obj}</swrl:argumentn>"
      elsif(obj.is_a?(Time))
        "<swrl:argumentn rdf:datatype=\"http://www.w3.org/2001/XMLSchema#dateTime\">#{obj.iso8601}</swrl:argumentn>"
      elsif(obj.is_a?(Date))
        "<swrl:argumentn rdf:datatype=\"http://www.w3.org/2001/XMLSchema#dateTime\">#{Time.new(obj.to_s).iso8601}</swrl:argumentn>"
      # Building the document here
      elsif(obj.is_a?(Hash))
        rules = obj.map do |(body,head)|
          "<swrl:Imp><swrl:body rdf:parseType=\"Collection\">#{GRel::QL.to_rules(body,context)}</swrl:body ><swrl:head rdf:parseType=\"Collection\">#{GRel::QL.to_rules(head,context)}</swrl:head></swrl:Imp>"
        end.join("")
        doc = "<rdf:RDF xml:base=\"#{GRel::NAMESPACE}\" xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\" xmlns:owl=\"http://www.w3.org/2002/07/owl#\" xmlns:swrl=\"http://www.w3.org/2003/11/swrl#\" xmlns:ruleml=\"http://www.w3.org/2003/11/swrl\">"
        doc += context.values.join("")
        doc += rules
        doc + "</rdf:RDF>"
      else
        raise Exception.new("Unkown rule axiom #{obj.inspect}")        
      end
    end

    def self.unlink_sparql_query(ids)
      conditions = ids.map do |id|
        id = "@id(#{id})" if id && id.is_a?(String) && id.index("@id(").nil?        
        id = QL.to_query(id)
        "(?S = #{id} && isIRI(?O) && ?P != <http://www.w3.org/1999/02/22-rdf-syntax-ns#type>) || ?O = #{id}"
      end
      "SELECT ?S ?P ?O WHERE { ?S ?P ?O . FILTER (#{conditions.join(' || ')}) } "
    end

    def self.to_id(obj)
      if(obj =~ ID_REGEX)
        "<http://grel.org/ids/id/#{URI.encode(ID_REGEX.match(obj)[1])}>"
      else
        "<http://grel.org/ids/#{URI.encode(obj)}>"
      end
    end

    def self.to_turtle(obj, schema=false)
      data = "@prefix : <http://grel.org/vocabulary#> . @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> . "
      data = data + "@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> . " if schema

      data + QL.to_triples(obj).map{|t| t.map(&:to_s).join(" ") }.join(" .\n ") + " ."
    end

    def self.to_triples(obj)
      if(obj.is_a?(BlankId))
        obj.to_s
      elsif(obj.is_a?(Symbol))
        if(obj == :@type)
          "rdf:type"
        elsif(obj == :@subclass)
          "rdfs:subClassOf"
        elsif(obj == :@subproperty)
          "rdfs:subPropertyOf"
        elsif(obj == :@domain)
          "rdfs:domain"
        elsif(obj == :@range)
          "rdfs:range"
        elsif(obj == :@same_as)
          "<http://www.w3.org/2002/07/owl#sameAs>"
        elsif(obj == :@functional)
          "<http://www.w3.org/2002/07/owl#FunctionalProperty>"
        elsif(obj == :"<http://www.w3.org/2002/07/owl#FunctionalProperty>")
          "<http://www.w3.org/2002/07/owl#FunctionalProperty>"
        elsif(obj == :"<http://www.w3.org/2002/07/owl#sameAs>")
          "<http://www.w3.org/2002/07/owl#sameAs>"
        elsif(obj == :"<http://www.w3.org/2002/07/owl#onClass>")
          "<http://www.w3.org/2002/07/owl#onClass>"
        elsif(obj == :"<http://www.w3.org/2002/07/owl#qualifiedCardinality>")
          "<http://www.w3.org/2002/07/owl#qualifiedCardinality>"
        elsif(obj == :"<http://www.w3.org/2002/07/owl#minCardinality>")
          "<http://www.w3.org/2002/07/owl#minCardinality>"
        elsif(obj == :"<http://www.w3.org/2002/07/owl#maxCardinality>")
          "<http://www.w3.org/2002/07/owl#maxCardinality>"
        elsif(obj == :"<http://www.w3.org/2002/07/owl#minQualifiedCardinality>")
          "<http://www.w3.org/2002/07/owl#minQualifiedCardinality>"
        elsif(obj == :"<http://www.w3.org/2002/07/owl#maxQualifiedCardinality>")
          "<http://www.w3.org/2002/07/owl#maxQualifiedCardinality>"
        elsif(obj == :"<http://www.w3.org/2002/07/owl#cardinality>")
          "<http://www.w3.org/2002/07/owl#cardinality>"
        elsif(obj == :@some)
          "<http://www.w3.org/2002/07/owl#someValuesFrom>"
        elsif(obj == :@all)
          "<http://www.w3.org/2002/07/owl#allValuesFrom>"
        elsif(obj == :"<http://www.w3.org/2002/07/owl#Restriction>")
          "<http://www.w3.org/2002/07/owl#Restriction>"
        elsif(obj == :"<http://www.w3.org/2002/07/owl#onProperty>")
          "<http://www.w3.org/2002/07/owl#onProperty>"
        elsif(obj == :"<http://www.w3.org/2002/07/owl#DatatypeProperty>")
          "<http://www.w3.org/2002/07/owl#DatatypeProperty>"
        elsif(obj == :"<http://www.w3.org/2002/07/owl#ObjectProperty>")
          "<http://www.w3.org/2002/07/owl#ObjectProperty>"
        else
          ":#{obj}"
        end
      elsif(obj.is_a?(String))
        if(obj =~ ID_REGEX)
          QL.to_id(obj)
        else
          "\"#{obj}\""
        end
      elsif(obj == nil)
        NIL
      elsif(obj == Float)
        "<http://www.w3.org/2001/XMLSchema#float>"
      elsif(obj == Numeric || obj == Fixnum || obj == "Bignum")
        "<http://www.w3.org/2001/XMLSchema#integer>"
      elsif(obj == Time || obj == Date || obj == DateTime)
        "<http://www.w3.org/2001/XMLSchema#dateTime>"
      elsif(obj == TrueClass || obj == FalseClass)
        "<http://www.w3.org/2001/XMLSchema#boolean>"
      elsif(obj.is_a?(NonNegativeInteger))
        obj.to_s
      elsif(obj == true || obj == false)
        "\"#{obj}\"^^<http://www.w3.org/2001/XMLSchema#boolean>"
      elsif(obj.is_a?(Float))
        "\"#{obj}\"^^<http://www.w3.org/2001/XMLSchema#float>"
      elsif(obj.is_a?(Numeric))
        "\"#{obj}\"^^<http://www.w3.org/2001/XMLSchema#integer>"
      elsif(obj.is_a?(Time))
        "\"#{obj.iso8601}\"^^<http://www.w3.org/2001/XMLSchema#dateTime>"
      elsif(obj.is_a?(Date))
        "\"#{Time.new(obj.to_s).iso8601}\"^^<http://www.w3.org/2001/XMLSchema#dateTime>"
      elsif(obj.is_a?(Array)) # top level array, not array property in a hash
        if(obj.detect{|e| e.is_a?(Hash) || e.respond_to?(:to_triples) })
          obj.map{|e| QL.to_triples(e) }.inject([]){|a,i| a += i}
        else
          obj.each_slice(3).map do |s|
            s.map{|e| QL.to_triples(e) }
          end
        end
      elsif(obj.is_a?(Hash))
        # no blank nodes
        obj[:@id] = "@id(#{SecureRandom.hex})" if obj[:@id].nil?
        # normalising id values
        obj[:@id] = "@id(#{obj[:@id]})" if obj[:@id].index("@id(").nil?

        acum = []
        triples_acum = []
        triples_nested = []
        id = nil
        obj.each_pair do |k,v|
          p = QL.to_triples(k)
          if(v.is_a?(Hash))
            next_triples = QL.to_triples(v)
            triples_acum += next_triples
            v = next_triples.triples_id
            acum << [p,v] if v && k != :@id
          elsif(v.is_a?(Array)) # array as a property in a hash
            v.map{|o| QL.to_triples(o) }.each do |o|
              if(o.is_a?(Array) || o.respond_to?(:triples_id))
                acum << [p, o.triples_id]
                triples_nested += o
              else
                acum << [p, o]
              end
            end
          else
            if(k == :@id) 
              id = QL.to_triples(v)
            else
              v = QL.to_triples(v)
            end
            acum << [p,v] if v && k != :@id
          end
        end

        id = id || BlankId.new

        triples_acum = triples_acum + acum.map{|(p,o)| [id, p, o] } + triples_nested
        triples_acum.triples_id = id
        triples_acum
      else
        if(obj.respond_to?(:to_triples))
          obj.to_triples
        else
          "\"#{obj}\""
        end
      end
    end # end of to_triples

    class QueryContext

      TUPLE = "TUPLE"
      NODE = "NODE"

      attr_reader :last_registered_subject, :nodes, :projection, :limit, :offset, :order, :orig_query
      attr_accessor :triples, :optional_triples, :optional, :unions, :top_level

      def initialize(graph=nil)
        @id_counter = -1
        @filters_counter = -1
        @triples = []
        @optional_triples = []
        @optional_bgps = []
        @projection = {}
        @nodes = {}
        @graph = graph
        @optional = false
        @last_registered_subject = []
        @unions = []
        @limit = nil
        @offset = nil
        @orig_query = nil
        @query_keys = []
        @top_level = true
      end

      def register_query(query)
        @orig_query = query
        query.each_pair do |k,v|
          @query_keys << k if(k != :@id && k.to_s.index("$inv_").nil?)
        end
        self
      end

      def query_keys
        sets = [[@query_keys,@orig_query]]
        unions.each do |c|
          sets += c.query_keys
        end
        sets
      end

      def optional=(value)
        if(value == true)
          @optional = true
        else
          @optional = false
          @optional_bgps << @optional_triples
          @optional_triples = []
        end
      end

      def append(triples)
        if(@optional)
          @optional_triples += triples
        else
          @triples += triples
        end
      end

      def next_node_id
        @id_counter += 1
        @id_counter
      end

      def register_node(id,node_id,inverse=false)
        @filters_counter = -1
        subject = id
        predicate = "?P_mg_#{node_id}"
        object = "?O_mg_#{node_id}" 
        if(id.nil?)
          subject = "?S_mg_#{node_id}"
          @projection[subject] = true if(!inverse)
        else
          @projection[id] = true if(!inverse)
        end

        @last_registered_subject << subject
        # @projection[predicate] = true
        # @projection[object] = true
        @nodes[node_id] = subject

        [subject, predicate, object]
      end

      def last_registered_subject
        @last_registered_subject.pop
      end

      def node_to_optional(node_id) #, last_registered_subject)
        @projection.delete(node_id)
        @nodes.delete(node_id)
        # @last_registered_subject << last_registered_subject
      end

      def fresh_filter_predicate
        @filters_counter+=1
        "?P_#{@id_counter}_#{@filters_counter}"
      end

      def to_sparql_describe(preamble=true)
        bgps = @triples.map{|t| 
          if(t.is_a?(Filter))
            t.acum
          else
            t.join(' ') 
          end
        }.join(" . ")

        optional_bgps = @optional_bgps.map{|optional_triples| 
          "OPTIONAL { "+ optional_triples.map { |t|
            if(t.is_a?(Filter))
              t.acum
            else
              t.join(' ') 
            end
          }.join(" . ") + " }"
        }.join(" ")

        main_bgp = "#{bgps}"
        unless(@optional_bgps.empty?)
          main_bgp += " #{optional_bgps}"
        end

        query = if(preamble)
          query = "PREFIX : <http://grel.org/vocabulary#> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> PREFIX rdfs: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>"
          query = query + " PREFIX xsd: <http://www.w3.org/2001/XMLSchema#> PREFIX fn: <http://www.w3.org/2005/xpath-functions#> " 

          if(@unions.length>0)
            union_bgps = @unions.map{|u| u.to_sparql_describe(false) }.join(" UNION ")
            union_projections = @unions.map{|u| u.projection.keys }.flatten.uniq
            all_subjects = (@projection.keys + union_projections).uniq
            query += "DESCRIBE #{all_subjects.join(' ')} WHERE { { #{main_bgp} } UNION #{union_bgps} }"            
          else
            query += "DESCRIBE #{@projection.keys.join(' ')} WHERE { #{main_bgp} }"
          end
        else
          "{ #{main_bgp} }"
        end
      end

      def to_sparql_select(preamble=true)

        projection = {}

        bgps = @triples.map{ |t| 
          s,p,o = t
          if(s.to_s.index("?X_") == 0 && p.to_s.index("?X_") == 0 && o.to_s.index("?X_") == 0)
          elsif(s.to_s.index("?S_mg") == 0 && p.to_s.index("?P_mg") == 0 && o.to_s.index("?O_mg") == 0)
            nil
          else
            projection[s] = true if((s.to_s.index("?") == 0) && s.to_s.index("?X_").nil? && s.index("_mg_").nil?)  
            projection[p] = true if((p.to_s.index("?") == 0) && p.to_s.index("?X_").nil? && p.index("_mg_").nil?) 
            projection[o] = true if((o.to_s.index("?") == 0) && o.to_s.index("?X_").nil? && o.index("_mg_").nil?) 
            if(t.is_a?(Filter))
              t.acum
            else
              t.join(' ') 
            end
          end
        }.compact.join(" . ")

        optional_bgps = @optional_bgps.map{|optional_triples| 
          "OPTIONAL { "+ optional_triples.map { |t|
            s,p,o = t
            if(s.to_s.index("?") == 0 && p.to_s.index("?") == 0 && o.to_s.index("?") == 0)
              nil
            else
              projection[s] = true if((s.to_s.index("?") == 0) && s.to_s.index("?X_").nil?)  
              projection[p] = true if((p.to_s.index("?") == 0) && p.to_s.index("?X_").nil?) 
              projection[o] = true if((o.to_s.index("?") == 0) && o.to_s.index("?X_").nil?) 
              if(t.is_a?(Filter))
                t.acum
              else
                t.join(' ') 
              end
            end
          }.compact.join(" . ") + " }"
        }.join(" ")

        main_bgp = "#{bgps}"
        unless(@optional_bgps.empty?)
          main_bgp += " #{optional_bgps}"
        end

        query = if(preamble)
          query = "PREFIX : <http://grel.org/vocabulary#> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> PREFIX rdfs: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>"
          query = query + " PREFIX xsd: <http://www.w3.org/2001/XMLSchema#> PREFIX fn: <http://www.w3.org/2005/xpath-functions#> " 

          if(@unions.length>0)
            union_bgps = @unions.map{|u| u.to_sparql_describe(false) }.join(" UNION ")
            all_subjects = projection.keys
            query += "SELECT DISTINCT #{all_subjects.join(' ')} WHERE { { #{main_bgp} } UNION #{union_bgps} }"            
          else
            all_subjects = projection.keys
            query += "SELECT DISTINCT #{all_subjects.join(' ')} WHERE { #{main_bgp} }"
          end
        else
          "{ #{main_bgp} }"
        end
      end

      def limit=(limit)
        @limit = limit
        self
      end

      def offset=(offset)
        @offset = offset
        self
      end

      def union(other_context)
        @unions << other_context
        self
      end

      def run
        @graph.query(to_sparql_describe)
      end

      def required_properties
        props = []
        
      end
    end # end of QueryContext

    class Filter
      DEFINED_FILTERS = {
        :$neq => true, :$eq => true, :$lt => true,
        :$lteq => true, :$gt => true, :$gteq => true,
        :$not => true, :$like => true,
        :$or => true, :$and => true, :$in => true
      }

      def self.filter?(h)
        h.keys.length == 1 && DEFINED_FILTERS[h.keys.first]
      end
      
      attr_reader :variable, :acum
      
      def initialize(context)
        @context = context
        @acum = ""
        @variable = context.fresh_filter_predicate
      end

      def parse(h)
        parse_filter(h)
        @acum = "FILTER("+ @acum + ")"
      end

      def parse_filter(h)
        k = h.keys.first
        v = h.values.first
        self.send "generate_#{k.to_s.split("$").last}".to_sym, v
      end

      def generate_in(v)
        generate_or v.map{|x| {:$eq => x} }
      end

      def generate_neq(v)
        @acum = @acum + "(#{variable} != "
        operator = if(v.is_a?(Hash))
                     parse_filter(v)
                   else
                     QL.to_query(v,@context)
                   end
        @acum+="#{operator})"
      end

      def generate_eq(v)
        @acum = @acum + "(#{variable} = "
        operator = if(v.is_a?(Hash))
                     parse_filter(v)
                   else
                     QL.to_query(v,@context)
                   end
        @acum+="#{operator})"
      end

      def generate_lt(v)
        @acum = @acum + "(#{variable} < "
        operator = if(v.is_a?(Hash))
                     parse_filter(v)
                   else
                     QL.to_query(v,@context)
                   end
        @acum+="#{operator})"
      end

      def generate_lteq(v)
        @acum = @acum + "(#{variable} <= "
        operator = if(v.is_a?(Hash))
                     parse_filter(v)
                   else
                     QL.to_query(v,@context)
                   end
        @acum+="#{operator})"
      end

      def generate_gt(v)
        @acum = @acum + "(#{variable} > "
        operator = if(v.is_a?(Hash))
                     parse_filter(v)
                   else
                     QL.to_query(v,@context)
                   end
        @acum+="#{operator})"
      end

      def generate_gteq(v)
        @acum = @acum + "(#{variable} <= "
        operator = if(v.is_a?(Hash))
                     parse_filter(v)
                   else
                     QL.to_query(v,@context)
                   end
        @acum+="#{operator})"
      end

      def generate_not(v)
        @acum += "!("
        if(v.is_a?(Hash))
          parse_filter(v)
        else
          @acum += QL.to_query(v,@context)
        end
        @acum += ")"
      end

      def generate_like(v)
        operator = if(v.is_a?(Regexp))
                     v.source
                   elsif(v.is_a?(String))
                     v
                   else
                     raise Exception.new("Only Regexes and Strings can be used with the $like operator")
                   end
        @acum += "(regex(#{variable},\"#{operator}\",\"i\"))"
      end

      def generate_or(v)
        if(v.is_a?(Array))
          @acum += "("
          v.each_with_index do |f,i|
            parse_filter(f)
            @acum += "||" if i<v.length-1
          end
          @acum += ")"
        else
          raise Exception.new("$or filter must accept an array of conditions")
        end
      end

      def generate_and(v)
        if(v.is_a?(Array))
          @acum += "("
          v.each_with_index do |f,i|
            parse_filter(f)
            @acum += "&&" if i<v.length-1
          end
          @acum += ")"
        else
          raise Exception.new("$or filter must accept an array of conditions")
        end
      end

    end

    class BGP

      attr_reader :bgp_id, :context, :data

      def initialize(data, context, inverse=false)
        @data = data
        @context = context
        @bgp_id = nil
        @inverse = inverse
      end

      def to_query
        acum = []

        node_id = @context.next_node_id
        id = @data[:@id]
        id = "@id(#{id})" if id && id.is_a?(String) && id.index("@id(").nil?        
        id = QL.to_query(id, context) if id
        subject_var_id,pred_var_id, obj_var_id = @context.register_node(id,node_id,@inverse)

        filters = []

        @data.inject([]) do |ac,(k,v)| 
          # $optional can point to an array of conditions that must be handled separetedly
          if(k.to_s == "$optional" && v.is_a?(Array))
            v.each{ |c| ac << [k,c] }
          else
            ac << [k,v]
          end
          ac
        end.each do |(k,v)|
          # process each property in the query hash
          inverse = false
          optional = false
          unless(k == :@id)
            prop = if(k.to_s.index("$inv_"))
                     inverse = true
                     k.to_s                     
                   elsif(k.to_s == "$optional")
                     context.optional = true
                     optional = true
                   else
                     parse_property(k)
                   end
            value = QL.to_query(v,context,inverse)
            if(value.is_a?(Array))
              context.append(value,false)
              value = value.triples_id
            elsif(value.is_a?(Filter))
              filters << value
              value = value.variable
            elsif(value == context) # It was a nested hash, retrieve the subject as object value
              if(optional)
                subject_to_replace = value.last_registered_subject
                context.node_to_optional(subject_to_replace)#, subject_var_id)
                context.optional_triples = context.optional_triples.map do |(s,p,o)|
                  s = (s == subject_to_replace ? subject_var_id : s)
                  o = (o == subject_to_replace ? subject_var_id : o)
                  [s, p, o]
                end
                context.optional = false
              else
                value = context.last_registered_subject
              end
            end
            acum << [prop,value] unless optional
          end
        end

        bgp_id = subject_var_id
        acum = acum.map do |(p,o)| 
          if(p.index("$inv_"))
            [o,QL.to_query(p.to_sym,@context),subject_var_id]
          else
            [subject_var_id,p,o]
          end
        end
        acum << [subject_var_id, pred_var_id, obj_var_id] if acum.empty?
        acum += filters
        acum
      end

      def parse_property(k)
        if(k.is_a?(String))
          k.gsub(":@type","<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>").
            gsub(":$inv_","^:")
        else
          QL.to_query(k, context)
        end
      end

    end # end of BGP

    def self.to_query(obj, context=QL::QueryContext.new, inverse=false)
      top_level = context.top_level
      context.top_level = false
      if(obj.is_a?(Symbol))
        if(obj == :@type)
          "rdf:type"
        elsif(obj == :@same_as)
          "<http://www.w3.org/2002/07/owl#sameAs>"
        elsif(obj.to_s.index("$inv_"))
          ":#{obj.to_s.split("$inv_").last}"
        elsif(obj.to_s == "_")
          "?X_#{obj.to_s.split('_').last}_#{context.next_node_id}"
        elsif(obj.to_s.index("_"))
          "?#{obj.to_s.split("_").drop(1).join("_")}"
        else
          ":#{obj}"
        end
      elsif(obj.is_a?(String))
        if(obj =~ ID_REGEX)
          QL.to_id(obj)
        else
          "\"#{obj}\""
        end
      elsif(obj.is_a?(Float))
        "\"#{obj}\"^^<http://www.w3.org/2001/XMLSchema#float>"
      elsif(obj.is_a?(Numeric))
        "\"#{obj}\"^^<http://www.w3.org/2001/XMLSchema#integer>"
      elsif(obj.is_a?(Time))
        "\"#{obj.iso8601}\"^^<http://www.w3.org/2001/XMLSchema#dateTime>"
      elsif(obj.is_a?(Date))
        "\"#{Time.new(obj.to_s).iso8601}\"^^<http://www.w3.org/2001/XMLSchema#dateTime>"
      elsif(obj.is_a?(Array))
        # TODO
      elsif(obj.is_a?(Hash))
        if(Filter.filter?(obj))
          filter = Filter.new(context)
          filter.parse(obj)
          filter
        else
          bgp = BGP.new(obj,context,inverse)
          next_triples = bgp.to_query
          # avoid patterns [?s1 ?p1 ?o1] where ?s1 is already linked in ?s0 ?p0 ?s1
          # they fail for SWRL rules in DESCRIBE queries
          unless(top_level == false && next_triples.length == 1 && 
                 next_triples.first.reject{|c| c.index("?")==0 && c.index("_mg_") }.empty?)
            context.append(next_triples)
          end
          context
        end
      else
        if(obj.respond_to?(:to_query))
          obj.to_query(context)
        else
          "\"#{obj}\""
        end
      end
    end # end of to_query

    def self.from_tuple_binding(tuple_value)
      if(tuple_value["type"] == "uri")
        from_binding_to_id(tuple_value["value"])
      elsif(tuple_value["datatype"])
        tuple_value["@type"] = tuple_value["datatype"]
        tuple_value["@value"] = tuple_value["value"]
        from_binding_value(tuple_value)
      else
        tuple_value["@value"] = tuple_value["value"]
        from_binding_value(tuple_value)
      end
    end

    def self.from_binding_to_id(obj)
      if(!obj.is_a?(String))
        obj
      elsif(obj == "http://www.w3.org/1999/02/22-rdf-syntax-ns#nil")
        nil
      elsif(obj.index("http://grel.org/ids/id/"))
        val = URI.unescape(obj.split("http://grel.org/ids/id/").last)
        "@id(#{val})"
      elsif(obj.index("http://grel.org/ids/"))
        URI.unescape(obj.split("http://grel.org/ids/").last)
      elsif(obj.index("http://grel.org/vocabulary#"))
        obj.split("http://grel.org/vocabulary#").last.to_sym
      else
        obj
      end
    end

    def self.from_binding_value(obj)
      if(obj.is_a?(Hash) && obj["@id"])
        from_binding_hash(obj)
      elsif(obj.is_a?(Hash) && obj["@type"])
        if(obj["@type"] == "http://www.w3.org/2001/XMLSchema#dateTime")
          Time.parse(obj["@value"])
        elsif(obj["@type"] == "http://www.w3.org/2001/XMLSchema#integer")
          obj["@value"].to_i
        elsif(obj["@type"] == "http://www.w3.org/2001/XMLSchema#float")
          obj["@value"].to_f
        elsif(obj["@type"] == "http://www.w3.org/2001/XMLSchema#boolean")
          (obj["@value"] == "true" ? true : false)
        else
          obj["@value"]
        end
      elsif(obj.is_a?(Hash) && obj["@value"])
        val = obj["@value"]
        if(val == "true")
          true
        elsif(val == "false")
          false
        elsif(val =~ /^\d+\.\d*$/)
          val.to_f
        elsif(val =~ /^d+$/)
          val.to_i
        elsif(val == "http://www.w3.org/1999/02/22-rdf-syntax-ns#nil")
          nil
        else
          val
        end
      elsif(obj.is_a?(Array))
        obj.map{|o| from_binding_value(o)}
      else
        from_binding_to_id(obj)
      end
    end # end of from_binding_value

    def self.from_binding_hash(node)
      node = node.raw_json if node.respond_to?(:raw_json)
      node.delete("@context")
      node = node.to_a.inject({}) do |ac, (p,v)|
        p = p[1..-1].to_sym if(p.index(":") == 0)
        p = p.split("#").last.to_sym if(p.index("#"))
        p = p.to_sym if(p == "@id" || p == "@type")
        v = from_binding_value(v)
        ac[p] = v; ac
      end
      node
    end

    def self.from_bindings_to_nodes(bindings,context, options = {})
      unlinked = options[:unlinked] || false
      nodes = {}
      uris = {}
      json = bindings
      json = [json] unless json.is_a?(Array)
      json.each do|node|
        node.each_pair do |k,v|
          # weird things happening with describe queries and arrays
          if(v.is_a?(Array))
            v = v.uniq
            v = v.first if v.length ==1
            node[k] = v
          end
        end

        node = from_binding_hash(node)
        nodes[node[:@id]] = node
        node.delete(:@id) unless node[:@id].index("@id(")
      end

      nodes.each do |(node_id,node)|       
        node.each_pair do |k,v|
          # weird things happening with describe queries and arrays
          if(v.is_a?(Array))
            v = v.uniq
            v = v.first if v.length ==1
            node[k] = v
          end

          if(v.is_a?(Hash) && v[:@id] && nodes[v[:@id]])
            node[k] = nodes[v[:@id]]
            nodes.delete(v[:@id]) if unlinked
          elsif(v.is_a?(Hash) && v[:@id])
            node[k] = from_binding_to_id(v[:@id])
          elsif(v.is_a?(Array))
            node[k] = v.map do |o|
              # recursive execution for each element in the array
              if(o.is_a?(Hash) && o[:@id] && nodes[o[:@id]])
                to_link = nodes[o[:@id]]
                nodes.delete(o[:@id]) if unlinked
                to_link
              elsif(o.is_a?(Hash) && o[:@id])
                from_binding_to_id(o[:@id])
              else
                o
              end
            end
          end
        end
      end

      nodes.values
    end

  end # end of class QL
end # end of GRel module
