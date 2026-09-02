defmodule Aesir.ZoneServer.Unit.Player.Handlers.LootHandlerZenyTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ParamChange
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Unit.Player.Handlers.LootHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @zeny_param 20

  setup :verify_on_exit!
  setup :set_mimic_from_context

  setup do
    Mimic.copy(CharacterPersistence)
    Mimic.copy(UnitRegistry)

    stub(CharacterPersistence, :update_character, fn _, _, _ -> {:ok, %Character{}} end)
    stub(UnitRegistry, :update_unit_state, fn :player, _, _ -> :ok end)

    :ok
  end

  test "a successful bGetZenyNum roll grants a random amount from 1 through its maximum" do
    state = state(%{get_zeny: {25, 40}})

    assert {:noreply, updated} =
             LootHandler.mob_killed(%{mob_level: 20}, state, fn
               100 -> 25
               40 -> 17
             end)

    assert updated.game_state.zeny == 117

    assert_received {:send, _channel,
                     {:param_change, %ParamChange{var_id: @zeny_param, value: 117}}}
  end

  test "a failed bGetZenyNum chance roll grants nothing" do
    state = state(%{get_zeny: {25, 40}})

    assert {:noreply, ^state} =
             LootHandler.mob_killed(%{mob_level: 20}, state, fn 100 -> 26 end)

    refute_received {:send, _channel, {:param_change, %ParamChange{var_id: @zeny_param}}}
  end

  test "a negative bGetZenyNum amount scales its random maximum by monster level" do
    state = state(%{get_zeny: {100, -3}})

    assert {:noreply, updated} =
             LootHandler.mob_killed(%{mob_level: 20}, state, fn
               100 -> 1
               60 -> 42
             end)

    assert updated.game_state.zeny == 142
  end

  defp state(equipment) do
    game_state = %PlayerState{
      character_id: 7,
      zeny: 100,
      stats: %Stats{modifiers: %Modifiers{equipment: equipment}}
    }

    %SessionState{game_state: game_state, connection_pid: self()}
  end
end
