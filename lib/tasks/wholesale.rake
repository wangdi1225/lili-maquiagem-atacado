namespace :wholesale do
  desc "Seed do catálogo de maquiagem por atacado (BRL)"
  task seed_catalog: :environment do
    ship = Spree::ShippingCategory.first_or_create!(name: 'Default')

    # Arquiva produtos de exemplo (USD) para o storefront mostrar só o catálogo próprio
    Spree::Product.where(status: 'active').find_each do |p|
      p.update_columns(status: 'archived', discontinue_on: Time.current)
    end

    cats = {
      'Batom' => 'Batom', 'Base & Corretivo' => 'Base & Corretivo', 'Blush & Iluminador' => 'Blush & Iluminador',
      'Sombras & Paletas' => 'Sombras & Paletas', 'Cílios & Delineador' => 'Cílios & Delineador',
      'Pincéis & Acessórios' => 'Pincéis & Acessórios', 'Skincare' => 'Skincare', 'Perfumes' => 'Perfumes'
    }.map do |key, name|
      taxonomy = Spree::Taxonomy.find_or_create_by!(name: 'Categorias')
      root = taxonomy.root
      Spree::Taxon.find_or_create_by!(name: name, taxonomy: taxonomy, parent: root)
    end
    cat_by_name = cats.index_by(&:name)

    brands = %w[RubyRose MaxLove Fenzza BelleAngel Macrilan SPColors Melu Femella].map do |b|
      taxonomy = Spree::Taxonomy.find_or_create_by!(name: 'Marcas')
      root = taxonomy.root
      Spree::Taxon.find_or_create_by!(name: b, taxonomy: taxonomy, parent: root)
    end
    brand_by_name = brands.index_by(&:name)

    opt_cor  = Spree::OptionType.find_or_create_by!(name: 'cor') { |o| o.presentation = 'Cor'; o.position = 1 }
    opt_tom  = Spree::OptionType.find_or_create_by!(name: 'tonalidade') { |o| o.presentation = 'Tonalidade'; o.position = 2 }
    opt_frag = Spree::OptionType.find_or_create_by!(name: 'fragrancia') { |o| o.presentation = 'Fragrância'; o.position = 3 }

    set_price = lambda do |variant, amount|
      if variant.respond_to?(:set_price)
        variant.set_price('BRL', amount)
      else
        variant.price = amount
      end
    end

    catalog = [
      { name: 'Batom Líquido Matte 24h — Barra com 24 un', sku: 'BT24-MAX', price: 189.90, cat: 'Batom', brand: 'MaxLove',
        desc: 'Batom líquido matte de longa duração (24h). Barra fechada com 24 unidades em cores sortidas. Excelente margem para revenda.',
        opt: :cor, values: %w[Vermelho Rosa Nude Coral Vinho Telha] },
      { name: 'Base Líquida Matte Alta Cobertura — Barra com 12 un', sku: 'BS12-FEM', price: 156.00, cat: 'Base & Corretivo', brand: 'Femella',
        desc: 'Base líquida matte, alta cobertura, toque seco. Barra com 12 unidades (tonalidades 01 a 06, 2 de cada).',
        opt: :tom, values: %w[01 02 03 04 05 06] },
      { name: 'Corretivo Líquido HD — Barra com 24 un', sku: 'CR24-RB', price: 168.00, cat: 'Base & Corretivo', brand: 'RubyRose',
        desc: 'Corretivo líquido HD alta cobertura, não craquela. Barra com 24 unidades.',
        opt: :tom, values: %w[Claro Médio Escuro] },
      { name: 'Blush em Pó Compacto — Barra com 24 un', sku: 'BL24-FP', price: 144.00, cat: 'Blush & Iluminador', brand: 'Femella',
        desc: 'Blush compacto ultrafino, alta pigmentação. Barra com 24 unidades em cores sortidas.',
        opt: :cor, values: %w[Rosa Pêssego Terracota Malva] },
      { name: 'Iluminador Líquido Glow — Barra com 24 un', sku: 'IL24-SP', price: 156.00, cat: 'Blush & Iluminador', brand: 'SPColors',
        desc: 'Iluminador líquido efeito glow, pode ser misturado à base. Barra com 24 unidades.',
        opt: :cor, values: %w[Dourado Rosado Champagne] },
      { name: 'Paleta de Sombras 18 Cores — Caixa com 12 un', sku: 'PS18-ML', price: 420.00, cat: 'Sombras & Paletas', brand: 'Melu',
        desc: 'Paleta 18 cores (matte + cintilante), alta fixação. Caixa fechada com 12 paletas.',
        opt: nil, values: [] },
      { name: 'Máscara de Cílios Volume Russo — Caixa com 24 un', sku: 'MC24-BA', price: 132.00, cat: 'Cílios & Delineador', brand: 'BelleAngel',
        desc: 'Máscara de cílios volume russo, à prova d\'água. Caixa com 24 unidades.',
        opt: nil, values: [] },
      { name: 'Delineador Líquido Preto — Caixa com 48 un', sku: 'DL48-MC', price: 144.00, cat: 'Cílios & Delineador', brand: 'Macrilan',
        desc: 'Delineador líquido preto intenso, ponta fina. Caixa com 48 unidades.',
        opt: nil, values: [] },
      { name: 'Kit Pincéis Maquiagem 12 Peças — Caixa com 6 kits', sku: 'KP12-MC', price: 294.00, cat: 'Pincéis & Acessórios', brand: 'Macrilan',
        desc: 'Kit profissional com 12 pincéis + nécessaire. Caixa com 6 kits.',
        opt: nil, values: [] },
      { name: 'Gloss Labial Volumoso — Caixa com 24 un', sku: 'GL24-ML', price: 108.00, cat: 'Batom', brand: 'Melu',
        desc: 'Gloss labial efeito volumoso, não grudento. Caixa com 24 unidades em cores sortidas.',
        opt: :cor, values: %w[Incolor Rosa Vermelho Nude] },
      { name: 'Pó Compacto Facial — Barra com 24 un', sku: 'PC24-RB', price: 156.00, cat: 'Base & Corretivo', brand: 'RubyRose',
        desc: 'Pó compacto ultrafino com espelho e esponja. Barra com 24 unidades (tons 01-04).',
        opt: :tom, values: %w[01 02 03 04] },
      { name: 'Body Splash 90ml — Caixa com 12 un', sku: 'BS90-FZ', price: 96.00, cat: 'Perfumes', brand: 'Fenzza',
        desc: 'Body splash 90ml, fragrâncias inspiradas. Caixa com 12 unidades sortidas.',
        opt: :frag, values: ['Amadeirado', 'Floral', 'Cítrico', 'Doce'] },
      { name: 'Esmalte Cremoso 8ml — Caixa com 48 un', sku: 'ES48-SP', price: 120.00, cat: 'Blush & Iluminador', brand: 'SPColors',
        desc: 'Esmalte cremoso 8ml, secagem rápida. Caixa com 48 unidades em cores sortidas.',
        opt: :cor, values: %w[Vermelho Nude Preto Rosa Branco] },
      { name: 'Esponja de Maquiagem Gota — Pacote com 30 un', sku: 'EP30-BA', price: 75.00, cat: 'Pincéis & Acessórios', brand: 'BelleAngel',
        desc: 'Esponja gota macia, expande com água. Pacote com 30 unidades.',
        opt: nil, values: [] }
    ]

    online = Spree::Channel.find_by(default: true) || Spree::Channel.first
    wholesale = Spree::Channel.find_by(code: 'wholesale')

    created = 0
    catalog.each do |item|
      slug_base = item[:sku].downcase
      product = Spree::Product.find_by(slug: slug_base) || Spree::Product.new
      product.assign_attributes(
        name: item[:name], description: item[:desc], sku: item[:sku], slug: slug_base,
        available_on: 3.days.ago, status: 'active', shipping_category: ship
      )
      product.taxons = [cat_by_name[item[:cat]], brand_by_name[item[:brand]]].compact.uniq
      product.save!
      set_price.call(product.master, item[:price])
      product.master.save!

      if item[:opt]
        ot = { cor: opt_cor, tom: opt_tom, frag: opt_frag }[item[:opt]]
        item[:values].each_with_index do |val, i|
          ov = Spree::OptionValue.find_or_create_by!(option_type: ot, name: "#{ot.name}-#{val.parameterize}") do |o|
            o.presentation = val
            o.position = i
          end
          vsku = "#{item[:sku]}-#{(i + 1).to_s.rjust(2, '0')}"
          variant = product.variants.find_by(sku: vsku) || product.variants.new(sku: vsku)
          variant.option_values = [ov]
          set_price.call(variant, item[:price])
          variant.save!
        end
      end

      [online, wholesale].compact.each do |ch|
        pub = Spree::ProductPublication.find_or_initialize_by(product: product, channel: ch)
        pub.published_at ||= Time.current
        pub.save!
      end
      created += 1
    end

    puts "Catálogo pronto: #{created} produtos, #{Spree::Product.available.count} disponíveis em BRL."
  end
end
