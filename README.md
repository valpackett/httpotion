# HTTPotion [![Build Status](https://travis-ci.org/myfreeweb/httpotion.png?branch=master)](https://travis-ci.org/myfreeweb/httpotion)

HTTP client for Elixir, based on [ibrowse](https://github.com/cmullaparthi/ibrowse).
Continues the HTTPun tradition of [HTTParty](https://github.com/jnunemaker/httparty), [HTTPretty](https://github.com/gabrielfalcao/HTTPretty), [HTTParrot](https://github.com/edgurgel/httparrot) and [HTTPie](https://github.com/jkbr/httpie).

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
    Dict.put headers, "User-Agent", "github-potion"
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
