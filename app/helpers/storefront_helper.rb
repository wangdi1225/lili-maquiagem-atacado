module StorefrontHelper
  def brl(amount)
    number_to_currency(amount.to_f, locale: :'pt-BR', unit: 'R$', separator: ',', delimiter: '.', format: '%u %n')
  end

  def root_taxons
    @root_taxons ||= begin
      taxonomy = Spree::Taxonomy.find_by(name: 'Categorias') || Spree::Taxonomy.first
      taxonomy ? taxonomy.root.children.to_a : []
    end
  end

  def wholesale_min_total
    Rails.application.config.x.wholesale.min_total
  end

  def default_whatsapp
    Rails.application.config.x.whatsapp.default_number
  end

  def salespeople
    Rails.application.config.x.whatsapp.salespeople
  end

  def product_image(product, css: "w-full h-48 object-cover")
    img = product.images.first
    if img
      image_tag main_app.url_for(img), class: css, loading: "lazy", alt: product.name
    else
      tag.div(class: "#{css} bg-pink-100 flex items-center justify-center text-5xl", alt: product.name) { "💄" }
    end
  end

  def whatsapp_quote_link(order)
    money = ->(v) { number_to_currency(v.to_f, locale: :'pt-BR', unit: 'R$', separator: ',', delimiter: '.', format: '%u %n') }
    lines = ["*Cotação de pedido* (atacado)"]
    order.line_items.each do |li|
      opts = li.variant.option_values.map(&:presentation).join('/')
      opts = opts.present? ? " (#{opts})" : ""
      lines << "• #{li.quantity}x #{li.name}#{opts} — #{money.call(li.price * li.quantity)}"
    end
    lines << ""
    lines << "*Total estimado: #{money.call(order.item_total)}*"
    lines << "(pedido mínimo #{money.call(wholesale_min_total)} — gostaria de fechar esta cotação?)"
    "https://wa.me/#{default_whatsapp}?text=#{ERB::Util.url_encode(lines.join("\n"))}"
  end

  def product_min_price(product)
    prices = ([product.master&.price] + product.variants.map(&:price)).compact
    prices.min || 0
  end

  def variant_label(variant)
    variant.option_values.map(&:presentation).join(" / ").presence || "Padrão"
  end
end
