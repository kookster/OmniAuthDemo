Authentication with OmniAuth
=========================== 

# Intro
	
- Authentication, Authorization, Identity, Profile
- Security, Password reuse, Encryption, Privacy
- Protocols - OpenId, OAuth(2), CAS, Mozilla Persona (browserid)

# Demo Goals

 - Be able to authenticate using multiple means and external services
 - Have app specific login/password as a fallback
 - OmniAuth does both well.

# Auth Options

 - plataformatec/devise
 - intridea/omniauth
 - binarylogic/authlogic
 - NoamB/sorcery

# Local Faves

 - thoughtbot/clearance
 - dockyard/easy_auth

# Create Project and Install OmniAuth

	rails new Project

Add to Gemfile and bundle:

	gem 'bcrypt-ruby', '~> 3.0.0'

	gem 'omniauth'

	gem 'omniauth-identity'


Now add the rack middleware and options in an initializer.
You can specify what fields to care about, and these show up in the default form.

config/initializers/omniauth.rb:

	Rails.application.config.middleware.use OmniAuth::Builder do
		provider :identity, :fields => [:name, :email]
	end


# Identity Model

OmniAuth::Identity is implemented like an external provider, but is resident in your app

Need the identity and user models:

	rails g model identity email:string password_digest:string

Update Identity model to inherit from:

	OmniAuth::Identity::Models::ActiveRecord

Add attribute access:

	attr_accessible :email, :password, :password_confirmation

Can test by going to [http://localhost:3000/auth/identity/register](http://localhost:3000/auth/identity/register)

# Sessions

Need a sessions controller and actions for new, create, destroy, failure:

	rails g controller Sessions new create destroy failure


Session new page that links to: `/auth/identity/register`

After you register, tries to take you to a strategy specific callback: `/auth/identity/callback`

routes.rb:

	match '/auth/:provider/callback', :to => 'sessions#create'
	match '/auth/failure', :to => 'sessions#failure'
	match '/logout', :to => 'sessions#destroy', :as => 'logout'

	root :to => 'sessions#new'


(Don't forget to delete the `public/index.html` to make root work.)
	
Also - when there is an error - a rack var has the login info:

	def new
		@identity = env['omniauth.identity']
	end


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

### Finding or Creating Users/Authentications

sessions_controller.rb:

	def create
		auth_hash = request.env['omniauth.auth']
		authentication = Authentication.find_or_create_from_auth_hash(auth_hash)
		self.current_user = authentication.user
		redirect_to root_url, :notice => "Logged in successfully."
	end

The 'omniauth.auth' hash, set by omniauth rack middleware, has the info returned from a succssful authentication.

- `auth_hash['provider']` is set to the string name of the provider

- `auth_hash['uid']` is set to some unique id for the user scoped by the provider


Other hashes are usually included, but vary by provider and strategy implementation.

- `auth_hash['info']` typically has basic user info (login, email)

- `auth_hash['extra']` can include this as well, or used for extended profile info

- `auth_hash['credentials']` typically has an access token and expiry for OAuth2 providers

Use these in the models to find/create the `Authentication` & `User`.

authentication.rb

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

user.rb

	def self.find_or_create_from_auth_hash(auth_hash)
		info = auth_hash['info']
		name = info['name'] || info['email']
		find_or_create_by_name(name)
	end

# Adding another provider: omniauth-github

Add the strategy gem and bundle:

	gem 'omniauth-github'

Add it to the config/init
	
	provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET'], :scope => 'user,repo,gist'

Now go create an app on github, and get the key and secret.

Set these in your local env, and on heroku:

.rvmrc (or equivalent)

	export GITHUB_KEY=abcdefghijklmnop
	export GITHUB_SECRET=abcdefghijklmnopabcdefghijklmnopabcdefghijklmnop

heroku cmd line:

	heroku config:add GITHUB_KEY=abcdefghijklmnop
	heroku config:add GITHUB_SECRET=abcdefghijklmnopabcdefghijklmnopabcdefghijklmnop

