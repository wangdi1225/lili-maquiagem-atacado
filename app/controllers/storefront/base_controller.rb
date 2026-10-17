module Storefront
  class BaseController < ApplicationController
    layout "storefront"
    helper StorefrontHelper

    before_action :load_current_order

    private

    def current_order
      @current_order
    end
    helper_method :current_order

    def load_current_order
      @current_order = if session[:order_id]
        order = Spree::Order.find_by(id: session[:order_id])
        order if order && order.completed_at.nil?
      end
    end

    def ensure_order!
      @current_order ||= Spree::Order.create!(
        store: Spree::Store.default,
        currency: Spree::Store.default.default_currency || 'BRL'
      )
      session[:order_id] = @current_order.id
      @current_order
    end
  end
end
