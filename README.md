[![hex.pm version](https://img.shields.io/hexpm/v/httpotion.svg?style=flat)](https://hex.pm/packages/httpotion)
[![hex.pm downloads](https://img.shields.io/hexpm/dt/httpotion.svg?style=flat)](https://hex.pm/packages/httpotion)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/httpotion/)
[![Build Status](https://img.shields.io/travis/myfreeweb/httpotion.svg?style=flat)](https://travis-ci.org/myfreeweb/httpotion)
[![unlicense](https://img.shields.io/badge/un-license-green.svg?style=flat)](http://unlicense.org)

# HTTPotion

HTTP client for [Elixir], based on [ibrowse].
Continues the HTTPun tradition of [HTTParty], [HTTPretty], [HTTParrot] and [HTTPie].

## Installation

Add HTTPotion to your project's dependencies in `mix.exs`:

```elixir
  defp deps do
    [
      {:httpotion, "~> 3.1.0"}
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
iex> response = HTTPotion.get "https://httpbin.org/get"
%HTTPotion.Response{
  body: "{\n…",
  headers: %HTTPotion.Headers{ hdrs: %{"connection" => "keep-alive", …} },
  status_code: 200
}

iex> HTTPotion.Response.success?(response)
true

# Response headers are wrapped to allow case-insensitive access (and to support both atoms and strings)
iex> response.headers[:sErvEr]
"meinheld/0.6.1"

iex> response.headers["ConTenT-TyPe"]
"application/json"

# Response headers can have multiple values
iex> response = HTTPotion.get "https://httpbin.org/response-headers?foo=1&foo=2&bar=1"
%HTTPotion.Response{
  body: "{\n…",
  headers: %HTTPotion.Headers{ hdrs: %{"foo" => ["1", "2"], "bar" => "1" …} },
  status_code: 200
}

# You can provide a map for the query string
iex> HTTPotion.get("https://httpbin.org/get", query: %{page: 2})
%HTTPotion.Response{body: "…", headers: …, status_code: 200}

# Follow redirects
iex> HTTPotion.get("https://httpbin.org/redirect-to?url=http%3A%2F%2Fexample.com%2F", follow_redirects: true)
%HTTPotion.Response{body: "…<title>Example Domain</title>…", headers: …, status_code: 200}

# Send form data
iex> HTTPotion.post "https://httpbin.org/post", [body: "hello=" <> URI.encode_www_form("w o r l d !!"),
  headers: ["User-Agent": "My App", "Content-Type": "application/x-www-form-urlencoded"]]
%HTTPotion.Response{body: "…", headers: …, status_code: 200}

# Use a custom method
iex> HTTPotion.request :propfind, "http://httpbin.org/post", [body: "I have no idea what I'm doing"]
%HTTPotion.Response{body: "…", headers: …, status_code: 405}

# Send Basic auth credentials
iex> HTTPotion.get "https://httpbin.org/basic-auth/foo/bar", [basic_auth: {"foo", "bar"}]
%HTTPotion.Response{
  body: "…",
  headers: %HTTPotion.Headers { hdrs: %{"Access-Control-Allow-Credentials": "true", …} },
  status_code: 200
}

# Pass options to ibrowse (note that it usually takes char_lists, not elixir strings)
iex> HTTPotion.get "https://check-tls.akamaized.net", [ ibrowse: [ ssl_options: [ versions, [:'tlsv1.1'] ] ] ]
%HTTPotion.Response{body: "…TLS SNI: present - Check TLS - (https,tls1.1,ipv4)…", headers: …, status_code: 200}

# Change the timeout (default is 5000 ms)
iex> HTTPotion.get "https://example.com", [timeout: 10_000]

# If there is an error a `HTTPotion.ErrorResponse` is returned
iex> HTTPotion.get "http://localhost:1"
%HTTPotion.ErrorResponse{message: "econnrefused"}

# You can also raise `HTTPError` with the `bang` version of request
iex> HTTPotion.get! "http://localhost:1"
** (HTTPotion.HTTPError) econnrefused
```

The `Response` is [a struct](https://elixir-lang.org/getting-started/structs.html), you can access its fields like: `response.body`.

`response.headers` is a struct (`HTTPotion.Headers`) that wraps a map to provide case-insensitive access (so you can use `response.headers[:authorization]` and it doesn't matter if the server returned `AuThOrIZatIOn` or something).

`HTTPError` is [an exception](https://elixir-lang.org/getting-started/try-catch-and-rescue.html) that happens when a bang request (`request!` / `get!` / …) fails.

Available options and their default values:

```elixir
{
  body: "",                # Request's body contents, e.g. "{json: \"string\"}"
  headers: [],             # Request's headers, e.g. [Accept: "application/json"]
  query: nil,              # Query string, e.g. %{page: 1}
  timeout: 5000,           # Timeout in milliseconds, e.g. 5000
  basic_auth: nil,         # Basic auth credentials, e.g. {"username", "password"}
  stream_to: nil,          # A process to stream the response to when performing async requests
  direct: nil,             # An ibrowse worker for direct mode
  ibrowse: [],             # ibrowse options
  auto_sni: true,          # Whether TLS SNI should be automatically configured (does URI parsing)
  follow_redirects: false, # Whether redirects should be followed
}

```

### Metaprogramming magic

You can extend `HTTPotion.Base` to make cool HTTP API wrappers (this example uses [Poison] for JSON):

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
    body |> Poison.decode!
  end
end
```

```elixir
iex> GitHub.get("users/myfreeweb").body["public_repos"]
233
```

Read the source to see all the hooks.

Keep in mind that `process_response_body` and `process_response_chunk` get iodata.
By default, they call `IO.iodata_to_binary`.
But efficient parsers like Poison can work directly on iodata.

### Asynchronous requests

You can get the response streamed to your current process asynchronously:

```elixir
iex> HTTPotion.get "http://httpbin.org/get", [stream_to: self]
%HTTPotion.AsyncResponse{id: -576460752303419903}

iex> flush
%HTTPotion.AsyncHeaders{
  id: -576460752303419903,
  status_code: 200,
  headers: %HTTPotion.Headers{ hdrs: %{"connection" => "keep-alive", …} }
}
%HTTPotion.AsyncChunk{
  id: -576460752303419903,
  chunk: "{\n…"
}
%HTTPotion.AsyncEnd{
  id: -576460752303419903
}
```

Note that instead of `process_response_body`, `process_response_chunk` is called on the chunks before sending them out to the receiver (the `stream_to` process).

### Direct access to ibrowse workers

ibrowse allows you to use its separate worker processes directly.
We expose this functionality through the `direct` option.

Don't forget that you have to pass the URL to the worker process, which means the worker only communicates with one server (domain!)

```elixir
iex> {:ok, worker_pid} = HTTPotion.spawn_worker_process("http://httpbin.org")

iex> HTTPotion.get "httpbin.org/get", [direct: worker_pid]
%HTTPotion.Response{body: "…", headers: ["Connection": "close", …], status_code: 200}
```

You can even combine it with async!

```elixir
iex> {:ok, worker_pid} = HTTPotion.spawn_worker_process("http://httpbin.org")

iex> HTTPotion.post "httpbin.org/post", [direct: worker_pid, stream_to: self, headers: ["User-Agent": "hello it's me"]]
%HTTPotion.AsyncResponse{id: {1372,8757,656584}}
```

### Type analysis

HTTPotion contains [typespecs] so your usage can be checked with [dialyzer], probably via [dialyxir] or [elixir-ls].

HTTPotion's tests are checked with dialyxir.

[Elixir]: https://elixir-lang.org
[ibrowse]: https://github.com/cmullaparthi/ibrowse
[HTTParty]: https://github.com/jnunemaker/httparty
[HTTPretty]: https://github.com/gabrielfalcao/HTTPretty
[HTTParrot]: https://github.com/edgurgel/httparrot
[HTTPie]: https://github.com/jkbr/httpie
[Poison]: https://github.com/devinus/poison
[typespecs]: https://elixir-lang.org/getting-started/typespecs-and-behaviours.html
[dialyzer]: http://erlang.org/doc/man/dialyzer.html
[dialyxir]: https://github.com/jeremyjh/dialyxir
[elixir-ls]: https://github.com/JakeBecker/elixir-ls

## Contributing

Please feel free to submit pull requests!

By participating in this project you agree to follow the [Contributor Code of Conduct](https://www.contributor-covenant.org/version/1/4/).

[The list of contributors is available on GitHub](https://github.com/myfreeweb/httpotion/graphs/contributors).

## License

This is free and unencumbered software released into the public domain.  
For more information, please refer to the `UNLICENSE` file or [unlicense.org](http://unlicense.org).
