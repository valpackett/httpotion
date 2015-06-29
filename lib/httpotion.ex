defmodule HTTPotion.Base do
  defmacro __using__(_) do
    quote do
      def start do
        :application.ensure_all_started(:httpotion)
      end

      def spawn_worker_process(url, options \\ []) do
        GenServer.start(:ibrowse_http_client, url |> process_url |> String.to_char_list, options)
      end

      def spawn_link_worker_process(url, options \\ []) do
        GenServer.start_link(:ibrowse_http_client, url |> process_url |> String.to_char_list, options)
      end

      def stop_worker_process(pid), do: :ibrowse.stop_worker_process(pid)

      def process_url(url) do
        unless url =~ ~r/\Ahttps?:\/\//, do: "http://" <> url, else: url
      end

      def process_request_body(body), do: body

      def process_request_headers(headers), do: headers

      def process_status_code(status_code), do: elem(:string.to_integer(status_code), 0)

      def process_response_body(body = {:file, filename}), do: IO.iodata_to_binary(filename)
      def process_response_body(body), do: IO.iodata_to_binary(body)

      def process_response_chunk(body = {:file, filename}), do: IO.iodata_to_binary(filename)
      def process_response_chunk(chunk = {:error, error}), do: chunk
      def process_response_chunk(chunk), do: IO.iodata_to_binary(chunk)

      def process_response_headers(headers) do
        Enum.reduce(headers, [], fn { k, v }, acc ->
          key = String.to_atom(to_string(k))
          value = to_string(v)

          Dict.update(acc, key, value, &[value | List.wrap(&1)])
        end) |> Enum.sort
      end

      def process_options(options), do: options

      @spec process_arguments(atom, String.t, Dict.t) :: Dict.t
      def process_arguments(method, url, options) do
        options    = process_options(options)
        body       = Dict.get(options, :body, "")
        headers    = Dict.get(options, :headers, [])
        timeout    = Dict.get(options, :timeout, 5000)
        ib_options = Dict.get(options, :ibrowse, [])

        if stream_to = Dict.get(options, :stream_to) do
          ib_options = Dict.put(ib_options, :stream_to, spawn(__MODULE__, :transformer, [stream_to]))
        end

        if user_password = Dict.get(options, :basic_auth) do
          {user, password} = user_password
          ib_options = Dict.put(ib_options, :basic_auth, { to_char_list(user), to_char_list(password) })
        end

        if user_password = Dict.get(options, :digest_auth) do
          {user, password} = user_password
          response = HTTPotion.get(url)          
          digest_token =  HTTPotion.DigestAuth.get_digest_token(response, url, user, password)

          headers =  Dict.put(headers, :"Authorization", "Digest #{digest_token}")
        end

        %{
          method:     method,
          url:        url |> to_string |> process_url |> to_char_list,
          body:       body |> process_request_body,
          headers:    headers |> process_request_headers |> Enum.map(fn ({k, v}) -> { to_char_list(k), to_char_list(v) } end),
          timeout:    timeout,
          ib_options: ib_options
        }
      end

      def transformer(target) do
        receive do
          { :ibrowse_async_headers, id, status_code, headers } ->
            send(target, %HTTPotion.AsyncHeaders{
              id: id,
              status_code: process_status_code(status_code),
              headers: process_response_headers(headers)
            })
            transformer(target)
          { :ibrowse_async_response, id, chunk } ->
            send(target, %HTTPotion.AsyncChunk{
              id: id,
              chunk: process_response_chunk(chunk)
            })
            transformer(target)
          { :ibrowse_async_response_end, id } ->
            send(target, %HTTPotion.AsyncEnd{ id: id })
        end
      end

      @doc """
      Sends an HTTP request.
      Args:
        * method - HTTP method, atom (:get, :head, :post, :put, :delete, etc.)
        * url - URL, binary string or char list
        * options - orddict of options
      Options:
        * body - request body, binary string or char list
        * headers - HTTP headers, orddict (eg. ["Accept": "application/json"])
        * timeout - timeout in ms, integer
        * basic_auth - basic auth credentials (eg. {"user", "password"})
        * stream_to - if you want to make an async request, the pid of the process
        * direct - if you want to use ibrowse's direct feature, the pid of
                   the worker spawned by spawn_worker_process or spawn_link_worker_process
      Returns HTTPotion.Response or HTTPotion.AsyncResponse if successful.
      Raises  HTTPotion.HTTPError if failed.
      """
      @spec request(atom, String.t, Dict.t) :: %HTTPotion.Response{} | %HTTPotion.AsyncResponse{}
      def request(method, url, options \\ []) do
        args = process_arguments(method, url, options)
        if conn_pid = Dict.get(options, :direct) do
          :ibrowse.send_req_direct(conn_pid, args[:url], args[:headers], args[:method], args[:body], args[:ib_options], args[:timeout])
        else
          :ibrowse.send_req(args[:url], args[:headers], args[:method], args[:body], args[:ib_options], args[:timeout])
        end |> handle_response
      end

      @doc "Deprecated form of request; body and headers are now options, see request/3."
      def request(method, url, body, headers, options) do
        request(method, url, options |> Dict.put(:body, body) |> Dict.put(:headers, headers))
      end

      @doc "Deprecated form of request with the direct option; body and headers are now options, see request/3."
      def request_direct(conn_pid, method, url, body \\ "", headers \\ [], options \\ []) do
        request(method, url, options |> Dict.put(:direct, conn_pid))
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
            raise HTTPotion.HTTPError, message: error_to_string(reason)
          { :error, :conn_failed } ->
            raise HTTPotion.HTTPError, message: "conn_failed"
          { :error, reason } ->
            raise HTTPotion.HTTPError, message: error_to_string(reason)
        end
      end

      def get(url,     options \\ []), do: request(:get, url, options)
      def put(url,     options \\ []), do: request(:put, url, options)
      def head(url,    options \\ []), do: request(:head, url, options)
      def post(url,    options \\ []), do: request(:post, url, options)
      def patch(url,   options \\ []), do: request(:patch, url, options)
      def delete(url,  options \\ []), do: request(:delete, url, options)
      def options(url, options \\ []), do: request(:options, url, options)

      defoverridable Module.definitions_in(__MODULE__)
    end
  end
end

defmodule HTTPotion.DigestAuth do
  def get_digest_token(response, url, username, password) do
      digest_head = parse_digest_header(response.headers |> Dict.get(:"WWW-Authenticate"))
      %{"realm" => realm, "nonce"  => nonce} = digest_head
      cnonce = :crypto.strong_rand_bytes(16) |> md5
      url = URI.parse(url)
      response = create_digest_response(
                  username,
                  password,
                  realm,
                  digest_head |> Map.get("qop"),
                  url.path,
                  nonce,
                  cnonce)
      digest =
        [{"username", username},
         {"realm", realm},
         {"nonce", nonce},
         {"uri", url.path},
         {"cnonce", cnonce},
         {"response", response}]
        |> add_opaque(digest_head |> Map.get("opaque"))
        |> Enum.map(fn {key, val} -> {key, "\"#{val}\""} end)
        |> add_nonce_counter
        |> add_auth(digest_head |> Map.get("qop"))
        |> Enum.map(fn {key, val} -> "#{key}=#{val}" end)
        |> Enum.join(", ")
  end

  defp parse_digest_header(auth_head) do
    cond do
      parsed = Regex.scan(~r/(\w+\s*)=\"([\w=\s\\]+)/, auth_head) ->
        parsed
        |> Enum.map(fn [_, key, val] -> {key, val} end)
        |> Enum.into(%{})
      true -> raise "Error in digest authentication header: #{auth_head}"
    end
  end

  defp create_digest_response(username, password, realm, qop, uri, nonce, cnonce) do
    ha1 = [username, realm, password] |> Enum.join(":") |> md5
    ha2 = ["GET", uri] |> Enum.join(":") |> md5
    create_digest_response(ha1, ha2, qop, nonce, cnonce)
  end

  defp create_digest_response(ha1, ha2, nil, nonce, _cnonce),
  do: [ha1, nonce, ha2] |> Enum.join(":") |> md5

  defp create_digest_response(ha1, ha2, _qop, nonce, cnonce) do
    [ha1, nonce, "00000001", cnonce, "auth", ha2] |> Enum.join(":") |> md5
  end

  defp add_opaque(digest, nil), do: digest
  defp add_opaque(digest, opaque), do: [{"opaque", opaque} | digest]

  defp add_nonce_counter(digest), do: [{"nc", "00000001"} | digest]

  defp add_auth(digest, nil) do
    digest
  end

  defp add_auth(digest, cop) do
    cond do
      cop |> String.contains?("auth") -> [{"qop", "\"auth\""} | digest]
      true -> digest
    end
  end

  defp md5(data) do
    Base.encode16(:erlang.md5(data), case: :lower)
  end

end

defmodule HTTPotion do
  @moduledoc """
  The HTTP client for Elixir.
  """

  defmodule Response do
    defstruct status_code: nil, body: nil, headers: []

    def success?(%__MODULE__{ status_code: code }) do
      code in 200..299
    end

    def success?(%__MODULE__{ status_code: code } = response, :extra) do
      success?(response) or code in [302, 304]
    end
  end

  defmodule AsyncResponse do
    defstruct id: nil
  end

  defmodule AsyncHeaders do
    defstruct id: nil, status_code: nil, headers: []
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
