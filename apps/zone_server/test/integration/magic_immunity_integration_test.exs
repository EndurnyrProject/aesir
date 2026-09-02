defmodule Aesir.ZoneServer.Integration.MagicImmunityIntegrationTest do
  @moduledoc """
  End-to-end coverage for the `bNoMagicDamage` equipment bonus at 100: targeted
  magic misses, ground magic deals nothing, foreign magic statuses are refused
  (including the wearer's own targeted support), self-targeted magic still
  applies, Dispell fails, and Sanctuary heals nothing.

  Drives real player sessions through the real packet path (`SkillCast` /
  `GroundSkillCast` -> `PlayerSession` -> `Skill.Interpreter`) with no stubs on
  the immunity path. The foreign caster is a persisted character so its
  gemstone catalysts come from a real inventory. A non-immune control player
  proves the refused casts actually lands when the gear is absent.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillDamage
  alias Aesir.Repo
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage, as: SkillUnitStorage
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "prontera"
  @coldbolt 14
  @stonecurse 16
  @blessing 34
  @sanctuary 70
  @stormgust 89
  @energycoat 157
  @dispell 289
  @yellow_gemstone 715
  @red_gemstone 716
  @blue_gemstone 717

  # Energy Coat is a Mage quest skill; the wearer must carry the Mage lineage.
  @mage 2

  @wearer_cell {151, 150}
  @control_cell {151, 151}

  # Explicit ids keep the players clear of mob instance ids: a bare target id
  # that also names a live mob is resolved as that mob by single-target skills.
  @wearer_id 9_921_001
  @control_id 9_921_002

  setup do
    :ok = MapFlags.reload()
    :ok
  end

  describe "bNoMagicDamage at 100" do
    test "a bolt shows a zero-damage hit and costs the wearer nothing" do
      %{caster: caster, wearer: wearer} = world()
      wearer_id = wearer.character.id
      wearer_hp = current_hp(wearer.pid)

      with_pvp(fn ->
        flush_packets()
        cast(caster, @coldbolt, wearer_id)

        assert_eventually(fn ->
          Enum.any?(bolt_packets(wearer_id), &(&1.damage == 0))
        end)
      end)

      refute Enum.any?(bolt_packets(wearer_id), &(&1.damage > 0))
      assert current_hp(wearer.pid) == wearer_hp
    end

    test "Storm Gust ticks deal nothing and never freeze the wearer" do
      %{caster: caster, wearer: wearer, control: control} = world()
      wearer_id = wearer.character.id
      wearer_hp = current_hp(wearer.pid)
      control_hp = current_hp(control.pid)

      with_pvp(fn ->
        cast_ground(caster, @stormgust, @wearer_cell)

        assert_eventually(
          fn ->
            case Enum.find(SkillUnitStorage.all(), &(&1.skill_name == :wz_stormgust)) do
              nil -> false
              group -> Map.get(group.state.hit_counts, wearer_id, 0) >= 3
            end
          end,
          8_000
        )
      end)

      assert_eventually(fn -> current_hp(control.pid) < control_hp end)

      refute eventually(
               fn ->
                 current_hp(wearer.pid) < wearer_hp or
                   StatusStorage.has_status?(:player, wearer_id, :sc_freeze)
               end,
               1_000
             ),
             "the wearer took Storm Gust damage or was frozen"
    end

    test "foreign and self-cast targeted magic statuses are refused, self-targeted ones apply" do
      %{caster: caster, wearer: wearer, control: control} = world()
      wearer_id = wearer.character.id
      control_id = control.character.id

      with_pvp(fn ->
        # The control proves a pinned Stone Curse from this caster reaches status
        # application; the wearer then receives the same pinned casts.
        stone_curse(caster, control_id)
        assert_eventually(fn -> StatusStorage.has_status?(:player, control_id, :sc_stone) end)

        for _ <- 1..3 do
          stone_curse(caster, wearer_id)
          settle_cast(caster)
        end
      end)

      refute eventually(fn -> StatusStorage.has_status?(:player, wearer_id, :sc_stone) end, 500)

      cast(caster, @blessing, control_id)
      assert_eventually(fn -> StatusStorage.has_status?(:player, control_id, :sc_blessing) end)

      settle_cast(caster)
      refill(caster)
      cast(caster, @blessing, wearer_id)
      settle_cast(caster)

      refute eventually(
               fn -> StatusStorage.has_status?(:player, wearer_id, :sc_blessing) end,
               500
             )

      cast(wearer, @blessing, wearer_id)
      settle_cast(wearer)

      refute eventually(
               fn -> StatusStorage.has_status?(:player, wearer_id, :sc_blessing) end,
               500
             )

      refill(wearer)
      cast(wearer, @energycoat, wearer_id)

      assert_eventually(
        fn -> StatusStorage.has_status?(:player, wearer_id, :sc_energycoat) end,
        8_000
      )
    end

    test "Dispell from another player leaves the wearer's Energy Coat in place" do
      %{caster: caster, wearer: wearer, control: control} = world()
      wearer_id = wearer.character.id
      control_id = control.character.id

      cast(wearer, @energycoat, wearer_id)

      assert_eventually(
        fn -> StatusStorage.has_status?(:player, wearer_id, :sc_energycoat) end,
        8_000
      )

      # Applying a status recalculates the wearer's stats, which rebuilds the
      # equipment modifiers from its (empty) inventory; put the gear back on.
      equip_player_with(wearer, %{no_magic_damage: 100, no_regen: 1})

      cast(caster, @blessing, control_id)
      assert_eventually(fn -> StatusStorage.has_status?(:player, control_id, :sc_blessing) end)

      settle_cast(caster)
      refill(caster)
      cast(caster, @dispell, control_id)

      assert_eventually(fn ->
        not StatusStorage.has_status?(:player, control_id, :sc_blessing)
      end)

      settle_cast(caster)
      refill(caster)
      cast(caster, @dispell, wearer_id)
      settle_cast(caster)

      refute eventually(
               fn -> not StatusStorage.has_status?(:player, wearer_id, :sc_energycoat) end,
               500
             )
    end

    test "Sanctuary heals the wearer for nothing while healing a bystander" do
      %{caster: caster, wearer: wearer, control: control} = world()
      wearer_hp = halve_hp(wearer)
      control_hp = halve_hp(control)

      cast_ground(caster, @sanctuary, @wearer_cell)

      assert_eventually(fn -> current_hp(control.pid) > control_hp end, 8_000)

      refute eventually(fn -> current_hp(wearer.pid) > wearer_hp end, 1_500),
             "Sanctuary healed the magic-immune wearer"
    end
  end

  # The wearer carries the immunity plus `no_regen` (bNoRegen) so natural
  # recovery cannot move its HP during a heal check. The control player stands
  # in the same cells with no gear. The caster is persisted so it can hold the
  # gemstones its skills consume.
  defp world do
    caster = start_persisted_caster()

    wearer =
      start_player_session(
        id: @wearer_id,
        position: @wearer_cell,
        class: @mage,
        base_level: 99,
        job_level: 50,
        vit: 0,
        luk: 0,
        learned_skills: %{"#{@blessing}" => 10, "#{@energycoat}" => 1}
      )

    control =
      start_player_session(
        id: @control_id,
        position: @control_cell,
        base_level: 99,
        job_level: 50,
        vit: 0,
        luk: 0
      )

    refill(caster)
    refill(wearer)
    refill(control)
    equip_player_with(wearer, %{no_magic_damage: 100, no_regen: 1})
    equip_player_with(control, %{no_regen: 1})

    %{caster: caster, wearer: wearer, control: control}
  end

  defp start_persisted_caster do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "gtb_caster_#{uniq}",
        user_pass: "password",
        sex: "M",
        email: "gtb_caster_#{uniq}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "GtbCaster#{uniq}",
        class: 0,
        base_level: 99,
        job_level: 50,
        str: 1,
        agi: 1,
        vit: 1,
        int: 99,
        dex: 99,
        luk: 1,
        hp: 1_000,
        max_hp: 1_000,
        sp: 1_000,
        max_sp: 1_000,
        last_map: @map,
        last_x: 150,
        last_y: 150,
        save_map: @map,
        save_x: 150,
        save_y: 150,
        learned_skills: %{
          "#{@coldbolt}" => 1,
          "#{@stonecurse}" => 10,
          "#{@blessing}" => 10,
          "#{@sanctuary}" => 10,
          "#{@stormgust}" => 10,
          "#{@dispell}" => 5
        }
      })
      |> Repo.insert()

    seed_item(character.id, @yellow_gemstone, 2)
    seed_item(character.id, @red_gemstone, 10)
    seed_item(character.id, @blue_gemstone, 2)

    start_player_session(character: character, map_name: @map, position: {150, 150})
  end

  defp seed_item(character_id, nameid, amount) do
    {:ok, _item} =
      InventoryPersistence.insert_item(character_id, %{
        nameid: nameid,
        amount: amount,
        identify: 1,
        equip: 0
      })

    :ok
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

  # Stone Curse rolls its own 60% die before the status gate. Seeding the
  # caster session's RNG right before the cast makes that first roll 27, so a
  # cast that reaches the target always attempts the status.
  defp stone_curse(caster, target_id) do
    settle_cast(caster)
    refill(caster)
    :sys.replace_state(caster.pid, fn state -> :rand.seed(:exsss, {1, 2, 3}) && state end)
    cast(caster, @stonecurse, target_id)
  end

  defp cast(caster, skill_id, target_id) do
    simulate_incoming_message(caster.pid, %SkillCast{
      skill_id: skill_id,
      level: learned_level(caster, skill_id),
      target_id: target_id
    })
  end

  defp cast_ground(caster, skill_id, {x, y}) do
    simulate_incoming_message(caster.pid, %GroundSkillCast{
      skill_id: skill_id,
      level: learned_level(caster, skill_id),
      x: x,
      y: y
    })
  end

  defp learned_level(player, skill_id) do
    learned = get_player_state(player.pid).stats.progression.learned_skills
    max(Learned.learned_level(learned, skill_id), 1)
  end

  # Waits for a cast in progress to resolve and for its after-cast delay to
  # expire, so the next cast is not refused. A cast the interpreter refused
  # never shows a `casting` descriptor and returns at once.
  defp settle_cast(player) do
    assert_eventually(fn ->
      state = get_player_state(player.pid)
      state.casting == nil and PlayerState.act_ready?(state, System.monotonic_time(:millisecond))
    end)
  end

  defp bolt_packets(target_id) do
    SkillDamage
    |> collect_packets_of_type(100)
    |> Enum.filter(&(&1.skill_id == @coldbolt and &1.target_id == target_id))
  end

  defp current_hp(pid), do: get_player_state(pid).stats.current_state.hp

  defp halve_hp(player) do
    half = div(current_hp(player.pid), 2)
    put_current(player, fn current, _derived -> %{current | hp: half} end)
    half
  end

  # A fresh session keeps the seeded HP/SP until something clamps them; start
  # every player at its real maximums so baselines are stable.
  defp refill(player) do
    put_current(player, fn current, derived ->
      %{current | hp: derived.max_hp, sp: derived.max_sp}
    end)
  end

  defp put_current(player, fun) do
    :sys.replace_state(player.pid, fn session_state ->
      stats = session_state.game_state.stats
      new_stats = %{stats | current_state: fun.(stats.current_state, stats.derived_stats)}
      %{session_state | game_state: %{session_state.game_state | stats: new_stats}}
    end)

    publish(player)
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

    publish(player)
  end

  defp publish(player) do
    :ok =
      UnitRegistry.update_unit_state(:player, player.character.id, get_player_state(player.pid))
  end
end
