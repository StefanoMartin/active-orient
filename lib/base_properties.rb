require 'active_model'
require 'active_support/concern'
require 'active_support/hash_with_indifferent_access'

module ActiveOrient
  module BaseProperties
    extend ActiveSupport::Concern

    def to_human
      "<#{self.class.to_s.demodulize}: " + content_attributes.map do |attr, value|
        "#{attr}: #{value}" unless value.nil?
      end.compact.sort.join(' ') + ">"
    end

    def content_attributes
      HashWithIndifferentAccess[attributes.reject do |(attr, _)|
        attr.to_s =~ /(_count)\z/ || [:created_at, :updated_at, :type, :id, :order_id, :contract_id].include?(attr.to_sym)
      end]
    end

    def update_missing attrs
      attrs = attrs.content_attributes unless attrs.kind_of?(Hash)
      attrs.each{ |attr, val| send "#{attr}=", val if send(attr).blank? }
      self # for chaining
    end

    def == other
      case other
      when String # Probably a link or a rid
        link == other || rid == other
      when  ActiveOrient::Model
	      link == other.link
      else
        content_attributes.keys.inject(true){ |res, key|
          res && other.respond_to?(key) && (send(key) == other.send(key))
        }
      end
    end

    def default_attributes
      {:created_at => Time.now,
       :updated_at => Time.now}
    end

    def set_attribute_defaults
      default_attributes.each do |key, val|
        self.send("#{key}=", val) if self.send(key).nil?
      end
    end

    included do
      after_initialize :set_attribute_defaults

      def self.prop *properties
        prop_hash = properties.last.is_a?(Hash) ? properties.pop : {}
        properties.each { |names| define_property names, nil }
        prop_hash.each { |names, type| define_property names, type }
      end

      def self.define_property names, body
        aliases = [names].flatten
        name = aliases.shift
        instance_eval do
          define_property_methods name, body
          aliases.each do |ali|
            alias_method "#{ali}", name
            alias_method "#{ali}=", "#{name}="
          end
        end
      end

      def self.define_property_methods name, body={}
        case body
        when '' # default getter and setter
          define_property_methods name

        when Array # [setter, getter, validators]
          define_property_methods name,
            :get => body[0],
            :set => body[1],
            :validate => body[2]

        when Hash # recursion base case
          getter = case # Define getter
          when body[:get].respond_to?(:call)
            body[:get]
          when body[:get]
            proc { self[name].send "to_#{body[:get]}" }
          else
            proc { self[name] }
          end
          define_method name, &getter if getter
          setter = case # Define setter
          when body[:set].respond_to?(:call)
            body[:set]
          when body[:set]
            proc { |value| self[name] = value.send "to_#{body[:set]}" }
          else
            proc { |value| self[name] = value } # p name, value;
          end
          define_method "#{name}=", &setter if setter

          # Define validator(s)
          [body[:validate]].flatten.compact.each do |validator|
            case validator
            when Proc
              validates_each name, &validator
            when Hash
              validates name, validator.dup
            end
          end

          # todo define self[:name] accessors for :virtual and :flag properties

        else # setter given
          define_property_methods name, :set => body, :get => body
        end
      end

      unless defined?(ActiveRecord::Base) && ancestors.include?(ActiveRecord::Base)
        prop :created_at, :updated_at
      end

    end # included
  end # module BaseProperties
end
