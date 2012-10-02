class Identity < OmniAuth::Identity::Models::ActiveRecord
  attr_accessible :email, :name, :password, :password_confirmation
end
