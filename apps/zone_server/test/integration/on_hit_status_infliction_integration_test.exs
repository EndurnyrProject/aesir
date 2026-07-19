defmodule Aesir.ZoneServer.Integration.OnHitStatusInflictionIntegrationTest do
  @moduledoc """
  Integration coverage for equipment-driven on-hit status infliction
  (bonus2 bAddEff / bAddEffWhenHit / bResEff), closing out the item-bonus234
  epic (Task 18).

  Two scenarios, both driving the real `StatusStorage`/`UnitRegistry` chain
  with no stubs on `StatusEffect.Interpreter`:

    * An attacker's `{:add_eff, sc}` equipment lands a real auto attack
      through `Combat.execute_attack/3` on a live mob and the status is
      genuinely stored.
    * The `res_eff_exempt` single-subtraction seam between `OnHitEffects`
      (subtracts the defender's `{:res_eff, sc}` tolerance once, at the proc
      rate, then calls `apply_status` with `res_eff_exempt: true`) and a
      skill-sourced `apply_status` call that omits the flag and is still
      blocked by the interpreter's own tolerance step.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.DamageDealt
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.OnHitEffects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  describe "equipment add_eff through a real auto attack" do
    test "a guaranteed-rate add_eff inflicts sc_stun on a live mob target" do
      player = start_player_session(position: {150, 150})

      mob =
        start_mob_session(
          position: {151, 150},
          hp: 500,
          max_hp: 500
        )

      Process.sleep(50)
      flush_packets()

      stats =
        with_stats_equip_modifiers(get_player_stats(player.pid), %{
          {:add_eff, :sc_stun} => 10_000
        })

      player_state = get_player_state(player.pid)

      # Rate 10_000 is the facade-level forced-rate fallback from the task:
      # `Combat.execute_attack/3` does not expose the `OnHitEffects` `:roll`
      # injection point, so a maxed-out per-10000 rate makes the real
      # `:rand`-based roll a guaranteed attempt on the first landed hit.
      landed =
        Enum.reduce_while(1..30, false, fn _, _acc ->
          assert Combat.execute_attack(stats, player_state, mob.unit_id) == :ok
          Process.sleep(20)

          if StatusStorage.has_status?(:mob, mob.unit_id, :sc_stun) do
            {:halt, true}
          else
            {:cont, false}
          end
        end)

      assert landed, "sc_stun never landed on the mob after 30 attack attempts"
      assert_packet_sent(DamageDealt, 100)
    end
  end

  describe "res_eff single-subtraction seam" do
    test "full res_eff blocks the on-hit proc once, and still blocks a skill-sourced apply_status without res_eff_exempt" do
      mob = start_mob_session(position: {151, 150})

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 9001)
        |> with_combatant_equip_modifiers(%{{:add_eff, :sc_stun} => 5_000})

      defender =
        CombatTestHelper.create_mob_combatant(unit_id: mob.unit_id)
        |> with_combatant_equip_modifiers(%{{:res_eff, :sc_stun} => 10_000})

      # (1) OnHitEffects subtracts the defender's full tolerance at the proc
      # rate: `effective = 5_000 - 10_000` floors at 0 before any roll, so the
      # real `StatusEffect.Interpreter.apply_status/4` is never even reached.
      assert :ok = OnHitEffects.after_hit(attacker, defender, %{damage: 100})
      refute StatusStorage.has_status?(:mob, mob.unit_id, :sc_stun)

      # (2) The same tolerance value, reached through a skill-sourced
      # `apply_status` call that carries no `res_eff_exempt`, must still be
      # subtracted -- this time by the interpreter's own `roll_resistance`
      # step -- against a live player whose `equip_modifiers` are published
      # to the real `UnitRegistry` (mirroring `StateCommit.commit/2`).
      player = start_player_session(position: {150, 150})
      player_state = get_player_state(player.pid)

      geared_state =
        with_player_equip_modifiers(player_state, %{{:res_eff, :sc_stun} => 10_000})

      :ok = UnitRegistry.update_unit_state(:player, player.character.id, geared_state)

      assert {:error, :resisted} =
               StatusInterpreter.apply_status(:player, player.character.id, :sc_stun)

      refute StatusStorage.has_status?(:player, player.character.id, :sc_stun)
    end
  end

  defp with_player_equip_modifiers(player_state, mods) do
    %{player_state | stats: with_stats_equip_modifiers(player_state.stats, mods)}
  end

  defp with_stats_equip_modifiers(stats, mods) do
    %{stats | modifiers: %{stats.modifiers | equipment: mods}}
  end

  defp with_combatant_equip_modifiers(combatant, mods), do: %{combatant | equip_modifiers: mods}
end
