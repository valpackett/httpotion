# HTTPotion [![Build Status](https://travis-ci.org/myfreeweb/httpotion.png?branch=master)](https://travis-ci.org/myfreeweb/httpotion)

HTTP client for Elixir, based on [ibrowse](https://github.com/cmullaparthi/ibrowse).
Continues the HTTPun tradition of [HTTParty](https://github.com/jnunemaker/httparty), [HTTPretty](https://github.com/gabrielfalcao/HTTPretty) and [HTTPie](https://github.com/jkbr/httpie).

## Usage

```elixir
iex> HTTPotion.start
iex> HTTPotion.get "http://localhost:4000"
HTTPotion.Response[body: "...", headers: [{:Connection,"Keep-Alive"}...], status_code: 200]

iex> HTTPotion.get "http://localhost:1"
** (HTTPotion.HTTPError) econnrefused
```

You can also extend it to make cool API clients or something (this example uses [jsx](https://github.com/talentdeficit/jsx) for JSON):

```elixir
defmodule GitHub do
  use HTTPotion.Base
  def process_url(url) do
    :string.concat 'https://api.github.com/', url
  end
  def process_response_body(body) do
    json = :jsx.decode to_binary(body)
    json2 = Enum.map json, fn ({k, v}) -> { binary_to_atom(k), v } end
    :orddict.from_list json2
  end
end

iex> GitHub.start
iex> GitHub.get("users/myfreeweb").body[:public_repos]
37
```
