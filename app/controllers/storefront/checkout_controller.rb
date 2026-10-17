module Storefront
  class CheckoutController < BaseController
    include ActionView::Helpers::NumberHelper
    def new
      load_current_order
      if current_order.nil? || current_order.line_items.empty?
        flash[:alert] = "Seu carrinho está vazio."
        return redirect_to root_path
      end
      if current_order.item_total < min_total
        flash[:alert] = "Pedido mínimo de #{view_context.brl(min_total)} ainda não atingido."
        return redirect_to storefront_cart_path
      end
    end

    def create
      load_current_order
      order = current_order
      if order.nil? || order.line_items.empty?
        flash[:alert] = "Seu carrinho está vazio."
        return redirect_to root_path
      end
      if order.item_total < min_total
        flash[:alert] = "Pedido mínimo de #{view_context.brl(min_total)} não atingido."
        return redirect_to storefront_cart_path
      end

      name    = params[:name].to_s.strip
      company = params[:company].to_s.strip
      cnpj    = params[:cnpj].to_s.gsub(/[^0-9]/, '')
      phone   = params[:phone].to_s.strip
      address = params[:address].to_s.strip
      notes   = params[:notes].to_s.strip
      seller  = params[:seller].to_s.strip

      errors = []
      errors << "Nome é obrigatório" if name.blank?
      errors << "Empresa (razão social) é obrigatória" if company.blank?
      errors << "CNPJ inválido (14 dígitos)" unless cnpj.length == 14
      errors << "Telefone/WhatsApp é obrigatório" if phone.blank?
      if errors.any?
        flash.now[:alert] = errors.join("; ")
        return render :new, status: :unprocessable_entity
      end

      order.email = "#{cnpj}@pedido.whatsapp"
      order.public_metadata = (order.public_metadata || {}).merge(
        "canal" => "whatsapp",
        "cliente" => {
          "nome" => name, "empresa" => company, "cnpj" => cnpj,
          "telefone" => phone, "endereco" => address, "observacoes" => notes,
          "vendedor" => seller
        }
      )
      order.save!

      session[:order_id] = nil
      redirect_to storefront_order_complete_path(number: order.number)
    end

    def complete
      @order = Spree::Order.find_by!(number: params[:number])
      @client = @order.public_metadata["cliente"] || {}
      @wa_number = salespeople.find { |s| s[:name].to_s == @client["vendedor"].to_s }&.fetch(:number) || default_whatsapp
      @wa_text = whatsapp_message(@order, @client)
    end

    private

    def min_total
      Rails.application.config.x.wholesale.min_total
    end

    def salespeople
      Rails.application.config.x.whatsapp.salespeople.map { |s| { name: s[:name], number: s[:number] } }
    end

    def default_whatsapp
      Rails.application.config.x.whatsapp.default_number
    end

    def whatsapp_message(order, client)
      money = ->(v) { number_to_currency(v.to_f, locale: :'pt-BR', unit: 'R$', separator: ',', delimiter: '.', format: '%u %n') }
      lines = []
      lines << "*Novo pedido ##{order.number}* (atacado)"
      lines << "Cliente: #{client['nome']} — #{client['empresa']} (CNPJ #{client['cnpj']})"
      lines << "Telefone: #{client['telefone']}"
      lines << "Endereço: #{client['endereco']}" if client['endereco'].present?
      lines << ""
      lines << "*Itens:*"
      order.line_items.each do |li|
        opts = li.variant.option_values.map(&:presentation).join('/')
        opts = opts.present? ? " (#{opts})" : ""
        lines << "• #{li.quantity}x #{li.name}#{opts} — #{money.call(li.price * li.quantity)}"
      end
      lines << ""
      lines << "*Total: #{money.call(order.item_total)}*"
      lines << "Obs: #{client['observacoes']}" if client['observacoes'].present?
      lines.join("\n")
    end
  end
end
