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
    "https://api.github.com" <> url
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

And now with async!

```elixir
iex> HTTPotion.get "http://floatboth.com", [], [stream_to: self]
HTTPotion.AsyncResponse[id: {1372,8757,656584}]
iex> flush()
HTTPotion.AsyncHeaders[id: {1372,8757,656584}, status_code: 200, headers: ["keep-alive", "Content-Type": "text/html;charset=utf-8", Date: "Sun, 23 Jun 2013 17:32:32 GMT", Server: "cloudflare-nginx", "Transfer-Encoding": "chunked"]]
HTTPotion.AsyncChunk[id: {1372,8757,656584}, chunk: "<!DOCTYPE html>\n..."]
HTTPotion.AsyncEnd[id: {1372,8757,656584}]
```

## License

Copyright © 2013 Greg V <floatboth@me.com>  
This work is free. You can redistribute it and/or modify it under the
terms of the Do What The Fuck You Want To Public License, Version 2,
as published by Sam Hocevar. See the COPYING file for more details.
