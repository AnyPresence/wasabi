require 'spec_helper'

describe Wasabi::Parser do
  context 'with: marketo.wsdl' do
    subject do
      parser = Wasabi::Parser.new Nokogiri::XML(xml)
      parser.parse
      parser
    end

    let(:xml) { fixture(:marketo).read }

    it 'parses the operations' do
      expect(subject.operations[:get_lead][:input]).to eq({:name=>"paramsGetLead", :namespace_identifier=>"tns", :namespace=>"http://www.marketo.com/mktows/"})
    end
  end
end
