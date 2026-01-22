Rails.application.routes.draw do
  post "/encode", to: "short_urls#encode"
  post "/decode", to: "short_urls#decode"
  get "/:code", to: "short_urls#redirect"
end
