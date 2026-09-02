defmodule Aesir.ZoneServer.Integration.MagicReflectIntegrationTest do
  @moduledoc """
  End-to-end coverage for the `bMagicDamageReturn` equipment bonus: a wearer's
  gear bounces a targeted magic hit back at its caster.

  Drives real player sessions on a PvP-flagged map through the real packet path
  (`SkillCast` -> `PlayerSession` -> `Skill.Interpreter` -> `MagicAttack`) with
  no stubs on the reflect path. The bonus is read off the wearer's live
  `equip_modifiers` published to the `UnitRegistry`, exactly as it would be
  after equipping the gear.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "prontera"
  @coldbolt 14
  @frostdiver 15
  @jupitel 84

  setup do
    :ok = MapFlags.reload()
    :ok
  end

  describe "bMagicDamageReturn" do
    test "a reflected nuke damages the caster, leaves the target untouched and does not move the caster" do
      with_pvp(fn ->
        {caster, target} = scenario(caster: [int: 1, vit: 99])
        equip_player_with(target, %{magic_damage_return: 100})

        caster_hp = current_hp(caster.pid)
        target_hp = current_hp(target.pid)

        cast(caster, @jupitel, target.character.id)

        assert_eventually(fn -> current_hp(caster.pid) < caster_hp end)

        refute eventually(
                 fn ->
                   state = get_player_state(caster.pid)
                   current_hp(target.pid) < target_hp or {state.x, state.y} != {150, 150}
                 end,
                 500
               ),
               "the target took damage or the caster was displaced by its own reflected nuke"
      end)
    end

    test "a reflected Frost Diver freezes the caster, not the target" do
      with_pvp(fn ->
        # The freeze follows the hit, not its damage: a high-MDEF target and a
        # low-INT caster keep every reflected nuke at 1 damage so the caster
        # survives each retry.
        {caster, target} = scenario(caster: [int: 1], target: [int: 99])
        equip_player_with(target, %{magic_damage_return: 100})
        caster_id = caster.character.id

        assert cast_until(caster, @frostdiver, target.character.id, fn ->
                 StatusStorage.has_status?(:player, caster_id, :sc_freeze)
               end),
               "the reflected Frost Diver never froze the caster"

        refute StatusStorage.has_status?(:player, target.character.id, :sc_freeze)
      end)
    end

    test "the caster's own magic reduction halves a reflected bolt" do
      with_pvp(fn ->
        full = reflected_damage(scenario())
        halved = reflected_damage(scenario(caster: [equip: %{no_magic_damage: 50}]))

        assert full > 0
        assert halved == full - div(full * 50, 100)
      end)
    end

    test "a reflected hit lands on a reflecting caster exactly once" do
      with_pvp(fn ->
        {caster, target} =
          scenario(
            caster: [equip: %{magic_damage_return: 100}],
            target: [connection_pid: spawn_link(fn -> Process.sleep(:infinity) end)]
          )

        equip_player_with(target, %{magic_damage_return: 100})

        caster_id = caster.character.id
        caster_hp = current_hp(caster.pid)
        target_hp = current_hp(target.pid)

        flush_packets()
        cast(caster, @coldbolt, target.character.id)

        assert_eventually(fn -> current_hp(caster.pid) < caster_hp end)

        # Only the caster's connection forwards packets, so every positive hit on
        # the caster is one delivery; its HP loss must be that single hit.
        assert [%SkillDamage{damage: damage}] =
                 SkillDamage
                 |> collect_packets_of_type(300)
                 |> Enum.filter(&(&1.target_id == caster_id and &1.damage > 0))

        assert caster_hp - current_hp(caster.pid) == damage
        assert current_hp(target.pid) == target_hp
      end)
    end
  end

  # Runtime map flags live in this test's ETS world, so they must be cleared
  # from the test process itself rather than from `on_exit`.
  defp with_pvp(fun) do
    :ok = MapFlags.set_runtime(@map, :pvp, true)

    try do
      fun.()
    after
      MapFlags.clear_runtime(@map, :pvp)
    end
  end

  # Two hostile players one cell apart. The caster is pinned at vit/luk 0 so a
  # reflected status lands with certainty. `equip:` sets a side's gear.
  defp scenario(opts \\ []) do
    {caster_equip, caster_opts} = Keyword.pop(Keyword.get(opts, :caster, []), :equip, %{})
    {target_equip, target_opts} = Keyword.pop(Keyword.get(opts, :target, []), :equip, %{})

    caster =
      start_player_session(
        Keyword.merge(
          [
            position: {150, 150},
            base_level: 99,
            job_level: 50,
            int: 99,
            dex: 99,
            vit: 0,
            luk: 0,
            learned_skills: %{
              "#{@coldbolt}" => 1,
              "#{@frostdiver}" => 10,
              "#{@jupitel}" => 1
            }
          ],
          caster_opts
        )
      )

    target =
      start_player_session(
        Keyword.merge([position: {151, 150}, base_level: 99, vit: 99], target_opts)
      )

    refill(caster)
    refill(target)
    equip_player_with(caster, caster_equip)
    equip_player_with(target, target_equip)

    {caster, target}
  end

  defp cast(caster, skill_id, target_id) do
    level = get_player_state(caster.pid).stats.progression.learned_skills["#{skill_id}"] || 1

    simulate_incoming_message(caster.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: target_id
    })
  end

  # Frost Diver's freeze is the skill's own chance roll inside the caster's
  # session (65% at level 10, then the caster's magical resistance), so the cast
  # is repeated until the outcome appears; thirty misses in a row is astronomically
  # unlikely. Each retry starts from full SP so the loop never stalls on an empty
  # pool.
  defp cast_until(caster, skill_id, target_id, done?, tries \\ 30) do
    Enum.reduce_while(1..tries, false, fn _, _acc ->
      refill(caster)
      cast(caster, skill_id, target_id)

      if eventually(done?, 1_500) do
        {:halt, true}
      else
        {:cont, false}
      end
    end)
  end

  defp reflected_damage({caster, target}) do
    equip_player_with(target, %{magic_damage_return: 100})
    before = current_hp(caster.pid)
    cast(caster, @coldbolt, target.character.id)
    assert_eventually(fn -> current_hp(caster.pid) < before end)
    before - current_hp(caster.pid)
  end

  defp current_hp(pid), do: get_player_state(pid).stats.current_state.hp

  # A fresh session keeps the seeded HP/SP until something clamps them; start
  # every player at its real maximums so baselines are stable.
  defp refill(player) do
    :sys.replace_state(player.pid, fn session_state ->
      stats = session_state.game_state.stats
      derived = stats.derived_stats
      current = %{stats.current_state | hp: derived.max_hp, sp: derived.max_sp}
      new_stats = %{stats | current_state: current}
      %{session_state | game_state: %{session_state.game_state | stats: new_stats}}
    end)

    :ok =
      UnitRegistry.update_unit_state(:player, player.character.id, get_player_state(player.pid))
  end

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
