require "spec_helper"

describe Wasabi::Document do
  context "with: multiple_namespaces.wsdl" do

    subject { Wasabi::Document.new fixture(:multiple_namespaces).read }

    describe '#namespace' do
      subject { super().namespace }
      it { should == "http://example.com/actions" }
    end

    describe '#endpoint' do
      subject { super().endpoint }
      it { should == URI("http://example.com:1234/soap") }
    end

    describe '#element_form_default' do
      subject { super().element_form_default }
      it { should == :qualified }
    end

    it 'has 1 operation' do
      expect(subject.operations.size).to eq(1)
    end

    describe '#operations' do
      subject { super().operations }
      it do
      should == { :save => { :action => "http://example.com/actions.Save", :input=>{:name=>"Save", :namespace_identifier=>"actions", :namespace=>"http://example.com/actions"}, :output=>{:name=>"SaveResponse", :namespace_identifier=>"actions", :namespace=>"http://example.com/actions"}, :namespace_identifier => "actions", :parameters => { :article => { :name => "article", :type => "Article", :namespace_identifier=>"article", :namespace=>"http://example.com/article" } } } }
    end
    end

    describe '#type_namespaces' do
      subject { super().type_namespaces }
      it do
      should =~ [
        [["Save"], "http://example.com/actions"],
        [["Save", "article"], "http://example.com/actions"],
        [["Article"], "http://example.com/article"],
        [["Article", "Author"], "http://example.com/article"],
        [["Article", "Title"], "http://example.com/article"]
      ]
    end
    end

    describe '#type_definitions' do
      subject { super().type_definitions }
      it do
      should =~ [ [["Save", "article"], "Article"] ]
    end
    end

  end
end
