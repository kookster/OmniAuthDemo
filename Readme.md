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

Add to Gemfile:

	gem 'bcrypt-ruby', '~> 3.0.0'

	gem 'omniauth'

	gem 'omniauth-identity'

bundle...


# Identity Model

OmniAuth::Identity is implemented like an external provider, but is resident in your app

Need the identity and user models:

	rails g model identity email:string password_digest:string


Update Identity model to inherit from:

	OmniAuth::Identity::Models::ActiveRecord

Add attribute access:

	attr_accessible :email, :name, :password, :password_confirmation

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


