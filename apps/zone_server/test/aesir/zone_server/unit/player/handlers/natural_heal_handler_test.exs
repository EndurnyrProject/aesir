defmodule Aesir.ZoneServer.Unit.Player.Handlers.NaturalHealHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ParamChange
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Unit.Player.Handlers.NaturalHealHandler
  alias Aesir.ZoneServer.Unit.Player.NaturalHeal.Timing
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # SP_HP / SP_SP param ids
  @sp_hp 5
  @sp_sp 7
  # VIT 50 and max HP 500: 10 + 2 HP per natural heal.
  @hp_amount 12
  @red_potion 501

  setup :set_mimic_from_context

  setup do
    Mimic.copy(CharacterPersistence)
    Mimic.copy(ModifierCalculator)
    Mimic.copy(Passives)

    stub(UnitRegistry, :update_unit_state, fn _, _, _ -> :ok end)
    stub(CharacterPersistence, :update_stats, fn _, _, _ -> {:ok, %Character{}} end)
    stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

    stub(Passives, :regen, fn _ ->
      %{skill_hp_regen: 0, skill_sp_regen: 0, allow_while_moving: false}
    end)

    stub(Passives, :sitting_regen, fn _ -> %{sitting_hp_regen: 0, sitting_sp_regen: 0} end)

    :ok
  end

  describe "handle_tick/2" do
    test "publishes regenerated HP/SP as one complete resource snapshot" do
      state = build_state(hp: 100, sp: 50)

      game_state = %{
        state.game_state
        | party_id: 7,
          character_name: "Aesir",
          map_name: "prontera"
      }

      test_pid = self()

      stub(Manager, :sync_member, fn 7, 1, member ->
        send(test_pid, {:party_member, member})
        {:ok, %{}}
      end)

      assert {:noreply, updated} =
               NaturalHealHandler.handle_tick(%{state | game_state: game_state}, 500)

      assert_receive {:party_member, member}

      assert member == %Member{
               char_id: 1,
               name: "Aesir",
               job_id: 0,
               base_level: 1,
               hp: 100 + @hp_amount,
               max_hp: 500,
               sp: updated.game_state.stats.current_state.sp,
               max_sp: 500,
               ap: 0,
               max_ap: 0,
               online: true,
               map_name: "prontera"
             }
    end

    test "a zero-delta tick only advances the timing" do
      reject(UnitRegistry, :update_unit_state, 3)
      reject(CharacterPersistence, :update_stats, 3)
      state = build_state(hp: 500, sp: 500)

      assert {:noreply, updated} = NaturalHealHandler.handle_tick(state, 500)

      assert updated.game_state === state.game_state
      assert updated.regen_timing == %Timing{clock_ms: 500, hp_last_ms: 500, sp_last_ms: 500}
      refute_received {:send, _channel, _payload}
    end

    test "a healing tick commits and pushes and persists only the changed resource" do
      test_pid = self()
      expect(UnitRegistry, :update_unit_state, fn :player, 1, _state -> :ok end)

      stub(CharacterPersistence, :update_stats, fn 1, changed, async: true ->
        send(test_pid, {:persisted, changed})
        {:ok, %Character{}}
      end)

      state = build_state(hp: 100, sp: 500)

      assert {:noreply, updated} = NaturalHealHandler.handle_tick(state, 500)

      assert updated.game_state.stats.current_state.hp == 100 + @hp_amount
      assert_received {:send, _channel, {_tag, %ParamChange{var_id: @sp_hp}}}
      refute_received {:send, _channel, {_tag, %ParamChange{var_id: @sp_sp}}}
      assert_received {:persisted, %{hp: 112}}
    end

    test "regenerates on the reference cadence: ticks 1, 13 and 25 standing" do
      assert heals(build_state(hp: 100, sp: 500), 25) == 3
    end

    test "an owned guild castle doubles the natural HP cadence" do
      state = %{build_state(hp: 100, sp: 500) | castle_regen?: true}

      assert heals(state, 13) == 3
      assert heals(build_state(hp: 100, sp: 500), 13) == 2
    end

    test "a dead player heals nothing and restarts the natural timestamps" do
      reject(CharacterPersistence, :update_stats, 3)
      state = build_state(hp: 0, sp: 0, action: :dead)

      assert {:noreply, updated} = NaturalHealHandler.handle_tick(state, 500)

      assert updated.game_state === state.game_state
      assert updated.regen_timing.hp_last_ms == 500
    end

    test "a hidden or cloaked player does not regenerate" do
      reject(CharacterPersistence, :update_stats, 3)
      state = build_state(hp: 100, sp: 50, id: 88_002, action: :sitting)
      on_exit(fn -> StatusStorage.remove_status(:player, 88_002, :sc_hiding) end)
      on_exit(fn -> StatusStorage.remove_status(:player, 88_002, :sc_cloaking) end)

      for status <- [:sc_hiding, :sc_cloaking] do
        :ok = StatusStorage.apply_status(:player, 88_002, status, val1: 3)
        assert {:noreply, updated} = NaturalHealHandler.handle_tick(state, 500)
        assert updated.game_state === state.game_state
        :ok = StatusStorage.remove_status(:player, 88_002, status)
      end
    end

    test "an overweight player does not regenerate" do
      reject(CharacterPersistence, :update_stats, 3)
      state = build_state(hp: 100, sp: 50, inventory: heavy_inventory())

      assert run(state, 17).game_state === state.game_state
    end

    test "a no_regen status modifier (No-Recover) blocks every channel" do
      reject(CharacterPersistence, :update_stats, 3)
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{no_regen: true} end)

      state = build_state(hp: 100, sp: 50)

      assert run(state, 17).game_state === state.game_state
    end

    test "Tension Relax while overweight heals at the normal cadence" do
      id = 88_003
      on_exit(fn -> StatusStorage.remove_status(:player, id, :sc_tensionrelax) end)
      :ok = StatusStorage.apply_status(:player, id, :sc_tensionrelax, duration: 180_000)

      stub(ModifierCalculator, :get_all_modifiers, fn _, _ ->
        %{hp_regen_tick_rate: 200, skill_hp_regen_tick_rate: 200}
      end)

      state = build_state(hp: 100, sp: 500, id: id, inventory: heavy_inventory())

      assert heals(state, 13) == 2
    end

    test "equipment and status recovery rates add into the HP amount" do
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{hp_regen: 50} end)
      state = build_state(hp: 100, sp: 500, equipment: %{hp_regen: 50})

      assert {:noreply, updated} = NaturalHealHandler.handle_tick(state, 500)
      assert updated.game_state.stats.current_state.hp == 100 + 2 * @hp_amount
    end

    test "the equipment no-regen HP bit blocks HP but leaves SP" do
      state = build_state(hp: 100, sp: 50, equipment: %{no_regen: 1})

      assert {:noreply, updated} = NaturalHealHandler.handle_tick(state, 500)
      assert updated.game_state.stats.current_state.hp == 100
      assert updated.game_state.stats.current_state.sp > 50
    end
  end

  defp run(state, ticks) do
    Enum.reduce(1..ticks, state, fn _, acc ->
      {:noreply, next} = NaturalHealHandler.handle_tick(acc, 500)
      next
    end)
  end

  defp heals(state, ticks) do
    final = run(state, ticks)

    div(
      final.game_state.stats.current_state.hp - state.game_state.stats.current_state.hp,
      @hp_amount
    )
  end

  # 300 Red Potions weigh 21_000, over the natural-heal rate of a STR 10 Novice in both modes.
  defp heavy_inventory do
    PlayerState.from_list([
      %InventoryItem{id: 1, char_id: 1, nameid: @red_potion, amount: 300, equip: 0, identify: 1}
    ])
  end

  defp build_state(opts) do
    stats = %Stats{
      base_stats: %BaseStats{str: 10, agi: 10, vit: 50, int: 50, dex: 10, luk: 10},
      derived_stats: %DerivedStats{max_hp: 500, max_sp: 500, max_ap: 0, aspd: 150},
      current_state: %CurrentState{hp: opts[:hp], sp: opts[:sp], ap: 0},
      progression: %PlayerProgression{job_id: 0, base_level: 1},
      modifiers: %Modifiers{equipment: Keyword.get(opts, :equipment, %{})}
    }

    game_state = %PlayerState{
      character_id: Keyword.get(opts, :id, 1),
      account_id: 100,
      action_state: Keyword.get(opts, :action, :idle),
      movement_state: :standing,
      inventory: Keyword.get(opts, :inventory, %{}),
      stats: stats
    }

    %SessionState{game_state: game_state, connection_pid: self()}
  end
end
