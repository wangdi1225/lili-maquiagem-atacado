module Storefront
  class TaxonsController < BaseController
    def show
      key = params[:slug].to_s
      @taxon = Spree::Taxon.find_by(permalink: key) ||
               Spree::Taxon.where("permalink LIKE ?", "%/#{key}").first ||
               Spree::Taxon.where("lower(name) = ?", key.downcase.tr('-', ' ')).first
      raise ActiveRecord::RecordNotFound unless @taxon
      @sort = params[:sort].to_s
      @page = [params[:page].to_i, 1].max
      per = 24
      scope = @taxon.products.available
      sorted = case @sort
               when 'price_asc'  then scope.joins(master: :prices).where(spree_prices: { currency: 'BRL' }).order('spree_prices.amount ASC').distinct
               when 'price_desc' then scope.joins(master: :prices).where(spree_prices: { currency: 'BRL' }).order('spree_prices.amount DESC').distinct
               else                   scope.order(:name)
               end
      @count = @taxon.products.available.count
      @total_pages = [(@count.to_f / per).ceil, 1].max
      @page = [@page, @total_pages].min
      @products = sorted.includes(variants_including_master: :images).limit(per).offset((@page - 1) * per)
    end
  end
end
