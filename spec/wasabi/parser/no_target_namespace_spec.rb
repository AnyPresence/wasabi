require "spec_helper"

describe Wasabi::Parser do
  context "with a WSDL defining xs:schema without targetNamespace" do

    subject do
      parser = Wasabi::Parser.new Nokogiri::XML(xml)
      parser.parse
      parser
    end

    let(:xml) do
      %Q{
        <definitions xmlns='http://schemas.xmlsoap.org/wsdl/'
          xmlns:xs='http://www.w3.org/2001/XMLSchema'
          targetNamespace='http://def.example.com'>
          <types>
            <xs:schema elementFormDefault='qualified'>
              <xs:element name='Save'>
                <xs:complexType></xs:complexType>
              </xs:element>
            </xs:schema>
          </types>
        </definitions>
      }
    end

    it "assigns types to the nil namespace when targetNamespace is omitted from schema" do
      expect(subject.types[nil]["Save"][:namespace]).to eq(nil)
    end

  end
end
