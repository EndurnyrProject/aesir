defmodule Aesir.ZoneServer.Integration.SniperSkillsTest do
  @moduledoc "Real-session Sniper skill coverage in renewal and pre-renewal."
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillDamage
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Combat.CriticalHits
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage, as: SkillUnitStorage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Sniper.Formulas
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @map "prontera"
  @skills %{"127" => 1, "128" => 10, "129" => 5, "380" => 10, "381" => 5, "382" => 5, "383" => 10}

  setup do
    stub(CriticalHits, :is_critical_hit?, fn _rate -> true end)
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  test "True Sight commits all-stat and flat HIT bonuses and Quagmire strips and prevents it" do
    sniper = start_sniper()
    before = get_player_state(sniper.pid).stats
    cast(sniper, 380, 10)

    assert eventually(fn ->
             StatusStorage.has_status?(:player, sniper.character.id, :sc_truesight)
           end)

    stats = get_player_state(sniper.pid).stats
    assert Stats.get_effective_stat(stats, :str) == Stats.get_effective_stat(before, :str) + 5
    assert stats.modifiers.status_effects.hit == 30
    assert stats.combat_stats.hit >= before.combat_stats.hit + 30

    assert :ok =
             PlayerSession.apply_status(sniper.pid, :sc_quagmire,
               val1: 1,
               val2: 0,
               duration: 30_000,
               bypass_resistance: true
             )

    refute StatusStorage.has_status?(:player, sniper.character.id, :sc_truesight)

    cast(sniper, 380, 10)
    _state = get_player_state(sniper.pid)
    assert StatusStorage.get_status(:player, sniper.character.id, :sc_truesight) == nil
  end

  test "Wind Walker reaches a party member without stacking Increase AGI haste" do
    caster_character = insert_character(%{})
    ally_character = insert_character(%{last_x: 151})
    assert {:ok, party} = PartyManager.create("Snipers#{caster_character.id}", caster_character)
    assert {:ok, _party} = PartyManager.add_member(party.party_id, ally_character)
    sniper = start_session(Repo.get!(Character, caster_character.id))
    ally = start_session(Repo.get!(Character, ally_character.id))

    assert :ok =
             PlayerSession.apply_status(sniper.pid, :sc_increaseagi,
               val1: 10,
               val2: 15,
               duration: 60_000
             )

    agi_speed = StatusManager.walk_speed_for(get_player_state(sniper.pid).stats)
    cast(sniper, 383, 10)

    assert eventually(fn ->
             StatusStorage.has_status?(:player, sniper.character.id, :sc_windwalk) and
               StatusStorage.has_status?(:player, ally.character.id, :sc_windwalk) and
               get_player_state(sniper.pid).stats.modifiers.status_effects[:flee] == 5
           end)

    state = get_player_state(sniper.pid)
    assert state.stats.modifiers.status_effects.haste_rate == 25
    assert StatusManager.walk_speed_for(state.stats) == agi_speed
    assert state.walk_speed == agi_speed
  end

  test "Falcon Assault delivers the same single misc hit on repeated casts" do
    sniper = start_sniper()
    mob = start_target({158, 150})
    stats = get_player_state(sniper.pid).stats

    expected =
      Formulas.falcon_assault_damage(5, 10, %{
        agi: Stats.get_effective_stat(stats, :agi),
        dex: Stats.get_effective_stat(stats, :dex),
        int: Stats.get_effective_stat(stats, :int)
      })

    target_id = mob.unit_id
    initial_hp = mob_hp(mob)
    clear_packet_inbox()
    cast(sniper, 381, 5, target_id)

    assert_receive {:packet_sent,
                    %SkillDamage{skill_id: 381, target_id: ^target_id, damage: first, div: 1},
                    _channel},
                   4000

    assert first > 0
    assert first == expected
    assert eventually(fn -> mob_hp(mob) == initial_hp - first end)

    assert eventually(fn ->
             PlayerState.act_ready?(
               get_player_state(sniper.pid),
               System.monotonic_time(:millisecond)
             )
           end)

    cast(sniper, 381, 5, target_id)

    assert_receive {:packet_sent,
                    %SkillDamage{skill_id: 381, target_id: ^target_id, damage: second, div: 1},
                    _channel},
                   4000

    assert second == first
    assert eventually(fn -> mob_hp(mob) == initial_hp - first - second end)
  end

  test "Falcon Assault without the falcon spends no SP and damages nothing" do
    sniper = start_sniper(%{option: 0})
    mob = start_target({158, 150})
    initial_hp = mob_hp(mob)
    initial_sp = get_player_state(sniper.pid).stats.current_state.sp
    clear_packet_inbox()
    cast(sniper, 381, 5, mob.unit_id)
    state = get_player_state(sniper.pid)

    assert state.stats.current_state.sp == initial_sp
    assert mob_hp(mob) == initial_hp
    refute_receive {:packet_sent, %SkillDamage{skill_id: 381}, _channel}, 100
  end

  @tag game_mode: :renewal, integration_pre_re: false
  test "renewal Focused Arrow Strike crits through high flee and hits the splash and an enemy trap" do
    sniper = start_sniper()
    primary = start_target({158, 150}, agi: 9999)
    neighbour = start_target({160, 152})
    outside = start_target({162, 150})
    trap = register_enemy_trap(primary, {159, 151})
    assert get_mob_state(primary.pid).mob_data.stats.agi == 9999

    cast(sniper, 382, 5, primary.unit_id)

    assert eventually(fn -> mob_hp(primary) < 100_000 and mob_hp(neighbour) < 100_000 end)
    assert mob_hp(outside) == 100_000

    assert eventually(fn ->
             cell = SkillUnitStorage.get_cell(trap.cell_id)
             is_nil(cell) or cell.hp < trap.hp
           end)
  end

  @tag game_mode: :pre_renewal, integration_re: false
  test "classic Focused Arrow Strike hits beside the Bresenham line inside the lane" do
    sniper = start_sniper()
    primary = start_target({158, 150})
    neighbour = start_target({156, 151})
    outside = start_target({156, 152})

    cast(sniper, 382, 5, primary.unit_id)

    assert eventually(fn -> mob_hp(primary) < 100_000 and mob_hp(neighbour) < 100_000 end)
    assert mob_hp(outside) == 100_000
  end

  @tag game_mode: :pre_renewal, integration_re: false
  test "classic empty lane falls back to the clicked off-lane target" do
    sniper = start_sniper()
    target = start_target({159, 152})
    cast(sniper, 382, 5, target.unit_id)
    assert eventually(fn -> mob_hp(target) < 100_000 end)
  end

  defp register_enemy_trap(owner, position) do
    now = System.monotonic_time(:millisecond)
    group_id = System.unique_integer([:positive])

    group = %Group{
      group_id: group_id,
      skill_id: 116,
      skill_name: :ht_landmine,
      level: 1,
      caster_id: owner.unit_id,
      caster_type: :mob,
      map_name: @map,
      center: position,
      cells: [position],
      interval: 1000,
      next_tick_at: now + 60_000,
      expires_at: now + 60_000,
      state: %{
        base_damage: 500,
        trap: %TrapState{},
        cell_attrs: %{position => %{flags: [:targetable], hp: 100_000, max_hp: 100_000}}
      }
    }

    assert :ok = SkillUnitManager.register(group)
    [cell] = SkillUnitStorage.get_cells_by_group(group_id)
    cell
  end

  defp start_target(position, opts \\ []) do
    mob =
      start_mob_session(
        [map_name: @map, position: position, hp: 100_000, max_hp: 100_000, vit: 0, luk: 0] ++ opts
      )

    on_exit(fn -> if Process.alive?(mob.pid), do: end_mob_session(mob) end)
    mob
  end

  defp mob_hp(mob), do: get_mob_state(mob.pid).hp

  defp cast(session, skill_id, level, target_id \\ nil) do
    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: target_id || session.character.id
    })
  end

  defp start_sniper(overrides \\ %{}) do
    overrides |> insert_character() |> start_session()
  end

  defp start_session(character) do
    for attrs <- [
          %{nameid: 1701, amount: 1, equip: 34},
          %{nameid: 1750, amount: 20, equip: 0x008000}
        ] do
      assert {:ok, _item} =
               InventoryPersistence.insert_item(character.id, Map.put(attrs, :identify, 1))
    end

    session =
      start_player_session(
        character: character,
        map_name: @map,
        position: {character.last_x, character.last_y}
      )

    Mimic.allow(CriticalHits, self(), session.pid)
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end

  defp insert_character(overrides) do
    unique = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "sn#{unique}",
        username: "sn#{unique}",
        user_pass: "password",
        email: "sn#{unique}@aesir.test"
      })
      |> Repo.insert()

    attrs =
      Map.merge(
        %{
          account_id: account.id,
          char_num: 0,
          name: "Sniper#{unique}",
          sex: "M",
          class: 4012,
          base_level: 99,
          job_level: 70,
          str: 20,
          agi: 20,
          vit: 0,
          int: 40,
          dex: 99,
          luk: 0,
          hp: 5000,
          max_hp: 5000,
          sp: 1000,
          max_sp: 1000,
          learned_skills: @skills,
          option: Option.id(:falcon),
          last_map: @map,
          last_x: 150,
          last_y: 150,
          save_map: @map,
          save_x: 150,
          save_y: 150
        },
        overrides
      )

    {:ok, character} = %Character{} |> Character.changeset(attrs) |> Repo.insert()
    character
  end
end
