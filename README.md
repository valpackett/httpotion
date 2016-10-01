# HTTPotion [![hex.pm version](https://img.shields.io/hexpm/v/httpotion.svg?style=flat)](https://hex.pm/packages/httpotion) [![hex.pm downloads](https://img.shields.io/hexpm/dt/httpotion.svg?style=flat)](https://hex.pm/packages/httpotion) [![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/httpotion/) [![Build Status](https://img.shields.io/travis/myfreeweb/httpotion.svg?style=flat)](https://travis-ci.org/myfreeweb/httpotion) [![unlicense](https://img.shields.io/badge/un-license-green.svg?style=flat)](http://unlicense.org)

HTTP client for [Elixir], based on [ibrowse].
Continues the HTTPun tradition of [HTTParty], [HTTPretty], [HTTParrot] and [HTTPie].

## Installation

Add HTTPotion to your project's dependencies in `mix.exs`:

```elixir
  defp deps do
    [
      {:httpotion, "~> 3.0.2"}
    ]
  end

  def application do
    [ applications: [:httpotion] ]
    # Application dependency auto-starts it, otherwise: HTTPotion.start
  end
```

And fetch your project's dependencies:

```bash
$ mix deps.get
```

## Usage

*Note*: You can load HTTPotion into the Elixir REPL by executing this command from the root of your project:

```
$ iex -S mix
```

Some basic examples:

```elixir
iex> response = HTTPotion.get "httpbin.org/get"
%HTTPotion.Response{body: "...", headers: [Connection: "keep-alive", ...], status_code: 200}

iex> HTTPotion.Response.success?(response)
true

# HTTPotion also supports querystrings like
iex> HTTPotion.get("httpbin.org/get", query: %{page: 2})
%HTTPotion.Response{body: "...", headers: [Connection: "keep-alive", ...], status_code: 200}

# Form data
iex> HTTPotion.post "https://httpbin.org/post", [body: "hello=" <> URI.encode_www_form("w o r l d !!"),
  headers: ["User-Agent": "My App", "Content-Type": "application/x-www-form-urlencoded"]]
%HTTPotion.Response{body: "...", headers: [Connection: "keep-alive", ...], status_code: 200}

iex> HTTPotion.request :propfind, "http://httpbin.org/post", [body: "I have no idea what I'm doing"]
%HTTPotion.Response{body: "...", headers: [Connection: "keep-alive", ...], status_code: 405}

iex> HTTPotion.get "httpbin.org/basic-auth/foo/bar", [basic_auth: {"foo", "bar"}]
%HTTPotion.Response{body: "...", headers: ["Access-Control-Allow-Credentials": "true", ...], status_code: 200}

# Passing options to ibrowse (note that it usually takes char_lists, not elixir strings)
iex> HTTPotion.get "http://ip6.me", [ ibrowse: [ proxy_host: 'fc81:6134:ba6c:8458:c99f:6c01:6472:8f1e', proxy_port: 8118 ] ]
%HTTPotion.Response{body: "...", headers: [Connection: "keep-alive", ...], status_code: 200}

# The default timeout is 5000 ms, but can be changed
iex> HTTPotion.get "http://example.com", [timeout: 10_000]

# If there is an error a `HTTPotion.ErrorResponse` is returned
iex> HTTPotion.get "http://localhost:1"
%HTTPotion.ErrorResponse{message: "econnrefused"}

# You can also raise `HTTPError` with the `bang` version of request
iex> HTTPotion.get! "http://localhost:1"
** (HTTPotion.HTTPError) econnrefused
```

The `Response` is [a struct](http://elixir-lang.org/getting-started/structs.html) – you access its fields like this: `response.body`.

`response.headers` is a `HTTPotion.Headers` struct that provides case-insensitive access (so you can use `response.headers[:authorization]` and it doesn't matter if the server returned `AuThOrIZatIOn` or something).

`HTTPError` is [an exception](http://elixir-lang.org/getting-started/try-catch-and-rescue.html) that happens when the request fails.

*Note*: the API changed in 2.0.0, body and headers are options now!

Available options and their default value:

```elixir
{
  body: "",                # Request's body contents Ex.: "{json: \"string\"}"
  headers: [],             # Request's headers. Ex.: ["Accepts" => "application/json"]
  timeout: 5000,           # Timeout in milliseconds Ex: 5000
  ibrowse: [],             # ibrowse options
  follow_redirects: false, # Specify whether redirects should be followed
  stream_to: nil,          # Specify a process to stream the response to when performing async requests
  basic_auth: nil,         # Basic auth credentials. Ex.: {"username", "password"}
}

```

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
    body |> IO.iodata_to_binary |> :jsx.decode
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

Don't forget that `IO.iodata_to_binary` is called by default in `process_response_body` and `process_response_chunk`, you'll probably need to call it too.

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

Note that instead of `process_response_body`, `process_response_chunk` is called on the chunks before sending them out to the receiver (the `stream_to` process).

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

By participating in this project you agree to follow the [Contributor Code of Conduct](http://contributor-covenant.org/version/1/1/0/).

[The list of contributors is available on GitHub](https://github.com/myfreeweb/httpotion/graphs/contributors).

## License

This is free and unencumbered software released into the public domain.  
For more information, please refer to the `UNLICENSE` file or [unlicense.org](http://unlicense.org).
