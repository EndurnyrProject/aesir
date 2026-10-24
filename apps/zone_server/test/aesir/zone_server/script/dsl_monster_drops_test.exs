defmodule Aesir.ZoneServer.Script.DslMonsterDropsTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Group
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.StealOps

  setup :set_mimic_private

  setup do
    on_exit(&Mobs.reload/0)
    :ok
  end

  @poring 1002
  @jellopy 909
  @apple 512
  @knife 1201

  defp ctx,
    do: %Ctx{
      char_id: 1,
      account_id: 100,
      connection_pid: nil,
      game_state: nil,
      source: {:npc, :test}
    }

  defp drops, do: Mobs.by_id(@poring) |> elem(1) |> Map.fetch!(:drops)

  describe "search_name/3" do
    defp mob(id, aegis, name, opts \\ []) do
      %MobDefinition{
        id: id,
        aegis_name: aegis,
        name: name,
        japanese_name: Keyword.get(opts, :jname),
        base_exp: Keyword.get(opts, :base_exp, 0),
        level: 1,
        hp: 1,
        stats: %{},
        attack_range: 1,
        size: :small,
        race: :formless,
        element: {:neutral, 1},
        walk_speed: 200,
        attack_delay: 1000,
        attack_motion: 500,
        client_attack_motion: 500,
        damage_motion: 300
      }
    end

    test "matches an aegis name always and a name only for a mob with experience or a spawn" do
      mobs = [
        mob(1, "SLAVE_A", "Slave"),
        mob(2, "SPAWNED", "Spawned"),
        mob(3, "HUNTED", "Hunted", base_exp: 5, jname: "Kariudo")
      ]

      spawned = MapSet.new([2])

      assert Mobs.search_name("slave_a", mobs, spawned) == 1
      assert Mobs.search_name("Slave", mobs, spawned) == 0
      assert Mobs.search_name("spawned", mobs, spawned) == 2
      assert Mobs.search_name("hunted", mobs, spawned) == 3
      assert Mobs.search_name("KARIUDO", mobs, spawned) == 3
    end

    test "the lowest id that matches wins and the clone id range is skipped" do
      mobs = [mob(20, "TWIN", "Shared", base_exp: 1), mob(10, "OTHER", "Twin", base_exp: 1)]
      assert Mobs.search_name("twin", mobs, MapSet.new()) == 10

      clone = [mob(4000, "CLONE", "Clone", base_exp: 1)]
      assert Mobs.search_name("CLONE", clone, MapSet.new()) == 0
    end

    test "names compare on their first 24 characters" do
      long = String.duplicate("a", 24)
      mobs = [mob(1, long <> "TAIL", "x", base_exp: 1)]
      assert Mobs.search_name(long, mobs, MapSet.new()) == 1
    end
  end

  describe "addmonsterdrop" do
    test "updates the first drop of the same item in place, or appends a new one" do
      assert {_ctx, 1} = Dsl.addmonsterdrop(ctx(), @poring, @apple, 5000, 1)

      assert [_, _, _, %MobDrop{item: "Apple", rate: 5000, steal_protected: true}, _, apple2 | _] =
               drops()

      assert %MobDrop{item: "Apple", rate: 150} = apple2

      assert {_ctx, 1} = Dsl.addmonsterdrop(ctx(), "PORING", @knife, 10_000)
      assert %MobDrop{item: "Knife", rate: 10_000, random_option_group: nil} = List.last(drops())
    end

    test "a full drop table refuses a new item but still updates one it has" do
      assert {_ctx, 1} = Dsl.addmonsterdrop(ctx(), @poring, @knife, 10)
      assert {_ctx, 1} = Dsl.addmonsterdrop(ctx(), @poring, 501, 10)
      assert length(drops()) == 10

      assert {_ctx, 0} = Dsl.addmonsterdrop(ctx(), @poring, 502, 10)
      assert {_ctx, 1} = Dsl.addmonsterdrop(ctx(), @poring, 501, 20)
    end

    test "carries a random option group only for weapon, armour and shadow gear" do
      stub(RandomOptions, :group, fn
        5 -> {:ok, %Group{id: 5, name: "Group_5", slots: [], max_random: 0, random: []}}
        _id -> :error
      end)

      assert {_ctx, 1} = Dsl.addmonsterdrop(ctx(), @poring, @knife, 10, 0, 5)
      assert %MobDrop{random_option_group: "Group_5"} = List.last(drops())

      assert {_ctx, 0} = Dsl.addmonsterdrop(ctx(), @poring, @jellopy, 10, 0, 5)
      assert {_ctx, 0} = Dsl.addmonsterdrop(ctx(), @poring, @knife, 10, 0, 6)
    end

    test "an unknown monster or item, or a rate outside 1..10000, changes nothing" do
      before = drops()

      assert {_ctx, 0} = Dsl.addmonsterdrop(ctx(), 999_999, @apple, 10)
      assert {_ctx, 0} = Dsl.addmonsterdrop(ctx(), @poring, 999_999, 10)
      assert {_ctx, 0} = Dsl.addmonsterdrop(ctx(), @poring, @apple, 0)
      assert {_ctx, 0} = Dsl.addmonsterdrop(ctx(), @poring, @apple, 10_001)
      assert drops() == before
    end
  end

  describe "a monster spawned before the edit" do
    setup :setup_ets_tables

    test "is stolen from with its kind's edited table" do
      {:ok, poring} = Mobs.by_id(@poring)

      spawn_ref = %MobSpawn{
        mob: @poring,
        amount: 1,
        respawn_time: 1,
        spawn_area: %SpawnArea{x: 0, y: 0}
      }

      state = Aesir.TestMob.publish(MobState.new(1, poring, spawn_ref, "prontera", 0, 0))
      first_roll = fn _bound -> 0 end

      assert {:ok, @jellopy, _state} = StealOps.attempt_steal(state, 1_000, 10, first_roll)

      assert {_ctx, 1} = Dsl.delmonsterdrop(ctx(), @poring, @jellopy)
      assert {:ok, item_id, _state} = StealOps.attempt_steal(state, 1_000, 10, first_roll)
      refute item_id == @jellopy
    end
  end

  describe "delmonsterdrop" do
    test "removes every drop of the item and returns 1, or 0 when the monster has none" do
      assert {_ctx, 1} = Dsl.delmonsterdrop(ctx(), @poring, @apple)
      refute Enum.any?(drops(), &(&1.item == "Apple"))

      assert {_ctx, 0} = Dsl.delmonsterdrop(ctx(), @poring, @apple)
    end

    test "an unknown item or monster fails the command, reads 0 and the script goes on" do
      assert {%Ctx{status: :ok, failures: [{:delmonsterdrop, :unknown_item}]}, 0} =
               Dsl.delmonsterdrop(ctx(), @poring, 999_999)

      assert {%Ctx{status: :ok, failures: [{:delmonsterdrop, :unknown_mob}]}, 0} =
               Dsl.delmonsterdrop(ctx(), 999_999, @apple)
    end
  end
end
