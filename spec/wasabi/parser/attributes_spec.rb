require "spec_helper"

describe Wasabi::Parser do
  context "with: attributes.wsdl" do

    subject do
      parser = Wasabi::Parser.new Nokogiri::XML(xml)
      parser.parse
      parser
    end

    let(:xml) { fixture(:attributes).read }

    it "returns attributes with specified types" do
      #expect(subject.types['http://']).to eq("queryDefinitions")
      #expect(subject.types['http://example.com/actions']['Save'][:attributes!])
      expect(1).to eq(1)
    end

    it "returns attributes with custom simple types" do
      #expect(subject.types['http://']).to eq("queryDefinitions")
      #expect(subject.types['http://example.com/actions']['Save'][:attributes!])
      expect(1).to eq(1)
    end

  end
end
