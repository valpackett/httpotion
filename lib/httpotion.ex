defmodule HTTPotion.Base do
  @moduledoc """
  The base module of HTTPotion.

  When used, it defines overridable functions, which allows you to make customized HTTP client modules (see the README).
  It is used by the `HTTPotion` module to provide the a basic general-purpose client.
  """

  defmacro __using__(_) do
    quote do

      @doc "Ensures that HTTPotion and its dependencies are started."
      def start do
        :application.ensure_all_started(:httpotion)
      end

      @doc "Starts a worker process for use with the `direct` option."
      def spawn_worker_process(url, options \\ []) do
        GenServer.start(:ibrowse_http_client, url |> process_url(options) |> String.to_char_list, options)
      end

      @doc "Starts a linked worker process for use with the `direct` option."
      def spawn_link_worker_process(url, options \\ []) do
        GenServer.start_link(:ibrowse_http_client, url |> process_url(options) |> String.to_char_list, options)
      end

      @doc "Stops a worker process started with `spawn_worker_process/2` or `spawn_link_worker_process/2`."
      def stop_worker_process(pid), do: :ibrowse.stop_worker_process(pid)

      def process_url(url), do: url

      def process_url(url, options) do
        process_url(url)
        |> prepend_protocol
        |> append_query_string(options)
      end

      defp prepend_protocol(url) do
        if url =~ ~r/\Ahttps?:\/\// do
          url
        else
          "http://" <> url
        end
      end

      defp append_query_string(url, options) do
        if options[:query] do
          url <> "?#{URI.encode_query(options[:query])}"
        else
          url
        end
      end

      def process_request_body(body), do: body

      def process_request_headers(headers), do: headers

      def process_status_code(status_code), do: elem(:string.to_integer(status_code), 0)

      def process_response_body(body = {:file, filename}), do: IO.iodata_to_binary(filename)
      def process_response_body(body), do: IO.iodata_to_binary(body)

      def process_response_chunk(body = {:file, filename}), do: IO.iodata_to_binary(filename)
      def process_response_chunk(chunk = {:error, error}), do: chunk
      def process_response_chunk(chunk), do: IO.iodata_to_binary(chunk)

      def process_response_location(response) do
        process_response_headers(elem(response, 2))[:Location]
      end

      def process_response_headers(headers) do
        headers_list = Enum.reduce(headers, %{}, fn { k, v }, acc ->
          key = k |> to_string |> String.downcase
          value = v |> to_string

          Map.update(acc, key, value, &[value | List.wrap(&1)])
        end)
        %HTTPotion.Headers{hdrs: headers_list}
      end

      def is_redirect(response) do
        status_code = process_status_code(elem(response, 1))
        status_code > 300 && status_code < 400
      end

      def response_ok(response) do
        elem(response, 0) == :ok
      end

      def process_options(options), do: options

      @spec process_arguments(atom, String.t, [{atom(), any()}]) :: %{}
      defp process_arguments(method, url, options) do
        options    = process_options(options)

        body       = Keyword.get(options, :body, "")
        headers    = Keyword.merge Application.get_env(:httpotion, :default_headers, []), Keyword.get(options, :headers, [])
        timeout    = Keyword.get(options, :timeout, Application.get_env(:httpotion, :default_timeout, 5000))
        ib_options = Keyword.merge Application.get_env(:httpotion, :default_ibrowse, []), Keyword.get(options, :ibrowse, [])
        follow_redirects = Keyword.get(options, :follow_redirects, Application.get_env(:httpotion, :default_follow_redirects, false))

        ib_options = if stream_to = Keyword.get(options, :stream_to), do: Keyword.put(ib_options, :stream_to, spawn(__MODULE__, :transformer, [stream_to, method, url, options])), else: ib_options
        ib_options = if user_password = Keyword.get(options, :basic_auth) do
          {user, password} = user_password
          Keyword.put(ib_options, :basic_auth, { to_char_list(user), to_char_list(password) })
        else
          ib_options
        end

        %{
          method:     method,
          url:        url |> to_string |> process_url(options) |> to_char_list,
          body:       body |> process_request_body,
          headers:    headers |> process_request_headers |> Enum.map(fn ({k, v}) -> { to_char_list(k), to_char_list(v) } end),
          timeout:    timeout,
          ib_options: ib_options,
          follow_redirects: follow_redirects
        }
      end

      def transformer(target, method, url, options) do
        receive do
          { :ibrowse_async_headers, id, status_code, headers } ->
            if(process_status_code(status_code) in [302, 304]) do
              location = process_response_headers(headers)[:Location]
              request(method, normalize_location(location, url), options)
            else
              send(target, %HTTPotion.AsyncHeaders{
                id: id,
                status_code: process_status_code(status_code),
                headers: process_response_headers(headers)
              })
              transformer(target, method, url, options)
            end
          { :ibrowse_async_response, id, chunk } ->
            send(target, %HTTPotion.AsyncChunk{
              id: id,
              chunk: process_response_chunk(chunk)
            })
            transformer(target, method, url, options)
          { :ibrowse_async_response_end, id } ->
            send(target, %HTTPotion.AsyncEnd{ id: id })
        end
      end

      @doc """
      Sends an HTTP request.

      Args:

      * `method` - HTTP method, atom (:get, :head, :post, :put, :delete, etc.)
      * `url` - URL, binary string or char list
      * `options` - orddict of options

      Options:

      * `body` - request body, binary string or char list
      * `headers` - HTTP headers, orddict (eg. `["Accept": "application/json"]`)
      * `timeout` - timeout in ms, integer
      * `basic_auth` - basic auth credentials (eg. `{"user", "password"}`)
      * `stream_to` - if you want to make an async request, the pid of the process
      * `direct` - if you want to use ibrowse's direct feature, the pid of
                  the worker spawned by `spawn_worker_process/2` or `spawn_link_worker_process/2`
      * `follow_redirects` - if true and a response is a redirect, header[:Location] is taken for the next request

      Returns `HTTPotion.Response` or `HTTPotion.AsyncResponse` if successful.
      Returns `HTTPotion.ErrorResponse` if failed.
      """
      @spec request(atom, String.t, [{atom(), any()}]) :: %HTTPotion.Response{} | %HTTPotion.AsyncResponse{} | %HTTPotion.ErrorResponse{}
      def request(method, url, options \\ []) do
        args = process_arguments(method, url, options)
        response = if conn_pid = Keyword.get(options, :direct) do
          :ibrowse.send_req_direct(conn_pid, args[:url], args[:headers], args[:method], args[:body], args[:ib_options], args[:timeout])
        else
          :ibrowse.send_req(args[:url], args[:headers], args[:method], args[:body], args[:ib_options], args[:timeout])
        end

        if response_ok(response) && is_redirect(response) && options[:follow_redirects] do
          location = process_response_location(response)
          next_url = normalize_location(location, url)
          request(method, next_url, options)
        else
          handle_response response
        end
      end

      @doc """
      Like `request`, but raises  `HTTPotion.HTTPError` if failed.
      """
      @spec request!(atom, String.t, [{atom(), any()}]) :: %HTTPotion.Response{} | %HTTPotion.AsyncResponse{}
      def request!(method, url, options \\ []) do
        case request(method, url, options) do
          %HTTPotion.ErrorResponse{message: message} ->
            raise HTTPotion.HTTPError, message: message
          response -> response
        end
      end

      defp normalize_location(location, url) do
        if String.starts_with?(location, "http") do
          location
        else
          Regex.named_captures(~r/(?<url>https?:\/\/.*?)\//, url)["url"] <> location
        end
      end

      @doc "Deprecated form of `request`; body and headers are now options, see `request/3`."
      def request(method, url, body, headers, options) do
        request(method, url, options |> Keyword.put(:body, body) |> Keyword.put(:headers, headers))
      end

      @doc "Deprecated form of `request` with the `direct` option; body and headers are now options, see `request/3`."
      def request_direct(conn_pid, method, url, body \\ "", headers \\ [], options \\ []) do
        request(method, url, options |> Keyword.put(:direct, conn_pid))
      end

      defp error_to_string(error) do
        if is_atom(error) or String.valid?(error), do: to_string(error), else: inspect(error)
      end

      def handle_response(response) do
        case response do
          { :ok, status_code, headers, body, _ } ->
            %HTTPotion.Response{
              status_code: process_status_code(status_code),
              headers: process_response_headers(headers),
              body: process_response_body(body)
            }
          { :ok, status_code, headers, body } ->
            %HTTPotion.Response{
              status_code: process_status_code(status_code),
              headers: process_response_headers(headers),
              body: process_response_body(body)
            }
          { :ibrowse_req_id, id } ->
            %HTTPotion.AsyncResponse{ id: id }
          { :error, { :conn_failed, { :error, reason }}} ->
            %HTTPotion.ErrorResponse{ message: error_to_string(reason)}
          { :error, :conn_failed } ->
            %HTTPotion.ErrorResponse{ message: "conn_failed"}
          { :error, reason } ->
            %HTTPotion.ErrorResponse{ message: error_to_string(reason)}
        end
      end

      @doc "A shortcut for `request(:get, url, options)`."
      def get(url,     options \\ []), do: request(:get, url, options)
      @doc "A shortcut for `request!(:get, url, options)`."
      def get!(url,     options \\ []), do: request!(:get, url, options)

      @doc "A shortcut for `request(:put, url, options)`."
      def put(url,     options \\ []), do: request(:put, url, options)
      @doc "A shortcut for `request!(:put, url, options)`."
      def put!(url,     options \\ []), do: request!(:put, url, options)

      @doc "A shortcut for `request(:head, url, options)`."
      def head(url,    options \\ []), do: request(:head, url, options)
      @doc "A shortcut for `request!(:head, url, options)`."
      def head!(url,    options \\ []), do: request!(:head, url, options)

      @doc "A shortcut for `request(:post, url, options)`."
      def post(url,    options \\ []), do: request(:post, url, options)
      @doc "A shortcut for `request!(:post, url, options)`."
      def post!(url,    options \\ []), do: request!(:post, url, options)

      @doc "A shortcut for `request(:patch, url, options)`."
      def patch(url,   options \\ []), do: request(:patch, url, options)
      @doc "A shortcut for `request!(:patch, url, options)`."
      def patch!(url,   options \\ []), do: request!(:patch, url, options)

      @doc "A shortcut for `request(:delete, url, options)`."
      def delete(url,  options \\ []), do: request(:delete, url, options)
      @doc "A shortcut for `request!(:delete, url, options)`."
      def delete!(url,  options \\ []), do: request!(:delete, url, options)

      @doc "A shortcut for `request(:options, url, options)`."
      def options(url, options \\ []), do: request(:options, url, options)
      @doc "A shortcut for `request!(:options, url, options)`."
      def options!(url, options \\ []), do: request!(:options, url, options)

      defoverridable Module.definitions_in(__MODULE__)
    end
  end
end

defmodule HTTPotion do
  @moduledoc """
  The HTTP client for Elixir.

  This module contains a basic general-purpose HTTP client.
  Everything in this module is created with `use HTTPotion.Base`.
  You can create your own customized client modules (see the README).
  """

  defmodule Response do
    defstruct status_code: nil, body: nil, headers: []

    def success?(%__MODULE__{ status_code: code }) do
      code in 200..299
    end
    def success?(_unknown) do
      false
    end

    def success?(%__MODULE__{ status_code: code } = response, :extra) do
      success?(response) or code in [302, 304]
    end
    def success?(_unknown, _extra) do
      false
    end

  end

  defmodule ErrorResponse do
    defstruct message: nil
  end

  defmodule Headers do
    defstruct hdrs: %{}

    defp normalized_key(key) do
      key |> to_string |> String.downcase
    end

    def fetch(%Headers{hdrs: headers}, key) do
      Map.fetch(headers, normalized_key(key))
    end

    def get_and_update(%Headers{hdrs: headers}, key, acc) do
      {val, updated} = Map.get_and_update(headers, normalized_key(key), acc)
      {val, %Headers{hdrs: updated}}
    end
  end

  defmodule AsyncResponse do
    defstruct id: nil
  end

  defmodule AsyncHeaders do
    defstruct id: nil, status_code: nil, headers: %{}
  end

  defmodule AsyncChunk do
    defstruct id: nil, chunk: nil
  end

  defmodule AsyncEnd do
    defstruct id: nil
  end

  defmodule HTTPError do
    defexception [:message]
  end

  use HTTPotion.Base
end
