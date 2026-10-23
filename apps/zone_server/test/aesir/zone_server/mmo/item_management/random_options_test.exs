defmodule Aesir.ZoneServer.Mmo.ItemManagement.RandomOptionsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions

  test "every shipped group rolls only known options and can always fill its picks" do
    for {id, group} <- RandomOptions.groups() do
      entries = List.flatten(group.slots) ++ group.random

      assert Enum.all?(group.slots, &(&1 != [])), "group #{id} has an empty slot"
      assert group.max_random == 0 or group.random != [], "group #{id} draws from no options"

      for entry <- entries do
        assert {:ok, _option} = RandomOptions.option(entry.option_id),
               "group #{id} rolls unknown option #{entry.option_id}"
      end
    end
  end

  @tag game_mode: :renewal
  test "the renewal catalog carries the reference rows" do
    assert {:ok, %{name: "VAR_STRAMOUNT", program: [{:bonus, :str, {:random_option, :value}}]}} =
             RandomOptions.option(3)

    assert map_size(RandomOptions.groups()) > 0
  end
end
