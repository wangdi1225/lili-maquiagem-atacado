module Storefront
  class CartController < BaseController
    def show
      load_current_order
    end

    def add
      order = ensure_order!
      variant = Spree::Variant.find(params[:variant_id])
      quantity = [params[:quantity].to_i, 1].max
      result = Spree::Cart::AddItem.call(order: order, variant: variant, quantity: quantity)
      if result.success?
        flash[:notice] = "Produto adicionado ao carrinho."
        redirect_to storefront_cart_path
      else
        flash[:alert] = "Não foi possível adicionar: #{result.error}"
        redirect_back fallback_location: root_path
      end
    rescue StandardError => e
      flash[:alert] = "Não foi possível adicionar: #{e.message}"
      redirect_back fallback_location: root_path
    end

    def update
      order = ensure_order!
      item = order.line_items.find(params[:line_item_id])
      qty = params[:quantity].to_i
      result = if qty <= 0
        Spree::Cart::RemoveLineItem.call(order: order, line_item: item)
      else
        Spree::Cart::SetQuantity.call(order: order, line_item: item, quantity: qty)
      end
      if result.success?
        flash[:notice] = "Carrinho atualizado."
      else
        flash[:alert] = "Erro ao atualizar: #{result.error}"
      end
      redirect_to storefront_cart_path
    rescue StandardError => e
      flash[:alert] = "Erro ao atualizar: #{e.message}"
      redirect_to storefront_cart_path
    end

    def set
      order = ensure_order!
      item = order.line_items.find(params[:id])
      qty = [params[:qty].to_i, 0].max
      result = if qty <= 0
        Spree::Cart::RemoveLineItem.call(order: order, line_item: item)
      else
        Spree::Cart::SetQuantity.call(order: order, line_item: item, quantity: qty)
      end
      redirect_to storefront_cart_path
    rescue StandardError
      redirect_to storefront_cart_path
    end

    def remove
      order = ensure_order!
      item = order.line_items.find(params[:id])
      result = Spree::Cart::RemoveLineItem.call(order: order, line_item: item)
      flash[:notice] = "Item removido." if result.success?
      flash[:alert] = "Erro ao remover: #{result.error}" unless result.success?
      redirect_to storefront_cart_path
    rescue StandardError => e
      flash[:alert] = "Erro ao remover: #{e.message}"
      redirect_to storefront_cart_path
    end
  end
end
