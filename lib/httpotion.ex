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
        GenServer.start(:ibrowse_http_client, url |> process_url(options) |> String.to_charlist, options)
      end

      @doc "Starts a linked worker process for use with the `direct` option."
      def spawn_link_worker_process(url, options \\ []) do
        GenServer.start_link(:ibrowse_http_client, url |> process_url(options) |> String.to_charlist, options)
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

      def process_request_headers(headers, _body), do: process_request_headers(headers)

      def process_request_headers(headers, body, _options), do: process_request_headers(headers, body)

      def process_status_code(status_code), do: elem(:string.to_integer(status_code), 0)

      def process_response_body(body = {:file, filename}), do: IO.iodata_to_binary(filename)
      def process_response_body(body), do: IO.iodata_to_binary(body)

      def process_response_body(_headers, body), do: process_response_body(body)

      def process_response_chunk(body = {:file, filename}), do: IO.iodata_to_binary(filename)
      def process_response_chunk(chunk = {:error, error}), do: chunk
      def process_response_chunk(raw) when is_tuple(raw), do: raw
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

      def redirect_method(response, method) do
        case process_status_code(elem(response, 1)) do
          303 ->
            :get
          _ ->
            method
        end
      end

      def response_ok(response) do
        elem(response, 0) == :ok
      end

      def process_options(options), do: options

      @typedoc """
      List of options to all request functions.

      * `body` - request body
      * `headers` - HTTP headers (e.g. `["Accept": "application/json"]`)
      * `query` - URL query string (e.g. `%{page: 1}`)
      * `timeout` - timeout in milliseconds
      * `basic_auth` - basic auth credentials (e.g. `{"user", "password"}`)
      * `stream_to` - if you want to make an async request, reference to the process
      * `direct` - if you want to use ibrowse's direct feature, reference to
                   the worker spawned by `spawn_worker_process/2` or `spawn_link_worker_process/2`
      * `ibrowse` - options for ibrowse
      * `auto_sni` - if true and the URL is https, configures the `server_name_indication` ibrowse/ssl option
                     to be the host part of the requestedURL
      * `follow_redirects` - if true and a response is a redirect, re-requests with `header[:Location]`
      """
      @type http_opts :: [
        body: binary() | charlist(),
        headers: [{atom() | String.Chars.t, String.Chars.t}],
        query: %{optional(String.Chars.t) => String.Chars.t},
        timeout: timeout(),
        basic_auth: {List.Chars.t, List.Chars.t},
        stream_to: pid() | port() | atom() | {atom(), node()},
        direct: pid() | port() | atom() | {atom(), node()},
        ibrowse: keyword(),
        auto_sni: boolean(),
        follow_redirects: boolean(),
      ]

      @typedoc "Result returned from `request/3`, `get/2`, `post/2`, `put/2`, etc."
      @type http_result :: HTTPotion.Response.t | %HTTPotion.AsyncResponse{} | %HTTPotion.ErrorResponse{}

      @typedoc "Result returned from `request!/3`, `get!/2`, `post!/2`, `put!/2`, etc."
      @type http_result_bang :: HTTPotion.Response.t | %HTTPotion.AsyncResponse{}

      @spec process_arguments(atom, String.Chars.t, http_opts) :: map()
      defp process_arguments(method, url, options) do
        options    = process_options(options)

        url        = url |> to_string |> process_url(options)
        body       = Keyword.get(options, :body, "")
                     |> process_request_body
        headers    = Application.get_env(:httpotion, :default_headers, [])
                     |> Keyword.merge(Keyword.get(options, :headers, [])
                       |> Enum.map(fn ({k, v}) -> { (if is_atom(k), do: k, else: String.to_atom(to_string(k))), to_string(v) } end))
                     |> process_request_headers(body, options)
        timeout    = Keyword.get(options, :timeout, Application.get_env(:httpotion, :default_timeout, 5000))
        ib_options = Application.get_env(:httpotion, :default_ibrowse, [])
                     |> Keyword.merge(Keyword.get(options, :ibrowse, []))
        stream_to  = Keyword.get(options, :stream_to)
        auto_sni   = Keyword.get(options, :auto_sni, Application.get_env(:httpotion, :default_auto_sni, true))
        follow_redirects = Keyword.get(options, :follow_redirects, Application.get_env(:httpotion, :default_follow_redirects, false))

        ib_options = case stream_to do
          {pid, :once} ->
            Keyword.put(ib_options, :stream_to, {spawn(__MODULE__, :transformer, [pid, method, url, options]), :once})
          nil ->
            ib_options
          pid ->
            Keyword.put(ib_options, :stream_to, spawn(__MODULE__, :transformer, [pid, method, url, options]))
        end

        ib_options = if user_password = Keyword.get(options, :basic_auth) do
          {user, password} = user_password
          Keyword.put(ib_options, :basic_auth, { to_charlist(user), to_charlist(password) })
        else
          ib_options
        end

        ib_options = if auto_sni do
          url_parsed = URI.parse url
          if url_parsed.scheme == "https" do
            Keyword.update(ib_options, :ssl_options, [server_name_indication: url_parsed.host |> to_charlist], fn sslo ->
              Keyword.put(sslo, :server_name_indication, url_parsed.host |> to_charlist)
            end)
          else
            ib_options
          end
        else
          ib_options
        end

        %{
          method:     method,
          url:        url |> to_charlist,
          body:       body,
          headers:    headers |> Enum.map(fn ({k, v}) -> { to_charlist(k), to_charlist(v) } end),
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
          { :ibrowse_async_raw_req, raw_req } ->
            send(target, %HTTPotion.AsyncRawRequest{
              raw_request: raw_req
            })
            transformer(target, method, url, options)
          { :ibrowse_async_response, id, chunk } ->
            send(target, %HTTPotion.AsyncChunk{
              id: id,
              chunk: process_response_chunk(chunk)
            })
            transformer(target, method, url, options)
          { :ibrowse_async_response_end, id } ->
            send(target, %HTTPotion.AsyncEnd{ id: id })
          { :ibrowse_async_response_timeout, id } ->
            send(target, %HTTPotion.AsyncTimeout{ id: id })
        end
      end

      @doc """
      Sends an HTTP request.

      See the type documentation of `http_opts` for a description of options.
      """
      @spec request(atom, String.Chars.t, http_opts) :: http_result
      def request(method, url, options \\ []) do
        args = process_arguments(method, url, options)
        response = if conn_pid = Keyword.get(options, :direct) do
          :ibrowse.send_req_direct(conn_pid, args[:url], args[:headers], args[:method], args[:body], args[:ib_options], args[:timeout])
        else
          :ibrowse.send_req(args[:url], args[:headers], args[:method], args[:body], args[:ib_options], args[:timeout])
        end

        if response_ok(response) && is_redirect(response) && args[:follow_redirects] do
          location = process_response_location(response)
          next_url = normalize_location(location, url)
          next_method = redirect_method(response, method)
          request(next_method, next_url, options)
        else
          handle_response response
        end
      end

      @doc """
      Like `request/3`, but raises  `HTTPotion.HTTPError` if failed.
      """
      @spec request!(atom, String.Chars.t, http_opts) :: http_result_bang
      def request!(method, url, options \\ []) do
        case request(method, url, options) do
          %HTTPotion.ErrorResponse{message: message} ->
            raise HTTPotion.HTTPError, message: message
          response -> response
        end
      end

      defp normalize_location(location, url) do
        URI.merge(url, location) |> URI.to_string()
      end

      @deprecated "Use request/3 instead"
      def request(method, url, body, headers, options) do
        request(method, url, options |> Keyword.put(:body, body) |> Keyword.put(:headers, headers))
      end

      @deprecated "Use request/3 with 'direct' option instead"
      def request_direct(conn_pid, method, url, body \\ "", headers \\ [], options \\ []) do
        request(method, url, options |> Keyword.put(:direct, conn_pid))
      end

      defp error_to_string(error) do
        if is_atom(error) or String.valid?(error), do: to_string(error), else: inspect(error)
      end

      def handle_response(response) do
        case response do
          { :ok, status_code, headers, body, _ } ->
            processed_headers = process_response_headers(headers)
            %HTTPotion.Response{
              status_code: process_status_code(status_code),
              headers: processed_headers,
              body: process_response_body(processed_headers, body)
            }
          { :ok, status_code, headers, body } ->
            processed_headers = process_response_headers(headers)
            %HTTPotion.Response{
              status_code: process_status_code(status_code),
              headers: processed_headers,
              body: process_response_body(processed_headers, body)
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
      @spec get(String.Chars.t, http_opts) :: http_result
      def get(url,     options \\ []), do: request(:get, url, options)
      @doc "A shortcut for `request!(:get, url, options)`."
      @spec get!(String.Chars.t, http_opts) :: http_result_bang
      def get!(url,    options \\ []), do: request!(:get, url, options)

      @doc "A shortcut for `request(:put, url, options)`."
      @spec put(String.Chars.t, http_opts) :: http_result
      def put(url,     options \\ []), do: request(:put, url, options)
      @doc "A shortcut for `request!(:put, url, options)`."
      @spec put!(String.Chars.t, http_opts) :: http_result_bang
      def put!(url,    options \\ []), do: request!(:put, url, options)

      @doc "A shortcut for `request(:head, url, options)`."
      @spec head(String.Chars.t, http_opts) :: http_result
      def head(url,    options \\ []), do: request(:head, url, options)
      @doc "A shortcut for `request!(:head, url, options)`."
      @spec head!(String.Chars.t, http_opts) :: http_result_bang
      def head!(url,   options \\ []), do: request!(:head, url, options)

      @doc "A shortcut for `request(:post, url, options)`."
      @spec post(String.Chars.t, http_opts) :: http_result
      def post(url,    options \\ []), do: request(:post, url, options)
      @doc "A shortcut for `request!(:post, url, options)`."
      @spec post!(String.Chars.t, http_opts) :: http_result_bang
      def post!(url,   options \\ []), do: request!(:post, url, options)

      @doc "A shortcut for `request(:patch, url, options)`."
      @spec patch(String.Chars.t, http_opts) :: http_result
      def patch(url,   options \\ []), do: request(:patch, url, options)
      @doc "A shortcut for `request!(:patch, url, options)`."
      @spec patch!(String.Chars.t, http_opts) :: http_result_bang
      def patch!(url,  options \\ []), do: request!(:patch, url, options)

      @doc "A shortcut for `request(:delete, url, options)`."
      @spec delete(String.Chars.t, http_opts) :: http_result
      def delete(url,  options \\ []), do: request(:delete, url, options)
      @doc "A shortcut for `request!(:delete, url, options)`."
      @spec delete!(String.Chars.t, http_opts) :: http_result_bang
      def delete!(url,  options \\ []), do: request!(:delete, url, options)

      @doc "A shortcut for `request(:options, url, options)`."
      @spec options(String.Chars.t, http_opts) :: http_result
      def options(url, options \\ []), do: request(:options, url, options)
      @doc "A shortcut for `request!(:options, url, options)`."
      @spec options!(String.Chars.t, http_opts) :: http_result_bang
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
    defstruct status_code: -1, body: nil, headers: []
    @type t :: %__MODULE__{status_code: integer(), body: any(), headers: Access.t}

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
    @behaviour Access

    defp normalized_key(key) do
      key |> to_string |> String.downcase
    end

    def fetch(%Headers{hdrs: headers}, key) do
      Map.fetch(headers, normalized_key(key))
    end

    def get(%Headers{hdrs: headers}, key, default) do
      Map.get(headers, normalized_key(key), default)
    end

    def get_and_update(%Headers{hdrs: headers}, key, acc) do
      {val, updated} = Map.get_and_update(headers, normalized_key(key), acc)
      {val, %Headers{hdrs: updated}}
    end

    def pop(%Headers{hdrs: headers}, key) do
      {val, updated} = Map.pop(headers, normalized_key(key))
      {val, %Headers{hdrs: updated}}
    end
  end

  defmodule AsyncResponse do
    defstruct id: nil
  end

  defmodule AsyncHeaders do
    defstruct id: nil, status_code: -1, headers: []
    @type t :: %__MODULE__{id: any(), status_code: integer(), headers: Access.t}
  end

  defmodule AsyncChunk do
    defstruct id: nil, chunk: nil
  end

  defmodule AsyncEnd do
    defstruct id: nil
  end

  defmodule AsyncRawRequest do
    defstruct id: nil, raw_request: nil
  end

  defmodule AsyncTimeout do
    defstruct id: nil
  end

  defmodule HTTPError do
    defexception [:message]
  end

  use HTTPotion.Base
end
