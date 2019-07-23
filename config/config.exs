use Mix.Config

config :httpotion, :default_headers, [] # NOTE: Must be a keyword list here
config :httpotion, :default_timeout, 10000
# config :httpotion, :default_ibrowse, [.. dynamic TLS conf by default ..]
config :httpotion, :default_auto_sni, true
config :httpotion, :default_follow_redirects, false
