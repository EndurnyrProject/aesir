defmodule Aesir.ZoneServer.Mmo.ItemManagement.RandomOptionsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Loader, as: ItemGroupsLoader
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs

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

  test "every shipped monster drop and item-group entry names a known group" do
    mob_groups =
      for mob <- Mobs.all(),
          drop <- mob.drops ++ mob.mvp_drops,
          drop.random_option_group,
          do: drop.random_option_group

    for name <- Enum.uniq(mob_groups),
        do: assert({:ok, _group} = RandomOptions.group_by_name(name), "unknown group #{name}")

    for {_key, group} <- ItemGroupsLoader.load(),
        subgroup <- group.subgroups,
        entry <- subgroup.entries,
        entry.random_option_group do
      assert {:ok, _group} = RandomOptions.group(entry.random_option_group)
    end
  end

  test "roll_named rolls nothing for no group name or an unknown one" do
    assert RandomOptions.roll_named(nil) == []
    assert RandomOptions.roll_named("No_Such_Group") == []
  end

  @tag game_mode: :renewal
  test "roll_named rolls a named group's fixed slots" do
    {:ok, group} = RandomOptions.group_by_name("Group_1")

    assert length(RandomOptions.roll_named("Group_1")) >= length(group.slots)
  end

  @tag game_mode: :renewal
  test "the renewal catalog carries the reference rows" do
    assert {:ok, %{name: "VAR_STRAMOUNT", program: [{:bonus, :str, {:random_option, :value}}]}} =
             RandomOptions.option(3)

    assert map_size(RandomOptions.groups()) > 0
  end
end
