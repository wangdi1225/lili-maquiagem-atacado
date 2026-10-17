module Storefront
  class SearchController < BaseController
    def show
      @q = params[:q].to_s.strip
      @sort = params[:sort].to_s
      scope = Spree::Product.available
      if @q.present?
        like = "%#{@q.downcase}%"
        scope = scope.left_joins(:variants)
                     .where("lower(spree_products.name) LIKE :l OR lower(spree_products.description) LIKE :l OR lower(spree_variants.sku) LIKE :l", l: like)
                     .distinct
      end
      @products = apply_sort(scope).limit(120)
      @count = @products.size
    end

    private

    def apply_sort(scope)
      case params[:sort]
      when 'price_asc'  then scope.joins(master: :prices).where(spree_prices: { currency: 'BRL' }).order('spree_prices.amount ASC').distinct
      when 'price_desc' then scope.joins(master: :prices).where(spree_prices: { currency: 'BRL' }).order('spree_prices.amount DESC').distinct
      when 'name'       then scope.order(:name)
      else                   scope.order(available_on: :desc)
      end
    end
  end
end
