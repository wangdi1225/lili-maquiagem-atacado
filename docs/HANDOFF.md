# 交接文档:Lili Maquiagem Atacado(彩妆批发单店系统)

> 面向后续维护者。读完本文档应能:独立部署、日常运维、排障、二次开发。
> 配套:`README.md`(快速开始)、`config/initializers/wholesale.rb`(业务配置)。

---

## 1. 项目概述

巴西市场 B2B 彩妆批发网站(单店),复刻 Teeki 平台店铺(lilimaquiagem.com.br)的业务模式:

- 面向**零售商/lojistas**,注册信息以 **CNPJ** 为准,按"条/盒/箱"批发单位销售;
- **无在线支付**:下单后生成 WhatsApp 深链,订单转人工确认,线下 PIX/转账收款;
- 最低起订金额(默认 R$1000)拦截结账;
- 管理后台供店长上架商品、管理订单。

业务闭环:

```
买家浏览(首页/分类/商品) → 选色号变体加购 → 购物车(起订额校验)
→ 结账表单(姓名/公司/CNPJ/电话/地址/销售员/备注)
→ 订单入库(Spree::Order, state=cart, 客户资料写入 public_metadata)
→ 完成页生成 wa.me 深链(预填订单摘要, 按销售员路由客服号码)
→ 店长后台 /admin/orders 查看 → WhatsApp 沟通收款 → 后台推进订单状态
```

---

## 2. 系统架构

### 2.1 技术栈(锁定版本,升级前必读第 6 节)

| 层 | 组件 | 版本 | 说明 |
|---|---|---|---|
| 语言/框架 | Ruby | 3.3.x | 系统 Ruby 2.6 不可用;Homebrew `ruby@3.3` |
| | Rails | 7.2.4 | |
| 电商内核 | spree / spree_core / spree_api | 5.6.1 | 商品/变体/价格/订单/税区/渠道/Market |
| 后台 | spree_admin | 5.6.1 | 服务端渲染(Tailwind),非 React |
| 认证 | spree_auth_devise 4.6.3 + devise 4.9.4 | | Devise mapping 名 `:spree_user` |
| 授权 | cancancan 3.7.0 | | Spree Admin 内置 Ability |
| Web 服务器 | Puma | 8.0.2 | 开发单进程;生产建议 cluster |
| 数据库 | SQLite(sqlite3 gem 2.10) | | 文件 `storage/development.sqlite3`;生产建议 PostgreSQL |
| 后台样式 | tailwindcss-ruby | 4.x | 需 `spree:admin:tailwindcss:build` 构建产物 |
| 店面样式 | Tailwind CDN | | **生产应替换为构建产物**(见 5.2) |
| 文件存储 | ActiveStorage(本地 disk) | | `storage/` 目录,商品图经后台上传 |

### 2.2 部署拓扑

**当前(开发)**:

```
浏览器 → http://127.0.0.1:3000 (Puma, RAILS_ENV=development)
```

**建议(生产,对齐参考站架构)**:

```
买家 → Cloudflare(DNS 托管 + 橙云代理 + 静态缓存 + WAF/rate limit)
     → VPS(DigitalOcean 等)
        → Caddy(自动 Let's Encrypt 证书, 反代, apex→www 301)
           → Puma(RAILS_ENV=production, systemd 托管)
              → PostgreSQL(建议) / SQLite(小规模可接受)
              → ActiveStorage disk: storage/
```

### 2.3 代码结构(定制部分 = 维护重点)

Spree 以 Rails Engine 挂载在 `/`(含 `/admin`、`/api`);**自定义代码**如下,其余均为 gem 原生:

| 路径 | 职责 |
|---|---|
| `config/routes.rb` | 店面路由(必须在 `mount Spree::Core::Engine` **之前**定义才优先生效) |
| `app/controllers/storefront/*` | 店面 6 个控制器:base(会话购物车)/home/taxons/products/cart/checkout |
| `app/views/storefront/**` | 店面视图:布局、首页、分类、商品、购物车、结账、完成页 |
| `app/views/spree/user_sessions/new.html.erb` | 后台登录页(自绘,`layout false`) |
| `app/views/spree/user_passwords/new.html.erb` | 找回密码页(自绘) |
| `app/controllers/spree/user_*_controller.rb` | Devise 会话/密码/注册/确认控制器(Spree 5.6 兼容补丁,见 6.2) |
| `app/helpers/storefront_helper.rb` | BRL 格式化、分类导航、占位图、变体标签 |
| `config/initializers/wholesale.rb` | **业务配置**:起订额/WhatsApp 号码/销售员(ENV 可覆盖) |
| `config/initializers/spree_devise_aliases.rb` | `current_user` 等 Devise 别名注入(`to_prepare`) |
| `config/initializers/spree.rb` | `Spree.admin_user_class`、库存开关等 |
| `config/locales/pt-BR.yml` | pt-BR 数字/日期/字段翻译(**缺失会导致后台价格解析崩溃**,见 6.8) |
| `lib/spree/authentication_helpers.rb` | 认证路径 helper 修复版(生成器拷入 app,可改) |
| `lib/tasks/wholesale.rake` | `wholesale:seed_catalog` 彩妆目录种子(幂等) |
| `db/migrate/20261017100000_*.rb` | 幂等补丁迁移:补 `spree_users.deleted_at` + confirmable 列 |
| `app/assets/tailwind/spree_admin.css` | 后台 Tailwind 构建入口(生成器产物,可自定义主题) |

### 2.4 数据模型要点(Spree 原生表)

- 商品:`spree_products`(无 sku 列!SKU 在变体)→ `spree_variants`(master + 色号变体)→ `spree_prices`(variant_id+currency 唯一,**BRL 价格必须存在**商品才可见);
- 分类:`spree_taxonomies`(Categorias / Marcas)→ `spree_taxons`(permalink 形如 `categorias/batom`,**无 slug 列**,`slug` 是方法);
- 可见性:`spree_product_publications`(product×channel,`published_at`)+ `status='active'` + 有当前货币价格 ⇒ `Spree::Product.available`;
- 订单:`spree_orders`(number/state/item_total/`public_metadata` JSON)+ `spree_line_items`;
  - **客户资料不建表**,存 `spree_orders.public_metadata`:
    `{"canal":"whatsapp","cliente":{"nome","empresa","cnpj","telefone","endereco","observacoes","vendedor"}}`;
- 店铺上下文:`spree_stores` → `spree_markets`(**货币/语言由 Market 委托**,改 store 列无效)→ `spree_channels`(online/wholesale/pos);
- 用户:`spree_users`(Devise + paranoia `deleted_at`),角色 `spree_roles/spree_role_users`(admin)。

### 2.5 认证与授权链路(易错,重点)

```
Devise mapping :spree_user (路由 /user/spree_user/sign_in, 由 spree_auth_devise 注入 Spree::Core::Engine)
   ├─ 控制器: app Spree::UserSessionsController < Devise::SessionsController (layout false)
   ├─ helper: current_spree_user (Devise 生成)
   ├─ 别名:   current_user / user_signed_in? / authenticate_user!
   │          (config/initializers/spree_devise_aliases.rb, to_prepare 注入 ActionController::Base)
   ├─ Spree helper: spree_current_user / spree_admin_login_path ...
   │          (lib/spree/authentication_helpers.rb, 已改为固定路径/正确 proxy)
   └─ 后台授权: Spree::Admin::BaseController#authorize_admin (CanCan)
              未登录 → 302 /user/spree_user/sign_in
```

注意:`Spree.user_class.model_name.singular_route_key == "user"`,而 Devise mapping 是
`:spree_user`,两者不一致是全部认证补丁的根源(见 6.2/6.3)。

---

## 3. 功能清单

### 3.1 店面(游客可用,无需登录)

| 功能 | 路由 | 实现 |
|---|---|---|
| 首页(hero/分类/商品网格) | `/` | `storefront/home#index` |
| 分类列表 | `/t/:slug` | `storefront/taxons#show`(按 permalink 匹配) |
| 商品详情(色号变体逐行加购) | `/products/:slug` | `storefront/products#show` |
| 购物车(改量/删除/合计) | `/cart`, `POST /cart/add`, `PATCH /cart/update`, `DELETE /cart/remove/:id` | `storefront/cart#*`,调用 `Spree::Cart::AddItem/SetQuantity/RemoveLineItem` 服务 |
| 起订额拦截 | 购物车页进度条+提示;`/checkout` GET 未达标 302 回购物车;**同时提供 WhatsApp 报价出口** | `config.x.wholesale.min_total` |
| 结账表单(CNPJ 14 位校验等) | `GET/POST /checkout` | `storefront/checkout#new/create` |
| 订单完成页 + WhatsApp 深链 | `/pedido/:number` | `storefront/checkout#complete`(wa.me + URL-encoded 订单摘要) |
| 占位商品图(无图时 💄 色块) | — | `StorefrontHelper#product_image` |
| 商品卡快捷加购("+" 按钮,加 1 件首变体) | 首页/分类网格 | `_product_card.html.erb` |
| 悬浮迷你购物车条(数量/合计/去结算或报价) | 全站底部 | `_mini_cart.html.erb`(布局渲染) |
| 未达起订额时的**WhatsApp 报价通道**(cotação) | 购物车页/悬浮条 | `StorefrontHelper#whatsapp_quote_link` |
| 起订额进度条 | 购物车页 | `cart/show.html.erb` |

### 3.2 后台(Spree Admin,需登录)

| 功能 | 路由 | 说明 |
|---|---|---|
| 登录/登出/找回密码 | `/user/spree_user/sign_in` 等 | 自绘登录页;登录成功跳 `/admin` |
| Dashboard/分析 | `/admin` | Spree 原生 |
| 商品管理(列表/新建/编辑/变体/图片) | `/admin/products*` | **店长上架入口**;价格填嵌套 BRL 输入框 |
| 订单管理(列表/详情/状态推进) | `/admin/orders*` | WhatsApp 订单客户资料在详情 metadata |
| 分类/品牌(Taxonomies)、客户、库存位置、渠道等 | `/admin/...` | Spree 原生 |

### 3.3 业务规则

- 起订额:`config.x.wholesale.min_total`(默认 1000,ENV `WHOLESALE_MIN_TOTAL`);
- 无库存跟踪:`Spree::Config.track_inventory_levels = false`(initializer `after_initialize`);
- 无支付/运费:不装 spree_gateway,不配置 ShippingMethod 结账路径;
- 多客服:`config.x.whatsapp.salespeople`,结账可选,完成页按其号码生成 wa.me;
- 货币/语言:Market = BRL / pt-BR;店面文案硬编码 pt-BR,后台英文(可后续接 spree_i18n)。

---

## 4. 配置项速查

| 位置 | 键 | 默认 | 作用 |
|---|---|---|---|
| `config/initializers/wholesale.rb` | `config.x.wholesale.min_total` | 1000.0 | 最低起订金额(BRL) |
| | `config.x.wholesale.min_quantity` | 1 | 预留(当前未强制) |
| | `config.x.whatsapp.default_number` | 5511966682273 | 默认客服号(国际格式无 +) |
| | `config.x.whatsapp.salespeople` | 3 人 | 销售员名单(name/number) |
| ENV | `WHOLESALE_MIN_TOTAL` / `WHOLESALE_MIN_QTY` / `WHOLESALE_WHATSAPP` | — | 覆盖上述 |
| `config/initializers/spree.rb` | `Spree.admin_user_class` | "Spree::User" | **必须**,否则后台登录跳转崩溃 |
| | `Spree::Config.track_inventory_levels` | false | 关库存 |
| `config/initializers/devise.rb` | `Devise.secret_key` | 随机(生成时写入) | **生产必须改为 ENV 注入** |
| `config/locales/pt-BR.yml` | number.currency.format 等 | — | **不可删**,后台价格解析依赖 |
| `config/application.rb` | `config.i18n.fallbacks = true` | — | 缺失翻译回退 en |

---

## 5. 生产运维手册

### 5.1 部署(新机器,Ubuntu/Debian 示例)

```bash
# 依赖
sudo apt install -y git build-essential libsqlite3-dev libyaml-dev curl
# Ruby 3.3(推荐 mise/rbenv):
curl https://mise.run | sh && mise install ruby@3.3 && mise use -g ruby@3.3
gem install bundler rails -v '~> 7.2.0' --no-document

# 代码
git clone <repo> wholesale_store && cd wholesale_store
bundle install --deployment

# 初始化(首次)
RAILS_ENV=production SECRET_KEY_BASE=$(bin/rails secret) \
  bin/rails db:prepare
ADMIN_EMAIL=owner@empresa.com ADMIN_PASSWORD='<强密码>' bin/rails db:seed
bin/rails wholesale:seed_catalog

# 构建
RAILS_ENV=production bin/rails spree:admin:tailwindcss:build   # 产物 app/assets/builds/
RAILS_ENV=production bin/rails assets:precompile               # sprockets
RAILS_ENV=production SECRET_KEY_BASE=... bin/rails server -e production  # 或见 5.3 systemd
```

**PostgreSQL 切换(推荐)**:Gemfile 加 `gem "pg"`,`config/database.yml` 改 adapter/URL,
`bin/rails db:prepare` 重建,再 `wholesale:seed_catalog`。SQLite 数据可用
`sqlite3 storage/development.sqlite3 .dump` 导出后转换,或直接重新种子。

### 5.2 生产必改清单(上线前逐项核对)

- [ ] `config/environments/production.rb`:确认 `force_ssl = true`;
- [ ] **Tailwind CDN 移除**:店面布局 `app/views/layouts/storefront.html.erb` 的
      `<script src="https://cdn.tailwindcss.com">` 替换为构建产物(把店面 css 也纳入
      tailwind 构建或改用预编译 css),否则生产有性能与 CSP 风险;
- [ ] `Devise.secret_key` 与 `SECRET_KEY_BASE` 改为 ENV/credentials 注入;
- [ ] 修改默认管理员密码;删除演示订单/演示销售员;
- [ ] `config.x.whatsapp.*` 换成真实客服号码;
- [ ] 配置邮件(SMTP)以便 Devise 找回密码可用(当前未配,找回仅页面流程);
- [ ] Cloudflare:DNS 托管、www 橙云、缓存规则(`/uploads`、`/assets` 长缓存;HTML 不缓存);
- [ ] 备份策略启用(5.5)。

### 5.3 进程托管(systemd 示例)

```ini
# /etc/systemd/system/wholesale.service
[Unit]
Description=Lili Maquiagem Atacado (Puma)
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/srv/wholesale_store
Environment=RAILS_ENV=production
Environment=SECRET_KEY_BASE=<...>
Environment=WHOLESALE_WHATSAPP=5511xxxxxxxxx
ExecStart=/usr/local/bin/bundle exec puma -C config/puma.rb -b tcp://127.0.0.1:3000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Caddy 反代示例:

```caddy
lili.example.com {
    redir https://www.lili.example.com{uri} permanent
}
www.lili.example.com {
    encode zstd gzip
    reverse_proxy 127.0.0.1:3000
    header /assets/* Cache-Control "public, max-age=31536000, immutable"
}
```

### 5.4 发布流程(每次上线)

```bash
cd /srv/wholesale_store && git pull
bundle install --deployment
bin/rails db:migrate                       # 有迁移时
RAILS_ENV=production bin/rails spree:admin:tailwindcss:build
RAILS_ENV=production bin/rails assets:precompile
sudo systemctl restart wholesale
curl -sf https://www.../up | head -c 50    # 健康检查(routes 中 /up)
```

### 5.5 备份与恢复

- **SQLite 方案**:每日 `sqlite3 storage/production.sqlite3 ".backup '/backups/db-$(date +%F).sqlite3'"`
  + 打包 `storage/`(ActiveStorage 文件)+ `git bundle` 代码;保留 30 天;
- **PG 方案**:`pg_dump -Fc` 每日 + WAL 归档(可选);
- 恢复:停服 → 覆盖数据库文件/`pg_restore` → 还原 `storage/` → 起服;
- **演练**:每季度做一次恢复演练并记录耗时。

### 5.6 监控与日志

- 日志:`log/production.log`(logrotate 按天切割,保留 14 天);Puma stdout 进 journald;
- 拨测:`/up`(Rails 健康路由)+ 首页 200 探测(UptimeRobot/Checkly,5 分钟);
- 错误聚合:建议接 Sentry(`sentry-ruby` + `sentry-rails`);
- 业务看板:后台 `/admin`(订单量/销售额分析页)。

### 5.7 安全清单

- HTTPS 强制(Cloudflare/Caddy);`SECRET_KEY_BASE`、`Devise.secret_key` 保密并定期轮换;
- 后台账号最小化;离职店长账号在后台 Users 删除(Spree 用 paranoia 软删);
- Cloudflare rate limiting:`/cart/add`、`/checkout` POST 限流防刷;
- 依赖升级:`bundle audit`(bundler-audit)每月;Spree 大版本升级见 6.9;
- LGPD:订单含 CNPJ/电话等个人数据,备份加密、访问受控;隐私政策页待补。

### 5.8 日常运维 SOP

| 任务 | 操作 |
|---|---|
| 店长上架商品 | 后台 `/admin/products/new`:名称/SKU/描述/状态 active;价格填 **BRL 嵌套输入框**(如 `189,90`);保存后到产品页 Variants 加色号;Taxons 挂分类+品牌;确认 Publications 勾选渠道 |
| 改 WhatsApp 号码/销售员 | 编辑 `config/initializers/wholesale.rb` → 重启服务 |
| 改起订额 | 同上(`min_total`)或 ENV `WHOLESALE_MIN_TOTAL` |
| 新增管理员 | 后台 Users 新建并赋 admin 角色;或 console:`u=Spree::User.new(email:,password:); u.save!; u.spree_roles << Spree::Role.find_or_create_by!(name:'admin')` |
| 重置管理员密码 | console:`Spree::User.find_by(email:...).update!(password: '新密码')` |
| 处理 WhatsApp 订单 | 后台 Orders 搜单号 → 详情看 metadata 客户资料 → 线下收款后改状态(complete/发货) |
| 商品下架 | 后台产品页状态改 archived 或设 discontinue_on |
| 查看某订单原始数据 | console:`Spree::Order.find_by(number:'R...').public_metadata` |
| 重建目录种子 | `bin/rails wholesale:seed_catalog`(幂等;会归档当前 active 商品!) |

---

## 6. 故障排查(已知坑位与速查)

### 6.1 环境类

| 症状 | 原因/处理 |
|---|---|
| `rails` 命令在 iCloud 同步目录(如 ~/Documents)挂起 | macOS iCloud 元数据问题;项目必须放在非同步目录(当前 ~/dev) |
| gem 安装极慢 | 国内网络;`index.rubygems.org/info/*` 端点通常可用,耐心等待;勿用已死的 gems.ruby-china.com |
| Ruby 版本报错 | 必须 Ruby 3.3(brew `ruby@3.3`);系统 Ruby 2.6/4.x 均不行 |

### 6.2 认证类(Spree 5.6 + spree_auth_devise 4.6.3 固有缺陷,已补丁)

| 症状 | 根因 | 现有补丁位置 |
|---|---|---|
| `undefined method 'current_user'` | singular_route_key("user") ≠ Devise mapping(:spree_user) | `spree_devise_aliases.rb`(to_prepare 注入别名) |
| 登录页 500 `uninitialized constant Spree::UserSessionsController` | 该 gem 仅在存在旧 spree_backend/frontend 引擎时加载控制器 | `app/controllers/spree/user_*_controller.rb` |
| 登录页渲染报路由 helper 缺失 | Devise 命名路由只在 Spree::Core::Engine 路由集 | 自绘登录视图(固定路径)+ `authentication_helpers.rb` 修复 |
| 改 initializer 后行为回退 | `after_initialize` 不随 dev reload 重跑 | 一律用 `config.to_prepare` |

### 6.3 数据/迁移类

| 症状 | 处理 |
|---|---|
| `no such column: spree_users.deleted_at` | 跑 `db/migrate/20261017100000_*` 补丁迁移 |
| spree_auth 旧迁移与 core 基线冲突(create_users 已存在) | 该 9 个迁移**不要**重新拷入;缺列用幂等迁移补 |
| 商品在店面不显示 | 三条件:status=active、有 BRL 价格、ProductPublication 已发布渠道;后台检查 |
| 改 store.default_currency 无效 | 货币由 `store.default_market.currency` 委托;改 Market |

### 6.4 后台类

| 症状 | 处理 |
|---|---|
| `/admin` 500 `asset "spree/admin/application.css" not present` | `bin/rails spree:admin:tailwindcss:build`(生产加 RAILS_ENV) |
| 后台建品 500 `RegexpError ... separator` | pt-BR 翻译缺失;确认 `config/locales/pt-BR.yml` 存在 + fallbacks=true |
| 后台建品 500 `UNIQUE spree_prices(variant_id,currency)` | 同时提交顶层 price 与嵌套 BRL 价格;浏览器 UI 无此问题,API/curl 调用只发嵌套字段 |
| 后台界面英文 | 正常(未装 spree_i18n);需要时加 gem 并配置 |

### 6.5 店面类

| 症状 | 处理 |
|---|---|
| 加购后购物车为空 | 看 `Spree::Cart::AddItem` 返回:`result.error`;常见为变体无当前货币价格 |
| `/t/xxx` 404/500 | taxon 用 `permalink` 查询(无 slug 列);首页链接已做前缀剥离 |
| 价格显示 `R$ 1.234,56` 异常 | 检查 pt-BR.yml 与 helper `brl()`(number_to_currency pt-BR) |

### 6.6 日志定位套路

```bash
tail -f log/development.log            # 开发
grep -n 'POST "/checkout"' log/production.log | tail -1   # 定位请求行号
sed -n '行号,+400p' log/production.log | grep -vE 'SELECT|↳|CACHE'  # 过滤 SQL 看异常
```

### 6.7 重启与热载边界

- `app/`、`config/routes.rb`、`config/locales/` 改动:dev 自动热载;
- `config/initializers/`、`lib/`、Gemfile 改动:dev 需 `touch tmp/restart.txt`;生产必须重启;
- 数据库迁移后必须重启。

### 6.8 不要做的事

- 不要删除 `config/locales/pt-BR.yml`、`spree_devise_aliases.rb`、`lib/spree/authentication_helpers.rb`;
- 不要把项目移回 iCloud 同步目录;
- 不要升级 spree_auth_devise/spree 大版本前不做 staging 验证(6.9);
- 不要直接改 `spree_users` 表结构绕过补丁迁移。

### 6.9 升级指引

- 小版本(`bundle update spree --conservative`):staging 跑通 3.1/3.2 全链路 + 后台建品/登录;
- 大版本(Spree 6 / Rails 8):评估点=认证补丁是否仍需要(上游可能修复)、Market/Channel 模型变化、admin 模板变化;预留 1 周;
- Ruby:跟随 Spree 官方支持矩阵。

---

## 7. 维护者上手指南

1. 环境:brew/mise 装 Ruby 3.3 → `bundle install` → `bin/rails db:prepare` →
   `ADMIN_EMAIL=... ADMIN_PASSWORD=... bin/rails db:seed` → `bin/rails wholesale:seed_catalog`
   → `bin/rails spree:admin:tailwindcss:build` → `bin/rails s`;
2. 冒烟测试(5 分钟):首页 200 → 商品页加购 → 购物车 → 未达起订额被拦 → 凑单后结账
   (CNPJ 填 14 位)→ 完成页 wa.me 链接 → 后台登录看到该订单;
3. 读码顺序:`config/routes.rb` → `app/controllers/storefront/*` →
   `app/views/storefront/**` → `config/initializers/wholesale.rb` → 6.2 认证三件套;
4. 改业务规则优先改 `wholesale.rb`;改页面改 `app/views/storefront`;
   **不要**在 Spree gem 视图上做 override 除非必要;
5. 提交规范:功能分支 → PR 描述含"影响面+冒烟结果";合并后按 5.4 发布。

---

## 8. 已知限制与后续路线(MVP 边界)

已实现之外、参考站有或业务需要但**未做**的:

1. 客户注册/登录与"我的订单"(当前纯游客下单);
2. 运费计算与物流对接(Melhor Envio/Correios)、CEP 自动填充;
3. PIX 在线收款对账(Mercado Pago/Asaas webhook)——当前线下;
4. 商品图批量导入与 imgproxy 式按需变体(当前后台单图上传);
5. 后台界面 pt-BR 化(spree_i18n);
6. 邮件通知(下单确认/发货)与 WhatsApp Cloud API 模板消息;
7. NFe 发票(Focus NFe/PlugNotas)、LGPD 隐私页;
8. 搜索/过滤/促销引擎(Spree 内置 promotions 未启用);
9. 自动化测试(建议补 RSpec:起订额、CNPJ 校验、加购服务三个用例起步)。

建议迭代顺序:9 → 4 → 2 → 3 → 6 → 1 → 5 → 7 → 8。

---

*文档版本:2026-10-17;维护责任人:__________;上次演练恢复:__________*
