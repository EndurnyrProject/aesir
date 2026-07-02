defmodule Aesir.ZoneServer.Unit.Player.PlayerSessionDropTest do
  @moduledoc """
  Exercises the killer-session drop wiring on the `:mob_killed` handler: EXP is
  still awarded, the drop table is rolled with the killer's LUK/base level, and
  a non-empty roll is placed through the map `Coordinator`.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.ItemDrop.DropCalculator
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Unit.Player.Handlers.ExperienceHandler
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

  # mob_level matches the killer's base_level (50) so the renewal level-gap
  # penalty is neutral (rate 100) and does not affect the mocked EXP amounts
  # this file is actually exercising (drop wiring).
  defp payload(drops) do
    %{
      mob_id: 1001,
      base_exp: 100,
      job_exp: 50,
      drops: drops,
      mob_level: 50,
      map: "morocc",
      x: 200,
      y: 90
    }
  end

  test "awards exp and places rolled drops via the coordinator" do
    test_pid = self()

    expect(ExperienceHandler, :handle_gain_exp, fn 100, 50, state ->
      send(test_pid, :exp_awarded)
      {:noreply, state}
    end)

    drops = [%MobDrop{item: "Red_Potion", rate: 10_000}]
    rolled = [{501, 1, 200, 90}]

    expect(DropCalculator, :roll, fn ^drops, 7, 50, 50, "morocc", 200, 90 -> rolled end)
    expect(Coordinator, :drop_items, fn "morocc", ^rolled, 200, 90 -> :ok end)

    {:noreply, _state} = PlayerSession.handle_info({:mob_killed, payload(drops)}, state())

    assert_received :exp_awarded
  end

  test "an empty roll does not call the coordinator" do
    expect(ExperienceHandler, :handle_gain_exp, fn 100, 50, state -> {:noreply, state} end)

    drops = [%MobDrop{item: "Red_Potion", rate: 1}]
    expect(DropCalculator, :roll, fn ^drops, 7, 50, 50, "morocc", 200, 90 -> [] end)
    reject(&Coordinator.drop_items/4)

    {:noreply, _state} = PlayerSession.handle_info({:mob_killed, payload(drops)}, state())
  end

  test "a legacy payload without drops still awards exp and skips drops" do
    expect(ExperienceHandler, :handle_gain_exp, fn 10, 0, state -> {:noreply, state} end)
    reject(&DropCalculator.roll/7)
    reject(&Coordinator.drop_items/4)

    {:noreply, _state} =
      PlayerSession.handle_info(
        {:mob_killed, %{base_exp: 10, job_exp: 0, mob_level: 50}},
        state()
      )
  end
end
