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
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

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

  defp state do
    %{game_state: PlayerState.new(character()), connection_pid: self()}
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

  test "places rolled drops via the coordinator" do
    drops = [%MobDrop{item: "Red_Potion", rate: 10_000}]
    rolled = [{501, 1, 200, 90, true}]

    stub(ModifierCalculator, :get_all_modifiers, fn :player, 1 -> %{} end)
    expect(DropCalculator, :roll, fn ^drops, 7, 50, 50, 0, "morocc", 200, 90 -> rolled end)
    expect(Coordinator, :drop_items, fn "morocc", ^rolled, 200, 90 -> :ok end)

    {:noreply, _state} =
      PlayerSession.handle_info({:loot, {:mob_killed, payload(drops)}}, state())
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
