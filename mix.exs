defmodule HTTPotion.Mixfile do
  use Mix.Project

  def project do
    [app: :httpotion,
     version: "0.2.2",
     elixir: "~> 0.10.2",
     deps: deps]
  end

  def application do
    [applications: [:ssl, :ibrowse]]
  end

  defp deps do
    [
      {:ibrowse, "4.0.1", github: "cmullaparthi/ibrowse"}
    ]
  end
end
