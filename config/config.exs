use Mix.Config

config :httpotion, :default_headers, [] # NOTE: Must be a keyword list here
config :httpotion, :default_timeout, 5000
config :httpotion, :default_ibrowse, []
config :httpotion, :default_auto_sni, true
config :httpotion, :default_follow_redirects, false
