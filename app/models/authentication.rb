class Authentication < ActiveRecord::Base

  attr_accessible :provider, :uid, :user_id

  belongs_to :user
  validates_presence_of :user_id, :uid, :provider
  validates_uniqueness_of :uid, :scope => :provider

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

end
