Code.require_file "../test_helper.exs", __FILE__

defmodule HTTPotionTest do
  use ExUnit.Case

  test "get" do
    resp = HTTPotion.get "http://localhost:4000"
    assert resp.status_code == 200
    assert resp.headers[:Connection] == "Keep-Alive"
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

end
