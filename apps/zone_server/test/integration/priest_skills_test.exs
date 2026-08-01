defmodule Aesir.ZoneServer.Integration.PriestSkillsTest do
  @moduledoc """
  Server-only regression matrix for the complete normal Priest kit.

  The tests deliberately cross the public player-session, party, combat,
  status, spatial-index, and ground-unit boundaries. Corpse Resurrection and
  Redemptio lifecycle coverage lives beside this file in their dedicated
  integration tests, where packet recipients and retained-corpse identity can
  be asserted without obscuring the rest of the kit.
  """
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.LearnSkill
  alias Aesir.Net.SkillDamage
  alias Aesir.Net.SkillList
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage, as: SkillUnitStorage
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHolylight
  alias Aesir.ZoneServer.Mmo.Skills.Mage.MgSafetywall
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrBenedictio
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrImpositio
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrKyrie
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrMacemastery
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrMagnus
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrSanctuary
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrStrecovery
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager

  @priest_class 8
  @acolyte_class 4

  @normal_tree_path [
    {:al_heal, 1},
    {:al_holywater, 1},
    {:al_ruwach, 1},
    {:al_dp, 3},
    {:al_angelus, 2},
    {:mg_srecovery, 4},
    {:pr_macemastery, 1},
    {:pr_impositio, 3},
    {:pr_suffragium, 1},
    {:pr_aspersio, 5},
    {:pr_sanctuary, 3},
    {:mg_safetywall, 1},
    {:pr_slowpoison, 1},
    {:pr_strecovery, 1},
    {:all_resurrection, 1},
    {:pr_kyrie, 4},
    {:pr_magnificat, 3},
    {:pr_gloria, 3},
    {:pr_benedictio, 1},
    {:pr_lexdivina, 5},
    {:pr_turnundead, 3},
    {:pr_lexaeterna, 1},
    {:pr_magnus, 1}
  ]

  @ordinary_priest_skills ~w(
    mg_srecovery mg_safetywall all_resurrection pr_macemastery pr_impositio
    pr_suffragium pr_aspersio pr_benedictio pr_sanctuary pr_slowpoison
    pr_strecovery pr_kyrie pr_magnificat pr_gloria pr_lexdivina pr_turnundead
    pr_lexaeterna pr_magnus
  )a

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  test "a real Priest session learns every ordinary branch and exercises Mace Mastery" do
    priest =
      start_player_session(
        id: 24_001,
        name: "CompletePriest",
        class: @priest_class,
        base_level: 99,
        job_level: 50,
        skill_point: 60
      )

    flush_packets()

    Enum.each(@normal_tree_path, fn {skill_name, target_level} ->
      skill_id = catalog_id(skill_name)
      Enum.each(1..target_level, fn _level -> learn(priest.pid, skill_id) end)
    end)

    learned = get_player_state(priest.pid).stats.progression.learned_skills

    for skill_name <- @ordinary_priest_skills do
      assert learned[catalog_id(skill_name)] >= 1, "expected #{skill_name} to be learned"
    end

    mastery_level = learned[catalog_id(:pr_macemastery)]
    assert PrMacemastery.atk_bonus(mastery_level, %{weapon_type: :mace}) == 3
    assert PrMacemastery.critical_bonus(mastery_level, %{weapon_type: :mace}) == 10
    refute Map.has_key?(learned, catalog_id(:pr_redemptio))
  end

  test "real party and target sessions receive direct, party, cure, barrier, and holy effects" do
    caster_character = character_fixture("PriestMatrixCaster", @priest_class, {150, 150})
    ally_character = character_fixture("PriestMatrixAlly", @acolyte_class, {151, 150})

    assert {:ok, party} = PartyManager.create("PriestMatrix", caster_character)
    assert {:ok, _party} = PartyManager.add_member(party.party_id, ally_character)

    caster =
      start_player_session(
        character: Repo.get!(Character, caster_character.id),
        position: {150, 150}
      )

    ally =
      start_player_session(
        character: Repo.get!(Character, ally_character.id),
        position: {151, 150}
      )

    caster_state = get_player_state(caster.pid)

    assert :ok =
             StatusInterpreter.apply_status(:player, ally.character.id, :sc_stun,
               caster_id: caster.character.id,
               duration: 30_000
             )

    assert StatusStorage.has_status?(:player, ally.character.id, :sc_stun)

    assert {:ok, ^caster_state} =
             PrStrecovery.cast(
               caster_state,
               {:unit, ally.character.id},
               1,
               PrStrecovery.definition()
             )

    refute StatusStorage.has_status?(:player, ally.character.id, :sc_stun)

    assert {:ok, ^caster_state} =
             PrKyrie.cast(caster_state, {:unit, ally.character.id}, 4, PrKyrie.definition())

    assert StatusStorage.has_status?(:player, ally.character.id, :sc_kyrie)

    assert {:ok, ^caster_state} =
             PrImpositio.cast(caster_state, :self, 3, PrImpositio.definition())

    assert StatusStorage.has_status?(:player, caster.character.id, :sc_impositio)
    assert StatusStorage.has_status?(:player, ally.character.id, :sc_impositio)

    mob =
      start_mob_session(
        unit_id: 24_050,
        position: {152, 150},
        hp: 500,
        max_hp: 500,
        race: :undead
      )

    flush_packets()

    assert {:ok, ^caster_state} =
             AlHolylight.cast(caster_state, {:unit, mob.unit_id}, 1, AlHolylight.definition())

    assert_receive {:packet_sent, %SkillDamage{target_id: 24_050, skill_id: 156}, _}, 1_000
    assert_eventually(fn -> get_mob_state(mob.pid).hp < 500 end)
  end

  test "B.S. Sacramenti uses two real Acolyte companions and blesses its immediate area" do
    caster =
      start_player_session(
        id: 24_101,
        name: "BenedictioPriest",
        class: @priest_class,
        position: {150, 150},
        sp: 100,
        max_sp: 100
      )

    west =
      start_player_session(
        id: 24_102,
        name: "BenedictioWest",
        class: @acolyte_class,
        position: {149, 150},
        sp: 100,
        max_sp: 100
      )

    east =
      start_player_session(
        id: 24_103,
        name: "BenedictioEast",
        class: @acolyte_class,
        position: {151, 150},
        sp: 100,
        max_sp: 100
      )

    caster_state = %{get_player_state(caster.pid) | dir: 4}
    west_sp = get_player_state(west.pid).stats.current_state.sp
    east_sp = get_player_state(east.pid).stats.current_state.sp

    assert {:ok, ^caster_state} =
             PrBenedictio.cast(caster_state, {:ground, 150, 150}, 1, PrBenedictio.definition())

    assert get_player_state(west.pid).stats.current_state.sp == west_sp - 10
    assert get_player_state(east.pid).stats.current_state.sp == east_sp - 10

    for character_id <- [caster.character.id, west.character.id, east.character.id] do
      assert StatusStorage.has_status?(:player, character_id, :sc_benedictio)
    end
  end

  test "Sanctuary, Safety Wall, and Magnus run as real ground-unit groups" do
    :ets.insert(
      EtsTable.table_for(:map_cache),
      {"prontera", MapData.new("prontera", 300, 300)}
    )

    manager =
      start_supervised!(
        {SkillUnitManager, name: nil, schedule_tick: fn _pid, _interval -> :ok end}
      )

    Process.put({SkillUnitManager, :server}, manager)
    on_exit(fn -> Process.delete({SkillUnitManager, :server}) end)

    caster =
      start_player_session(
        id: 24_201,
        name: "GroundPriest",
        class: @priest_class,
        position: {120, 120},
        int: 80,
        base_level: 99,
        sp: 1_000,
        max_sp: 1_000
      )

    caster_state = get_player_state(caster.pid)
    wounded_hp = caster_state.stats.current_state.hp
    assert wounded_hp < caster_state.stats.derived_stats.max_hp

    assert {:ok, ^caster_state} =
             PrSanctuary.cast(caster_state, {:ground, 120, 120}, 1, PrSanctuary.definition())

    sanctuary = Enum.find(SkillUnitStorage.all(), &(&1.skill_name == :pr_sanctuary))
    assert sanctuary.visibility == :public
    assert :ok = SkillUnitManager.tick(manager, sanctuary.next_tick_at)
    assert_eventually(fn -> get_player_state(caster.pid).stats.current_state.hp > wounded_hp end)

    assert {:ok, ^caster_state} =
             MgSafetywall.cast(caster_state, {:ground, 130, 130}, 1, MgSafetywall.definition())

    safety_wall = Enum.find(SkillUnitStorage.all(), &(&1.skill_name == :mg_safetywall))
    assert safety_wall.cells == [{130, 130}]

    protected =
      start_player_session(
        id: 24_203,
        name: "SafetyWallTarget",
        class: @acolyte_class,
        position: {130, 130}
      )

    assert {:ok, _safety_wall} = MgSafetywall.on_interval(safety_wall, safety_wall.created_at)
    assert StatusStorage.has_status?(:player, protected.character.id, :sc_safetywall)

    mob =
      start_mob_session(
        unit_id: 24_250,
        position: {140, 140},
        hp: 1_000,
        max_hp: 1_000,
        race: :undead
      )

    assert {:ok, ^caster_state} =
             PrMagnus.cast(caster_state, {:ground, 140, 140}, 1, PrMagnus.definition())

    magnus = Enum.find(SkillUnitStorage.all(), &(&1.skill_name == :pr_magnus))
    assert length(magnus.cells) == 33
    assert :ok = SkillUnitManager.tick(manager, magnus.next_tick_at)
    assert_eventually(fn -> get_mob_state(mob.pid).hp < 1_000 end)
  end

  defp learn(player_pid, skill_id) do
    simulate_incoming_message(player_pid, %LearnSkill{skill_id: skill_id})
    assert_receive {:packet_sent, %SkillList{}, _}, 1_000
  end

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  defp character_fixture(name, class, {x, y}) do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: String.downcase(name),
        user_pass: "password",
        sex: "M",
        email: "#{String.downcase(name)}@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %{
        account_id: account.id,
        name: name,
        char_num: 0,
        class: class,
        base_level: 99,
        job_level: 50,
        last_map: "prontera",
        last_x: x,
        last_y: y,
        hp: 1_000,
        max_hp: 1_000,
        sp: 1_000,
        max_sp: 1_000
      }
      |> Character.new()
      |> Repo.insert()

    character
  end
end
