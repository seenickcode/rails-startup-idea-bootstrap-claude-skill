Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  root "home#index"

  get  "/signin", to: "auth#new", as: :signin
  get  "/signup", to: redirect("/signin")
  post "/auth", to: "auth#create", as: :auth
  get  "/auth/verify", to: "auth#verify", as: :verify_auth
  delete "/signout", to: "auth#destroy", as: :signout

  post "/newsletter", to: "newsletter#create", as: :newsletter_signup
  post "/checkout", to: "checkout#create", as: :checkout
  post "/webhooks/stripe", to: "webhooks/stripe#create"

  get "up" => "rails/health#show", as: :rails_health_check
end
