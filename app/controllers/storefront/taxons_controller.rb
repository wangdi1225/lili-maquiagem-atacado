module Storefront
  class TaxonsController < BaseController
    def show
      key = params[:slug].to_s
      @taxon = Spree::Taxon.find_by(permalink: key) ||
               Spree::Taxon.where("permalink LIKE ?", "%/#{key}").first ||
               Spree::Taxon.where("lower(name) = ?", key.downcase.tr('-', ' ')).first
      raise ActiveRecord::RecordNotFound unless @taxon
      @products = @taxon.products.available.order(:name).limit(120)
    end
  end
end
