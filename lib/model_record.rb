module ModelRecord
  ############### RECORD FUNCTIONS ###############

  ############# GET #############

  def to_orient
    "##{rid}"
  end

  def from_orient
    self
  end

  # Returns just the name of the Class

  def classname
    self.class.to_s.split(':')[-1]
  end

  # Obtain the RID of the Record

  def rid
    begin
      "#{@metadata[:cluster]}:#{@metadata[:record]}"
    rescue
      "0:0"
    end
  end

  # Create a query

  def query q
    a = ActiveOrient::Query.new
    a.queries << q
    a.execute_queries
  end

  # Get the version of the object

  def version
    @metadata[:version]
  end

  ########### UPDATE PROPERTY ############

=begin
  Convient method for populating embedded- or linkset-properties
  In both cases an array/a collection is stored in the database.
  Its called via
    model.add_item_to_property(linkset- or embedded property, Object_to_be_linked_to\)
  or
    mode.add_items_to_property( linkset- or embedded property ) do
      Array_of_Objects_to_be_linked_to
      #(actually, the objects must inherent from ActiveOrient::Model, Numeric, String)
    end
  to_do: use "<<" to add the item to the property
=end

  def method_missing *args
    print "TEST, #{args} \n"
    if args[1] == "<<" or args[1] == "|="
      update_item_property "ADD", "#{args[0][0..-2]}", args[2]
    elsif args[0][-1] == "="
      update_item_property "SET", "#{args[0][0..-2]}", args[1]
    elsif args[1] == ">>"
      update_item_property "REMOVE", "#{args[0][0..-2]}", args[2]
    end
  end


  def update_item_property method, array, item = nil, items = nil
    begin
      logger.progname = 'ActiveOrient::Model#UpdateItemToProperty'
      execute_array = Array.new
      print "#{self.attributes.class} \n"
      self.attributes[array] = Array.new unless attributes[array].present?

      add_2_execute_array = -> (it) do
        case it
        when ActiveOrient::Model
          updating = "##{it.rid}"
        when String
          updating = "'#{it}'"
        when Numeric
          updating = "#{it}"
        when Array
          updating = it.map{|x| "##{x.rid}"} if it[0].is_a? ActiveOrient::Model
        end
        unless updating.nil?
          command = "UPDATE ##{rid} ADD #{array} = #{updating}"
          command.gsub!(/\"/,"") if updating.is_a? Array
          print "#{command} \n"
          execute_array << {type: "cmd", language: "sql", command: command}
        else
          logger.error{"Only Basic Formats supported. Cannot Serialize #{it.class} this way"}
          logger.error{"Try to load the array from the DB, modify it and update the hole record"}
        end
      end

      items = yield if block_given?

      if !items.nil?
        items.each{|x|
          add_2_execute_array[x];
          self.attributes[array] << x}
      elsif item.present?
        add_2_execute_array[item]
        self.attributes[array] << item
      end

      orientdb.execute do
        execute_array
      end
    rescue RestClient::InternalServerError => e
      logger.error{"Duplicate found in #{array}"}
      logger.error{e.inspect}
    end
  end

  def add_item_to_property array, item = nil
    items = block_given? ? yield : nil
    update_item_property "ADD", array, item, items
  end
  alias add_items_to_property add_item_to_property
  ## historical aliases
  alias update_linkset  add_item_to_property
  alias update_embedded  add_item_to_property

  def set_item_to_property array, item = nil
    items = block_given? ? yield : nil
    update_item_property "SET", array, item, items
  end

  def remove_item_to_property array, item = nil
    items = block_given? ? yield : nil
    update_item_property "REMOVE", array, item, items
  end

  ############# DELETE ###########

#  Removes the Model-Instance from the database

def delete
  orientdb.delete_record rid
  ActiveOrient::Base.remove_rid self if is_edge? # removes the obj from the rid_store
end

########### UPDATE ############

=begin
  Convient update of the dataset by calling sql-patch
  The attributes are saved to the database.
  With the optional :set argument ad-hoc attributes can be defined
    obj = ActiveOrient::Model::Contracts.first
    obj.name =  'new_name'
    obj.update set: { yesterdays_event: 35 }
=end

  def update set: {}
    attributes.merge!(set) if set.present?
    result = orientdb.patch_record(rid) do
      attributes.merge({'@version' => @metadata[:version], '@class' => @metadata[:class]})
    end
    # returns a new instance of ActiveOrient::Model
    reload! ActiveOrient::Model.orientdb_class(name:  classname).new(JSON.parse(result))
    # instantiate object, update rid_store and reassign to self
  end

=begin
  Overwrite the attributes with Database-Contents (or attributes provided by the updated_dataset.model-instance)
=end

  def reload! updated_dataset = nil
    updated_dataset = orientdb.get_record(rid) if updated_dataset.nil?
    @metadata[:version] = updated_dataset.version
    attributes = updated_dataset.attributes
    self  # return_value  (otherwise only the attributes would be returned)
  end

  ########## CHECK PROPERTY ########

=begin
  An Edge is defined
  * when inherented from the superclass »E» (formal definition)
  * if it has an in- and an out property

  Actually we just check the second term as we trust the constuctor to work properly
=end

  def is_edge?
    attributes.keys.include?('in') && attributes.keys.include?('out')
  end

end
