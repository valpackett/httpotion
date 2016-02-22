use Mix.Config

config :ex_doc, :markdown_processor, ExDoc.Markdown.Pandoc

config :httpotion, :default_headers, []
config :httpotion, :default_timeout, 5000
config :httpotion, :default_ibrowse, []
config :httpotion, :default_follow_redirects, false
