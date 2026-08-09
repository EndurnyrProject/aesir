defmodule Aesir.ZoneServer.Unit.Player.Handlers.LootHandlerKillGainTest do
  @moduledoc """
  On-kill HP/SP gain equipment bonuses (`bHPGainValue`, `bSPGainValue`,
  `bMagicHPGainValue`, `bMagicSPGainValue`, `bLongSPGainValue`, `bSPGainRace`).

  `LootHandler.kill_gain_reward/2` heals the killer for the amount matching the
  killing blow's attack type, but only for the player's own weapon/magic kill.
  """
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Player.Handlers.LootHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatsManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  setup :verify_on_exit!

  setup do
    Mimic.copy(StatsManager)
    Mimic.copy(MessageRouter)
    Mimic.copy(Aesir.ZoneServer.CharacterPersistence)

    # Keep the heal path isolated from registry/network side effects: threading
    # the new game_state back is all the assertions need.
    stub(StatsManager, :update_game_state, fn state, game_state ->
      %{state | game_state: game_state}
    end)

    stub(MessageRouter, :send_to, fn _pid, _packet -> :ok end)
    stub(Aesir.ZoneServer.CharacterPersistence, :update_stats, fn _id, _attrs, _opts -> :ok end)
    :ok
  end

  defp state(equipment, hp \\ 100, sp \\ 50) do
    stats = %Stats{
      current_state: %CurrentState{hp: hp, sp: sp},
      derived_stats: %DerivedStats{max_hp: 1000, max_sp: 500},
      modifiers: %Modifiers{equipment: equipment}
    }

    %SessionState{
      game_state: %PlayerState{character_id: 7, stats: stats, action_state: :idle},
      connection_pid: self()
    }
  end

  defp payload(kill_bf, opts \\ []) do
    %{
      kill_bf: kill_bf,
      mob_race: Keyword.get(opts, :mob_race, :formless),
      final_source: Keyword.get(opts, :final_source, {:player, 7})
    }
  end

  defp vitals(state),
    do: {state.game_state.stats.current_state.hp, state.game_state.stats.current_state.sp}

  test "melee kill grants hp_gain_value HP and sp_gain_value SP" do
    equipment = %{hp_gain_value: 30, sp_gain_value: 12}
    {:noreply, new_state} = LootHandler.kill_gain_reward(payload(:melee), state(equipment))

    assert vitals(new_state) == {130, 62}
  end

  test "melee kill adds sp_gain_race for the matching race plus the wildcard" do
    equipment = %{
      {:sp_gain_race, :formless} => 10,
      {:sp_gain_race, :all} => 3,
      sp_gain_value: 5
    }

    {:noreply, new_state} =
      LootHandler.kill_gain_reward(payload(:melee, mob_race: :formless), state(equipment))

    assert vitals(new_state) == {100, 68}
  end

  test "a non-matching race still gets the sp_gain_race wildcard only" do
    equipment = %{{:sp_gain_race, :demihuman} => 10, {:sp_gain_race, :all} => 3}

    {:noreply, new_state} =
      LootHandler.kill_gain_reward(payload(:melee, mob_race: :formless), state(equipment))

    assert vitals(new_state) == {100, 53}
  end

  test "ranged kill grants only long_sp_gain_value SP (no HP channel)" do
    equipment = %{long_sp_gain_value: 15, hp_gain_value: 99, magic_hp_gain_value: 99}
    {:noreply, new_state} = LootHandler.kill_gain_reward(payload(:ranged), state(equipment))

    assert vitals(new_state) == {100, 65}
  end

  test "magic kill grants magic_hp_gain_value HP and magic_sp_gain_value SP" do
    equipment = %{magic_hp_gain_value: 40, magic_sp_gain_value: 20, hp_gain_value: 99}
    {:noreply, new_state} = LootHandler.kill_gain_reward(payload(:magic), state(equipment))

    assert vitals(new_state) == {140, 70}
  end

  test "the gain is clamped at max HP/SP" do
    equipment = %{hp_gain_value: 5000, sp_gain_value: 5000}

    {:noreply, new_state} =
      LootHandler.kill_gain_reward(payload(:melee), state(equipment, 995, 495))

    assert vitals(new_state) == {1000, 500}
  end

  test "a kill by the player's homunculus grants the owner no on-kill gain" do
    equipment = %{hp_gain_value: 30, sp_gain_value: 12}

    {:noreply, new_state} =
      LootHandler.kill_gain_reward(
        payload(:melee, final_source: {:homunculus, 900}),
        state(equipment)
      )

    assert vitals(new_state) == {100, 50}
  end

  test "a kill credited to a different character grants nothing" do
    equipment = %{hp_gain_value: 30}

    {:noreply, new_state} =
      LootHandler.kill_gain_reward(
        payload(:melee, final_source: {:player, 999}),
        state(equipment)
      )

    assert vitals(new_state) == {100, 50}
  end

  test "an ineligible blow classification (:other) grants nothing" do
    equipment = %{hp_gain_value: 30, sp_gain_value: 12}
    {:noreply, new_state} = LootHandler.kill_gain_reward(payload(:other), state(equipment))

    assert vitals(new_state) == {100, 50}
  end
end
