defmodule HTTPotion.Mixfile do
  use Mix.Project

  def project do
    [app: :httpotion,
     version: "0.1.0",
     deps: deps]
  end

  def application do
    [applications: [:ibrowse]]
  end

  defp deps do
    [
      {:ibrowse, "4.0.1", github: "cmullaparthi/ibrowse"}
    ]
  end
end
