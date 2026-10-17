# Configurações da loja de atacado (edite aqui ou via variáveis de ambiente)
Rails.application.configure do
  config.x.wholesale.min_total       = ENV.fetch("WHOLESALE_MIN_TOTAL", "1000").to_f   # pedido mínimo (R$)
  config.x.wholesale.min_quantity    = ENV.fetch("WHOLESALE_MIN_QTY", "1").to_i
  config.x.whatsapp.default_number   = ENV.fetch("WHOLESALE_WHATSAPP", "5511966682273")
  config.x.whatsapp.salespeople      = [
    { name: "Nataly",  number: "5511966682273" },
    { name: "Larissa", number: "5511917815466" },
    { name: "Julia",   number: "5511951763777" }
  ]
end

Rails.application.config.after_initialize do
  # Sem controle de estoque (igual à loja de referência: stock_control=false)
  Spree::Config.track_inventory_levels = false
end
