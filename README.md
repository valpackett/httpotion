# HTTPotion [![hex.pm version](https://img.shields.io/hexpm/v/httpotion.svg?style=flat)](https://hex.pm/packages/httpotion) [![hex.pm downloads](https://img.shields.io/hexpm/dt/httpotion.svg?style=flat)](https://hex.pm/packages/httpotion) [![Build Status](https://img.shields.io/travis/myfreeweb/httpotion.svg?style=flat)](https://travis-ci.org/myfreeweb/httpotion)  [![WTFPL](https://img.shields.io/badge/license-WTFPL-brightgreen.svg?style=flat)](https://www.tldrlegal.com/l/wtfpl)

HTTP client for Elixir, based on [ibrowse].
Continues the HTTPun tradition of [HTTParty], [HTTPretty], [HTTParrot] and [HTTPie].

[ibrowse]: https://github.com/cmullaparthi/ibrowse
[HTTParty]: https://github.com/jnunemaker/httparty
[HTTPretty]: https://github.com/gabrielfalcao/HTTPretty
[HTTParrot]: https://github.com/edgurgel/httparrot
[HTTPie]: https://github.com/jkbr/httpie

## Installation

Add HTTPotion **and ibrowse** to your project's dependencies in `mix.exs`:

```elixir
  defp deps do
    [
      {:ibrowse, github: "cmullaparthi/ibrowse", tag: "v4.1.0"},
      {:httpotion, "~> 0.2.0"}
    ]
  end
```

And fetch your project's dependencies:

```bash
$ mix deps.get
```

## Usage

```iex
iex> HTTPotion.start
{:ok, [:asn1, :public_key, :ssl, :ibrowse, :httpotion]}
iex> response = HTTPotion.get "http://localhost:4000"
%HTTPotion.Response{body: "...", headers: [{:Connection,"Keep-Alive"}...], status_code: 200}
iex> HTTPotion.Response.success?(response)
true

iex> HTTPotion.get "http://localhost:1"
** (HTTPotion.HTTPError) econnrefused
```

You can also extend it to make cool API clients or something (this example uses [jsx](https://github.com/talentdeficit/jsx) for JSON):

```elixir
defmodule GitHub do
  use HTTPotion.Base

  def process_url(url) do
    "https://api.github.com/" <> url
  end

  def process_request_headers(headers) do
    Dict.put headers, :"User-Agent", "github-potion"
  end

  def process_response_body(body) do
    json = :jsx.decode to_string(body)
    json2 = Enum.map json, fn ({k, v}) -> { binary_to_atom(k), v } end
    :orddict.from_list json2
  end
end
```

```iex
iex> GitHub.start
{:ok, [:asn1, :public_key, :ssl, :ibrowse, :httpotion]}
iex> GitHub.get("users/myfreeweb").body[:public_repos]
37
```

And now with async!

```iex
iex> HTTPotion.get "http://floatboth.com", [], [stream_to: self]
%HTTPotion.AsyncResponse{id: {1372,8757,656584}}
iex> flush
%HTTPotion.AsyncHeaders{id: {1372,8757,656584}, status_code: 200, headers: ["keep-alive", "Content-Type": "text/html;charset=utf-8", Date: "Sun, 23 Jun 2013 17:32:32 GMT", Server: "cloudflare-nginx", "Transfer-Encoding": "chunked"]}
%HTTPotion.AsyncChunk{id: {1372,8757,656584}, chunk: "<!DOCTYPE html>\n..."}
%HTTPotion.AsyncEnd{id: {1372,8757,656584}}
```

## License

Copyright © 2013-2014 [myfreeweb](https://github.com/myfreeweb), [lexmag](https://github.com/lexmag) and [contributors](https://github.com/myfreeweb/httpotion/graphs/contributors)
This work is free. You can redistribute it and/or modify it under the
terms of the Do What The Fuck You Want To Public License, Version 2,
as published by Sam Hocevar. See the COPYING file for more details.
