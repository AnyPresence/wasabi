require "spec_helper"

describe Wasabi::Document do
  context "with: namespaced_actions.wsdl" do

    subject { Wasabi::Document.new fixture(:namespaced_actions).read }

    describe '#namespace' do
      subject { super().namespace }
      it { should == "http://api.example.com/api/" }
    end

    describe '#endpoint' do
      subject { super().endpoint }
      it { should == URI("https://api.example.com/api/api.asmx") }
    end

    describe '#element_form_default' do
      subject { super().element_form_default }
      it { should == :qualified }
    end

    it 'has 3 operations' do
      expect(subject.operations.size).to eq(3)
    end

    describe '#operations' do
      subject { super().operations }
      it do
      should include(
        { :delete_client => { :input => {:name=>"Client.Delete", :namespace_identifier=>"tns", :namespace=>"http://api.example.com/api/"}, :output=>{:name=>"Client.DeleteResponse", :namespace_identifier=>"tns", :namespace=>"http://api.example.com/api/"}, :action => "http://api.example.com/api/Client.Delete", :namespace_identifier => "tns", :parameters=>{:ApiKey=>{:name=>"ApiKey", :type=>"string", :namespace_identifier=>"s", :namespace=>"http://www.w3.org/2001/XMLSchema"}, :ClientID=>{:name=>"ClientID", :type=>"string", :namespace_identifier=>"s", :namespace=>"http://www.w3.org/2001/XMLSchema"}} } },
        { :get_clients   => { :input => {:name=>"User.GetClients", :namespace_identifier=>"tns", :namespace=>"http://api.example.com/api/"}, :output=>{:name=>"User.GetClientsResponse", :namespace_identifier=>"tns", :namespace=>"http://api.example.com/api/"}, :action => "http://api.example.com/api/User.GetClients", :namespace_identifier => "tns", :parameters=>{:ApiKey=>{:name=>"ApiKey", :type=>"string", :namespace_identifier=>"s", :namespace=>"http://www.w3.org/2001/XMLSchema"}} } },
        { :get_api_key   => { :input => {:name=>"User.GetApiKey", :namespace_identifier=>"tns", :namespace=>"http://api.example.com/api/"}, :output => {:name=>"User.GetApiKeyResponse", :namespace_identifier=>"tns", :namespace=>"http://api.example.com/api/"}, :action => "http://api.example.com/api/User.GetApiKey", :namespace_identifier => "tns", :parameters=>{:SiteUrl=>{:name=>"SiteUrl", :type=>"string", :namespace_identifier=>"s", :namespace=>"http://www.w3.org/2001/XMLSchema"}, :Username=>{:name=>"Username", :type=>"string", :namespace_identifier=>"s", :namespace=>"http://www.w3.org/2001/XMLSchema"}, :Password=>{:name=>"Password", :type=>"string", :namespace_identifier=>"s", :namespace=>"http://www.w3.org/2001/XMLSchema"}} } }
      )
    end
    end

  end
end
