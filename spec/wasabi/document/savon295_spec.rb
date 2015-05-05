require "spec_helper"

describe Wasabi::Document do
  context "with: savon295.wsdl" do

    subject { Wasabi::Document.new fixture(:savon295).read }

    describe '#operations' do
      subject { super().operations }
      it do
      should include(
        { :sendsms => { :input=>{:name=>"sendsms", :namespace_identifier=>"tns", :namespace=>"http://bedrift.telefonkatalogen.no"}, :output=>{:name=>"sendsmsResponse", :namespace_identifier=>"tns", :namespace=>"http://bedrift.telefonkatalogen.no"}, :action => "sendsms", :namespace_identifier => "tns", :namespace=>"http://bedrift.telefonkatalogen.no" } }
      )
    end
    end

  end
end
