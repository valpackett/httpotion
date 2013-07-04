Code.require_file "../test_helper.exs", __FILE__

defmodule HTTPotionTest do
  use ExUnit.Case

  test "get" do
    resp = HTTPotion.get "http://floatboth.com"
    assert resp.status_code == 200
    assert resp.headers[:Connection] == "keep-alive"
    assert is_binary(resp.body)
  end

  test "fail" do
    assert_raise HTTPotion.HTTPError, "econnrefused", fn ->
      HTTPotion.get "http://localhost:1"
    end
  end

  test "extension" do
    defmodule TestClient do
      use HTTPotion.Base
      def process_url(url) do
        :string.concat 'https://', url
      end
    end

    # you don't have https on localhost, eh?
    assert_raise HTTPotion.HTTPError, "econnrefused", fn ->
      TestClient.get "localhost"
    end
  end

  test "async" do
    HTTPotion.AsyncResponse[id: resp] = HTTPotion.get "http://floatboth.com", [], [stream_to: self]
    receive do
      HTTPotion.AsyncHeaders[id: id, status_code: status_code, headers: headers] ->
        assert id == resp
        assert status_code == 200
        assert headers[:Connection] == "keep-alive"
    end
    receive do
      HTTPotion.AsyncChunk[id: id, chunk: _chunk] ->
        assert id == resp
    end
    receive do
      HTTPotion.AsyncEnd[id: id] ->
        assert id == resp
    end
  end

end
