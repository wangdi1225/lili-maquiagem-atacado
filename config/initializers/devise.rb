# Devise secret key.
# - production: MUST come from ENV (set via systemd/ENV: DEVISE_SECRET_KEY)
# - dev/test:   falls back to an insecure dev-only value
if Rails.env.production?
  Devise.secret_key = ENV.fetch("DEVISE_SECRET_KEY")
else
  Devise.secret_key = ENV.fetch("DEVISE_SECRET_KEY", "dev-only-insecure-key-0123456789abcdef0123456789abcdef")
end
