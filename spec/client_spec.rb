require 'spec_helper'

describe Rightnow::Client do
  let(:client) { Rightnow::Client.new "http://something", :api_key => "API", :secret_key => "SECRET" }

  describe ".initialize" do
    it "should store host and default attributes" do
      client = Rightnow::Client.new "http://community.company.com"
      client.host.should == "http://community.company.com"
      client.api_key.should == nil
      client.secret_key.should == nil
      client.version.should == '2010-05-15'
      client.user.should == 'hl.api@hivelive.com'
    end

    it "accepts options" do
      client = Rightnow::Client.new "host", :api_key => "APIKEY", :secret_key => "SECRETKEY", :version => '2042-13-13', :user => 'api@domain.com'
      client.api_key.should == "APIKEY"
      client.secret_key.should == "SECRETKEY"
      client.version.should == '2042-13-13'
      client.user.should == 'api@domain.com'
    end
  end

  describe '#search' do
    it "compute correct request" do
      stub_request(:get, "http://something/api/endpoint?Action=Search&ApiKey=API&PermissionedAs=hl.api@hivelive.com&Signature=nwmG/dgt9MLvq1CXWTtSLqcaaaY=&SignatureVersion=2&format=json&limit=20&objects=Posts&sort=az&start=21&term=white&version=2010-05-15").to_return :body => '[]'
      client.search(:term => 'white', :sort => 'az', :page => 2).should == []
    end

    it "accepts `as` option" do
      stub_request(:get, "http://something/api/endpoint?Action=Search&ApiKey=API&PermissionedAs=api@domain.com&Signature=MmHBXKKsEfJJPX8EW%2B8ZqMnGEGc=&SignatureVersion=2&format=json&limit=20&objects=Posts&sort=az&start=21&term=white&version=2010-05-15").to_return :body => '[]'
      client.search(:term => 'white', :sort => 'az', :page => 2, :as => 'api@domain.com').should == []
    end

    it "returns correctly parsed response" do
      stub_request(:get, /.*/).to_return :body => fixture('search.json')
      response = client.search
      response.size.should == 5
      response.first.should be_instance_of(Rightnow::Models::Post)
    end
  end

  describe '#post_get' do
    it "compute correct request" do
      stub_request(:get, "http://something/api/endpoint?Action=PostGet&ApiKey=API&PermissionedAs=hl.api@hivelive.com&Signature=bFdCqLpLcCHT3jQEz7nndKrVVk8=&SignatureVersion=2&format=json&postHash=fa8e6cc713&version=2010-05-15").to_return :body => '{}'
      client.post_get("fa8e6cc713").should be_nil
    end

    context "with stubbed answer" do
      before { stub_request(:get, /.*/).to_return :body => fixture('post_get.json') }

      it "returns correctly parsed response" do
        response = client.post_get "fa8e6cc713"
        response.should be_instance_of(Rightnow::Models::Post)
        response.view_count.should == 795
        response.hash.should == "fa8e6cc713"
      end

      it "accepts multiple elements" do
        posts = client.post_get ["fa8e6cc713", "fa8e6cb714"]
        posts.size.should == 2
        posts.first.should be_instance_of(Rightnow::Models::Post)
      end

      it "accepts Rightnow::Post instances" do
        post = Rightnow::Models::Post.new(:hash => "fa8e6cc713")
        res = client.post_get post
        res.should be_instance_of(Rightnow::Models::Post)
        res.view_count.should == 795
      end

      it "merges input Rightnow::Post instance with results" do
        post = Rightnow::Models::Post.new(:hash => "fa8e6cc713")
        res = client.post_get post
        res.view_count.should == 795
        res.hash.should == "fa8e6cc713"
      end
    end
  end

  describe '#comment_list' do
    it "compute correct request" do
      stub_request(:get, "http://something/api/endpoint?Action=CommentList&ApiKey=API&PermissionedAs=toto&Signature=0J8ggfqObzTGxydijxgdLSvNzds=&SignatureVersion=2&format=json&postHash=fa8e6cc713&version=2010-05-15").to_return :body => '{"comments": []}'
      client.comment_list("fa8e6cc713", as: 'toto').should == []
      # the `as: 'toto'` hack is just here to change the signature,
      # webmock doesn't like the original one: AEyyp+MpfxT/DlhRqAfzvT1dFCM
    end

    it "raise error in case of bad return value" do
      stub_request(:get, /.*/).to_return body: '{}'
      expect {
        client.comment_list "fa8e6cc713"
      }.to raise_error(Rightnow::Error, "Missing `comments` key in CommentList response: {}")
    end

    context "with stubbed answer" do
      before { stub_request(:get, /.*/).to_return body: fixture('comment_list.json') }

      it "returns correctly parsed response" do
        response = client.comment_list "fa8e6cc713"
        response.size.should == 3
        response.first.should be_instance_of(Rightnow::Models::Comment)
      end
    end
  end

  describe '#comment_add' do
    it "compute correct request" do
      stub_request(:post, "http://something/api/endpoint").with(:body => {"Action"=>"CommentAdd", "ApiKey"=>"API", "PermissionedAs"=>"toto", "Signature"=>"kJXXoPZ7xexKxv8duTYmtS519GY=", "SignatureVersion"=>"2", "format"=>"json", "payload"=>"<?xml version='1.0'?><comments><comment><value><![CDATA[test]]></value></comment></comments>", "postHash"=>"fa8e6cc713", "version"=>"2010-05-15"}).to_return :body => '{"comment": {}}'
      client.comment_add("fa8e6cc713", 'test', as: 'toto')
    end

    it "return comment model" do
      stub_request(:post, "http://something/api/endpoint").to_return :body => fixture('comment_add.json')
      client.comment_add("fa8e6cc713", 'test', as: 'toto').should be_instance_of Rightnow::Models::Comment
    end
  end

  describe '#comment_update' do

    it "return comment model" do
      stub_request(:post, "http://something/api/endpoint").to_return :body => fixture('comment_add.json')
      client.comment_update(777, 'test', as: 'toto').should be_instance_of Rightnow::Models::Comment
    end
  end

  describe '#comment_delete' do
    it "compute correct request" do
      stub_request(:get, "http://something/api/endpoint?Action=CommentDelete&ApiKey=API&PermissionedAs=hl.api@hivelive.com&Signature=BdDIajOi/eZprayZ8X8eEsH1yb4=&SignatureVersion=2&commentId=777&format=json&version=2010-05-15").to_return body: '{"comment": {"id": 777}}'
      client.comment_delete(777).should == {'comment' => {'id' => 777}}
    end
  end

  describe "#request" do
    it "compute correct request" do
      stub_request(:get, "http://something/api/endpoint?Action=UserList&ApiKey=API&PermissionedAs=hl.api@hivelive.com&Signature=wLTpdU5EEyYBlDg%2BMz5AGEAPs98=&SignatureVersion=2&format=json&version=2010-05-15").to_return :body => '{}'
      client.request('UserList').should == {}
    end

    it "raise correct exceptions on 401" do
      stub_request(:get, /.*/).to_return(:status => 401, :body => '{"error":{"message":"invalid parameter","code":42}}')
      expect {
        client.request 'UserList'
      }.to raise_error(Rightnow::Error, "invalid parameter (42)")
    end

    it "raise correct exceptions on error without details" do
      stub_request(:get, /.*/).to_return(:status => 401, :body => '{"something":"happened"}')
      expect {
        client.request 'UserList'
      }.to raise_error(Rightnow::Error, 'API returned 401 without explanation: {"something":"happened"}')
    end

    it "raise correct exceptions on bad JSON" do
      stub_request(:get, /.*/).to_return(:status => 200, :body => 'bad')
      expect {
        client.request 'UserList'
      }.to raise_error(Rightnow::JsonParseError, 'bad')
    end

    it "parse JSON response correctly" do
      stub_request(:get, /.*/).
        to_return(:status => 200, :body => fixture('search.json'))
      results = client.request 'Search'
      results.size.should == 5
      results.first.should == fixture('post.rb', :ruby)
    end
  end

  describe "#comment_xml_paypload" do
    it "should generate correct XML payload" do
      client.send(:comment_xml_payload, "test").to_s.should == "<?xml version='1.0'?><comments><comment><value><![CDATA[test]]></value></comment></comments>"
    end
  end

  describe "#signed_params" do
    subject { client.send :signed_params, "Something" }

    it { should include('Action' => 'Something', 'ApiKey' => 'API') }
    it { should include('version' => '2010-05-15', 'SignatureVersion' => '2') }
    it { should include('PermissionedAs' => 'hl.api@hivelive.com') }
    it { should include('Signature' => 'vIONtWGXvdAG/McOTM0KuFD+O2g=') }
    it { should include('format' => 'json') }
    it { subject.size.should == 7 }

    context "with custom permission" do
      subject { client.send :signed_params, "Something", :as => 'email@domain.com' }

      it { should include('PermissionedAs' => 'email@domain.com') }
      it { should include('Signature' => 'i66NBNtwG21kxDHYOVMQpb7bhzk=') }
      it { should_not include('as') }
    end

    context "with custom values" do
      subject { client.send :signed_params, "Something", 'term' => 'white' }

      it { should include('Signature' => 'vIONtWGXvdAG/McOTM0KuFD+O2g=') }
      it { should include('term' => 'white') }
    end

    context "with custom user in client" do
      before { client.user = 'api@domain.com' }

      it { should include('PermissionedAs' => 'api@domain.com') }
      it { should include('Signature' => 'tdUCB7FafhflaQ/pCIWK+NQnhMY=') }
      it { should_not include('as') }
    end

  end
end