defmodule HTTPotion.Mixfile do
  use Mix.Project

  def project do
    if Mix.env == :dial, do: Application.ensure_all_started(:ex_unit)
    [ app: :httpotion,
      name: "httpotion",
      source_url: "https://github.com/myfreeweb/httpotion",
      version: "3.1.0",
      elixir:  "~> 1.3",
      docs: [ extras: ["README.md", "CODE_OF_CONDUCT.md"] ],
      description: description(),
      deps: deps(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env),
      test_pattern: "*_test.ex",
      warn_test_pattern: "*_test.exs",
      preferred_cli_env: [ dialyzer: :dial ] ]
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
    [ {:ibrowse, "~> 4.4"},
      {:ex_doc, "~> 0.18", only: [:dev, :test, :docs]} ]
  end

  defp package do
    [ files: [ "lib", "mix.exs", "README.md", "CODE_OF_CONDUCT.md", "UNLICENSE" ],
      maintainers: [ "Greg V", "Aleksei Magusev" ],
      licenses: [ "Unlicense" ],
      links: %{ "GitHub" => "https://github.com/myfreeweb/httpotion" } ]
  end

  # http://learningelixir.joekain.com/dialyzer-and-integration-tests/
  # modified to only compile for dialyzer, not for running tests
  defp elixirc_paths(:dial), do: ["lib", "test"]
  defp elixirc_paths(_),     do: ["lib"]
end
