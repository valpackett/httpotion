defmodule HTTPotion.Mixfile do
  use Mix.Project

  def project do
    [ app: :httpotion,
      name: "httpotion",
      source_url: "https://github.com/myfreeweb/httpotion",
      version: "3.0.2",
      elixir:  "~> 1.1",
      docs: [ extras: ["README.md", "CODE_OF_CONDUCT.md"] ],
      description: description(),
      deps: deps(),
      package: package() ]
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
      {:ex_doc, "~> 0.12", only: [:dev, :test, :docs]} ]
  end

  defp package do
    [ files: [ "lib", "mix.exs", "README.md", "CODE_OF_CONDUCT.md", "UNLICENSE" ],
      maintainers: [ "Greg V", "Aleksei Magusev" ],
      licenses: [ "Unlicense" ],
      links: %{ "GitHub" => "https://github.com/myfreeweb/httpotion" } ]
  end
end
