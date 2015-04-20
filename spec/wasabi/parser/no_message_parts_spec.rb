require 'spec_helper'

describe Wasabi::Parser do
  context 'with: no_message_parts.wsdl' do

    subject do
      parser = Wasabi::Parser.new Nokogiri::XML(xml)
      parser.parse
      parser
    end

    let(:xml) { fixture(:no_message_parts).read }

    it 'falls back to using the message type in the port element' do
      # Operation's input has no part element in the message, so using the message type.
      expect(subject.operations[:save][:input]).to eq({:name=>"Save", :namespace_identifier=>"actions", :namespace=>"http://example.com/actions"})

      # Operation's output has part element in the message, so using part element's type.
      expect(subject.operations[:save][:output]).to eq({:name=>"SaveResponse", :namespace_identifier=>"actions", :namespace=>"http://example.com/actions"})
    end

    it 'falls back to using the namespace ID in the port element' do
      expect(subject.operations[:save][:namespace_identifier]).to eq('actions')
    end

    it 'gracefully handles port messages without a colon' do
      expect(subject.operations[:delete][:input]).to eq({:name=>"Delete", :namespace_identifier=>nil, :namespace=>"http://schemas.xmlsoap.org/wsdl/"})
      expect(subject.operations[:delete][:output]).to eq({:name=>"DeleteResponse", :namespace_identifier=>nil, :namespace=>"http://schemas.xmlsoap.org/wsdl/"})
      expect(subject.operations[:delete][:namespace_identifier]).to be_nil
    end
  end
end
