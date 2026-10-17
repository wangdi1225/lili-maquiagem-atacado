Rails.application.routes.draw do
  # Storefront (custom, minimal — catalog + cart + WhatsApp checkout)
  root "storefront/home#index"

  get  "/t/:slug",              to: "storefront/taxons#show",    as: :storefront_taxon
  get  "/products/:slug",       to: "storefront/products#show",  as: :storefront_product
  get  "/cart",                 to: "storefront/cart#show",      as: :storefront_cart
  post "/cart/add",             to: "storefront/cart#add"
  patch "/cart/update",         to: "storefront/cart#update"
  delete "/cart/remove/:id",    to: "storefront/cart#remove",    as: :storefront_cart_remove
  get  "/checkout",             to: "storefront/checkout#new",   as: :storefront_checkout
  post "/checkout",             to: "storefront/checkout#create"
  get  "/pedido/:number",       to: "storefront/checkout#complete", as: :storefront_order_complete

  get "up" => "rails/health#show", as: :rails_health_check

  # Spree engines (admin panel at /admin, API at /api)
  mount Spree::Core::Engine, at: '/'
end
