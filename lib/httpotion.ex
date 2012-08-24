defmodule HTTPotion do
  @moduledoc """
  The HTTP client for Elixir.
  """

  defrecord Response, status_code: nil, body: nil, headers: []
  defexception HTTPError, message: nil

  def start do
    :ibrowse.start
  end

  def process_response(status_code, headers, body) do
    Response.new(
      status_code: elem(:string.to_integer(status_code), 1),
      headers: :orddict.from_list(Enum.map headers, fn ({k, v}) -> { binary_to_atom(to_binary(k)), to_binary(v) } end),
      body: to_binary(body)
    )
  end

  @doc """
  Sends an HTTP request.
  Args:
    * method - HTTP method, atom (:get, :head, :post, :put, :delete, etc.)
    * url - URL, binary string
    * body - request body, binary string
    * headers - HTTP headers, orddict (eg. [{:Accept, "application/json"}])
    * options - orddict of options
  Options:
    * timeout - timeout in ms, integer
  """
  def request(method, url, body // "", headers // [], options // []) do
    timeout = options[:timeout] || 5000
    headers = Enum.map headers, fn ({k, v}) -> { to_char_list(k), to_char_list(v) } end
    body = to_char_list body
    case :ibrowse.send_req(to_char_list(url), headers, method, body, [], timeout) do
      {:ok, status_code, headers, body} ->
        process_response status_code, headers, body
      {:error, {:conn_failed, {:error, reason}}} ->
        raise HTTPError.new message: to_binary(reason)
      {:error, reason} ->
        raise HTTPError.new message: to_binary(reason)
    end
  end

  def get(url, headers // [], options // []) do request(:get, url, headers, options) end
  def put(url, body, headers // [], options // []) do request(:get, url, body, headers, options) end
  def head(url, headers // [], options // []) do request(:head, url, headers, options) end
  def post(url, body, headers // [], options // []) do request(:get, url, body, headers, options) end
  def delete(url, headers // [], options // []) do request(:delete, url, headers, options) end
  def options(url, headers // [], options // []) do request(:options, url, headers, options) end
end
