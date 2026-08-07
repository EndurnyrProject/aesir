defmodule Aesir.ZoneServer.Integration.AssassinCompletionIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase
  use Mimic

  @moduletag :integration
  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.DamageDealt
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.SkillCast
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Grant
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsCloaking
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsEnchantpoison
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsGrimtooth
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsKatar
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsLeft
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsPoisonreact
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsRight
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsSonicaccel
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsSonicblow
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsSplasher
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsVenomdust
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsVenomknife
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  @map "assassin_completion_test"
  @assassin_skill_ids Enum.to_list(132..141) ++ [1_003, 1_004]
  @mob_compatible_ids [135, 136, 137, 140, 141]
  @red_gemstone 716
  @venom_knife_item 1_771
  @ammo_slot 0x008000

  @assassin_modules [
    AsRight,
    AsLeft,
    AsKatar,
    AsCloaking,
    AsSonicblow,
    AsGrimtooth,
    AsEnchantpoison,
    AsPoisonreact,
    AsVenomdust,
    AsSplasher,
    AsSonicaccel,
    AsVenomknife
  ]

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    :rand.seed(:exsss, {28, 28, 28})
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 30, 30)})
    :ok
  end

  test "catalog, ordinary tree, permanent grants, mob contract, and protocol form one exact boundary" do
    {:ok, application_modules} = :application.get_key(:zone_server, :modules)

    discovered_assassin_modules =
      Enum.filter(application_modules, fn module ->
        String.starts_with?(
          Atom.to_string(module),
          "Elixir.Aesir.ZoneServer.Mmo.Skills.Assassin."
        ) and function_exported?(module, :__skill_capabilities__, 0)
      end)

    assert MapSet.new(discovered_assassin_modules) == MapSet.new(@assassin_modules)

    for {module, expected_definition, capability} <- expected_catalog() do
      assert module.definition() == expected_definition
      assert {:ok, ^expected_definition} = Catalog.by_id(expected_definition.id)
      assert {:ok, ^expected_definition} = Catalog.by_name(expected_definition.name)
      assert {:ok, ^module} = capability_module(capability, expected_definition.name)
    end

    assert @assassin_skill_ids ==
             Enum.map(expected_catalog(), fn {_module, definition, _} -> definition.id end)

    {:ok, assassin_job_id} = AvailableJobs.job_name_to_id(:assassin)

    owned_tree_ids =
      assassin_job_id
      |> SkillTree.tree_for()
      |> Map.values()
      |> Enum.filter(&(&1.owner_job_id == assassin_job_id))
      |> MapSet.new(& &1.skill_id)

    assert owned_tree_ids == MapSet.new(132..141)

    learned = Map.new(@assassin_skill_ids, &{&1, 1})
    assert Enum.sort(SkillTree.permanent_skill_ids(learned)) == [1_003, 1_004]
    assert {:ok, %{1_003 => 1}} = Grant.grant(%{}, :as_sonicaccel, 1)
    assert {:ok, %{1_004 => 1}} = Grant.grant(%{}, :as_venomknife, 1)

    for ordinary_id <- 132..141 do
      assert {:error, :not_grantable} = Grant.grant(%{}, ordinary_id, 1)
    end

    for skill_id <- @mob_compatible_ids do
      assert {:ok, %{requires: []}} = Catalog.by_id(skill_id)
    end

    assert Map.has_key?(%DamageDealt{}, :damage)
    assert Map.has_key?(%DamageDealt{}, :damage2)
    assert Map.has_key?(%DamageDealt{}, :div)

    for module <- @assassin_modules do
      source = module.module_info(:compile)[:source] |> List.to_string() |> File.read!()
      refute source =~ "Aesir.Net."
    end
  end

  test "minimum and maximum ranks drive every passive, active, and ground behavior" do
    assert AsRight.right_hand_damage_rate(1, %{}) == 60
    assert AsRight.right_hand_damage_rate(5, %{}) == 100
    assert AsLeft.left_hand_damage_rate(1, %{}) == 40
    assert AsLeft.left_hand_damage_rate(5, %{}) == 80
    assert Passives.right_hand_damage_rate(player(%{132 => 1})) == 60
    assert Passives.right_hand_damage_rate(player(%{132 => 5})) == 100
    assert Passives.left_hand_damage_rate(player(%{133 => 1})) == 40
    assert Passives.left_hand_damage_rate(player(%{133 => 5})) == 80
    assert AsKatar.atk_bonus(1, %{weapon_type: :katar}) == 3
    assert AsKatar.atk_bonus(10, %{weapon_type: :katar}) == 30
    assert AsKatar.atk_bonus(10, %{weapon_type: :dagger}) == 0
    assert AsSonicaccel.__skill_capabilities__() == [:passive]

    assert AsSonicblow.skill_ratio(1, false) == 300
    assert AsSonicblow.skill_ratio(10, false) == 1_200
    assert AsSonicblow.skill_ratio(1, true) == 450
    assert AsSonicblow.skill_ratio(10, true) == 1_800
    assert AsGrimtooth.skill_ratio(1) == 120
    assert AsGrimtooth.skill_ratio(5) == 200

    assert {:ok, %{duration: 5_000, interval: 1_000, cells: level_one_cells}} =
             AsVenomdust.on_place(venom_dust_group(1))

    assert {:ok, %{duration: 50_000, interval: 1_000, cells: level_ten_cells}} =
             AsVenomdust.on_place(venom_dust_group(10))

    assert MapSet.new(level_one_cells) == MapSet.new(level_ten_cells)
    assert MapSet.size(MapSet.new(level_one_cells)) == 5

    Mimic.copy(Combat)
    Mimic.copy(SkillAttack)

    target = start_mob_session(unit_id: unique_id(), map_name: @map, position: {11, 10})
    on_exit(fn -> if Process.alive?(target.pid), do: end_mob_session(target) end)

    expect(Combat, :execute_sonic_blow_attack, 2, fn _caster, target_id, opts ->
      assert target_id == target.unit_id
      assert opts[:skill_level] in [1, 10]
      assert opts[:skill_ratio] in [300, 1_200]
      assert opts[:accelerated]
      assert opts[:display_hit_count] == 8
      {:ok, %{hit?: false, damage: 0, target_survives?: true}}
    end)

    accelerated = player(%{1_003 => 1})

    for level <- [1, 10] do
      assert {:ok, ^accelerated} =
               AsSonicblow.cast(
                 accelerated,
                 {:unit, target.unit_id},
                 level,
                 AsSonicblow.definition()
               )
    end

    stub(Combat, :resolve_target_position, fn target_id ->
      assert target_id == target.unit_id
      {:ok, :mob, {11, 10, @map}}
    end)

    expect(Combat, :execute_splash_attack, 2, fn _caster, {11, 10}, 1, opts ->
      assert opts[:skill_level] in [1, 5]
      assert opts[:skill_ratio] in [120, 200]
      []
    end)

    for level <- [1, 5] do
      assert {:ok, ^accelerated} =
               AsGrimtooth.cast(
                 accelerated,
                 {:unit, target.unit_id},
                 level,
                 AsGrimtooth.definition()
               )
    end

    armed = %{
      accelerated
      | inventory: %{
          1 => %InventoryItem{nameid: @venom_knife_item, amount: 2, equip: @ammo_slot}
        }
    }

    expect(SkillAttack, :execute_forced_no_card_attack, fn ^armed, {:mob, target_id}, opts ->
      assert target_id == target.unit_id
      assert opts[:skill_level] == 1
      assert opts[:skill_ratio] == 500
      assert opts[:bonus_atk] == 30
      {:ok, %{hit?: false, damage: 0, target_survives?: true}}
    end)

    assert {:ok, ^armed} =
             AsVenomknife.cast(
               armed,
               {:unit, {:mob, target.unit_id}},
               1,
               AsVenomknife.definition()
             )

    status_session =
      start_player_session(
        id: unique_id(),
        class: 12,
        learned_skills: %{139 => 10},
        hp: 1_000,
        max_hp: 1_000,
        sp: 1_000,
        max_sp: 1_000,
        map_name: @map,
        position: {10, 10}
      )

    on_exit(fn ->
      if Process.alive?(status_session.pid), do: end_player_session(status_session)
    end)

    status_caster = get_player_state(status_session.pid)
    status_id = status_caster.character_id

    for level <- [1, 10] do
      assert {:ok, _cloaked} =
               AsCloaking.cast(status_caster, :self, level, AsCloaking.definition())

      assert %{val1: ^level, tick: tick} =
               StatusStorage.get_status(:player, status_id, :sc_cloaking)

      assert tick == if(level == 1, do: 500, else: 9_000)

      assert {:ok, _uncloaked} =
               AsCloaking.cast(status_caster, :self, level, AsCloaking.definition())

      assert {:ok, ^status_caster} =
               AsEnchantpoison.cast(
                 status_caster,
                 :self,
                 level,
                 AsEnchantpoison.definition()
               )

      assert %{val1: ^level, started_at: started_at, expires_at: expires_at} =
               StatusStorage.get_status(:player, status_id, :sc_encpoison)

      assert expires_at - started_at == if(level == 1, do: 30_000, else: 165_000)

      assert {:ok, ^status_caster} =
               AsPoisonreact.cast(
                 status_caster,
                 :self,
                 level,
                 AsPoisonreact.definition()
               )

      assert %{
               val1: ^level,
               state: %{charges: charges},
               started_at: started_at,
               expires_at: expires_at
             } =
               StatusStorage.get_status(:player, status_id, :sc_poisonreact)

      assert charges == div(level, 2)
      assert expires_at - started_at == if(level == 1, do: 20_000, else: 60_000)

      assert {:ok, ^status_caster} =
               AsSplasher.cast(
                 status_caster,
                 {:unit, target.unit_id},
                 level,
                 AsSplasher.definition()
               )

      assert %{val1: ^level, state: %{remaining_ms: remaining, poison_react_level: 10}} =
               StatusStorage.get_status(:mob, target.unit_id, :sc_splasher)

      assert remaining == (12 - level) * 1_000
      StatusStorage.clear_unit_statuses(:mob, target.unit_id)
    end
  end

  test "invalid and interrupted resource-consuming skills leave all commitments untouched" do
    assassin = start_resource_assassin()
    assassin_id = assassin.character.id
    target = start_mob_session(unit_id: unique_id(), map_name: @map, position: {11, 10})
    on_exit(fn -> if Process.alive?(target.pid), do: end_mob_session(target) end)

    before = live_resource_snapshot(assassin.pid)
    target_hp = get_mob_state(target.pid).hp

    invalid_casts = [
      {:target, 135, 11, assassin_id},
      {:target, 136, 11, target.unit_id},
      {:target, 137, 6, target.unit_id},
      {:target, 138, 11, assassin_id},
      {:target, 139, 11, assassin_id},
      {:ground, 140, 11, {12, 10}},
      {:target, 141, 11, target.unit_id},
      {:target, 1_004, 2, target.unit_id}
    ]

    for invalid_cast <- invalid_casts do
      drive_invalid_cast(assassin.pid, invalid_cast)
      refute get_player_state(assassin.pid).casting
      assert live_resource_snapshot(assassin.pid) == before
      assert get_mob_state(target.pid).hp == target_hp
    end

    refute StatusStorage.has_status?(:player, assassin_id, :sc_cloaking)
    refute StatusStorage.has_status?(:player, assassin_id, :sc_encpoison)
    refute StatusStorage.has_status?(:player, assassin_id, :sc_poisonreact)
    refute StatusStorage.has_status?(:mob, target.unit_id, :sc_poison)
    refute StatusStorage.has_status?(:mob, target.unit_id, :sc_splasher)

    timed = player(%{141 => 10})

    assert {:casting, ^timed, %{skill_id: 141, level: 10}} =
             SkillInterpreter.begin_cast(timed, 141, 10, {:unit, target.unit_id})

    refute StatusStorage.has_status?(:mob, target.unit_id, :sc_splasher)
  end

  test "Assassin modules do not leak into sessions or handlers" do
    lib_root = Path.expand("../../lib/aesir/zone_server", __DIR__)

    offenders =
      lib_root
      |> Path.join("**/*.ex")
      |> Path.wildcard()
      |> Enum.reject(&excluded_coupling_path?/1)
      |> Enum.filter(&(File.read!(&1) =~ "Mmo.Skills.Assassin."))

    assert offenders == []

    session_sources = [
      Path.join(lib_root, "unit/player/player_session.ex"),
      Path.join(lib_root, "unit/mob/mob_session.ex")
    ]

    assert Enum.all?(session_sources, fn path -> not (File.read!(path) =~ "Mmo.Skills.") end)
  end

  defp expected_catalog do
    [
      {AsRight,
       definition(
         id: 132,
         name: :as_right,
         display_name: "Righthand Mastery",
         max_level: 5,
         target_type: :passive
       ), :passive},
      {AsLeft,
       definition(
         id: 133,
         name: :as_left,
         display_name: "Lefthand Mastery",
         max_level: 5,
         target_type: :passive
       ), :passive},
      {AsKatar,
       definition(
         id: 134,
         name: :as_katar,
         display_name: "Katar Mastery",
         max_level: 10,
         target_type: :passive
       ), :passive},
      {AsCloaking,
       definition(
         id: 135,
         name: :as_cloaking,
         display_name: "Cloaking",
         max_level: 10,
         target_type: :self,
         status: :sc_cloaking,
         sp_cost: List.duplicate(15, 10),
         requires: []
       ), :active},
      {AsSonicblow,
       definition(
         id: 136,
         name: :as_sonicblow,
         display_name: "Sonic Blow",
         max_level: 10,
         target_type: :target_enemy,
         damage_type: :damage,
         range: 1,
         sp_cost: Enum.to_list(16..34//2),
         cooldown: List.duplicate(1_000, 10),
         require_weapon: [:katar],
         requires: []
       ), :active},
      {AsGrimtooth,
       definition(
         id: 137,
         name: :as_grimtooth,
         display_name: "Grimtooth",
         max_level: 5,
         target_type: :target_enemy,
         damage_type: :damage,
         range: [3, 4, 5, 6, 7],
         splash_radius: 1,
         sp_cost: List.duplicate(3, 5),
         requires: []
       ), :active},
      {AsEnchantpoison,
       definition(
         id: 138,
         name: :as_enchantpoison,
         display_name: "Enchant Poison",
         max_level: 10,
         target_type: :target_ally,
         range: 1,
         status: :sc_encpoison,
         sp_cost: List.duplicate(20, 10),
         duration: Enum.map(1..10, &(30_000 + 15_000 * (&1 - 1)))
       ), :active},
      {AsPoisonreact,
       definition(
         id: 139,
         name: :as_poisonreact,
         display_name: "Poison React",
         max_level: 10,
         target_type: :self,
         status: :sc_poisonreact,
         sp_cost: [25, 30, 35, 40, 45, 50, 55, 60, 45, 45],
         duration: [
           20_000,
           25_000,
           30_000,
           35_000,
           40_000,
           45_000,
           50_000,
           55_000,
           60_000,
           60_000
         ]
       ), :active},
      {AsVenomdust,
       definition(
         id: 140,
         name: :as_venomdust,
         display_name: "Venom Dust",
         max_level: 10,
         target_type: :ground,
         range: 2,
         hit_interval: 1_000,
         unit_duration: Enum.to_list(5_000..50_000//5_000),
         sp_cost: List.duplicate(20, 10),
         item_cost: [%{id: 716, amount: 1}],
         requires: []
       ), :ground},
      {AsSplasher,
       definition(
         id: 141,
         name: :as_splasher,
         display_name: "Venom Splasher",
         max_level: 10,
         target_type: :target_enemy,
         range: 1,
         cast_time: List.duplicate(500, 10),
         fixed_cast_time: List.duplicate(500, 10),
         sp_cost: Enum.to_list(12..30//2),
         cooldown: Enum.to_list(11_000..2_000//-1_000),
         requires: []
       ), :active},
      {AsSonicaccel,
       definition(
         id: 1_003,
         name: :as_sonicaccel,
         display_name: "Sonic Acceleration",
         max_level: 1,
         target_type: :passive,
         quest_skill: true,
         quest_owner_job: :assassin
       ), :passive},
      {AsVenomknife,
       definition(
         id: 1_004,
         name: :as_venomknife,
         display_name: "Throw Venom Knife",
         max_level: 1,
         target_type: :target_enemy,
         damage_type: :damage,
         range: 9,
         sp_cost: [35],
         requires_ammo: true,
         quest_skill: true,
         quest_owner_job: :assassin
       ), :active}
    ]
  end

  defp definition(attrs), do: struct!(Definition, attrs)

  defp capability_module(:active, name), do: Catalog.active_module_for(name)
  defp capability_module(:ground, name), do: Catalog.ground_module_for(name)
  defp capability_module(:passive, name), do: Catalog.passive_module_for(name)

  defp venom_dust_group(level) do
    %Group{
      group_id: level,
      skill_name: :as_venomdust,
      level: level,
      center: {15, 15}
    }
  end

  defp player(learned_skills) do
    %PlayerState{
      character_id: unique_id(),
      x: 10,
      y: 10,
      map_name: @map,
      stats: %Stats{
        current_state: %{hp: 1_000, sp: 1_000},
        derived_stats: %{max_hp: 1_000, max_sp: 1_000},
        progression: %PlayerProgression{job_id: 12, learned_skills: learned_skills}
      },
      inventory: %{},
      zeny: 0
    }
    |> PlayerStateFixture.build()
  end

  defp start_resource_assassin do
    character = insert_resource_assassin()
    seed_item(character.id, @red_gemstone, 1)
    seed_item(character.id, @venom_knife_item, 1, @ammo_slot)

    session =
      start_player_session(character: character, map_name: @map, position: {10, 10})

    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end

  defp insert_resource_assassin do
    uniq = unique_id()

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "assassincompletion#{uniq}",
        userid: "assassincompletion#{uniq}",
        user_pass: "password",
        email: "assassincompletion#{uniq}@aesir.test"
      })
      |> Repo.insert()

    attrs = %{
      account_id: account.id,
      char_num: 0,
      name: "AssassinCompletion#{uniq}",
      class: 12,
      base_level: 80,
      job_level: 50,
      str: 80,
      agi: 80,
      vit: 40,
      int: 10,
      dex: 99,
      luk: 40,
      max_hp: 20_000,
      hp: 20_000,
      max_sp: 2_000,
      sp: 2_000,
      learned_skills: Map.new(@assassin_skill_ids, &{Integer.to_string(&1), 10}),
      last_map: @map,
      last_x: 10,
      last_y: 10,
      save_map: @map,
      save_x: 10,
      save_y: 10
    }

    {:ok, character} = %Character{} |> Character.changeset(attrs) |> Repo.insert()
    character
  end

  defp seed_item(character_id, nameid, amount, equip \\ 0) do
    assert {:ok, _item} =
             InventoryPersistence.insert_item(character_id, %{
               nameid: nameid,
               amount: amount,
               equip: equip,
               identify: 1
             })
  end

  defp drive_invalid_cast(pid, {:target, skill_id, level, target_id}) do
    simulate_incoming_message(pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: target_id
    })

    _sync = get_player_state(pid)
    :ok
  end

  defp drive_invalid_cast(pid, {:ground, skill_id, level, {x, y}}) do
    simulate_incoming_message(pid, %GroundSkillCast{skill_id: skill_id, level: level, x: x, y: y})
    _sync = get_player_state(pid)
    :ok
  end

  defp live_resource_snapshot(pid) do
    state = get_player_state(pid)

    %{
      sp: state.stats.current_state.sp,
      gemstone: Inventory.held_amount(state.inventory, @red_gemstone),
      venom_knives: inventory_amount(state.inventory, @venom_knife_item),
      cooldowns: state.skill_cooldowns,
      act_delay_until: state.act_delay_until
    }
  end

  defp inventory_amount(inventory, nameid) do
    inventory
    |> Map.values()
    |> Enum.find(&(&1.nameid == nameid))
    |> Map.fetch!(:amount)
  end

  defp excluded_coupling_path?(path) do
    String.contains?(path, "/mmo/skills/") or
      String.contains?(path, "/content/") or
      String.ends_with?(path, "/mmo/skill/catalog.ex")
  end

  defp unique_id, do: System.unique_integer([:positive])
end
