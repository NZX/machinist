require 'active_support/inflector'


module NormalStrategy
  def prepare
    @object = @klass.new
  end

  attr_reader :object

  def assign_attribute(key, value)
    super
    @object.send("#{key}=", value)
  end

  alias_method :finalised_object, :object
end

module OtherStrategy
  def finalised_object
    @klass.new(@assigned_attributes)
  end
end


module Machinist

  # When you make an object, the blueprint for that object is instance evaled
  # against a Lathe.
  #
  # The Lathe implements all the methods that are available to the blueprint,
  # including method_missing to let the blueprint define attributes.
  class Lathe

    def initialize(klass, strategy, serial_number, attributes = {})
      @klass               = klass
      @strategy            = strategy
      @serial_number       = serial_number
      @assigned_attributes = {}

      self.extend(strategy)
      prepare

      attributes.each {|key, value| assign_attribute(key, value) }
    end

    # Returns a unique serial number for the object under construction.
    attr_reader :serial_number
    alias_method :sn, :serial_number

    # Returns the object under construction.
    #
    # e.g.
    #   Post.blueprint do
    #     title { "A Title" }
    #     body  { object.title.downcase }
    #   end
    attr_reader :object
    alias_method :finalised_object, :object

    def method_missing(attribute, *args, &block) #:nodoc:
      unless attribute_assigned?(attribute)
        assign_attribute(attribute, generate_attribute(attribute, *args, &block))
      end
    end

    # Undef a couple of methods that are common ActiveRecord attributes.
    # (Both of these are deprecated in Ruby 1.8 anyway.)
    undef_method :id   if respond_to?(:id)
    undef_method :type if respond_to?(:type)

  protected

    def generate_attribute(attribute, *args, &block)
      count = args.shift if args.first.is_a?(Fixnum)
      if count
        Array.new(count) { generate_value(attribute, *args, &block) }
      else
        generate_value(attribute, *args, &block)
      end
    end

    def generate_value(attribute, *args, &block)
      raise ArgumentError unless args.empty?  # FIXME: Better error
      yield
    end
    
    def assign_attribute(key, value)
      @assigned_attributes[key.to_sym] = value
    end
  
    def attribute_assigned?(key)
      @assigned_attributes.has_key?(key.to_sym)
    end

  end
end
