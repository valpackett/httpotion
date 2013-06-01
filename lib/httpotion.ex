defmodule HTTPotion.Base do
  defmacro __using__(_) do
    quote do

      def start do
        :ibrowse.start
        :ssl.start
      end

      def process_url(url) do
        if :string.substr(url, 1, 4) != 'http' do
          :string.concat 'http://', url
        else
          url
        end
      end

      def process_request_body(body) do
        to_char_list body
      end

      def process_response_body(body) do
        to_binary body
      end

      def process_response(status_code, headers, body) do
        HTTPotion.Response.new(
          status_code: elem(:string.to_integer(status_code), 0),
          headers: :orddict.from_list(Enum.map headers, fn ({k, v}) -> { binary_to_atom(to_binary(k)), to_binary(v) } end),
          body: process_response_body(body)
        )
      end

      @doc """
      Sends an HTTP request.
      Args:
        * method - HTTP method, atom (:get, :head, :post, :put, :delete, etc.)
        * url - URL, binary string or char list
        * body - request body, binary string or char list
        * headers - HTTP headers, orddict (eg. [{:Accept, "application/json"}])
        * options - orddict of options
      Options:
        * timeout - timeout in ms, integer
      Returns HTTPotion.Response if successful.
      Raises  HTTPotion.HTTPError if failed.
      """
      def request(method, url, body // "", headers // [], options // []) do
        url = process_url to_char_list(url)
        timeout = Keyword.get options, :timeout, 5000
        headers = Enum.map headers, fn ({k, v}) -> { to_char_list(k), to_char_list(v) } end
        body = process_request_body body
        case :ibrowse.send_req(url, headers, method, body, [], timeout) do
          {:ok, status_code, headers, body} ->
            process_response status_code, headers, body
          {:error, {:conn_failed, {:error, reason}}} ->
            raise HTTPotion.HTTPError.new message: to_binary(reason)
          {:error, reason} ->
            raise HTTPotion.HTTPError.new message: to_binary(reason)
        end
      end

      def get(url, headers // [], options // []), do: request(:get, url, "", headers, options)
      def put(url, body, headers // [], options // []), do: request(:get, url, body, headers, options)
      def head(url, headers // [], options // []), do: request(:head, url, "", headers, options)
      def post(url, body, headers // [], options // []), do: request(:post, url, body, headers, options)
      def delete(url, headers // [], options // []), do: request(:delete, url, "", headers, options)
      def options(url, headers // [], options // []), do: request(:options, url, "", headers, options)

      defoverridable Module.definitions_in(__MODULE__)
    end
  end
end

defmodule HTTPotion do
  @moduledoc """
  The HTTP client for Elixir.
  """

  defrecord Response, status_code: nil, body: nil, headers: []
  defexception HTTPError, message: nil

  use HTTPotion.Base

end
