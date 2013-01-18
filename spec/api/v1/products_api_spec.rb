require 'spec_helper'

describe VersionEye::ProductsApi do
  def encode_prod_key(prod_key)
    prod_key.gsub("/", "--").gsub(".", "~")
  end

  describe "GET detailed info for specific packcage" do
    before(:each) do
      @test_product = ProductFactory.create_new
    end

    after(:each) do
      @test_product.remove
    end

    it "returns same product" do
      prod_key_safe = encode_prod_key(@test_product.prod_key)
      package_url =  "/v1/products/#{prod_key_safe}.json"
      get package_url
      response.status.should eql(200)
      
      response_data = JSON.parse(response.body)
      response_data["name"].should eql(@test_product.name)
    end
  end


  describe "Search packages" do
    before(:each) do
      @test_products = []
      5.times {|i| @test_products << ProductFactory.create_new(i)}
    end

    after(:each) do
      @test_products.each {|item| item.delete}
    end

    it "returns statuscode 400, when search query is too short or missing " do
      get "/v1/products/search/1.json"
      response.status.should eql(400)
    end

    it "returns status 200 and search results with correct parameters" do
      search_term = @test_products[0].name.chop.chop
      get "/v1/products/search/#{search_term}.json"
      response.status.should eql(200)
      response_data = JSON.parse(response.body)
      response_data[0]["name"].should =~ /test_/
    end
  end

  describe "unauthorized user tries to use follow" do
    before(:each) do
      @test_product = ProductFactory.create_new 101
      @safe_prod_key = encode_prod_key(@test_product.prod_key)
   end

    after(:each) do
      @test_product.remove
    end
    it "returns unauthorized error, when lulsec tries to get follow status" do
      get "/v1/products/#{@safe_prod_key}/follow"
      response.status.should == 401
    end 

    it "returns unauthorized error, when lulsec tries to follow package" do
      post "/v1/products/#{@safe_prod_key}/follow"
      response.status.should == 401
    end

    it "returns unauthorized error, when lulSec tries to unfollow"  do
      delete "/v1/products/#{@safe_prod_key}/follow"
      response.status.should == 401
    end

  end

  describe "authorized user tries to use follow" do
      before(:each) do
        @test_product = ProductFactory.create_new 102
        @test_user = UserFactory.create_new
        @user_api = ApiFactory.create_new @test_user
        @safe_prod_key = encode_prod_key(@test_product.prod_key)

        #initialize new session
        post '/v1/sessions', :api_key => @user_api.api_key
      end

      after(:each) do
        @test_product.remove
        @user_api.remove
        @test_user.remove
      end

      it "checking state of follow should be successful" do
        get "/v1/products/#{@safe_prod_key}/follow"
        response.status.should == 200
        response_data =  JSON.parse(response.body)
        response_data["prod_key"].should eql(@test_product.prod_key)
        response_data["follows"].should be_false
      end

      it "returns success if authorized user follows specific package" do
        post "/v1/products/#{@safe_prod_key}/follow"
        response.status.should == 201
        response_data =  JSON.parse(response.body)
        response_data["prod_key"].should eql(@test_product.prod_key)
        response_data["follows"].should be_true 
      end

      it "returns proper response if authorized unfollows specific package" do
        delete "/v1/products/#{@safe_prod_key}/follow"
        response.status.should == 200

        get "/v1/products/#{@safe_prod_key}/follow"
        response_data = JSON.parse(response.body)
        response_data["follows"].should be_false
      end
  end

  describe "accessing follow with instantaneous authorization" do
      before(:each) do
        @test_user = UserFactory.create_new 10
        @test_product = ProductFactory.create_new 103
        @user_api = ApiFactory.create_new @test_user
        @safe_prod_key = encode_prod_key(@test_product.prod_key)
     end

      after(:each) do
        @test_user.remove
        @test_product.remove
        @user_api.remove

        #always logout & clear session
        delete "/v1/sessions"
      end

      it "fails when user skips authorization key" do
        get "/v1/products/#{@safe_prod_key}/follow"
        pp response
        response.status.should == 401
      end

      it "returns success if user, who's not authorized yet, tries to check follow" do
        get "/v1/products/#{@safe_prod_key}/follow", :api_key => @user_api.api_key
        response.status.should == 200

      end
  end
end
