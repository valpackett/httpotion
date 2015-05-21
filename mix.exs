defmodule HTTPotion.Mixfile do
  use Mix.Project

  def project do
    [app: :httpotion,
     version: "2.1.0",
     elixir:  "~> 1.0",
     description: description,
     deps: deps,
     package: package]
  end

  def application do
    [applications: [:ssl, :ibrowse]]
  end

  defp description do
    """
    Fancy HTTP client for Elixir, based on ibrowse.
    """
  end

  defp deps do
    [{:ibrowse, github: "cmullaparthi/ibrowse", tag: "v4.1.1"}]
  end

  defp package do
    [files: ["lib", "mix.exs", "README.md", "COPYING"],
     contributors: ["Greg V", "Aleksei Magusev", "pragdave", "Adam Kittelson", "Ookami Kenrou", "Sumeet Singh", "Guillermo Iguaran", "jadlr", "parroty", "Daniel Berkompas", "Florian J. Breunig", "Gabe Kopley", "Arjan van der Gaag", "Joseph Wilk", "Aidan Steele", "Paulo Almeida", "Peter Hamilton", "Rachel Bowyer", "Steve", "Wojciech Kaczmarek", "d0rc", "falood", "Arkar Aung", "Dave Thomas", "Eduardo Gurgel", "Eito Katagiri", "Everton Ribeiro"],
     licenses: ["Do What the Fuck You Want to Public License, Version 2"],
     links: %{ "GitHub" => "https://github.com/myfreeweb/httpotion" }]
  end
end
