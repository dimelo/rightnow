# Rightnow

[![Build Status](https://travis-ci.org/dimelo/rightnow.png?branch=master)](https://travis-ci.org/dimelo/rightnow)

Ruby wrapper for the Oracle Rightnow Social API v2

## Installation

Add this line to your application's Gemfile:

    gem 'rightnow-client'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rightnow-client

## Usage

Instanciate a new client with your community url, API keys and API default user:

```ruby
client = Rightnow::Client.new "http://community.company.com", :api_key => "YOUR_PUBLIC_KEY", :secret_key => "YOUR_PRIVATE_KEY", :user => "api@dimelo.com"
```

The user specified here is a user of the community (usually a superadmin) which must have the permissions for all the actions you want to do with the client.

Then you can query the search API with:

```ruby
res = client.search term: 'white', limit: 50
```

Get more details for one or more post:

```ruby
client.post_get res.first
client.post_get ["fa8e6cc713", "fa8e6cb714"]
```

Fetch all comments for a post:

```ruby
client.comment_list res.first
client.comment_list "fa8e6cc713"
```

Add a comment:

```ruby
client.comment_add res.first, "Hello", as: 'user@email.com'
client.comment_add "fa8e6cc713", "Hello", as: 'user@email.com'
```

Edit a comment:

```ruby
client.comment_update res.first, "Hello 2", as: 'user@email.com'
client.comment_update "fa8e6cc713", "Hello 2", as: 'user@email.com'
```

Delete a comment:

```ruby
client.comment_delete 777, as: 'author@email.com'
```

Get more details for one or more users:

```ruby
client.user_get res.first.created_by.hash
client.user_get ["fa8e6cc713", "fa8e6cb714"]
```

Or any other generic request:

```ruby
client.request 'UserList', :as => 'admin@domain.com'
```

## Debug

Instanciate the client with a `:debug => true` option to get debug info:

```ruby
client = Rightnow::Client.new "http://community.company.com", ..., :debug => true
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
