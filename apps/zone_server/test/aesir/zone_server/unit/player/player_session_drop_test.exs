defmodule Aesir.ZoneServer.Unit.Player.PlayerSessionDropTest do
  @moduledoc """
  Exercises the killer-session drop wiring on the `:mob_killed` handler: the
  drop table is rolled with the killer's LUK/base level and a non-empty roll
  is placed through the map `Coordinator`. EXP no longer flows through this
  handler (see `Unit.Mob.KillExp` / `{:mob_kill_exp, ...}`), so it is not
  exercised here.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.ItemDrop.DropCalculator
  alias Aesir.ZoneServer.Mmo.ItemDrop.LootOwnership
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.OreTable
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Player.Handlers.LootHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  setup do
    Mimic.copy(OreTable)
  end

  defp character do
    %Character{
      id: 1,
      account_id: 100,
      name: "Killer",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      class: 0,
      base_level: 50,
      job_level: 50,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 7
    }
  end

  defp state(opts \\ []) do
    game_state = PlayerState.new(character())

    game_state =
      put_in(
        game_state.stats.progression.learned_skills,
        Keyword.get(opts, :learned_skills, %{})
      )

    %{game_state: game_state, connection_pid: self()}
  end

  defp payload(drops) do
    %{
      mob_id: 1001,
      drops: drops,
      mob_level: 50,
      map: "morocc",
      x: 200,
      y: 90
    }
  end

  test "places a legacy payload's rolled drops publicly via the coordinator" do
    drops = [%MobDrop{item: "Red_Potion", rate: 10_000}]
    rolled = [{501, 1, 200, 90, true}]

    stub(ModifierCalculator, :get_all_modifiers, fn :player, 1 -> %{} end)
    expect(DropCalculator, :roll, fn ^drops, 7, 50, 50, 0, "morocc", 200, 90 -> rolled end)
    expect(Coordinator, :drop_items, fn "morocc", ^rolled, 200, 90 -> :ok end)

    {:noreply, _state} =
      PlayerSession.handle_info({:loot, {:mob_killed, payload(drops)}}, state())
  end

  test "threads ownership through to the coordinator" do
    drops = [%MobDrop{item: "Red_Potion", rate: 10_000}]
    rolled = [{501, 1, 200, 90, true}]
    ownership = %LootOwnership{first: 1, second: 2, third: 3}
    owned_payload = Map.merge(payload(drops), %{ownership: ownership, boss?: true})

    stub(ModifierCalculator, :get_all_modifiers, fn :player, 1 -> %{} end)
    expect(DropCalculator, :roll, fn ^drops, 7, 50, 50, 0, "morocc", 200, 90 -> rolled end)

    expect(Coordinator, :drop_items, fn "morocc",
                                        ^rolled,
                                        200,
                                        90,
                                        ownership: {^ownership, true} ->
      :ok
    end)

    {:noreply, _state} =
      PlayerSession.handle_info({:loot, {:mob_killed, owned_payload}}, state())
  end

  test "a killer without Ore Discovery receives only normal drops" do
    drops = [%MobDrop{item: "Red_Potion", rate: 10_000}]
    rolled = [{501, 1, 200, 90, true}]

    stub(ModifierCalculator, :get_all_modifiers, fn :player, 1 -> %{} end)
    stub(DropCalculator, :roll, fn ^drops, 7, 50, 50, 0, "morocc", 200, 90 -> rolled end)
    reject(&OreTable.entries/0)
    expect(Coordinator, :drop_items, fn "morocc", ^rolled, 200, 90 -> :ok end)

    {:noreply, _state} =
      PlayerSession.handle_info({:loot, {:mob_killed, payload(drops)}}, state())
  end

  test "Ore Discovery adds at most one ore after all normal drops" do
    drops = [%MobDrop{item: "Red_Potion", rate: 10_000}, %MobDrop{item: "Orange", rate: 10_000}]
    rolled = [{501, 1, 200, 90, true}, {502, 1, 201, 90, true}]
    expected = rolled ++ [{700, 1, 200, 90, true}]

    stub(ModifierCalculator, :get_all_modifiers, fn :player, 1 -> %{} end)
    stub(DropCalculator, :roll, fn ^drops, 7, 50, 50, 0, "morocc", 200, 90 -> rolled end)
    stub(OreTable, :entries, fn -> [{700, 10_000}] end)
    expect(Coordinator, :drop_items, fn "morocc", ^expected, 200, 90 -> :ok end)

    assert {:noreply, _state} =
             LootHandler.mob_killed(
               payload(drops),
               state(learned_skills: %{106 => 1}),
               fn _upper -> 1 end
             )
  end

  test "a Homunculus final blow keeps normal drops but skips player-only Ore Discovery" do
    drops = [%MobDrop{item: "Red_Potion", rate: 10_000}]
    rolled = [{501, 1, 200, 90, true}]
    typed_payload = Map.put(payload(drops), :final_source, {:homunculus, 20})

    stub(ModifierCalculator, :get_all_modifiers, fn :player, 1 -> %{} end)
    expect(DropCalculator, :roll, fn ^drops, 7, 50, 50, 0, "morocc", 200, 90 -> rolled end)
    reject(&OreTable.entries/0)
    expect(Coordinator, :drop_items, fn "morocc", ^rolled, 200, 90 -> :ok end)

    assert {:noreply, _state} =
             LootHandler.mob_killed(
               typed_payload,
               state(learned_skills: %{106 => 1}),
               fn _upper -> 1 end
             )
  end

  test "Ore Discovery selects an entry before rolling its rate" do
    drops = [%MobDrop{item: "Red_Potion", rate: 10_000}]
    expected = [{701, 1, 200, 90, true}]

    stub(ModifierCalculator, :get_all_modifiers, fn :player, 1 -> %{} end)
    stub(DropCalculator, :roll, fn ^drops, 7, 50, 50, 0, "morocc", 200, 90 -> [] end)
    stub(OreTable, :entries, fn -> [{700, 1}, {701, 5_000}] end)
    expect(Coordinator, :drop_items, fn "morocc", ^expected, 200, 90 -> :ok end)

    rng = fn
      2 ->
        Process.put(:ore_entry_selected, true)
        2

      10_000 ->
        true = Process.get(:ore_entry_selected)
        5_000
    end

    assert {:noreply, _state} =
             LootHandler.mob_killed(payload(drops), state(learned_skills: %{106 => 1}), rng)
  end

  test "threads the killer's drop_rate bonus into the roll" do
    drops = [%MobDrop{item: "Red_Potion", rate: 10_000}]

    stub(ModifierCalculator, :get_all_modifiers, fn :player, 1 -> %{drop_rate: 100} end)
    expect(DropCalculator, :roll, fn ^drops, 7, 50, 50, 100, "morocc", 200, 90 -> [] end)
    reject(&Coordinator.drop_items/4)

    {:noreply, _state} =
      PlayerSession.handle_info({:loot, {:mob_killed, payload(drops)}}, state())
  end

  test "an empty roll does not call the coordinator" do
    drops = [%MobDrop{item: "Red_Potion", rate: 1}]
    stub(ModifierCalculator, :get_all_modifiers, fn :player, 1 -> %{} end)
    expect(DropCalculator, :roll, fn ^drops, 7, 50, 50, 0, "morocc", 200, 90 -> [] end)
    reject(&Coordinator.drop_items/4)

    {:noreply, _state} =
      PlayerSession.handle_info({:loot, {:mob_killed, payload(drops)}}, state())
  end

  test "a legacy payload without drops skips drop rolling" do
    reject(&DropCalculator.roll/8)
    reject(&Coordinator.drop_items/4)

    {:noreply, _state} =
      PlayerSession.handle_info({:loot, {:mob_killed, %{mob_level: 50}}}, state())
  end
end
