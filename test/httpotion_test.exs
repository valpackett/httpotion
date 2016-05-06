defmodule HTTPotionTest do
  use ExUnit.Case
  import PathHelpers

  test "get" do
    assert_response HTTPotion.get("httpbin.org"), fn(response) ->
      assert match?(<<60, 33, 68, 79, _ :: binary>>, response.body)
    end
  end

  test "head" do
    assert_response HTTPotion.head("httpbin.org/get"), fn(response) ->
      assert response.body == ""
    end
  end

  test "post charlist body" do
    assert_response HTTPotion.post("httpbin.org/post", [body: 'test'])
  end

  test "post binary body" do
    { :ok, file } = File.read(fixture_path("image.png"))

    assert_response HTTPotion.post("httpbin.org/post", [body: file])
  end

  test "put" do
    assert_response HTTPotion.put("httpbin.org/put", [body: "test"])
  end

  test "patch" do
    assert_response HTTPotion.patch("httpbin.org/patch", [body: "test"])
  end

  test "delete" do
    assert_response HTTPotion.delete("httpbin.org/delete")
  end

  test "options" do
    assert_response HTTPotion.options("httpbin.org/get"), fn(response) ->
      assert response.headers[:"Content-Length"] == "0"
      assert is_binary(response.headers[:Allow])
    end
  end

  test "headers" do
    assert_response HTTPotion.head("http://httpbin.org/cookies/set?first=foo&second=bar"), fn(response) ->
      assert_list response.headers[:"Set-Cookie"], ["first=foo; Path=/", "second=bar; Path=/"]
    end
  end

  test "basic_auth option" do
    assert_response HTTPotion.get("http://httpbin.org/basic-auth/foo/bar", [ basic_auth: {"foo", "bar"} ])
  end

  test "ibrowse option" do
    ibrowse = [basic_auth: {'foo', 'bar'}]
    assert_response HTTPotion.get("http://httpbin.org/basic-auth/foo/bar", [ ibrowse: ibrowse ])
  end

  test "ibrowse save_response_to_file" do
    file = Path.join(System.tmp_dir, "httpotion_ibrowse_test.txt")
    ibrowse = [save_response_to_file: String.to_char_list(file)]
    assert_response HTTPotion.get("http://httpbin.org/bytes/2048", [ibrowse: ibrowse])
  end

  test "explicit http scheme" do
    assert_response HTTPotion.head("http://httpbin.org/get")
  end

  test "https scheme" do
    assert_response HTTPotion.head("https://httpbin.org/get")
  end

  test "char list URL" do
    assert_response HTTPotion.head('httpbin.org/get')
  end

  test "query string encoding" do
    assert HTTPotion.process_url("http://example.com", [query: %{param: "value"}]) == "http://example.com?param=value"
  end

  test "get exception" do
    assert_raise HTTPotion.HTTPError, "econnrefused", fn ->
      HTTPotion.get!("localhost:1")
    end
  end
  test "put exception" do
    assert_raise HTTPotion.HTTPError, "econnrefused", fn ->
      HTTPotion.put!("localhost:1")
    end
  end
  test "delete exception" do
    assert_raise HTTPotion.HTTPError, "econnrefused", fn ->
      HTTPotion.delete!("localhost:1")
    end
  end
  test "post exception" do
    assert_raise HTTPotion.HTTPError, "econnrefused", fn ->
      HTTPotion.post!("localhost:1")
    end
  end

  test "extension" do
    defmodule TestClient do
      use HTTPotion.Base

      def process_url(url) do
        send(self, :processed_url)
        super(url)
      end

      def process_options(options) do
        send(self, :processed_options)
        super(options)
      end
    end

    TestClient.head("httpbin.org/get")
    assert_received :processed_url
    assert_received :processed_options
  end

  test "asynchronous request" do
    ibrowse = [basic_auth: {'foo', 'bar'}]
    %HTTPotion.AsyncResponse{ id: id } = HTTPotion.get "httpbin.org/basic-auth/foo/bar", [stream_to: self, ibrowse: ibrowse]

    assert_receive %HTTPotion.AsyncHeaders{ id: ^id, status_code: 200, headers: _headers }, 1_000
    assert_receive %HTTPotion.AsyncChunk{ id: ^id, chunk: _chunk }, 1_000
    assert_receive %HTTPotion.AsyncEnd{ id: ^id }, 1_000
  end

  test "asynchronous follow redirect" do
    ibrowse = [basic_auth: {'foo', 'bar'}]
    %HTTPotion.AsyncResponse{ id: _ } = HTTPotion.get "http://httpbin.org/absolute-redirect/1", [stream_to: self, ibrowse: ibrowse]

    assert_receive %HTTPotion.AsyncHeaders{ status_code: 200, headers: _headers }, 1_000
    assert_receive %HTTPotion.AsyncChunk{ chunk: _chunk }, 1_000
    assert_receive %HTTPotion.AsyncEnd{ }, 1_000
  end

  test "follow relative redirect" do
    response = HTTPotion.get("http://httpbin.org/relative-redirect/1", [ follow_redirects: true ])

    assert_response response
    assert response.status_code == 200
    assert response.headers[:Location] == nil
  end

  test "follow relative https redirect" do
    response = HTTPotion.get("https://httpbin.org/relative-redirect/1", [ follow_redirects: true ])

    assert_response response
    assert response.status_code == 200
    assert response.headers[:Location] == nil
  end

  test "follow absolute redirect" do
    response = HTTPotion.get("http://httpbin.org/absolute-redirect/1", [ follow_redirects: true ])

    assert_response response
    assert response.status_code == 200
    assert response.headers[:Location] == nil
  end

  test "follow absolute https redirect" do
    response = HTTPotion.get("https://httpbin.org/absolute-redirect/1", [ follow_redirects: true ])

    assert_response response
    assert response.status_code == 200
    assert response.headers[:Location] == nil
  end

  defp assert_response(response, function \\ nil) do
    assert HTTPotion.Response.success?(response, :extra)
    assert response.headers[:Connection] == "keep-alive"
    assert is_binary(response.body)

    unless function == nil, do: function.(response)
  end

  defp assert_list(value, expected) do
    Enum.sort(value) == expected
  end
end
