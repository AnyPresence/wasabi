require "spec_helper"

describe Wasabi::Document do
  context "with: schema_using_element_refs.wsdl" do

    subject { Wasabi::Document.new fixture(:schema_using_element_refs).read }

    describe '#operations' do
      subject { super().operations }
      it do
        should include(
          { 
            :save => { 
              :parameters => { 
                'article' => {:name => 'article', :type => 'Article', :namespace_identifier => 'actions', :namespace => 'http://example.com/actions'}, 
                'header' => {:name => 'header', :type => 'Header', :namespace_identifier => 'actions', :namespace => 'http://example.com/actions'}
              }, :input => {
                :name => 'Save', :namespace_identifier => 'actions', :namespace => 'http://example.com/actions'
              }, :output => {
                :name => 'SaveResponse', :namespace_identifier => 'actions', :namespace => 'http://example.com/actions'
              }, 
              :action => "http://example.com/actions.Save", 
              :namespace_identifier => 'actions', 
              :namespace => 'http://example.com/actions' 
            } 
          }
        )
      end
    end

  end
end