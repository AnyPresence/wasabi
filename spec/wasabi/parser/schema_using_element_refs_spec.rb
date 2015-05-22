require 'spec_helper'

describe Wasabi::Parser do
  context 'with: types_with_same_name_in_separate_namespaces.wsdl' do
    subject do
      parser = Wasabi::Parser.new Nokogiri::XML(xml)
      parser.parse
      parser
    end

    let(:xml) { fixture(:schema_using_element_refs).read }

    it 'parses element references nested inside elements' do
      expect(subject.types['http://example.com/actions']['Save']['article']).to eq({:type => 'Article', :type_name => 'Article', :type_namespace => 'http://example.com/actions'})
      expect(subject.types['http://example.com/actions']['Save']['header']).to eq({:type => 'Header', :type_name => 'Header', :type_namespace => 'http://example.com/actions'})
      expect(subject.types['http://example.com/actions']['Save'][:order!]).to eq(['article', 'header'])
    end
    
    it 'parses element references nested inside complexTypes' do
      expect(subject.types['http://example.com/actions']['Header']['additionalInfo']).to eq({:type => 'string', :type_name => 'string', :type_namespace => 'http://www.w3.org/2001/XMLSchema'})
      expect(subject.types['http://example.com/actions']['Header'][:order!]).to eq(['ActionHeaderField1', 'Description', 'additionalInfo'])
    end
    
  end
end
