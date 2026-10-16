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
    * A player's full `{:res_eff, sc}` equipment resistance refuses the status
      in the status defense, both for an on-hit proc and for a skill-sourced
      `apply_status`.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.DamageDealt
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
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
        with_stats_equip_modifiers(
          get_player_stats(player.pid),
          CombatTestHelper.equip_modifiers(%{{:add_eff, :sc_stun} => 10_000})
        )

      player_state = get_player_state(player.pid)

      # Rate 10_000 is the facade-level forced-rate fallback from the task:
      # `Combat.execute_attack/3` does not expose the `OnHitEffects` `:roll`
      # injection point, so a maxed-out per-10000 rate makes the real
      # `:rand`-based roll a guaranteed attempt on the first landed hit.
      # The status starts 100 ms after the hit.
      landed =
        Enum.reduce_while(1..30, false, fn _, _acc ->
          assert Combat.execute_attack(stats, player_state, mob.unit_id) == :ok

          if eventually(fn -> StatusStorage.has_status?(:mob, mob.unit_id, :sc_stun) end, 200) do
            {:halt, true}
          else
            {:cont, false}
          end
        end)

      assert landed, "sc_stun never landed on the mob after 30 attack attempts"
      assert_packet_sent(DamageDealt, 100)
    end
  end

  describe "res_eff in the status defense" do
    test "full res_eff refuses an on-hit proc and a skill-sourced apply_status alike" do
      player = start_player_session(position: {150, 150})
      player_state = get_player_state(player.pid)

      geared_state =
        with_player_equip_modifiers(player_state, %{{:res_eff, :sc_stun} => 10_000})

      :ok = UnitRegistry.update_unit_state(:player, player.character.id, geared_state)

      wearer = start_player_session(position: {151, 150})

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: wearer.character.id)
        |> with_combatant_equip_modifiers(%{{:add_eff, :sc_stun} => 10_000})

      victim = CombatTestHelper.create_player_combatant(unit_id: player.character.id)
      landed = %{hit_class: :hit, attack_effects?: true, counter_effects?: true}

      assert :ok =
               OnHitEffects.after_hit(attacker, victim, landed,
                 attack_flag: BattleFlags.build(:weapon, :short, false)
               )

      Process.sleep(200)
      refute StatusStorage.has_status?(:player, player.character.id, :sc_stun)

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

  defp with_combatant_equip_modifiers(combatant, mods),
    do: %{combatant | equip_modifiers: CombatTestHelper.equip_modifiers(mods)}
end
