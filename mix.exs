defmodule HTTPotion.Mixfile do
  use Mix.Project

  def project do
    [app: :httpotion,
     version: "0.2.3",
     elixir:  "> 0.12.3",
     deps: deps]
  end

  def application do
    [applications: [:ssl, :ibrowse]]
  end

  defp deps do
    [{ :ibrowse, github: "cmullaparthi/ibrowse", tag: "v4.1.0" }]
  end
end
