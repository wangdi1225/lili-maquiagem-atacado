module Storefront
  class ProductsController < BaseController
    def show
      @product = with_product_preloads(Spree::Product.available)
                   .includes(variants_including_master: :option_values)
                   .find_by!(slug: params[:slug])
      @variants = @product.variants_including_master.reject(&:is_master)
      @variants = [@product.variants_including_master.find(&:is_master)].compact if @variants.empty?
    end
  end
end
