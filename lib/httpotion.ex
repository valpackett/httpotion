defmodule HTTPotion.Base do
  defmacro __using__(_) do
    quote do
      def start do
        Enum.each [:ssl, :ibrowse], Application.Behaviour.start(&1)
      end

      def process_url(url) do
        unless url =~ %r/\Ahttps?:\/\// do
          "http://" <> url
        else
          url
        end
      end

      def process_request_body(body), do: body

      def process_response_body(body) do
        to_string body
      end

      def process_response_chunk(chunk) do
        to_string chunk
      end

      def process_headers(headers) do
        :orddict.from_list(Enum.map headers, fn ({k, v}) -> { binary_to_atom(to_string(k)), to_string(v) } end)
      end

      def process_status_code(status_code) do
        elem(:string.to_integer(status_code), 0)
      end

      def transformer(target) do
        receive do
          {:ibrowse_async_headers, id, status_code, headers} ->
            target <- HTTPotion.AsyncHeaders[
              id: id,
              status_code: process_status_code(status_code),
              headers: process_headers(headers)
            ]
            transformer(target)
          {:ibrowse_async_response, id, chunk} ->
            target <- HTTPotion.AsyncChunk[
              id: id,
              chunk: process_response_chunk(chunk)
            ]
            transformer(target)
          {:ibrowse_async_response_end, id} ->
            target <- HTTPotion.AsyncEnd[id: id]
        end
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
        url = to_char_list process_url(to_string(url))
        timeout = Keyword.get options, :timeout, 5000
        stream_to = Keyword.get options, :stream_to
        ib_options = Keyword.get options, :ibrowse, []
        if stream_to, do:
          ib_options = Dict.put(ib_options, :stream_to, spawn(__MODULE__, :transformer, [stream_to]))
        headers = Enum.map headers, fn ({k, v}) -> { to_char_list(k), to_char_list(v) } end
        body = process_request_body body
        case :ibrowse.send_req(url, headers, method, body, ib_options, timeout) do
          {:ok, status_code, headers, body} ->
            HTTPotion.Response[
              status_code: process_status_code(status_code),
              headers: process_headers(headers),
              body: process_response_body(body)
            ]
          {:ibrowse_req_id, id} ->
            HTTPotion.AsyncResponse[id: id]
          {:error, {:conn_failed, {:error, reason}}} ->
            raise HTTPotion.HTTPError[message: to_string(reason)]
          {:error, :conn_failed} ->
            raise HTTPotion.HTTPError[message: "conn_failed"]
          {:error, reason} ->
            raise HTTPotion.HTTPError[message: to_string(reason)]
        end
      end

      def get(url, headers // [], options // []),         do: request(:get, url, "", headers, options)
      def put(url, body, headers // [], options // []),   do: request(:put, url, body, headers, options)
      def head(url, headers // [], options // []),        do: request(:head, url, "", headers, options)
      def post(url, body, headers // [], options // []),  do: request(:post, url, body, headers, options)
      def patch(url, body, headers // [], options // []), do: request(:patch, url, body, headers, options)
      def delete(url, headers // [], options // []),      do: request(:delete, url, "", headers, options)
      def options(url, headers // [], options // []),     do: request(:options, url, "", headers, options)

      defoverridable Module.definitions_in(__MODULE__)
    end
  end
end

defmodule HTTPotion do
  @moduledoc """
  The HTTP client for Elixir.
  """

  defrecord Response, status_code: nil, body: nil, headers: []
  defrecord AsyncResponse, id: nil
  defrecord AsyncHeaders, id: nil, status_code: nil, headers: []
  defrecord AsyncChunk, id: nil, chunk: nil
  defrecord AsyncEnd, id: nil

  defexception HTTPError, message: nil

  use HTTPotion.Base
end
