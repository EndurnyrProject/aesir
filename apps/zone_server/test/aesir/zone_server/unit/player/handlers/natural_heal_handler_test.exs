defmodule Aesir.ZoneServer.Unit.Player.Handlers.NaturalHealHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ParamChange
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Unit.Player.Handlers.NaturalHealHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
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

    stub(Passives, :sitting_regen, fn _ ->
      %{sitting_hp_regen: 0, sitting_sp_regen: 0}
    end)

    :ok
  end

  describe "handle_tick/2" do
    test "publishes regenerated HP/SP as one complete resource snapshot" do
      state = build_state(hp: 100, sp: 50, action: :idle, movement: :standing)

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
               NaturalHealHandler.handle_tick(%{state | game_state: game_state}, 10_000)

      assert_receive {:party_member, member}

      assert member == %Member{
               char_id: 1,
               name: "Aesir",
               job_id: updated.game_state.stats.progression.job_id,
               base_level: updated.game_state.stats.progression.base_level,
               hp: updated.game_state.stats.current_state.hp,
               max_hp: 500,
               sp: updated.game_state.stats.current_state.sp,
               max_sp: 500,
               ap: updated.game_state.stats.current_state.ap,
               max_ap: updated.game_state.stats.derived_stats.max_ap,
               online: true,
               map_name: "prontera"
             }

      refute_receive {:party_member, _member}
    end

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
      assert_received {:send, _channel, {_tag, %ParamChange{var_id: @sp_hp}}}
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

    test "an equipment hp_regen bonus shortens the HP interval" do
      baseline = build_state(hp: 100, sp: 50, action: :idle, movement: :standing)

      equipped =
        build_state(
          hp: 100,
          sp: 50,
          action: :idle,
          movement: :standing,
          equipment: %{hp_regen: 100}
        )

      {:noreply, plain} = NaturalHealHandler.handle_tick(baseline, 6_000)
      {:noreply, boosted} = NaturalHealHandler.handle_tick(equipped, 6_000)

      # amount = vit/5 + max(1, max_hp/200) = 12; +100% halves the interval, so
      # the same 6s elapsed crosses it twice.
      assert plain.game_state.stats.current_state.hp == 112
      assert boosted.game_state.stats.current_state.hp == 124
    end

    test "equipment and status regen bonuses sum into one rate" do
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{sp_regen: 100} end)

      state =
        build_state(
          hp: 500,
          sp: 50,
          action: :idle,
          movement: :standing,
          equipment: %{sp_regen: 100}
        )

      {:noreply, updated} = NaturalHealHandler.handle_tick(state, 8_000)

      # amount = 1 + int/6 + max_sp/100 = 1 + 8 + 5 = 14; rate 300 -> interval
      # 8000*100/300 = 2666, crossed 3 times in 8s.
      assert updated.game_state.stats.current_state.sp == 50 + 3 * 14
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

    test "adds Spiritual Cadence only while sitting" do
      baseline = build_state(hp: 100, sp: 50, action: :sitting, movement: :standing)

      {:noreply, without_cadence} = NaturalHealHandler.handle_tick(baseline, 10_000)

      stub(Passives, :sitting_regen, fn _ ->
        %{sitting_hp_regen: 120, sitting_sp_regen: 110}
      end)

      cadence = build_state(hp: 100, sp: 50, action: :sitting, movement: :standing)
      {:noreply, with_cadence} = NaturalHealHandler.handle_tick(cadence, 10_000)

      assert with_cadence.game_state.stats.current_state.hp -
               without_cadence.game_state.stats.current_state.hp == 120

      assert with_cadence.game_state.stats.current_state.sp -
               without_cadence.game_state.stats.current_state.sp == 110
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
      refute_received {:send, _channel, _payload}
    end

    test "no-recover skips natural regeneration" do
      reject(CharacterPersistence, :update_stats, 3)
      state = build_state(hp: 100, sp: 50, action: :idle, movement: :standing)
      state = put_in(state.game_state.character_id, 88_001)

      :ok = StatusStorage.apply_status(:player, 88_001, :sc_norecover_state)
      on_exit(fn -> StatusStorage.remove_status(:player, 88_001, :sc_norecover_state) end)

      assert {:noreply, ^state} = NaturalHealHandler.handle_tick(state, 10_000)
    end

    test "no packet push and no persist on a zero-delta tick (full HP and SP)" do
      reject(CharacterPersistence, :update_stats, 3)

      state = build_state(hp: 500, sp: 500, action: :idle, movement: :standing)

      assert {:noreply, _} = NaturalHealHandler.handle_tick(state, 500)
      refute_received {:send, _channel, _payload}
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
      assert_received {:send, _sp_channel, {_sp_tag, %ParamChange{var_id: @sp_sp}}}
      refute_received {:send, _hp_channel, {_hp_tag, %ParamChange{var_id: @sp_hp}}}
    end
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
