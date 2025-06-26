defmodule ZoneServerTest do
  use ExUnit.Case
  doctest ZoneServer

  test "greets the world" do
    assert ZoneServer.hello() == :world
  end
end
