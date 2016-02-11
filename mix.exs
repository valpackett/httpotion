defmodule HTTPotion.Mixfile do
  use Mix.Project

  def project do
    [ app: :httpotion,
      name: "httpotion",
      source_url: "https://github.com/myfreeweb/httpotion",
      version: "2.1.0",
      elixir:  "~> 1.0",
      docs: [ extras: ["README.md"] ],
      description: description,
      deps: deps,
      package: package ]
  end

  def application do
    [ applications: [:ssl, :ibrowse] ]
  end

  defp description do
    """
    Fancy HTTP client for Elixir, based on ibrowse.
    """
  end

  defp deps do
    [ {:ibrowse, "~> 4.2"},
      {:ex_doc, "~> 0.11", only: [:dev, :test]} ]
  end

  defp package do
    [ files: [ "lib", "mix.exs", "README.md", "UNLICENSE" ],
      contributors: [ "Greg V", "Aleksei Magusev", "thilko", "pragdave", "Adam Kittelson", "Greg", "Ookami Kenrou", "Guillermo Iguaran", "jadlr", "Sumeet Singh", "Hugo Ribeira", "parroty", "Daniel Berkompas", "Arkar Aung", "Henrik Nyh", "Joseph Wilk", "Low Kian Seong", "Nick", "Aidan Steele", "Paulo Almeida", "Peter Hamilton", "Rachel Bowyer", "Steve", "Strand McCutchen", "Syohei YOSHIDA", "Tomos John Rees", "Wojciech Kaczmarek", "d0rc", "falood", "Eduardo Gurgel", "Dave Thomas", "Eito Katagiri", "Everton Ribeiro", "Florian J. Breunig", "Gabe Kopley", "Arjan van der Gaag" ],
      licenses: [ "Unlicense", "Do What the Fuck You Want to Public License, Version 2" ],
      links: %{ "GitHub" => "https://github.com/myfreeweb/httpotion" } ]
  end
end
