module Storefront
  class TaxonsController < BaseController
    def show
      key = params[:slug].to_s
      @taxon = Spree::Taxon.find_by(permalink: key) ||
               Spree::Taxon.where("permalink LIKE ?", "%/#{key}").first ||
               Spree::Taxon.where("lower(name) = ?", key.downcase.tr('-', ' ')).first
      raise ActiveRecord::RecordNotFound unless @taxon
      @sort = params[:sort].to_s
      scope = @taxon.products.available
      @products = case @sort
                  when 'price_asc'  then scope.joins(master: :prices).where(spree_prices: { currency: 'BRL' }).order('spree_prices.amount ASC').distinct.limit(120)
                  when 'price_desc' then scope.joins(master: :prices).where(spree_prices: { currency: 'BRL' }).order('spree_prices.amount DESC').distinct.limit(120)
                  when 'name'       then scope.order(:name).limit(120)
                  else                   scope.order(:name).limit(120)
                  end
      @count = @products.size
    end
  end
end
