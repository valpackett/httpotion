defmodule HTTPotion.Mixfile do
  use Mix.Project

  def project do
    [app: :httpotion,
     version: "0.2.4",
     elixir:  ">= 0.13.3",
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
    [{:ibrowse, github: "cmullaparthi/ibrowse", tag: "v4.1.0"}]
  end

  defp package do
    [files: ["lib", "mix.exs", "README.md", "COPYING"],
     contributors: ["Greg V", "Aleksei Magusev"],
     licenses: ["Do What the Fuck You Want to Public License, Version 2"],
     links: %{ "GitHub" => "https://github.com/myfreeweb/httpotion" }]
  end
end
