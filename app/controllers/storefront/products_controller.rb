module Storefront
  class ProductsController < BaseController
    def show
      @product = Spree::Product.available.find_by!(slug: params[:slug])
      @variants = if @product.variants.any?
        @product.variants.order(:position)
      else
        [@product.master]
      end
    end
  end
end
