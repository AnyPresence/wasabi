require "spec_helper"

params = {
  :sender => {
    :name => 'sender', 
    :type => 'string',
    :namespace_identifier => 'xsd',
    :namespace => 'http://www.w3.org/2001/XMLSchema'
  },
  :cellular => {
    :name => 'cellular',
    :type => 'string',
    :namespace_identifier => 'xsd',
    :namespace => 'http://www.w3.org/2001/XMLSchema'
  },
  :msg => {
    :name => 'msg',
    :type => 'string',
    :namespace_identifier => 'xsd',
    :namespace => 'http://www.w3.org/2001/XMLSchema'
  },
  :smsnumgroup => {
    :name => 'smsnumgroup',
    :type => 'string',
    :namespace_identifier => 'xsd',
    :namespace => 'http://www.w3.org/2001/XMLSchema'
  },
  :emailaddr => {
    :name => 'emailaddr',
    :type => 'string',
    :namespace_identifier => 'xsd',
    :namespace => 'http://www.w3.org/2001/XMLSchema'
  },
  :udh => {
    :name => 'udh',
    :type => 'string',
    :namespace_identifier => 'xsd',
    :namespace => 'http://www.w3.org/2001/XMLSchema'
  },
  :datetime => {
    :name => 'datetime',
    :type => 'string',
    :namespace_identifier => 'xsd',
    :namespace => 'http://www.w3.org/2001/XMLSchema'
  },
  :format => {
    :name => 'format',
    :type => 'string',
    :namespace_identifier => 'xsd',
    :namespace => 'http://www.w3.org/2001/XMLSchema'
  },
  :dlrurl => {
    :name => 'dlrurl',
    :type => 'string',
    :namespace_identifier => 'xsd',
    :namespace => 'http://www.w3.org/2001/XMLSchema'
  }
}


describe Wasabi::Document do
  context "with: savon295.wsdl" do

    subject { Wasabi::Document.new fixture(:savon295).read }

    describe '#operations' do
      subject { super().operations }
      it do
      should include(
        { :sendsms => { :parameters => params, :input=>{:name=>"sendsms", :namespace_identifier=>"tns", :namespace=>"http://bedrift.telefonkatalogen.no"}, :output=>{:name=>"sendsmsResponse", :namespace_identifier=>"tns", :namespace=>"http://bedrift.telefonkatalogen.no"}, :action => "sendsms", :namespace_identifier => "tns", :namespace=>"http://bedrift.telefonkatalogen.no" } }
      )
    end
    end

  end
end
