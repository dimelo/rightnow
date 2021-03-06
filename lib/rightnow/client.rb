require 'openssl'
require 'base64'
require 'faraday'
require 'typhoeus'
require 'typhoeus/adapters/faraday'
require 'json'
require 'rexml/document'

module Rightnow
  class Client
    attr_accessor :host, :api_key, :secret_key, :version, :user, :debug

    def initialize host, opts = {}
      @host = host
      @api_key = opts[:api_key]
      @secret_key = opts[:secret_key]
      @user = opts[:user] || 'hl.api@hivelive.com'
      @version = opts[:version] || '2010-05-15'
      @debug = opts[:debug]

      @conn = Faraday.new(:url => host) do |faraday|
        faraday.response :logger if @debug
        faraday.adapter  :typhoeus
      end
    end

    # Send a search query, returning an array of Rightnow::Models::Post
    # results are limited to a few fields
    #
    # opts::
    #   A hash of options accepted by Rightnow's Search method
    #
    # returns::
    #   An array of Rightnow::Models::Post
    #
    # example:
    #   +search :term => 'white', :sort => 'az', :limit => 50, :page => 1+
    #
    def search opts = {}
      opts[:limit] ||= 20
      opts[:objects] ||= 'Posts'
      opts[:start] ||= (opts.delete(:page) - 1) * opts[:limit] + 1 if opts[:page]
      results = request 'Search', opts
      results.map {|r| Rightnow::Models::Post.new(r.underscore) }
    end

    # Retrieve full details for one or more posts.
    # Run multiple queries in parallel.
    #
    # posts::
    #   Either a single element or an array of Rightnow::Models::Post or post hash
    #
    # returns::
    #   A single element or an array of Rightnow::Models::Post
    #   depending on the argument (single value or array)
    #
    # example::
    #   +post_get ["fa8e6cc713", "fa8e6cb714"]+
    #
    def post_get posts
      responses = nil
      @conn.in_parallel do
        responses = [posts].flatten.map do |post|
          hash = post.is_a?(Models::Post) ? post.hash : post
          @conn.get 'api/endpoint', signed_params('PostGet', 'postHash' => hash)
        end
      end
      result = responses.zip([posts].flatten).map do |res, post|
        data = parse(res).underscore['post']
        if post.is_a? Models::Post
          post.attributes = data
          post
        elsif data.is_a? Hash
          Rightnow::Models::Post.new(data.merge(:hash => post))
        else
          nil
        end
      end
      posts.is_a?(Array) ? result : result.first
    end

    # Retrieve full details for one or more users.
    # Run multiple queries in parallel.
    #
    # users::
    #   Either a single element or an array of Rightnow::Models::User or user hash
    #
    # returns::
    #   A single element or an array of Rightnow::Models::User
    #   depending on the argument (single value or array)
    #
    # example::
    #   +user_get ["fa8e6cc713", "fa8e6cb714"]+
    #
    def user_get users
      responses = nil
      @conn.in_parallel do
        responses = [users].flatten.map do |user|
          hash = user.is_a?(Models::User) ? user.hash : user
          @conn.get 'api/endpoint', signed_params('UserGet', 'UserHash' => hash)
        end
      end
      result = responses.zip([users].flatten).map do |res, user|
        data = parse(res).underscore['user']
        if user.is_a? Models::User
          user.attributes = data
          user
        elsif data.is_a? Hash
          Rightnow::Models::User.new(data.merge(:hash => user))
        else
          nil
          end
      end
      users.is_a?(Array) ? result : result.first
    end

    # Retrieve comment list for a post.
    #
    # post::
    #   An instance of Rightnow::Models::Post or a post hash (String)
    #
    # returns::
    #   An array of Rightnow::Comment
    #
    # example::
    #   +comment_list "fa8e6cc713"+
    #
    def comment_list post, opts = {}
      hash = post.is_a?(Models::Post) ? post.hash : post
      results = request 'CommentList', opts.merge('postHash' => hash)
      raise Rightnow::Error.new("Missing `comments` key in CommentList response: #{results.inspect}") if not results['comments']
      results.underscore['comments'].map { |r| Rightnow::Models::Comment.new(r) }
    end

    # Add a comment to a post.
    #
    # post::
    #   An instance of Rightnow::Models::Post or a post hash (String)
    #
    # body::
    #   The body of the comment (String)
    #
    # returns::
    #   The instance of the newly created Rightnow::Comment
    #
    # example::
    #   +comment_add "fa8e6cc713", "+1", :as => 'someone@domain.com'+
    #
    def comment_add post, body, opts = {}
      hash = post.is_a?(Models::Post) ? post.hash : post
      results = request 'CommentAdd', opts.merge('postHash' => hash, 'payload' => comment_xml_payload(body).to_s, :verb => :post)
      raise Rightnow::Error.new("Missing `comment` key in CommentAdd response: #{results.inspect}") if not results['comment']
      Rightnow::Models::Comment.new results['comment'].underscore
    end

    # Edit a comment.
    #
    # comment::
    #   An instance of Rightnow::Models::Comment or a comment id (Integer)
    #
    # comment::
    #   The updated body of the comment (String)
    #
    # returns::
    #   The instance of the updated Rightnow::Comment
    #
    # example::
    #   +comment_update 94224, "+1", :as => 'someone@domain.com'+
    #
    def comment_update comment, body, opts = {}
      id = comment.is_a?(Models::Comment) ? comment.id : comment
      results = request 'CommentUpdate', opts.merge('commentId' => id, 'payload' => comment_xml_payload(body, :for => :update).to_s, :verb => :post)
      raise Rightnow::Error.new("Missing `comment` key in CommentUpdate response: #{results.inspect}") if not results['comment']
      Rightnow::Models::Comment.new results['comment'].underscore
    end

    # Delete a comment.
    #
    # comment::
    #   The id of the comment (Integer)
    #
    # example::
    #   +comment_delete 777+
    #
    def comment_delete comment, opts = {}
      request 'CommentDelete', opts.merge('commentId' => comment)
    end

    def request action, opts = {}
      verb = opts.delete(:verb) || :get
      response = @conn.send(verb, 'api/endpoint', signed_params(action, opts))
      puts response.body if @debug
      parse response
    end

  protected

    def parse response
      body = JSON.parse(response.body || '')
      if body.is_a?(Hash) and body.size == 1 and body['error'].is_a?(Hash)
        raise Rightnow::Error.new(body['error']['message'], body['error']['code'])
      elsif response.status != 200
        raise Rightnow::Error.new("API returned #{response.status} without explanation: #{response.body}")
      end
      body
    rescue JSON::ParserError
      raise Rightnow::JsonParseError.new(response.body)
    end

    def comment_xml_payload comment, opts = {}
      xml = '<?xml version="1.0"?><comments><comment><value></value></comment></comments>'
      # CommentUpdate action uses a slightly different markup -_-
      xml.gsub!(/<\/?comments>/, '') if opts[:for] == :update
      doc = REXML::Document.new xml
      doc.elements['//value'].add REXML::CData.new comment
      doc
    end

    def signed_params action, opts = {}
      opts ||= {} if not opts.is_a? Hash
      params = {
        'Action' => action,
        'ApiKey' => api_key,
        'PermissionedAs' => opts.delete(:as) || @user,
        'SignatureVersion' => '2',
        'version' => version
      }
      signstr = params.keys.sort_by(&:downcase).map {|k| "#{k}#{params[k]}" }.join
      signature = Base64.strict_encode64(OpenSSL::HMAC::digest("sha1", secret_key, signstr))
      params.merge({
        'Signature' => signature,
        'format' => 'json'
      }).merge(opts)
    end
  end
end