defmodule Aesir.ZoneServer.Unit.Player.Handlers.NaturalHealHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Packets.ZcParChange
  alias Aesir.ZoneServer.Unit.Player.Handlers.NaturalHealHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # SP_HP / SP_SP param ids
  @sp_hp 5
  @sp_sp 7

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

    :ok
  end

  describe "handle_tick/2" do
    test "regenerates HP for a damaged idle player and clamps at max" do
      # A single 500ms tick is sub-interval; HP rises once enough ticks
      # accumulate past the base HP interval (the accumulator carries progress).
      state = build_state(hp: 100, sp: 50, action: :idle, movement: :standing)

      final =
        Enum.reduce(1..20, state, fn _, acc ->
          {:noreply, next} = NaturalHealHandler.handle_tick(acc, 500)
          next
        end)

      hp_after = final.game_state.stats.current_state.hp

      assert hp_after > 100
      assert hp_after <= 500
      assert_received {:send_packet, %ZcParChange{var_id: @sp_hp}}
    end

    test "stops exactly at max HP across repeated ticks" do
      state = build_state(hp: 495, sp: 100, action: :idle, movement: :standing)

      final =
        Enum.reduce(1..200, state, fn _, acc ->
          {:noreply, next} = NaturalHealHandler.handle_tick(acc, 500)
          next
        end)

      assert final.game_state.stats.current_state.hp == 500
    end

    test "does not regen HP while moving without SM_MOVINGRECOVERY but still regens SP" do
      state = build_state(hp: 100, sp: 50, action: :idle, movement: :moving)

      final =
        Enum.reduce(1..40, state, fn _, acc ->
          {:noreply, next} = NaturalHealHandler.handle_tick(acc, 500)
          next
        end)

      assert final.game_state.stats.current_state.hp == 100
      assert final.game_state.stats.current_state.sp > 50
    end

    test "regens HP while moving when SM_MOVINGRECOVERY is known" do
      stub(Passives, :regen, fn _ ->
        %{skill_hp_regen: 0, skill_sp_regen: 0, allow_while_moving: true}
      end)

      state = build_state(hp: 100, sp: 50, action: :idle, movement: :moving)

      final =
        Enum.reduce(1..40, state, fn _, acc ->
          {:noreply, next} = NaturalHealHandler.handle_tick(acc, 500)
          next
        end)

      assert final.game_state.stats.current_state.hp > 100
    end

    test "bleeding (hp_regen: -100) zeroes HP regen but SP still regens" do
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{hp_regen: -100} end)

      state = build_state(hp: 100, sp: 50, action: :idle, movement: :standing)

      final =
        Enum.reduce(1..40, state, fn _, acc ->
          {:noreply, next} = NaturalHealHandler.handle_tick(acc, 500)
          next
        end)

      assert final.game_state.stats.current_state.hp == 100
      assert final.game_state.stats.current_state.sp > 50
    end

    test "skips entirely when the player is dead" do
      state = build_state(hp: 0, sp: 0, action: :dead, movement: :standing)

      assert {:noreply, ^state} = NaturalHealHandler.handle_tick(state, 500)
      refute_received {:send_packet, _}
    end

    test "no packet push and no persist on a zero-delta tick (full HP and SP)" do
      reject(CharacterPersistence, :update_stats, 3)

      state = build_state(hp: 500, sp: 500, action: :idle, movement: :standing)

      assert {:noreply, _} = NaturalHealHandler.handle_tick(state, 500)
      refute_received {:send_packet, _}
    end

    test "pushes SP_SP and persists only the SP field when only SP regenerates" do
      stub(CharacterPersistence, :update_stats, fn _id, changed, _opts ->
        refute Map.has_key?(changed, :hp)
        assert Map.has_key?(changed, :sp)
        {:ok, %Character{}}
      end)

      state = build_state(hp: 500, sp: 100, action: :idle, movement: :standing)

      final =
        Enum.reduce(1..20, state, fn _, acc ->
          {:noreply, next} = NaturalHealHandler.handle_tick(acc, 500)
          next
        end)

      sp_after = final.game_state.stats.current_state.sp

      assert sp_after > 100
      assert_received {:send_packet, %ZcParChange{var_id: @sp_sp}}
      refute_received {:send_packet, %ZcParChange{var_id: @sp_hp}}
    end
  end

  defp build_state(opts) do
    stats = %Stats{
      base_stats: %BaseStats{str: 10, agi: 10, vit: 50, int: 50, dex: 10, luk: 10},
      derived_stats: %DerivedStats{max_hp: 500, max_sp: 500, aspd: 150},
      current_state: %CurrentState{hp: opts[:hp], sp: opts[:sp]}
    }

    game_state = %PlayerState{
      character_id: 1,
      account_id: 100,
      action_state: opts[:action],
      movement_state: opts[:movement],
      stats: stats,
      regen_accumulators: %{hp_acc: 0, sp_acc: 0, skill_hp_acc: 0, skill_sp_acc: 0}
    }

    %{
      game_state: game_state,
      connection_pid: self()
    }
  end
end
