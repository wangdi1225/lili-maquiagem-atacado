module Storefront
  class HomeController < BaseController
    def index
      @products = with_product_preloads(Spree::Product.available)
                    .order(available_on: :desc).limit(24)
      taxonomy = Spree::Taxonomy.find_by(name: 'Categorias') || Spree::Taxonomy.first
      @taxons = taxonomy ? taxonomy.root.children.to_a : []
    end
  end
end
