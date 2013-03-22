require 'stardog'
require 'time'
require 'uri'
require 'securerandom'

class Array
  def triples_id
    self.first.first
  end
end

module GRel

  class ValidationError < Stardog::ICVException
    attr_accessor :icv_exception
    def initialize(msg, exception)
      super(msg)
      @icv_exception = exception
    end
  end

  DEBUG = ENV["GREL_DEBUG"] || false

  class Debugger
    def self.debug(msg)
      puts msg if DEBUG
    end
  end

  NAMESPACE = "http://grel.org/vocabulary#"
  ID_REGEX = /^\@id\((\w+)\)$/
  NIL = "\"http://www.w3.org/1999/02/22-rdf-syntax-ns#nil\""
  BNODE = "BNODE"

  class NonNegativeInteger

    def initialize(number)
      @number = number
    end

    def method_missing(name, *args, &blk)
      ret = @number.send(name, *args, &blk)
      ret.is_a?(Numeric) ? MyNum.new(ret) : ret
    end

    def to_s
      "\"#{@number}\"^^<http://www.w3.org/2001/XMLSchema#nonNegativeInteger>"
    end

  end

  class BlankId 

    attr_reader :blank_id

    def initialize
      @blank_id = BlankId.next_id
    end

    def self.next_id
      next_id = (@counter ||= 0)
      @counter += 1
      next_id
    end

    def to_s
      "_:#{@blank_id}"
    end
  end

  def graph(name='http://localhost:5822/',options = {})
    options[:user] ||= "admin"
    options[:password] ||= "admin"
    options[:validate] ||= false
    g = Base.new(name, options)
    g.with_db(options[:db]) if(options[:db])
    g
  end

end # end of module GRel

# remaining modules
require File.join(File.dirname(__FILE__), "grel", "ql")
require File.join(File.dirname(__FILE__), "grel", "base")
