module StorefrontHelper
  BRL = "BRL"

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

  # ---- Imagens / galeria ----

  # Media em ordem para a galeria: principal primeiro, depois o restante por posição, sem duplicatas.
  def product_media(product)
    media = product.media.to_a
    ([product.primary_media] + media).compact.uniq
  end

  # Variante webp de uma midia para um tamanho predefinido do Spree (:mini/:small/:medium/:large/:xlarge).
  def media_variant(media, size)
    dims = Spree::Config.product_image_variant_sizes[size] || [720, 720]
    media.attachment.variant(
      resize_to_fill: dims,
      format: "webp",
      saver: Spree::Asset::WEBP_SAVER_OPTIONS
    )
  end

  # srcset responsivo (larguras reais em pixels) a partir de varias variantes.
  def media_srcset(media, sizes = [:small, :medium, :large, :xlarge])
    sizes.filter_map do |s|
      dims = Spree::Config.product_image_variant_sizes[s]
      next unless dims
      "#{main_app.rails_representation_path(media_variant(media, s))} #{dims[0]}w"
    end.join(", ")
  end

  # Renderiza uma imagem de midia com srcset/sizes responsivo, lazy-load e fallback para o original.
  def render_media_image(media, alt, css: "w-full h-48 object-cover", size: :large,
                         sizes_attr: "(max-width: 768px) 100vw, 480px", eager: false, html: {})
    dims = Spree::Config.product_image_variant_sizes[size] || [720, 720]
    begin
      src    = main_app.rails_representation_path(media_variant(media, size))
      srcset = media_srcset(media)
    rescue StandardError => e
      Rails.logger.warn("[storefront] variante de imagem falhou (#{e.class}: #{e.message}); usando original")
      src    = main_app.rails_blob_path(media.attachment, disposition: "inline")
      srcset = nil
    end
    image_tag src,
              srcset: srcset,
              sizes: sizes_attr,
              class: css,
              loading: eager ? "eager" : "lazy",
              decoding: "async",
              width: dims[0],
              height: dims[1],
              alt: alt.presence || "produto",
              **html
  end

  # Imagem principal de um produto (cards, lista). Cai para placeholder 💄 quando nao ha midia.
  def product_image(product, css: "w-full h-48 object-cover", size: :large, eager: false, html: {})
    media = product.primary_media || product.media.first
    return placeholder_image(product, css) unless media&.attachment&.attached?

    render_media_image(media, media.alt.presence || product.name, css: css, size: size, eager: eager, html: html)
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

  # Extrai quantidade do pack ("Barra com 24 un", "Caixa com 12 un", "12 peças"...)
  def pack_unit_count(product)
    m = product.name.to_s.match(/(\d+)\s*(?:un|pcs|pe[cç]as?|kits?)\b/i)
    m && m[1].to_i.positive? ? m[1].to_i : nil
  end

  def unit_price(product)
    n = pack_unit_count(product)
    price = product_min_price(product)
    n && price && price > 0 ? (price / n).round(2) : nil
  end

  # 品牌：基于预加载的 taxons（含 taxonomy），内存过滤，避免每卡一次 JOIN 查询。
  def brand_of(product)
    product.taxons.find { |t| t.taxonomy&.name == "Marcas" }
  end

  # 最低价：基于预加载的 variants_including_master + prices。
  def product_min_price(product)
    product.variants_including_master.filter_map { |v| v.price_in(BRL).amount }.min || 0
  end

  # 变体价格（替代弃用的 variant.price）
  def variant_price(variant, currency = BRL)
    variant.price_in(currency).amount
  end

  def variant_label(variant)
    variant.option_values.map(&:presentation).join(" / ").presence || "Padrão"
  end

  # 快速加购的默认变体：首个非 master 变体（按 position），否则 master。
  def quick_add_variant(product)
    product.variants_including_master.find { |v| !v.is_master } ||
      product.variants_including_master.find(&:is_master)
  end

  private

  def placeholder_image(product, css)
    tag.div(class: "#{css} bg-pink-100 flex items-center justify-center text-5xl", alt: product.name) { "💄" }
  end
end
