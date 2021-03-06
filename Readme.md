Authentication with OmniAuth
=========================== 

# Basic Demo

- http://omniauthdemo.herokuapp.com/

# Demo Goals

 - Be able to authenticate using multiple means and external services
 - Have app specific login/password as a fallback
 - OmniAuth does both well.
 - Are social logins a good idea? https://blog.mailchimp.com/social-login-buttons-arent-worth-it
 - Regardless, great for SSO, or for adding integration with other services

# Auth Options

 - https://github.com/plataformatec/devise
 - https://github.com/intridea/omniauth
 - https://github.com/binarylogic/authlogic
 - https://github.com/NoamB/sorcery

# Local Faves

 - https://github.com/thoughtbot/clearance
 - https://github.com/dockyard/easy_auth

# OmniAuth?
 
#### "OmniAuth is a Ruby authentication framework aimed to abstract away the difficulties of working with various types of authentication providers. It is meant to be hooked up to just about any system, from social networks to enterprise systems to simple username and password authentication."

- Implemented using a base gem, and pluggable strategies.
- Each strategy is a different gem.
- Does not provide user models, or other convenience methods (e.g. `logged_in?`, `current_user`)
- Works with Devise, CanCan, etc.

# Create Project, Install OmniAuth & Identity

	rails new Project

Add to Gemfile and bundle:

```ruby
gem 'bcrypt-ruby', '~> 3.0.0'

gem 'omniauth'

gem 'omniauth-identity'
```

Now add the rack middleware and options in an initializer.
You can specify what fields to care about, and these show up in the default form.

config/initializers/omniauth.rb:

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
	provider :identity, :fields => [:name, :email]
end
```

# Identity Model

`OmniAuth::Identity` is implemented like an external provider, but it is resident in your app.
Stores email, hashed password, and potentially other info in a model (many persistence options).

Make an `Identity` model:

	rails g model identity email:string password_digest:string

Update Identity model to inherit from:

```ruby
OmniAuth::Identity::Models::ActiveRecord
```

Add attribute access (this is wrong on the identity gem docs):

```ruby
attr_accessible :email, :password, :password_confirmation
```

OmniAuth uses the `/auth/:provider` path as the link to follow to start the authentication process for a provider.

Can test by going to [http://localhost:3000/auth/identity/register](http://localhost:3000/auth/identity/register)


# Sessions

Need a sessions controller and actions for new, create, destroy, failure:

	rails g controller Sessions new create destroy failure

Session new page that links to: `/auth/identity/register`

After you register, tries to take you to a strategy specific callback: `/auth/identity/callback`

routes.rb:
```ruby
match '/auth/:provider/callback', :to => 'sessions#create'
match '/auth/failure', :to => 'sessions#failure'
match '/logout', :to => 'sessions#destroy', :as => 'logout'

root :to => 'sessions#new'
```

This is a bit sneaky: `sessions#create` method for all providers, but could have done one per provider, if that would have helped.
	
Also - when there is an error - a rack var has the login info:

```ruby
def new
	@identity = env['omniauth.identity']
end
```

# Users and Authentications

It's a good practice to have a many-to-one relationship between User and Auhentications.

Devise works this way with OmniAuth, and it makes sense with the goal of one Users with many external identities.

An authentication has the relationship to the user, the name/identifier of the provider, and the UID for the user from thaty provider.  This works for the identity strategy, and external strategies (e.g. {user_id:[user.id], provider:'identity', oid:[identity.id]}):

	rails g model authentication user_id:integer provider:string uid:string

Users should be about the person, and have info about them as domain objects with biz rules, not about how they login to some site:

	rails g model user name:string

Now we need to implement creating the authentication, user, and logging in.

We will implement it to work for identity, but should be very similar to how it works for other providers. The major difference should be in what data comes back from the provider, and how that is used to fill out the models.

### Some login basics (if you aren't using Devise, for example):

application_controller.rb
```ruby
class ApplicationController < ActionController::Base
	protect_from_forgery
	helper_method :current_user, :logged_in?

	private
	def current_user
		@current_user ||= User.find(session[:user_id]) if session[:user_id]
	end

	def current_user=(user)
		session[:user_id] = user.id
		@current_user = user
	end

	def logged_in?
		!!current_user
	end
end
```

### Show when we are logged in

app/views/sessions/new.erb:
```erb
<div>
<% if logged_in? %>

	<b><%= current_user.name %></b> is logged in.

<% else %>
	...
<% end %>
</div>
```
### Finding or Creating Users/Authentications

sessions_controller.rb:
```ruby
def create
	auth_hash = request.env['omniauth.auth']
	authentication = Authentication.find_or_create_from_auth_hash(auth_hash)
	self.current_user = authentication.user
	redirect_to root_url, :notice => "Logged in successfully."
end
```

The 'omniauth.auth' hash, set by omniauth rack middleware, has the info returned from a succssful authentication.

- `auth_hash['provider']` is set to the string name of the provider

- `auth_hash['uid']` is set to some unique id for the user scoped by the provider


Other hashes are usually included, but vary by provider and strategy implementation.

- `auth_hash['info']` typically has basic user info (login, email)

- `auth_hash['extra']` can include this as well, or used for extended profile info

- `auth_hash['credentials']` typically has an access token and expiry for OAuth2 providers

Use these in the models to find/create the `Authentication` & `User`.

authentication.rb
```ruby
def self.find_or_create_from_auth_hash(auth_hash)
	auth = find_by_provider_and_uid(auth_hash['provider'], auth_hash['uid'].to_s)
	unless auth
		user = User.find_or_create_from_auth_hash(auth_hash)

		auth_create_attributes = {
			:provider   => auth_hash['provider'],
			:uid        => auth_hash['uid']
		}
		
		auth = user.authentications.create!(auth_create_attributes)
	end
	auth
end
```

user.rb
```ruby
def self.find_or_create_from_auth_hash(auth_hash)
	info = auth_hash['info']
	name = info['name'] || info['email']
	find_or_create_by_name(name)
end
```

# Adding another provider: omniauth-github

Here is the gem: https://github.com/intridea/omniauth-github

For oauth, nice to be deployed to register an app, so I have the demo app on heroku:

http://omniauthdemo.herokuapp.com/

Add the strategy gem and bundle:

	gem 'omniauth-github'

Add it to the config/init
	
	provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET'], :scope => 'user,repo,gist'

Now go create an app on github, and get the key and secret: https://github.com/settings/applications

Set these in your local env, and on heroku:

.rvmrc (or equivalent)

	export GITHUB_KEY=abcdefghijklmnop
	export GITHUB_SECRET=abcdefghijklmnopabcdefghijklmnopabcdefghijklmnop

heroku cmd line:

	heroku config:add GITHUB_KEY=abcdefghijklmnop
	heroku config:add GITHUB_SECRET=abcdefghijklmnopabcdefghijklmnopabcdefghijklmnop

Add a link to github from the `sessions#new` page:
```erb
<h3>External Providers</h3>
<p><%= link_to "login", "/auth/github" %> with github.</p>
```

### That ought to do it - pretty much everything else we wrote carries over!


FYI - I temporarily logged the auth_hash, to give a sense of what is in there:
```yaml
	--- !map:OmniAuth::AuthHash 
	provider: github
	uid: "46439"
	info: !map:OmniAuth::AuthHash::InfoHash 
		nickname: kookster
		email: andrew_AT_beginsinwonder_DOT_com
		name: Andrew Kuklewicz
		image: https://secure.gravatar.com/avatar/abcdefghiklmnopqrstuvwxyz?d=https://a248.e.akamai.net/assets.github.com%2Fimages%2Fgravatars%2Fgravatar-user-420.png
		urls: !map:Hashie::Mash 
			GitHub: https://github.com/kookster
			Blog: http://beginsinwonder.com
	credentials: !map:Hashie::Mash 
		token: abcdefghiklmnopqrstuvwxyz
		expires: false
	extra: !map:Hashie::Mash 
		raw_info: !map:Hashie::Mash 
			type: User
			login: kookster
			owned_private_repos: 0
			followers: 11
			created_at: "2009-01-14T06:39:27Z"
			company: http://www.prx.org
			email: andrew_AT_beginsinwonder_DOT_com
			disk_usage: 59516
			plan: !map:Hashie::Mash 
				private_repos: 0
				space: 307200
				name: free
				collaborators: 0
			public_gists: 1
			blog: http://beginsinwonder.com
			hireable: false
			avatar_url: https://secure.gravatar.com/avatar/abcdefghiklmnopqrstuvwxyz?d=https://a248.e.akamai.net/assets.github.com%2Fimages%2Fgravatars%2Fgravatar-user-420.png
			private_gists: 0
			following: 8
			html_url: https://github.com/kookster
			name: Andrew Kuklewicz
			bio: Tech Dir @ prx.org
			collaborators: 0
			public_repos: 10
			id: 46439
			total_private_repos: 0
			location: Boston, MA
			url: https://api.github.com/users/kookster
			gravatar_id: abcdefghiklmnopqrstuvwxyz
```

# Next?

- Explore gem, and what strategies are available:
	- https://github.com/intridea/omniauth
	- https://github.com/intridea/omniauth/wiki
	- https://github.com/intridea/omniauth/wiki/List-of-Strategies
- Railscasts!
	- http://railscasts.com/episodes/235-omniauth-part-1
	- http://railscasts.com/episodes/236-omniauth-part-2
	- http://railscasts.com/episodes/241-simple-omniauth
	- http://railscasts.com/episodes/304-omniauth-identity
- Make your own strategies
	- Guide: https://github.com/intridea/omniauth/wiki/Strategy-Contribution-Guide
	- Abstract OAuth2 Strategy: https://github.com/intridea/omniauth-oauth2
	- Mine: https://github.com/PRX/omniauth-prx
- Integrate with Devise
	- https://github.com/plataformatec/devise/wiki/OmniAuth:-Overview
- Capture the credentials/tokens to make API calls
