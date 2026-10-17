module Spree
  module AuthenticationHelpers
    def self.included(receiver)
      receiver.helper_method(
        :spree_current_user,
        :spree_login_path,
        :spree_signup_path,
        :spree_logout_path,
        :spree_forgot_password_path,
        :spree_edit_password_path,
        :spree_admin_login_path,
        :spree_admin_logout_path
      )
    end

    def spree_current_user
      current_spree_user if respond_to?(:current_spree_user)
    end

    def spree_login_path(opts = {})
      spree_new_session_path(opts)
    end

    def spree_signup_path(opts = {})
      '/user/spree_user/sign_up'
    end

    def spree_logout_path(opts = {})
      spree_destroy_session_path(opts)
    end

    def spree_forgot_password_path(opts = {})
      '/user/spree_user/password/new'
    end

    def spree_edit_password_path(opts = {})
      '/user/spree_user/edit'
    end

    def spree_admin_login_path(opts = {})
      spree_new_session_path(opts)
    end

    def spree_admin_logout_path(opts = {})
      spree_destroy_session_path(opts)
    end

    private

    def spree_new_session_path(opts = {})
      return spree.new_spree_user_session_path(opts) if respond_to?(:spree) && spree.respond_to?(:new_spree_user_session_path)
      main_app.new_spree_user_session_path(opts)
    rescue NoMethodError
      '/user/spree_user/sign_in'
    end

    def spree_destroy_session_path(opts = {})
      return spree.destroy_spree_user_session_path(opts) if respond_to?(:spree) && spree.respond_to?(:destroy_spree_user_session_path)
      main_app.destroy_spree_user_session_path(opts)
    rescue NoMethodError
      '/user/spree_user/logout'
    end
  end
end

ApplicationController.include Spree::AuthenticationHelpers if defined?(ApplicationController)
