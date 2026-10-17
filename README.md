# Lili Maquiagem Atacado — 彩妆批发单店系统

> **私有仓库**:https://github.com/wangdi1225/lili-maquiagem-atacado (PRIVATE,仅协作者可见)
>
> **交接/运维请看 [`docs/HANDOFF.md`](docs/HANDOFF.md)**:架构详解、功能清单、
> 生产部署与运维手册、故障排查、维护者上手指南。

基于 **Spree Commerce 5.6(Ruby on Rails 7.2)** 的单店 B2B 彩妆批发网站,复刻巴西 Teeki 平台店铺
(lilimaquiagem.com.br)的核心业务模式:

- ✅ 复用开源电商内核(Spree),**无多租户复杂度**(单 Store)
- ✅ **无在线支付**:下单后生成 WhatsApp 深链(wa.me),订单转人工确认(PIX/转账线下收款)
- ✅ **管理后台**(Spree Admin,Tailwind 服务端渲染):店长可快速上架商品、管理分类/品牌/订单/客户
- ✅ B2B 特性:最低起订金额(R$1000,可配置)、CNPJ 必填、多客服 WhatsApp 轮选、色号/规格变体、按"条/盒"批发单位
- ✅ 巴西本地化:pt-BR 文案、BRL 货币、R$ 价格格式

## 技术栈

| 层 | 选型 |
|---|---|
| 电商内核 | Spree Commerce 5.6.1(spree_core + spree_api + spree_admin) |
| 认证 | spree_auth_devise 4.6.3(Devise) |
| 框架 | Rails 7.2.4 / Ruby 3.3 / Puma |
| 数据库 | SQLite(storage/development.sqlite3,生产建议 PostgreSQL) |
| 店面 | 自研轻量 ERB 视图 + Tailwind(CDN),无前端构建步骤 |
| 后台 | Spree Admin(Tailwind,`rails spree:admin:tailwindcss:build` 构建) |
| 库存 | 已关闭库存跟踪(`Spree::Config.track_inventory_levels = false`,对齐参考站) |

## 目录结构(定制部分)

```
app/controllers/storefront/   # 店面控制器(home/taxons/products/cart/checkout)
app/views/storefront/         # 店面视图(布局/首页/分类/商品/购物车/结账/完成页)
app/views/spree/user_sessions/  # 后台登录页(自定义,layout false)
app/controllers/spree/user_*_controller.rb  # Devise 会话/密码控制器(修复 Spree 5.6 兼容)
app/helpers/storefront_helper.rb
config/initializers/wholesale.rb          # ★ 业务配置:起订额/WhatsApp 号码/销售员
config/initializers/spree_devise_aliases.rb  # Devise helper 别名(current_user)
lib/spree/authentication_helpers.rb       # 修复后的 Spree 认证路径 helper
lib/tasks/wholesale.rake                  # 彩妆目录种子任务
```

## 本地运行

```bash
# 环境(一次性)
brew install ruby@3.3 sqlite
export PATH="/opt/homebrew/opt/ruby@3.3/bin:/opt/homebrew/lib/ruby/gems/3.3.0/bin:$PATH"

cd wholesale_store
bundle install
bin/rails db:prepare                    # 建库(已含全部 Spree 迁移)
ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD='SeuSenha#123' bin/rails db:seed
bin/rails wholesale:seed_catalog        # 导入彩妆批发目录(14 款,BRL)
bin/rails spree:admin:tailwindcss:build # 构建后台样式
bin/rails s -p 3000                     # 启动
```

- 店面:http://localhost:3000/
- 后台:http://localhost:3000/admin (演示账号在首次 `db:seed` 时由 ADMIN_EMAIL/ADMIN_PASSWORD 环境变量创建;本地当前为 admin@lilimaquiagem.local / 见各自环境)

## 购买流程(店面)

1. 首页/分类页(`/t/<分类>`)浏览 → 商品页选择色号变体、数量 → 加入购物车
2. 购物车:改数量/删除;未达起订额(R$1000)显示"Faltam R$ xxx"并**拦截结账**
3. 结账表单:姓名/公司/CNPJ(14 位校验)/电话/地址/销售员/备注
4. 提交 → 订单存入后台(state=cart,public_metadata 含全部客户资料)
   → 完成页生成 **wa.me 深链**(预填订单摘要,按所选销售员路由号码)
5. 店长在后台 `/admin/orders` 看到订单 → WhatsApp 沟通收款(PIX/转账)→ 后台改状态发货

## 店长上架商品(后台)

`/admin/products/new`:填名称/SKU/价格(BRL)/描述 → 保存;变体(色号)在产品页 Variants 添加;
分类挂到 Taxonomies(Categorias/Marcas)。商品默认发布到 Online Store + Wholesale 渠道。

## 业务配置(config/initializers/wholesale.rb)

```ruby
config.x.wholesale.min_total     = 1000.0        # 最低起订金额(ENV: WHOLESALE_MIN_TOTAL)
config.x.whatsapp.default_number = "55119666..."  # ENV: WHOLESALE_WHATSAPP
config.x.whatsapp.salespeople    = [...]          # 销售员名单(结账可选,路由 wa.me 号码)
```

## 从零重建的坑位记录(Spree 5.6.1 + spree_auth_devise 4.6.3)

1. `rails g spree:install` 不会自动复制 spree_auth 引擎迁移 → 手动
   `bin/rails spree_auth:install:migrations`;且其 2010 年 create_users 迁移与 core 基线冲突,
   删除后用一个幂等迁移补 `deleted_at`/confirmable 列(见 db/migrate/20261017100000_*.rb)。
2. Spree 5.6 没有 spree_backend/spree_frontend 引擎,spree_auth_devise 不加载其登录控制器 →
   在 app 内补 `Spree::UserSessionsController < Devise::SessionsController`(layout false)+ 自定义登录视图。
3. `Spree.user_class.model_name.singular_route_key == "user"`,但 Devise mapping 是 `:spree_user` →
   `lib/spree/authentication_helpers.rb` 与 `spree_devise_aliases.rb` 做了别名/固定路径修复。
4. `Spree.admin_user_class` 需要显式设置(config/initializers/spree.rb)。
5. 店铺货币由 **Market** 委托:改 `store.default_market.currency = 'BRL'`(直接改 store 列无效)。
6. 后台样式需 `spree:admin:tailwindcss:build`;`rails g spree:admin:install` 生成输入文件。
7. 商品必须发布到渠道(ProductPublication)+ 有 BRL 价格才会出现在 `Spree::Product.available`。
8. 店铺 locale 设为 pt-BR 后必须提供 pt-BR 数字翻译(config/locales/pt-BR.yml)+
   `config.i18n.fallbacks = true`,否则后台价格解析(LocalizedNumber)会因
   "Translation missing: ...separator" 崩溃。
9. 后台建品价格填在"嵌套的 master 价格(BRL)输入框";顶层 product[price] 与嵌套
   prices_attributes 同时提交会触发 spree_prices 唯一约束冲突(浏览器 UI 由 JS 同步,无此问题)。

## 生产部署建议(对齐参考站架构)

- Cloudflare(DNS + 橙云代理 + 静态缓存)→ VPS(DigitalOcean 等)→ Caddy(自动 Let's Encrypt)→ Puma
- 换 PostgreSQL + `rails assets:precompile` + `RAILS_ENV=production rails spree:admin:tailwindcss:build --minify`
- Tailwind CDN 换成构建产物;Sidekiq 处理邮件/事件任务;Sentry 监控

## 已知简化(MVP)

- 无客户注册/登录(纯游客下单 + WhatsApp,符合参考站模式)
- 无运费计算/物流对接(线下沟通)
- 订单停留在 cart 状态由店长人工推进
- 商品图为占位符(后台上传即显示)
