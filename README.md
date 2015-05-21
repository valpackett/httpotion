# HTTPotion [![hex.pm version](https://img.shields.io/hexpm/v/httpotion.svg?style=flat)](https://hex.pm/packages/httpotion) [![hex.pm downloads](https://img.shields.io/hexpm/dt/httpotion.svg?style=flat)](https://hex.pm/packages/httpotion) [![Build Status](https://img.shields.io/travis/myfreeweb/httpotion.svg?style=flat)](https://travis-ci.org/myfreeweb/httpotion)  [![WTFPL](https://img.shields.io/badge/license-WTFPL-brightgreen.svg?style=flat)](https://www.tldrlegal.com/l/wtfpl)

HTTP client for [Elixir], based on [ibrowse].
Continues the HTTPun tradition of [HTTParty], [HTTPretty], [HTTParrot] and [HTTPie].

## Installation

Add HTTPotion **and ibrowse** to your project's dependencies in `mix.exs`:

```elixir
  defp deps do
    [
      {:ibrowse, github: "cmullaparthi/ibrowse", tag: "v4.1.1"},
      {:httpotion, "~> 2.1.0"}
    ]
  end
  
  def application do
    [applications: [:httpotion]]
    # Application dependency auto-starts it, otherwise: HTTPotion.start
  end
```

And fetch your project's dependencies:

```bash
$ mix deps.get
```

## Usage

Some basic examples:

```elixir
iex> response = HTTPotion.get "httpbin.org/get"
%HTTPotion.Response{body: "...", headers: [Connection: "keep-alive", ...], status_code: 200}

iex> HTTPotion.Response.success?(response)
true

iex> response = HTTPotion.post "https://httpbin.org/post", [body: "hello=world", headers: ["User-Agent": "My App"]]
%HTTPotion.Response{body: "...", headers: [Connection: "keep-alive", ...], status_code: 200}

iex> response = HTTPotion.request :propfind, "http://httpbin.org/post", [body: "I have no idea what I'm doing"]
%HTTPotion.Response{body: "...", headers: [Connection: "keep-alive", ...], status_code: 405}

iex> response = HTTPotion.get "httpbin.org/basic-auth/foo/bar", [basic_auth: {"foo", "bar"}]
%HTTPotion.Response{body: "...", headers: ["Access-Control-Allow-Credentials": "true", ...], status_code: 200}

iex> HTTPotion.get "http://localhost:1"
** (HTTPotion.HTTPError) econnrefused
```

The `Response` is [a struct](http://elixir-lang.org/getting-started/structs.html) – you access its fields like this: `response.body`.

`HTTPError` is [an exception](http://elixir-lang.org/getting-started/try-catch-and-rescue.html) that happens when the request fails.

*Note*: the API changed in 2.0.0, body and headers are options now!

### Metaprogramming magic

You can extend `HTTPotion.Base` to make cool API clients or something (this example uses [jsx] for JSON):

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
    body |> to_string |> :jsx.decode
    |> Enum.map fn ({k, v}) -> { String.to_atom(k), v } end
    |> :orddict.from_list
  end
end
```

```elixir
iex> GitHub.get("users/myfreeweb").body[:public_repos]
37
```

Read the source to see all the hooks.
It's not intimidating at all, pretty easy to read actually :-)

### Asynchronous requests

Hey, we're on the Erlang VM, right?
Every serious OTP app probably makes a lot of these.
It's easy to do in HTTPotion.

```elixir
iex> HTTPotion.get "http://httpbin.org/get", [stream_to: self]
%HTTPotion.AsyncResponse{id: {1372,8757,656584}}

iex> flush
%HTTPotion.AsyncHeaders{id: {1372,8757,656584}, status_code: 200, headers: ["Transfer-Encoding": "chunked", ...]}
%HTTPotion.AsyncChunk{id: {1372,8757,656584}, chunk: "<!DOCTYPE html>\n..."}
%HTTPotion.AsyncEnd{id: {1372,8757,656584}}
```

### Direct access to ibrowse workers

ibrowse allows you to use its separate worker processes directly.
We expose this functionality through the `direct` option.

Don't forget that you have to pass the URL to the worker process, which means the worker only communicates with one server (domain!)

```elixir
iex> {:ok, worker_pid} = HTTPotion.spawn_worker_process("http://httpbin.org")

iex> HTTPotion.get "httpbin.org/get", [direct: worker_pid]
%HTTPotion.Response{body: "...", headers: ["Connection": "close", ...], status_code: 200}
```

You can even combine it with async!

```elixir
iex> {:ok, worker_pid} = HTTPotion.spawn_worker_process("http://httpbin.org")

iex> HTTPotion.post "httpbin.org/post", [direct: worker_pid, stream_to: self, headers: ["User-Agent": "hello it's me"]]
%HTTPotion.AsyncResponse{id: {1372,8757,656584}}
```

[Elixir]: http://elixir-lang.org
[ibrowse]: https://github.com/cmullaparthi/ibrowse
[HTTParty]: https://github.com/jnunemaker/httparty
[HTTPretty]: https://github.com/gabrielfalcao/HTTPretty
[HTTParrot]: https://github.com/edgurgel/httparrot
[HTTPie]: https://github.com/jkbr/httpie
[jsx]: https://github.com/talentdeficit/jsx

## Contributing

Please feel free to submit pull requests!
Bugfixes and simple non-breaking improvements will be accepted without any questions :-)

By participating in this project you agree to follow the [Contributor Code of Conduct](http://contributor-covenant.org/version/1/0/0/).

## License

Copyright © 2013-2015 [HTTPotion Contributors](https://github.com/myfreeweb/httpotion/graphs/contributors).

This work is free. You can redistribute it and/or modify it under the
terms of the Do What The Fuck You Want To Public License, Version 2,
as published by Sam Hocevar. See the COPYING file for more details.
