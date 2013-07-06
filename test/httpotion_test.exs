Code.require_file "../test_helper.exs", __FILE__

defmodule HTTPotionTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  test "get" do
    assert_response HTTPotion.get("http://httpbin.org/get")
  end

  test "head" do
    assert_response HTTPotion.head("http://httpbin.org/get"), fn(response) ->
      assert response.body == ""
    end
  end

  test "post" do
    assert_response HTTPotion.post("http://httpbin.org/post", "test")
  end

  test "put" do
    assert_response HTTPotion.put("http://httpbin.org/put", "test")
  end

  test "patch" do
    assert_response HTTPotion.patch("http://httpbin.org/patch", "test")
  end

  test "delete" do
    assert_response HTTPotion.delete("http://httpbin.org/delete")
  end

  test "options" do
    assert_response HTTPotion.options("http://httpbin.org/get"), fn(response) ->
      assert response.headers[:Allow] == "HEAD, OPTIONS, GET"
    end
  end

  test "https scheme" do
    assert_response HTTPotion.head("https://httpbin.org/get")
  end

  test "exception" do
    assert_raise HTTPotion.HTTPError, "econnrefused", fn ->
      HTTPotion.get "http://localhost:1"
    end
  end

  test "extension" do
    defmodule TestClient do
      use HTTPotion.Base

      def process_url(url) do
        IO.write "ok"

        super(url)
      end
    end

    assert capture_io(fn -> TestClient.head("http://httpbin.org/get") end) == "ok"
  end

  test "asynchronous request" do
    HTTPotion.AsyncResponse[id: id] = HTTPotion.get "http://httpbin.org/get", [], [stream_to: self]

    assert_receive HTTPotion.AsyncHeaders[id: ^id, status_code: 200, headers: _headers], 1_000
    assert_receive HTTPotion.AsyncChunk[id: ^id, chunk: _chunk], 1_000
    assert_receive HTTPotion.AsyncEnd[id: ^id], 1_000
  end

  def assert_response(response, function // nil) do
    assert response.status_code == 200
    assert response.headers[:Connection] == "keep-alive"
    assert is_binary(response.body)

    unless function == nil, do: function.(response)
  end
end
