defmodule Aesir.ZoneServer.Integration.ShortWeaponDamageReturnIntegrationTest do
  @moduledoc """
  Integration coverage for the `bShortWeaponDamageReturn` equipment bonus: a
  defender's gear reflects a percent of received melee physical damage back to
  the attacker.

  Drives the real combat/delivery chain (`Combat.execute_mob_attack/2` ->
  `DamageApplication`) with no stubs on the reflect path. The reflect is read
  off the defender's live `equip_modifiers` published to the real
  `UnitRegistry` (mirroring `StateCommit.commit/2`), and delivered to the mob
  through the same asynchronous reflect path Reflect Shield uses, so the mob
  loses HP without any feedback loop.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Unit.UnitRegistry

  describe "bShortWeaponDamageReturn" do
    test "equipment reflects part of a melee mob's damage back to it" do
      player = start_player_session(position: {150, 150}, vit: 1)
      mob = start_mob_session(position: {151, 150}, hp: 100_000, max_hp: 100_000)

      Process.sleep(50)
      equip_player_with(player, %{short_weapon_damage_return: 50})

      player_hp = current_hp(player.pid)
      mob_hp = current_mob_hp(mob.pid)

      assert land_melee_hit(mob, player, player_hp), "the mob never landed a hit on the player"
      assert eventually(fn -> current_mob_hp(mob.pid) < mob_hp end)

      reflected = mob_hp - current_mob_hp(mob.pid)
      taken = player_hp - current_hp(player.pid)

      assert reflected > 0
      assert reflected < taken
    end

    test "without the bonus, a landed melee mob hit reflects nothing" do
      player = start_player_session(position: {150, 150}, vit: 1)
      mob = start_mob_session(position: {151, 150}, hp: 100_000, max_hp: 100_000)

      Process.sleep(50)

      player_hp = current_hp(player.pid)
      mob_hp = current_mob_hp(mob.pid)

      assert land_melee_hit(mob, player, player_hp), "the mob never landed a hit on the player"

      refute eventually(fn -> current_mob_hp(mob.pid) < mob_hp end, 500)
    end
  end

  # Retries the mob's melee swing until it actually lands (flee/perfect-dodge
  # make a single swing non-deterministic), returning true once the player's HP
  # has dropped below `baseline_hp`.
  defp land_melee_hit(mob, player, baseline_hp, tries \\ 40) do
    Enum.reduce_while(1..tries, false, fn _, _acc ->
      assert :ok = Combat.execute_mob_attack(get_mob_state(mob.pid), player.character.id)

      if eventually(fn -> current_hp(player.pid) < baseline_hp end, 100) do
        {:halt, true}
      else
        {:cont, false}
      end
    end)
  end

  defp current_hp(pid), do: get_player_state(pid).stats.current_state.hp
  defp current_mob_hp(pid), do: get_mob_state(pid).hp

  # Puts the equipment modifiers on both the live PlayerSession's internal state
  # and its published UnitRegistry entry, so the session's own damage-commit
  # keeps the modifiers (they are real state, as they would be in production
  # after equipping the gear) rather than overwriting the registry copy.
  defp equip_player_with(player, mods) do
    :sys.replace_state(player.pid, fn session_state ->
      stats = session_state.game_state.stats
      new_stats = %{stats | modifiers: %{stats.modifiers | equipment: mods}}
      %{session_state | game_state: %{session_state.game_state | stats: new_stats}}
    end)

    :ok =
      UnitRegistry.update_unit_state(:player, player.character.id, get_player_state(player.pid))
  end
end
