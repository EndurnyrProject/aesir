defmodule Aesir.ZoneServer.Unit.Player.PlayerSessionScriptApplyTest do
  @moduledoc """
  Exercises the production `{:npc, {:script_apply, op}}` `handle_call` clause on
  `PlayerSession` directly: it must apply the op, publish the new state to the
  unit registry, and reply with `{:ok, game_state}` / `{:error, reason}` exactly
  as a routing NPC interaction expects.
  """

  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @zeny_param 20

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Mimic.copy(CharacterPersistence)
    Mimic.copy(UnitRegistry)

    stub(CharacterPersistence, :update_character, fn _, _, _ -> {:ok, %Character{}} end)
    :ok
  end

  test "applies the op, publishes the new state to the registry, replies {:ok, game_state}" do
    test_pid = self()

    expect(UnitRegistry, :update_unit_state, fn :player, 1000, game_state ->
      send(test_pid, {:published, game_state.zeny})
      :ok
    end)

    {:reply, reply, new_state} =
      PlayerSession.handle_call(
        {:npc, {:script_apply, {:pay_zeny, 200}}},
        self(),
        base_state(zeny: 1_000)
      )

    assert {:ok, game_state} = reply
    assert game_state.zeny == 800
    assert new_state.game_state.zeny == 800
    assert_received {:send, _ch, {:param_change, %{var_id: @zeny_param, value: 800}}}
    assert_received {:published, 800}
  end

  test "an error op replies {:error, reason} without publishing or mutating" do
    reject(&UnitRegistry.update_unit_state/3)

    state = base_state(zeny: 50)

    {:reply, reply, new_state} =
      PlayerSession.handle_call({:npc, {:script_apply, {:pay_zeny, 200}}}, self(), state)

    assert reply == {:error, :not_enough_zeny}
    assert new_state == state
  end

  defp base_state(opts) do
    %{
      connection_pid: self(),
      game_state: %PlayerState{
        character_id: 1000,
        account_id: 2000,
        zeny: Keyword.get(opts, :zeny, 0),
        vars: %{},
        temp_vars: %{},
        inventory: %{}
      }
    }
  end
end
