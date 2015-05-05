require "spec_helper"

describe Wasabi::Document do
  context "with: no_namespace.wsdl" do

    subject { Wasabi::Document.new fixture(:no_namespace).read }

    describe '#namespace' do
      subject { super().namespace }
      it { should == "urn:ActionWebService" }
    end

    describe '#endpoint' do
      subject { super().endpoint }
      it { should == URI("http://example.com/api/api") }
    end

    describe '#element_form_default' do
      subject { super().element_form_default }
      it { should == :unqualified }
    end

    it 'has 3 operations' do
      expect(subject.operations.size).to eq(3)
    end

    describe '#operations' do
      subject { super().operations }
      it do
      should include(
        { :get_user_login_by_id => { :input=>{:name=>"GetUserLoginById", :namespace_identifier=>"typens", :namespace=>"urn:ActionWebService"}, :output=>{:name=>"GetUserLoginByIdResponse", :namespace_identifier=>"typens", :namespace=>"urn:ActionWebService"}, :action => "/api/api/GetUserLoginById", :namespace_identifier => "typens", :namespace => "urn:ActionWebService" } },
        { :get_all_contacts => { :input=>{:name=>"GetAllContacts", :namespace_identifier=>"typens", :namespace=>"urn:ActionWebService"}, :output=>{:name=>"GetAllContactsResponse", :namespace_identifier=>"typens", :namespace=>"urn:ActionWebService"}, :action => "/api/api/GetAllContacts", :namespace_identifier => "typens", :namespace => "urn:ActionWebService" } },
        { :search_user => { :input=>{:name=>"SearchUser", :namespace_identifier=>nil, :namespace=>"http://schemas.xmlsoap.org/wsdl/"}, :output=>{:name=>"SearchUserResponse", :namespace_identifier=>nil, :namespace=>"http://schemas.xmlsoap.org/wsdl/"}, :action => "/api/api/SearchUser", :namespace_identifier => nil, :namespace => "http://schemas.xmlsoap.org/wsdl/" } }
      )
    end
    end

  end
end
