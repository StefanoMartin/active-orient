module  ActiveOrient
  require 'active_model'
  #
  # Base class for tableless IB data Models, extends ActiveModel API
  class Base
    extend ActiveModel::Naming
    extend ActiveModel::Callbacks
    include ActiveModel::Validations
    include ActiveModel::Serialization
    include ActiveModel::Serializers::Xml
    include ActiveModel::Serializers::JSON
    

    ##Every Rest::Base-Object is stored in the @@rid_store
    ## The Objects are just references to the @@rid_store.
    ## any Change of the Object is thus synchonized to any allocated variable
    #
    @@rid_store =  Hash.new

    def self.display_riid
      @@rid_store
    end
    def self.remove_riid obj
      @@rid_store[obj.riid]=nil 
    end
    def self.get_riid link

    end
    def self.store_riid obj
      if obj.rid.present? && obj.riid.all?{|x| x.present? && x>=0} # only positive values are stored
	  ## return the presence of a stored object as true by the block
	  ## the block is only executed if the presence is confirmed
	  ##  Nothing is returned from the class-method
	if @@rid_store[obj.riid].present? 
	  yield  if block_given?  	    
	end
	 @@rid_store[obj.riid] = obj
	 @@rid_store[obj.riid]  # return_value
      else
	obj # no rid-value: just return the obj
      end
    end


    define_model_callbacks :initialize

    mattr_accessor :logger
    # If a opts hash is given, keys are taken as attribute names, values as data.
    # The model instance fields are then set automatically from the opts Hash.
    def initialize attributes={}, opts={}
      logger.progname= "ActiveOrient::Base#initialize"
      #possible_link_array_candidates = link_candidates = Hash.new
      @metadata = HashWithIndifferentAccess.new
#      @edges = HashWithIndifferentAccess.new
    
      run_callbacks :initialize do
#	puts "initialize::attributes: #{attributes.inspect}"

	attributes.keys.each do | att |
	  unless att[0] == "@"	    # @ identifies Metadata-attributes
	    att =  att.to_sym if att.is_a?(String)    
	    unless self.class.instance_methods.detect{|x| x == att }
	      self.class.define_property att, nil 
	      logger.debug { "property #{att.to_s} assigned to #{self.class.to_s}" }
	    else
#	      logger.info{ "property #{att.to_s}  NOT assigned " }
	    end
	  end
	end

	if attributes['@type'] == 'd'  # document 
	  @metadata[ :type    ] = attributes.delete '@type'
	  @metadata[ :class   ] = attributes.delete '@class' 
	  @metadata[ :version ] = attributes.delete '@version' 
	  @metadata[ :fieldTypes ] = attributes.delete '@fieldTypes' 
	  if attributes.has_key?( '@rid' )
	    rid = attributes.delete '@rid' 
	    cluster, record = rid[1,rid.size].split(':') 
	    @metadata[ :cluster ] =  cluster.to_i
	    @metadata[ :record ] = record.to_i
	  end

	  #### edges -- remove in_ and out_ and de-capitalize the remaining edge
	  if @metadata[ :fieldTypes ].present? && (@metadata[ :fieldTypes ] =~ /=g/)
	    edges = @metadata['fieldTypes'].split(',').find_all{|x| x=~/=g/}.map{|x| x.split('=').first}
	    edges.each do |edge|
	      operator, *base_edge =  edge.split('_')
	      base_edge = base_edge.join('_')
	      unless self.class.instance_methods.detect{|x| x == base_edge }
		## define two methods: out_{Edge}/{in_Edge} -> edge. 
		self.class.define_property base_edge, nil 
		self.class.send :alias_method, base_edge.downcase, edge  #  
		logger.debug { "edge #{edge} assigned to #{self.class.to_s} and remaped to #{base_edge.downcase}" }  

	      end
	    end
	  end
	end


	  self.attributes = attributes # set_attribute_defaults is now after_init callback
	end
	ActiveOrient::Base.store_riid self
      end

    # ActiveModel API (for serialization)

    def attributes
      @attributes ||= HashWithIndifferentAccess.new
    end

    def attributes= attrs
      attrs.keys.each { |key| self.send("#{key}=", attrs[key]) }
    end

    # ActiveModel-style read/write_attribute accessors
    # Here we define the autoload mechanism
    def [] key

      iv= attributes[key.to_sym]
  #    iv.from_orient unless iv.nil?
      if  iv.is_a?(String) && iv.rid? #&& @metadata[:fieldTypes].present? && @metadata[:fieldTypes].include?( key.to_s+"=x" )
     # puts "autoload: #{iv}"
	ActiveOrient::Model.autoload_object  iv
      elsif iv.is_a?(Array) # && @metadata[:fieldTypes].present? && @metadata[:fieldTypes].match( key.to_s+"=[znmgx]" )
     # puts "autoload: #{iv.inspect}"
	OrientSupport::Array.new self, *iv.map{|y| (y.is_a?(String) && y.rid?) ? ActiveOrient::Model.autoload_object(  y ) : y  }
      else

	iv
      end
    end

    def update_attribute key, value
      @attributes[key] = value
    end
=begin
Here we define how the attributes are initialized 
Key and val are set by the RestCliend
=end
    def []= key, val
      val = val.rid if val.is_a? ActiveOrient::Model
#      if val.is_a?(Array) # && @metadata[:fieldTypes].present? && @metadata[:fieldTypes].include?( key.to_s+"=n" )
#	if @metadata[ :fieldTypes ] =~ /out=x,in=x/
#	puts "VAL is a ARRAY"
#	else
#	  puts "METADATA: #{ @metadata[ :fieldTypes ]}  "
#	end
#	val# = val.map{|x|  if val.is_a? ActiveOrient::Model then val.rid else val end }
#      end
      attributes[key.to_sym] = case val
	 when Array
	   if  val.first.is_a?(Hash)
	     v=val.map do |x| 
	       if x.is_a?( Hash ) 
		 HashWithIndifferentAccess.new(x)
	       else
		 x 
	       end
	     end
	     OrientSupport::Array.new( self, *v )
	   else
	     OrientSupport::Array.new( self, *val )
	   end
	 when Hash
	    HashWithIndifferentAccess.new(val) 
	 else
	   val
	 end
      
    end

    def to_model
      self
    end



    ### Noop methods mocking ActiveRecord::Base macros
    
    def self.attr_protected *args
    end

    def self.attr_accessible *args
    end

    ### ActiveRecord::Base association API mocks

    def self.belongs_to model, *args
      attr_accessor model
    end

    def self.has_one model, *args
      attr_accessor model
    end

    def self.has_many models, *args
      attr_accessor models

      define_method(models) do
        self.instance_variable_get("@#{models}") ||
          self.instance_variable_set("@#{models}", [])
      end
    end

    def self.find *args
      []
    end

    ### ActiveRecord::Base callback API mocks

    define_model_callbacks :initialize, :only => :after

    ### ActiveRecord::Base misc

    def self.serialize *properties
    end

  end # Model
end # module 
