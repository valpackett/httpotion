defmodule HTTPotion.Mixfile do
  use Mix.Project

  def project do
    [app: :httpotion,
     version: "0.1.0",
     deps: deps]
  end

  # Configuration for the OTP application
  def application do
    [applications: [:ibrowse]]
  end

  # Returns the list of dependencies in the format:
  # { :foobar, "0.1", git: "https://github.com/elixir-lang/foobar.git" }
  defp deps do
    [
      {:ibrowse, "4.0.1", git: "https://github.com/cmullaparthi/ibrowse.git"}
    ]
  end
end
