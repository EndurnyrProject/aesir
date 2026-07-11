defmodule Aesir.ZoneServer.Integration.ConsumableBuffsPhase3IntegrationTest do
  @moduledoc """
  End-to-end coverage for the Phase-3 consumable buff hooks (received-heal rate,
  variable-cast rate, SP-cost rate), each driven through its real consumer with
  the backing status applied via the real `StatusInterpreter`/`StatusStorage` and
  read through the real `ModifierCalculator` (no stubbed modifier map - the gate
  is that the shipped effect module -> resolver -> modifier vocabulary wiring is
  observable at the consumer):

    1. `SC_INCHEALRATE` (`received_heal_rate`) - a heal through
       `HealthHandler.apply_heal/3` restores the boosted amount for the buffed
       player and the plain amount for an unbuffed control given the same input.
    2. `SC_SKF_CAST` (`varcast_rate`) - a timed skill's variable cast computed by
       `Interpreter.begin_cast/4` is shorter for the buffed caster than for an
       unbuffed control, with the fixed portion untouched.
    3. `SC_SPCOST_RATE` (`sp_cost_rate`) - a skill cast through
       `Interpreter.cast/4` deducts less SP for the buffed caster than for an
       unbuffed control.

  Real sessions register the units and provide the fake connection so the status
  display broadcast has a target; the interpreter itself is driven with a plain
  game_state map keyed to the registered character id, exactly as the skill unit
  tests do, so the cast numbers stay deterministic.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.Handlers.HealthHandler

  # AL_INCAGI (id 29): a real self-castable ally buff. Level-1 SP cost 18,
  # cast time 800ms - both non-zero, so it exercises the SP-cost and cast-time
  # consumers without any stubbing.
  @al_incagi 29
  @al_incagi_sp_cost 18

  setup :set_mimic_private
  setup :verify_on_exit!

  describe "SC_INCHEALRATE" do
    test "a heal restores the boosted amount versus an unbuffed control" do
      buffed = start_player_session(id: 9801, name: "Blessed", base_level: 50)
      control = start_player_session(id: 9802, name: "Plain", base_level: 50)

      buffed_id = buffed.character.id
      on_exit(fn -> StatusInterpreter.remove_status(:player, buffed_id, :sc_inchealrate) end)

      # SC_INCHEALRATE val1 = 100 -> received_heal_rate +100% -> heals double.
      :ok =
        StatusInterpreter.apply_status(:player, buffed_id, :sc_inchealrate,
          val1: 100,
          duration: 1_800_000
        )

      flush_packets()

      heal = heal_amount(buffed)

      buffed_gain = heal_gain(buffed, heal)
      control_gain = heal_gain(control, heal)

      assert control_gain == heal
      assert buffed_gain == heal * 2
      assert buffed_gain > control_gain
    end
  end

  describe "SC_SKF_CAST" do
    test "the buffed caster's variable cast is shorter than an unbuffed control" do
      buffed = start_player_session(id: 9803, name: "Hasty", base_level: 50)
      control = start_player_session(id: 9804, name: "Slow", base_level: 50)

      buffed_id = buffed.character.id
      on_exit(fn -> StatusInterpreter.remove_status(:player, buffed_id, :sc_skf_cast) end)

      # SC_SKF_CAST is a negative varcast_rate delta (item ships -5); -50 keeps the
      # assertion a strict, rounding-proof inequality on the 800ms base cast.
      :ok =
        StatusInterpreter.apply_status(:player, buffed_id, :sc_skf_cast,
          val1: -50,
          duration: 1_800_000
        )

      flush_packets()

      assert {:casting, _gs, baseline} =
               Interpreter.begin_cast(game_state(control.character.id), @al_incagi, 1, :self)

      assert {:casting, _gs, reduced} =
               Interpreter.begin_cast(game_state(buffed_id), @al_incagi, 1, :self)

      assert reduced.fixed == baseline.fixed
      assert reduced.total - reduced.fixed < baseline.total - baseline.fixed
      assert reduced.total < baseline.total
    end
  end

  describe "SC_SPCOST_RATE" do
    test "the buffed caster deducts less SP than an unbuffed control" do
      buffed = start_player_session(id: 9805, name: "Frugal", base_level: 50)
      control = start_player_session(id: 9806, name: "Spender", base_level: 50)

      buffed_id = buffed.character.id
      control_id = control.character.id

      on_exit(fn ->
        StatusInterpreter.remove_status(:player, buffed_id, :sc_spcost_rate)
        StatusInterpreter.remove_status(:player, buffed_id, :sc_increaseagi)
        StatusInterpreter.remove_status(:player, control_id, :sc_increaseagi)
      end)

      # SC_SPCOST_RATE emits `%{sp_cost_rate: -val1}`; val1 = 50 -> -50% SP cost.
      :ok =
        StatusInterpreter.apply_status(:player, buffed_id, :sc_spcost_rate,
          val1: 50,
          duration: 1_800_000
        )

      flush_packets()

      assert {:ok, buffed_after} = Interpreter.cast(game_state(buffed_id), @al_incagi, 1, :self)
      assert {:ok, control_after} = Interpreter.cast(game_state(control_id), @al_incagi, 1, :self)

      buffed_spent = 100 - buffed_after.stats.current_state.sp
      control_spent = 100 - control_after.stats.current_state.sp

      # 18 base, -50% -> div(18 * 50, 100) = 9.
      assert control_spent == @al_incagi_sp_cost
      assert buffed_spent == div(@al_incagi_sp_cost * 50, 100)
      assert buffed_spent < control_spent
    end
  end

  # Reduces the session HP to 1 and returns the HP actually gained when healing by
  # `amount`, driving the real received-heal-rate consumer.
  defp heal_gain(player, amount) do
    game_state = put_in(get_player_state(player.pid).stats.current_state.hp, 1)
    state = %{game_state: game_state, connection_pid: player.connection_pid}

    {:noreply, healed} = HealthHandler.apply_heal(amount, nil, state)
    healed.game_state.stats.current_state.hp - 1
  end

  # A heal small enough that even the doubled buffed heal stays under max HP, so
  # neither result clamps and the boost is a clean factor of two.
  defp heal_amount(player) do
    max_hp = get_player_state(player.pid).stats.derived_stats.max_hp
    div(max_hp - 1, 3)
  end

  # Plain caster game_state keyed to a registered character id, mirroring the
  # skill interpreter unit tests. Only fields the cast path reads are populated.
  defp game_state(character_id) do
    %{
      character_id: character_id,
      x: 150,
      y: 150,
      map_name: "prontera",
      skill_cooldowns: %{},
      act_delay_until: 0,
      stats: %{
        base_stats: %{dex: 1, int: 1},
        current_state: %{sp: 100, hp: 100},
        derived_stats: %{max_sp: 200, max_hp: 100},
        progression: %{learned_skills: %{@al_incagi => 1}}
      }
    }
  end
end
