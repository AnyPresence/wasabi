require 'uri'
require 'wasabi/core_ext/string'

module Wasabi

  # = Wasabi::Parser
  #
  # Parses WSDL documents and remembers their important parts.
  class Parser

    XSD      = 'http://www.w3.org/2001/XMLSchema'
    WSDL     = 'http://schemas.xmlsoap.org/wsdl/'
    SOAP_1_1 = 'http://schemas.xmlsoap.org/wsdl/soap/'
    SOAP_1_2 = 'http://schemas.xmlsoap.org/wsdl/soap12/'

    STYLES = [:rpc_literal, :rpc_encoded, :document_literal]

    def initialize(document)
      self.document = document
      self.operations = {}
      self.namespaces = {}
      self.service_name = ''
      self.types = {}
      self.deferred_types = []
      self.element_form_default = :unqualified
      self.top_level_elements = {}
      self.style = nil
      self.pseudo_types = {}
      @generated_types = {}
    end

    # Returns the Nokogiri document.
    attr_accessor :document

    # Returns the target namespace.
    attr_accessor :namespace

    # Returns a map from namespace identifier to namespace URI.
    attr_accessor :namespaces

    # Returns the SOAP operations.
    attr_accessor :operations

    # Returns a map from a type name to a Hash with type information.
    attr_accessor :types

    # Returns a map of deferred type Proc objects.
    attr_accessor :deferred_types

    # Returns the SOAP endpoint.
    attr_accessor :endpoint

    # Returns the SOAP Service Name
    attr_accessor :service_name

    # Returns the elementFormDefault value.
    attr_accessor :element_form_default

    # Returns the top-level elements defined in the XML schemas
    attr_accessor :top_level_elements

    # Returns the style (either document or RPC)
    attr_accessor :style

    # Returns any pseudo types that were created for RPC calls
    attr_accessor :pseudo_types

    def parse
      parse_namespaces
      parse_endpoint
      parse_service_name
      parse_messages
      parse_port_types
      parse_port_type_operations
      parse_style
      parse_operations
      parse_operations_parameters
      parse_types
      parse_deferred_types
      parse_rpc_top_level_elements
      resolve_element_refs
      resolve_unknown_parameter_types
    end

    def parse_style
      binding = document.xpath('wsdl:definitions/wsdl:binding/soap:binding', {'wsdl' => WSDL, 'soap' => SOAP_1_1}).first
      binding ||= document.xpath('wsdl:definitions/wsdl:binding/soap:binding', {'wsdl' => WSDL, 'soap' => SOAP_1_2}).first
      @style = binding['style'] if binding
    end

    def parse_namespaces
      element_form_default = schemas.first && schemas.first['elementFormDefault']
      @element_form_default = element_form_default.to_s.to_sym if element_form_default

      namespace = document.root['targetNamespace']
      @namespace = namespace.to_s if namespace

      @namespaces = @document.namespaces.inject({}) do |memo, (key, value)|
        memo[key.sub('xmlns:', '')] = value
        memo
      end
    end

    def parse_endpoint
      if service_node = service
        endpoint = service_node.at_xpath('.//soap11:address/@location', 'soap11' => SOAP_1_1)
        endpoint ||= service_node.at_xpath(service_node, './/soap12:address/@location', 'soap12' => SOAP_1_2)
      end

      @endpoint = parse_url(endpoint) if endpoint
    end

    def parse_url(url)
      unescaped_url = URI.unescape(url.to_s)
      escaped_url   = URI.escape(unescaped_url)
      URI.parse(escaped_url)
    rescue URI::InvalidURIError
    end

    def parse_service_name
      service_name = document.root['name']
      @service_name = service_name.to_s if service_name
    end

    def parse_messages
      messages = document.root.element_children.select { |node| node.name == 'message' }
      @messages = Hash[messages.map { |node| [node['name'], node] }]
    end

    def parse_port_types
      port_types = document.root.element_children.select { |node| node.name == 'portType' }
      @port_types = Hash[port_types.map { |node| [node['name'], node] }]
    end

    def parse_port_type_operations
      @port_type_operations = {}

      @port_types.each do |port_type_name, port_type|
        operations = port_type.element_children.select { |node| node.name == 'operation' }
        @port_type_operations[port_type_name] = Hash[operations.map { |node| [node['name'], node] }]
      end
    end

    def parse_operations_parameters
      root_elements = document.xpath("wsdl:definitions/wsdl:types/*[local-name()='schema']/*[local-name()='element']", 'wsdl' => WSDL).each do |element|
        name = element.attribute('name').to_s.snakecase.to_sym

        if operation = operation_for_input_element(element.attribute('name').to_s, target_namespace(element))
          if element.xpath("*[local-name() ='complexType']").length > 0
            element.xpath("*[local-name() ='complexType']/*[local-name() ='sequence']/*[local-name() ='element']").each do |child_element|
              operation[:parameters] ||= {}
              if child_element.attribute('type')
                attr_name = child_element.attribute('name').to_s
                attr_ns_id = (attr_ns_id = child_element.attribute('type').to_s.split(':')).size > 1 ? attr_ns_id[0] : nil
                attr_type = (attr_type = child_element.attribute('type').to_s.split(':')).size > 1 ? attr_type[1] : attr_type[0]

                operation[:parameters][attr_name.to_sym] = { :name => attr_name, :type => attr_type, :namespace_identifier => attr_ns_id, :namespace => resolve_namespace(child_element, attr_ns_id) }
              elsif child_element.attribute('name') && child_element.xpath('xs:complexType', 'xs' => XSD).length > 0
                name = child_element['name']
                operation[:parameters][name] = { :name => name, :type => '__unknown__', :namespace_identifier => nil, :namespace => 'urn:__generated__', element: child_element }
              elsif child_element.attribute('ref')
                operation[:parameters][synthetic_ref_id(child_element)] = { :ref => child_element }
              end
            end
          # Didn't find any nested complexTypes under the element -- let's see if we can find one elsewhere in the schema
          else
            type = element.attribute('type').to_s
            if type
              type_tokens = type.split ":"
              ns_prefix = type_tokens.length == 1 ? nil : type_tokens[0]
              local_type_name = type_tokens.last

              namespace_key = ns_prefix.nil? ? "xmlns" : "xmlns:#{ns_prefix}"
              ns_value = element.namespaces[namespace_key]

              document.xpath("wsdl:definitions/wsdl:types/*[local-name()='schema']/*[local-name()='complexType' and @name='#{local_type_name}']", { 'wsdl' => WSDL }).each do |element|
                tns = target_namespace(element)
                if tns == ns_value
                  element.xpath("*[local-name() ='sequence']/*[local-name() ='element']").each do |child_element|
                    operation[:parameters] ||= {}

                    if child_element.attribute('type')
                      attr_name = child_element.attribute('name').to_s
                      attr_ns_id = (attr_ns_id = child_element.attribute('type').to_s.split(':')).size > 1 ? attr_ns_id[0] : nil
                      attr_type = (attr_type = child_element.attribute('type').to_s.split(':')).size > 1 ? attr_type[1] : attr_type[0]

                      operation[:parameters][attr_name.to_sym] = { :name => attr_name, :type => attr_type, :namespace_identifier => attr_ns_id, :namespace => resolve_namespace(child_element, attr_ns_id) }
                    elsif child_element.attribute('name') && child_element.xpath('xs:complexType', 'xs' => XSD).length > 0
                      name = child_element['name']
                      operation[:parameters][name] = { :name => name, :type => '__unknown__', :namespace_identifier => nil, :namespace => 'urn:__generated__', element: child_element }
                    elsif child_element.attribute('ref')
                      operation[:parameters][synthetic_ref_id(child_element)] = { :ref => child_element }
                    end
                  end
                  break
                end
              end
            end

          end
        end
      end
    end

    def parse_operations
      operations = document.xpath('wsdl:definitions/wsdl:binding/wsdl:operation', 'wsdl' => WSDL)
      operations.each do |operation|
        name = operation.attribute('name').to_s

        # TODO: check for soap namespace?
        soap_operation = operation.element_children.find { |node| node.name == 'operation' }
        soap_action = soap_operation['soapAction'] if soap_operation

        if soap_action
          soap_action = soap_action.to_s
          action = soap_action && !soap_action.empty? ? soap_action : name

          # There should be a matching portType for each binding, so we will lookup the input from there.
          output_namespace_id, output = output_for(operation)
          input_namespace_id, input = input_for(operation)

          # Store namespace identifier so this operation can be mapped to the proper namespace.
          @operations[name.snakecase.to_sym] = { :action => action, :input => {:name => input, :namespace_identifier => input_namespace_id, :namespace => resolve_namespace(operation, input_namespace_id)}, :output => {:name => output, :namespace_identifier => output_namespace_id, :namespace => resolve_namespace(operation, output_namespace_id)}, :namespace_identifier => input_namespace_id, :namespace => resolve_namespace(operation, input_namespace_id)}
        elsif !@operations[name.snakecase.to_sym]
          @operations[name.snakecase.to_sym] = { :action => name, :input => name }
        end
      end
    end

    def parse_types
      schemas.each do |schema|
        schema_namespace = schema['targetNamespace']

        schema.element_children.each do |node|
          namespace = schema_namespace || @namespace
          @top_level_elements[namespace] ||= {}

          case node.name
          when 'element'
            complex_type = node.at_xpath('./xs:complexType', 'xs' => XSD)
            if complex_type
              @top_level_elements[namespace][node['name'].to_s] = { :type_name => node['name'].to_s, :type_namespace => namespace, :type_namespace_identifier => nil }
              process_complex_type namespace, complex_type, node['name'].to_s
            else
              if node.attribute('type')
                type_ref = node.attribute('type').to_s
                qname = expand_name(type_ref, node)
                type_name = qname[:name]
                type_ns = qname[:namespace]
                type_ns_prefix = qname[:namespace_prefix]
                @top_level_elements[namespace][node['name'].to_s] = { :type_name => qname[:name], :type_namespace => qname[:namespace], :type_namespace_identifier => qname[:namespace_prefix] }
              end
            end
          when 'complexType'
            process_complex_type namespace, node, node['name'].to_s
          when 'simpleType'
            process_simple_type namespace, node, node['name'].to_s
          end
        end
      end
    end

    def parse_rpc_top_level_elements
      return unless @style == 'rpc'

      # Iterate over the operations and process each
      document.xpath('wsdl:definitions/wsdl:portType/wsdl:operation', 'wsdl' => WSDL).each do |operation|
        # In RPC style, the operation name is treated as a top level element
        operation_name = operation['name']
        input_message_name = nil
        input_elt = nil
        output_message_name = nil
        output_elt = nil
        operation.xpath('./wsdl:input', 'wsdl' => WSDL).each do |input|
          input_message_name = input['message']
          input_elt = input
        end
        operation.xpath('./wsdl:output', 'wsdl' => WSDL).each do |output|
          output_message_name = output['message']
          output_elt = output
        end

        input_qname = expand_name(input_message_name, input_elt)
        output_qname = expand_name(output_message_name, output_elt)

        input_element_name = operation_name
        output_element_name = output_message_name

        @top_level_elements[input_qname[:namespace]] ||= {}
        input_type_hash = @top_level_elements[input_qname[:namespace]]
        input_type_hash[input_qname[:name]] = {}
        input_type = input_type_hash[input_qname[:name]]
        # since this is a manufactured type, we don't want to conflict with user defined types,
        # so we'll prefix the type name with an ampersand, which would be illegal in XML, so there's no
        # chance of conflicting with an actual valid type
        input_type[:type_name] = "&" + input_element_name + "Type"
        input_type[:type_namespace] = input_qname[:namespace]
        input_type[:type_namespace_identifier] = input_qname[:namespace_prefix]

        create_rpc_pseudo_type(input_type, input_elt, operation_name.snakecase.to_sym, true)

        @top_level_elements[output_qname[:namespace]] ||= {}
        output_type_hash = @top_level_elements[output_qname[:namespace]]
        output_type_hash[output_qname[:name]] = {}
        output_type = output_type_hash[output_qname[:name]]
        # same here as above -- create manufactured type name
        output_type[:type_name] = "&" + output_qname[:name] + "Type"
        output_type[:type_namespace] = output_qname[:namespace]
        output_type[:type_namespace_identifier] = output_qname[:namespace_prefix]

        create_rpc_pseudo_type(output_type, output_elt, operation_name.snakecase.to_sym, false)
      end
    end

    def process_simple_type(namespace, type, name)
      @types[namespace] ||= {}
      @types[namespace][name] ||= { :namespace => namespace }

      type.xpath('./xs:restriction', 'xs' => XSD).each do |restriction|
        element_name = restriction.attribute('base').to_s
        local_type_name, ns_pfx = element_name.split(':').reverse
        ns = resolve_namespace(restriction, ns_pfx)
        @types[namespace][name][:base_type] = { :type => element_name, :type_name => local_type_name, :type_namespace => ns }
        restriction.xpath('./xs:enumeration', 'xs' => XSD).each do |enumeration|
          value = enumeration.attribute('value').to_s
          @types[namespace][name][:base_type][:enumeration] ||= []
          @types[namespace][name][:base_type][:enumeration] << value
        end
        restriction.xpath('./xs:pattern', 'xs' => XSD).each do |pattern|
          value = pattern.attribute('value').to_s
          @types[namespace][name][:base_type][:pattern] = value
        end
      end
    end

    def resolve_element_refs
      @operations.each do |operation_name, operation|
        new_params = {}
        next unless operation[:parameters]
        operation[:parameters].each do |ref_name, parameter|
          if parameter[:ref]
            elt = parameter[:ref]
            referenced_element = resolve_element_ref(elt)
            element_name = referenced_element[:name]
            local_type_name = referenced_element[:type_name]
            ns_pfx = referenced_element[:type_namespace_identifier]
            ns = referenced_element[:type_namespace]

            new_params[ref_name] = { :name => element_name, :type => local_type_name, :namespace_identifier => ns_pfx, :namespace => ns }
          end
        end
        new_params.each do |ref_name, new_param|
          operation[:parameters].delete(ref_name)
          operation[:parameters][new_param[:name]] = new_param
        end
      end

      @types.each do |namespace, values|
        values.each do |name, element|
          next unless element[:refs]
          new_elements = {}
          ref_names = element[:refs].map do |ref|
            referenced_element = resolve_element_ref(ref)
            element_name = referenced_element[:name]
            local_type_name = referenced_element[:type_name]
            ns_pfx = referenced_element[:type_namespace_identifier]
            ns = referenced_element[:type_namespace]
            new_elements[element_name] = { :type => local_type_name, :type_name => local_type_name, :type_namespace => ns }
            [synthetic_ref_id(ref), element_name]
          end

          refs = ref_names.to_h

          [:order!, :unordered].each do |sym|
            new_order = []
            if element[sym]
              element[sym].each do |ordered|
                if (refs.keys.include?(ordered))
                  new_order << refs[ordered]
                else
                  new_order << ordered
                end
              end
              element[sym] = new_order
            end
          end

          element.delete :refs

          new_elements.each do |element_name, value|
            @types[namespace][name][element_name] = value
          end

        end
      end
    end

    def resolve_unknown_parameter_types
      @operations.each do |operation_name, operation|
        next if !operation[:parameters]
        operation[:parameters].each do |parameter_name, parameter|
          if parameter[:type] == '__unknown__' && parameter[:namespace] == 'urn:__generated__'
            type = @types[parameter[:namespace]]
            target_generated_type = @generated_types[parameter[:element].to_s]
            parameter[:type] = target_generated_type[:type_name]
          end

          parameter.delete(:element) if parameter.has_key?(:element)
        end
      end

      @generated_types = nil
    end

    def process_complex_type(namespace, type, name)
      @types[namespace] ||= {}
      @types[namespace][name] ||= { :namespace => namespace }

      type.xpath('./xs:attribute', 'xs' => XSD).each do |attribute|
        attribute_name = attribute.attribute('name').to_s
        attribute_type = attribute.attribute('type')

        @types[namespace][name][:attributes!] ||= {}
        @types[namespace][name][:attributes!][attribute_name] = {}
        if attribute_type
          qname = expand_name(attribute_type.to_s, attribute)

          @types[namespace][name][:attributes!][attribute_name][:type] = attribute_name
          @types[namespace][name][:attributes!][attribute_name][:type_name] = qname[:name]
          @types[namespace][name][:attributes!][attribute_name][:type_namespace] = qname[:namespace]
        elsif attribute.xpath('./xs:simpleType', 'xs' => XSD).length > 0
          attribute.xpath('./xs:simpleType', 'xs' => XSD).each do |simple_type|
            generated_namespace = "urn:__generated__"
            @types[generated_namespace] ||= {}
            generated_name = "__generated__" + (@types[generated_namespace].length + 1).to_s
            @types[namespace][name][:attributes!][attribute_name][:type] = generated_name
            @types[namespace][name][:attributes!][attribute_name][:type_name]  = generated_name
            @types[namespace][name][:attributes!][attribute_name][:type_namespace]  = generated_namespace
            @generated_types[type.to_s] = @types[namespace][name][:attributes!][attribute_name]
            process_simple_type(generated_namespace, simple_type, generated_name)
          end
        end
      end

      type.xpath('./xs:sequence/xs:element', 'xs' => XSD).each do |inner|

        element_name = nil
        if inner.attribute('ref')
          element_name = synthetic_ref_id inner
          @types[namespace][name][:refs] ||= []
          @types[namespace][name][:refs] << inner
        else
          element_name = inner.attribute('name').to_s
          local_type_name, ns_pfx =  inner.attribute('type').to_s.split(':').reverse
          if local_type_name
            ns = resolve_namespace(inner, ns_pfx)
            @types[namespace][name][element_name] = { :type => inner.attribute('type').to_s, :type_name => local_type_name, :type_namespace => ns }

            [ :nillable, :minOccurs, :maxOccurs ].each do |attr|
              if v = inner.attribute(attr.to_s)
                @types[namespace][name][element_name][attr] = v.to_s
              end
            end
          # we have to recursively handle nested complex types ...
          elsif inner.xpath('./xs:complexType', 'xs' => XSD).length > 0
            inner.xpath('./xs:complexType', 'xs' => XSD).each do |inner_complex_type|
              generated_namespace = "urn:__generated__"
              @types[generated_namespace] ||= {}
              generated_name = "__generated__" + (@types[generated_namespace].length + 1).to_s
              @types[namespace][name][element_name] = { :type => generated_name, :type_name => generated_name, :type_namespace => generated_namespace }
              @generated_types[inner.to_s] = @types[namespace][name][element_name]
              process_complex_type(generated_namespace, inner_complex_type, generated_name)
            end
          # we also have to recursively handle nested simple types!
          elsif inner.xpath('./xs:simpleType', 'xs' => XSD).length > 0
            inner.xpath('./xs:simpleType', 'xs' => XSD).each do |inner_simple_type|
              generated_namespace = "urn:__generated__"
              @types[generated_namespace] ||= {}
              generated_name = "__generated__" + (@types[generated_namespace].length + 1).to_s
              @types[namespace][name][element_name] = { :type => generated_name, :type_name => generated_name, :type_namespace => generated_namespace }
              @generated_types[inner.to_s] = @types[namespace][name][element_name]
              process_simple_type(generated_namespace, inner_simple_type, generated_name)
            end
          end

        end

        @types[namespace][name][:order!] ||= []
        @types[namespace][name][:order!] << element_name
      end

      type.xpath('./xs:all/xs:element', 'xs' => XSD).each do |inner|
        element_name = nil
        if inner.attribute('ref')
          element_name = synthetic_ref_id inner
          @types[namespace][name][:refs] ||= []
          @types[namespace][name][:refs] << inner
        else
          element_name = inner.attribute('name').to_s
          local_type_name, ns_pfx =  inner.attribute('type').to_s.split(':').reverse
          ns = resolve_namespace(inner, ns_pfx)
          @types[namespace][name][element_name] = { :type => inner.attribute('type').to_s, :type_name => local_type_name, :type_namespace => ns }

          defaults = { minOccurs: 0, maxOccurs: 1}
          defaults.each do |attrib, default_value|
            if v = inner.attribute(attrib.to_s)
              @types[namespace][name][element_name][attrib] = v.to_s || defaul_value
            end
          end
        end

        @types[namespace][name][:unordered] ||= []
        @types[namespace][name][:unordered] << element_name
      end

      type.xpath('./xs:complexContent/xs:extension/xs:sequence/xs:element', 'xs' => XSD).each do |inner_element|
        element_name = nil
        if inner_element.attribute('ref')
          element_name = synthetic_ref_id inner_element
          @types[namespace][name][:refs] ||= []
          @types[namespace][name][:refs] << inner_element
        else
          element_name = inner_element.attribute('name').to_s
          local_type_name, ns_pfx = inner_element.attribute('type').to_s.split(':').reverse
          ns = resolve_namespace(inner_element, ns_pfx)
          @types[namespace][name][element_name] = { :type => inner_element.attribute('type').to_s, :type_name => local_type_name, :type_namespace => ns }
        end


        @types[namespace][name][:order!] ||= []
        @types[namespace][name][:order!] << element_name
      end

      type.xpath('./xs:complexContent/xs:extension[@base]', 'xs' => XSD).each do |inherits|
        base = inherits.attribute('base').value.match(/\w+$/).to_s

        if @types[namespace][base]
          # Reverse merge because we don't want subclass attributes to be overriden by base class
          @types[namespace][name] = types[namespace][base].merge(types[namespace][name])
          @types[namespace][name][:order!] = @types[namespace][base][:order!] | @types[namespace][name][:order!]
          @types[namespace][name][:refs] = @types[namespace][base][:refs] | @types[namespace][name][:refs]
          @types[namespace][name].delete(:refs) if @types[namespace][name][:refs].nil?
          @types[namespace][name][:base_type] = base
        else
          p = Proc.new do
            if @types[namespace][base]
              # Reverse merge because we don't want subclass attributes to be overriden by base class
              @types[namespace][name] = @types[namespace][base].merge(@types[namespace][name])
              @types[namespace][name][:order!] = @types[namespace][base][:order!] | @types[namespace][name][:order!]
              @types[namespace][name][:refs] = @types[namespace][base][:refs] | @types[namespace][name][:refs]
              @types[namespace][name].delete(:refs) if @types[namespace][name][:refs].nil?
              @types[namespace][name][:base_type] = base
            end
          end
          deferred_types << p
        end
      end
    end

    def parse_deferred_types
      deferred_types.each(&:call)
    end

    def input_for(operation)
      input_output_for(operation, 'input')
    end

    def output_for(operation)
      input_output_for(operation, 'output')
    end

    def input_output_for(operation, input_output)
      operation_name = operation['name']

      # Look up the input by walking up to portType, then up to the message.

      binding_type = operation.parent['type'].to_s.split(':').last
      if @port_type_operations[binding_type]
        port_type_operation = @port_type_operations[binding_type][operation_name]
      end

      port_type_input_output = port_type_operation &&
        port_type_operation.element_children.find { |node| node.name == input_output }

      # TODO: Stupid fix for missing support for imports.
      # Sometimes portTypes are actually included in a separate WSDL.
      if port_type_input_output
        if port_type_input_output.attribute('message').to_s.include? ':'
          port_message_ns_id, port_message_type = port_type_input_output.attribute('message').to_s.split(':')
        else
          port_message_type = port_type_input_output.attribute('message').to_s
        end

        message_ns_id, message_type = nil

        # When there is a parts attribute in soap:body element, we should use that value
        # to look up the message part from messages array.
        input_output_element = operation.element_children.find { |node| node.name == input_output }
        if input_output_element
          soap_body_element = input_output_element.element_children.find { |node| node.name == 'body' }
          soap_body_parts = soap_body_element['parts'] if soap_body_element
        end

        message = @messages[port_message_type]
        port_message_part = message.element_children.find do |node|
          soap_body_parts.nil? ? (node.name == 'part') : ( node.name == 'part' && node['name'] == soap_body_parts)
        end

        if port_message_part && port_element = port_message_part.attribute('element')
          port_message_part = port_element.to_s
          if port_message_part.include?(':')
            message_ns_id, message_type = port_message_part.split(':')
          else
            message_type = port_message_part
          end
        end

        # Fall back to the name of the binding operation
        if message_type
          [message_ns_id, message_type]
        elsif !message_type && input_output == 'output'
          # if its the output, use the output's name instead of the operation
          [port_message_ns_id, port_message_type]
        else
          [port_message_ns_id, operation_name]
        end
      else
        [nil, operation_name]
      end
    end

    def schemas
      types = section('types').first
      types ? types.element_children : []
    end

    def service
      services = section('service')
      services.first if services  # service nodes could be imported?
    end

    def section(section_name)
      sections[section_name] || []
    end

    def sections
      return @sections if @sections

      sections = {}
      document.root.element_children.each do |node|
        (sections[node.name] ||= []) << node
      end

      @sections = sections
    end

    # returns all types merged with pseudo types
    def all_types
      all = {}
      @types.each { |k,v| all[k] = v }

      @pseudo_types.each do |k,v|
        existing_types = all[k]
        if existing_types.nil?
          all[k] = v
        else
          all[k] = existing_types.merge(v)
        end
      end
      all
    end

    private

    def target_namespace(element)
      return nil if element.nil?

      tns = element.attribute('targetNamespace')
      if tns.nil?
        return target_namespace(element.parent)
      else
        return tns.to_s
      end
    end

    def resolve_namespace(element, prefix)
      ns_key = prefix.nil? ? "xmlns" : "xmlns:#{prefix}"
      element.namespaces[ns_key]
    end

    def operation_for_input_element(element_name, element_namespace)
      document.xpath("wsdl:definitions/wsdl:message/wsdl:part[contains(@element,'#{element_name}')]", "wsdl" => WSDL).each do |element|
        part_name = element['name']
        element.namespaces.each do |k,v|
          ns = k.split(":")[1]
          fully_qualified_element_name = ns.nil? ? element_name : "#{ns}:#{element_name}"
          if v == element_namespace && element.attribute('element').to_s == fully_qualified_element_name
            message_element = element.parent
            message_name = message_element.attribute('name').to_s

            message_namespace = target_namespace(message_element)
            document.xpath("wsdl:definitions/wsdl:portType/wsdl:operation/wsdl:input[contains(@message, '#{message_name}')]", "wsdl" => WSDL).each do |element|
              port_type_operation = element.parent
              port_type_operation_name = port_type_operation.attribute('name')
              port_type = port_type_operation.parent
              port_type_name = port_type.attribute('name')

              element.namespaces.each do |k,v|
                ns = k.split(":")[1]
                fully_qualified_element_name = ns.nil? ? element_name : "#{ns}:#{message_name}"
                if v == message_namespace && element.attribute('message').to_s == fully_qualified_element_name
                  operation_element = element.parent
                  operation_name = operation_element.attribute('name').to_s

                  # check the binding -- if there's a binding, and there's an input defined for the operation, and the body for the input defines a
                  # parts attribute, make sure that the name of the parts attribute matches the name of the part from above.  If not, then we simply
                  # want to return nil
                  document.xpath("wsdl:definitions/wsdl:binding[contains(@type, '#{port_type_name}')]/wsdl:operation[@name = '#{port_type_operation_name}']/wsdl:input", "wsdl" => WSDL).each do |binding_element|
                    soap_body = binding_element.xpath('soap12:body', 'soap12' => SOAP_1_2).first || binding_element.xpath('soap11:body', 'soap11' => SOAP_1_1).first
                    if soap_body
                      parts = soap_body['parts']
                      if parts && !parts.split.include?(part_name)
                        return nil
                      end
                    end
                  end

                  return @operations[operation_name.snakecase.to_sym]
                end
              end
            end

          end
        end
      end

      nil
    end

    def resolve_element_ref(element)
      ref_qname = expand_name(element.attribute('ref').to_s, element)

      namespace = ref_qname[:namespace]
      name = ref_qname[:name]

      ref_element = @top_level_elements[namespace][name]
      ref_element[:name] = name
      ref_element
    end

    def expand_name(name, elt)
      qname = {}

      segments = name.split(":")

      if segments.length == 1
        qname[:namespace_prefix] = nil
        qname[:name] = segments[0]
      else
        qname[:namespace_prefix] = segments.first
        qname[:name] = segments.last
      end

      qname[:namespace] = resolve_namespace(elt, qname[:namespace_prefix])
      qname
    end

    def synthetic_ref_id(element)
      "REF!" + element.attribute('ref').to_s
    end

    def parse_synthetic_ref_id(synthetic_ref_id)
      synthetic_ref_id.gsub /REF\!/, ''
    end

    def create_rpc_pseudo_type(type, elt, operation_identifier, input)
      operation = @operations[operation_identifier]

      message = elt['message']
      message_qname = expand_name(message, elt)

      message_declarations = document.xpath('wsdl:definitions/wsdl:message', 'wsdl' => WSDL).select do |message|
        segments = message['name'].split(':').reverse
        message_localname = segments[0]
        message_qname[:name] == message_localname
      end

      message_declaration = message_declarations.last

      @pseudo_types[type[:type_namespace]] ||= {}
      @pseudo_types[type[:type_namespace]][type[:type_name]] = {}

      pseudo_type = @pseudo_types[type[:type_namespace]][type[:type_name]]

      message_declaration.xpath('./wsdl:part', 'wsdl' => WSDL).each do |part|
        raise "Referencing an element not yet supported from a part declared in a message" if part['type'].nil? && !part['element'].nil?

        part_name = part['name']
        part_type = part['type']

        part_qname = expand_name(part_type, part)

        pseudo_type[:namespace] = type[:type_namespace]
        pseudo_type[:"order!"] ||= []
        pseudo_type[:"order!"] << part_name
        pseudo_type[part_name] ||= {}
        pseudo_type[part_name][:type] = part_type
        pseudo_type[part_name][:type_name] = part_qname[:name]
        pseudo_type[part_name][:type_namespace] = part_qname[:namespace]

        if input
          operation[:parameters] ||= {}
          operation[:parameters][part_name.to_sym] ||= {}
          operation[:parameters][part_name.to_sym][:name] = part_name
          operation[:parameters][part_name.to_sym][:type] = part_qname[:name]
          operation[:parameters][part_name.to_sym][:namespace_identifier] = part_qname[:namespace_prefix]
          operation[:parameters][part_name.to_sym][:namespace] = part_qname[:namespace]
        end
      end
    end
  end
end
