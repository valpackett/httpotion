Code.require_file "../test_helper", __FILE__

defmodule HTTPotionTest do
  use ExUnit.Case

  test "get" do
    resp = HTTPotion.get "http://localhost:4000"
    assert resp.status_code == 200
    assert resp.headers[:Connection] == "Keep-Alive"
  end

end
