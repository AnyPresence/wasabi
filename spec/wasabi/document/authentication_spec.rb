require "spec_helper"

describe Wasabi::Document do
  context "with: authentication.wsdl" do

    subject { Wasabi::Document.new fixture(:authentication).read }

    describe '#namespace' do
      subject { super().namespace }
      it { should == "http://v1_0.ws.auth.order.example.com/" }
    end

    describe '#endpoint' do
      subject { super().endpoint }
      it { should == URI("http://example.com/validation/1.0/AuthenticationService") }
    end

    describe '#element_form_default' do
      subject { super().element_form_default }
      it { should == :unqualified }
    end

    it 'has 1 operation' do
      expect(subject.operations.size).to eq(1)
    end

    describe '#operations' do
      subject { super().operations }
      it do
      should == {
        :authenticate => { :action => "authenticate", :input => {:name => "authenticate", :namespace_identifier=>"tns", :namespace=>"http://v1_0.ws.auth.order.example.com/" }, :output => {:name => "authenticateResponse", :namespace_identifier=>"tns", :namespace=>"http://v1_0.ws.auth.order.example.com/"}, :namespace_identifier=>"tns", :namespace=>"http://v1_0.ws.auth.order.example.com/", :parameters => { :user => { :name=>"user", :type=>"string", :namespace_identifier => "xs", :namespace => "http://www.w3.org/2001/XMLSchema" }, :password => { :name=>"password", :type=>"string", :namespace_identifier => "xs", :namespace => "http://www.w3.org/2001/XMLSchema" } } }
      }
    end
    end

  end
end
