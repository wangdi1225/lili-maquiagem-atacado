class Spree::UserSessionsController < Devise::SessionsController
  layout false

  protected

  def after_sign_in_path_for(_resource)
    '/admin'
  end

  def after_sign_out_path_for(_resource_or_scope)
    '/user/spree_user/sign_in'
  end
end
