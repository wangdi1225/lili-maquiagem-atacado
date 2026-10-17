# Spree's authentication helpers call current_user / user_signed_in? / authenticate_user!
# (Spree::User.model_name.singular_route_key == "user"), while the Devise mapping
# installed by spree_auth_devise is named :spree_user (current_spree_user).
# Inject aliases globally so engine controllers (e.g. Spree::Admin::*) work.
module SpreeDeviseUserAliases
  def current_user
    current_spree_user if respond_to?(:current_spree_user)
  end

  def user_signed_in?
    !!current_user
  end

  def authenticate_user!
    authenticate_spree_user! if respond_to?(:authenticate_spree_user!)
  end
end

Rails.application.config.to_prepare do
  ActionController::Base.include(SpreeDeviseUserAliases)
end
