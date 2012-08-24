# HTTPotion

HTTP client for Elixir, based on [ibrowse](https://github.com/cmullaparthi/ibrowse).
Continues the HTTPun tradition of [HTTParty](https://github.com/jnunemaker/httparty) and [HTTPie](https://github.com/jkbr/httpie).

## Usage

```elixir
iex> HTTPotion.get "http://localhost:4000"
HTTPotion.Response[body: "...", headers: [{:Connection,"Keep-Alive"}...], status_code: 200]

iex> HTTPotion.get "http://localhost:1"
** (HTTPotion.HTTPError) econnrefused
```
