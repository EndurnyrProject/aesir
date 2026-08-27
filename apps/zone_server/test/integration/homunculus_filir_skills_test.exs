defmodule Aesir.ZoneServer.Integration.HomunculusFilirSkillsTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Net.DamageDealt
  alias Aesir.Net.SkillDamage
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Combat.OnHitEffects
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.Config, as: AiConfig
  alias Aesir.ZoneServer.Mmo.Homunculus.SkillTree
  alias Aesir.ZoneServer.Mmo.Homunculus.Stats
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.AiHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @moon 8009
  @fleet 8010
  @speed 8011
  @sbr44 8012
  @gid 1_500_901
  @mob_gid 1_600_901
  @map "filir_skill_map"

  # DamageDealt swing types, mirroring Combat.PacketFactory's private constants.
  @attack_type_normal 0
  @attack_type_lucky_dodge 10

  setup do
    Mimic.copy(Broadcast)
    Mimic.copy(DamageApplication)
    Mimic.copy(HitCalculations)
    Mimic.copy(OnHitEffects)
    Mimic.copy(Persistence)
    Catalog.reload()
    on_exit(&Catalog.reload/0)
    :ok
  end

  test "catalog exposes exact Filir definitions and Renewal tables" do
    assert_definition(
      @moon,
      :hfli_moon,
      5,
      :target_enemy,
      15,
      [4, 8, 12, 16, 20],
      List.duplicate(2_000, 5)
    )

    for {id, name} <- [{@fleet, :hfli_fleet}, {@speed, :hfli_speed}] do
      assert_definition(id, name, 5, :self, 0, [30, 40, 50, 60, 70], [
        60_000,
        75_000,
        90_000,
        105_000,
        120_000
      ])

      assert {:ok, definition} = Catalog.by_id(id)
      assert definition.duration == [60_000, 55_000, 50_000, 45_000, 40_000]
    end

    assert_definition(@sbr44, :hfli_sbr44, 3, :target_enemy, 15, [1, 1, 1], [
      1_000,
      1_000,
      1_000
    ])

    assert {:ok, %{requires: [%{skill_id: @moon, level: 3}], form: :any}} =
             SkillTree.entry(6003, @fleet)

    assert {:ok, %{requires: [%{skill_id: @fleet, level: 3}], form: :any}} =
             SkillTree.entry(6003, @speed)

    assert {:ok, %{form: :evolved, required_intimacy: 91_000, requires: []}} =
             SkillTree.entry(6003, @sbr44)
  end

  test "Moonlight ranks one, three, and five deal one ranked hit with visual divisions" do
    test_pid = self()

    Mimic.stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
      send(test_pid, {:combat_packet, packet})
      :ok
    end)

    for {rank, cost, divisions, ratio} <- [{1, 4, 1, 220}, {3, 12, 2, 440}, {5, 20, 3, 660}] do
      session = session(learned_skills: %{@moon => 5}, sp: 100)
      register_units(session.homunculus, mob())

      assert {:ok, cast} =
               CastingHandler.begin(session, @moon, rank, {:unit, {:mob, @mob_gid}})

      assert cast.homunculus.sp == 100 - cost
      assert cast.homunculus.cooldowns[@moon] > System.monotonic_time(:millisecond)

      assert_receive {:"$gen_cast", {:combat, {:apply_damage, ^ratio, {:homunculus, @gid}}}}
      assert_receive {:combat_packet, %SkillDamage{damage: ^ratio, div: ^divisions}}
      refute_receive {:"$gen_cast", {:combat, {:apply_damage, _, _}}}
      refute_receive {:combat_packet, %SkillDamage{}}
      clear_units()
    end
  end

  test "Moonlight uses the interpreter's typed fifteen-cell range pipeline" do
    session = session(learned_skills: %{@moon => 1}, sp: 100)
    register_units(session.homunculus, mob(25))

    assert {:ok, _cast} =
             CastingHandler.begin(session, @moon, 1, {:unit, {:mob, @mob_gid}})

    clear_units()
    register_units(session.homunculus, mob(26))

    assert {:error, :out_of_range, ^session} =
             CastingHandler.begin(session, @moon, 1, {:unit, {:mob, @mob_gid}})
  end

  test "AI and direct Moonlight casts share the CastingHandler settlement" do
    direct = session(learned_skills: %{@moon => 1}, sp: 100)
    register_units(direct.homunculus, mob())

    assert {:ok, direct_cast} =
             CastingHandler.begin(direct, @moon, 1, {:unit, {:mob, @mob_gid}})

    assert_receive {:"$gen_cast", {:combat, {:apply_damage, 220, {:homunculus, @gid}}}}
    clear_units()

    ai =
      session(
        learned_skills: %{@moon => 1},
        sp: 100,
        ai_config: auto_skill_config(@moon, :enemy)
      )

    register_units(ai.homunculus, mob())
    register_owner(ai.game_state)
    armed = AiHandler.arm(ai)

    assert {:noreply, ai_cast} = AiHandler.tick(armed.homunculus_runtime.ai_timer_ref, armed)
    AiHandler.cancel(ai_cast)

    assert_receive {:"$gen_cast", {:combat, {:apply_damage, 220, {:homunculus, @gid}}}}
    assert ai_cast.homunculus.sp == direct_cast.homunculus.sp
    assert Map.has_key?(ai_cast.homunculus.cooldowns, @moon)
  end

  test "Fleeting Move and Speed store exact rank values, durations, and effective modifiers" do
    for rank <- [1, 3, 5] do
      fleet_session = session(learned_skills: %{@moon => 3, @fleet => 5}, sp: 100)
      register_homunculus(fleet_session.homunculus)
      assert {:ok, _cast} = CastingHandler.begin(fleet_session, @fleet, rank, :self)
      fleet = StatusStorage.get_status(:homunculus, @gid, :sc_fleet)
      assert {fleet.source_id, fleet.source_type} == {@gid, :homunculus}
      assert {fleet.val1, fleet.val2, fleet.val3} == {rank, 30 * rank, 5 + 5 * rank}
      assert_in_delta fleet.expires_at - System.monotonic_time(:millisecond), duration(rank), 100

      modifiers = ModifierCalculator.get_all_modifiers(:homunculus, @gid)
      assert modifiers.hom_aspd_rate == 30 * rank
      assert modifiers.atk_rate == 5 + 5 * rank

      baseline = Stats.recompute(fleet_session.homunculus, %{})
      buffed = Stats.recompute(fleet_session.homunculus, modifiers)
      assert buffed.attack_delay_ms < baseline.attack_delay_ms
      clear_units()

      speed_session =
        session(learned_skills: %{@moon => 3, @fleet => 3, @speed => 5}, sp: 100)

      register_homunculus(speed_session.homunculus)
      assert {:ok, _cast} = CastingHandler.begin(speed_session, @speed, rank, :self)
      speed = StatusStorage.get_status(:homunculus, @gid, :sc_speed)
      assert {speed.source_id, speed.source_type} == {@gid, :homunculus}
      assert {speed.val1, speed.val2} == {rank, 10 + 10 * rank}
      modifiers = ModifierCalculator.get_all_modifiers(:homunculus, @gid)
      assert modifiers.flee == 10 + 10 * rank

      baseline = Stats.recompute(speed_session.homunculus, %{})
      buffed = Stats.recompute(speed_session.homunculus, modifiers)
      assert buffed.combat_stats.flee == baseline.combat_stats.flee + 10 + 10 * rank
      clear_units()
    end
  end

  test "S.B.R.44 ranks one through three scale pre-cast intimacy through real damage" do
    for rank <- 1..3 do
      {character, row} = insert_filir(40_000)

      session =
        session(
          id: row.id,
          owner_character_id: character.id,
          intimacy_hundredths: 40_000,
          learned_skills: %{@sbr44 => 3}
        )

      register_units(session.homunculus, mob())

      assert {:ok, cast} =
               CastingHandler.begin(session, @sbr44, rank, {:unit, {:mob, @mob_gid}})

      expected_damage = 40_000 * rank

      assert_receive {:"$gen_cast",
                      {:combat, {:apply_damage, ^expected_damage, {:homunculus, @gid}}}}

      assert cast.homunculus.intimacy_hundredths == 100
      clear_units()
    end
  end

  test "S.B.R.44 rejects wrong form/species and intimacy 399 without settlement" do
    original =
      session(intimacy_hundredths: 91_000, learned_skills: %{@sbr44 => 1})
      |> then(&%{&1 | homunculus: %{&1.homunculus | class_id: 6003}})

    assert {:error, :skill_not_learned, ^original} =
             CastingHandler.begin(original, @sbr44, 1, {:unit, {:mob, @mob_gid}})

    wrong_species =
      session(intimacy_hundredths: 91_000, learned_skills: %{@sbr44 => 1})
      |> then(&%{&1 | homunculus: %{&1.homunculus | class_id: 6001}})

    assert {:error, :wrong_species, ^wrong_species} =
             CastingHandler.begin(wrong_species, @sbr44, 1, {:unit, {:mob, @mob_gid}})

    rejected = session(intimacy_hundredths: 399, learned_skills: %{@sbr44 => 1})
    register_units(rejected.homunculus, mob())

    assert {:error, :insufficient_intimacy, ^rejected} =
             CastingHandler.begin(rejected, @sbr44, 1, {:unit, {:mob, @mob_gid}})

    clear_units()
    accepted = session(intimacy_hundredths: 400, learned_skills: %{@sbr44 => 1})
    register_units(accepted.homunculus, mob())

    assert {:error, :homunculus_not_found, ^accepted} =
             CastingHandler.begin(accepted, @sbr44, 1, {:unit, {:mob, @mob_gid}})

    refute_receive {:"$gen_cast", {:combat, {:apply_damage, _, _}}}
  end

  test "an S.B.R.44 miss reports normally and settles without persisting intimacy" do
    test_pid = self()
    Mimic.stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :miss end)

    Mimic.stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
      send(test_pid, {:miss_packet, packet})
      :ok
    end)

    reject(&Persistence.load_for_character/1)
    reject(&Persistence.save_semantic/2)
    session = session(intimacy_hundredths: 40_000, learned_skills: %{@sbr44 => 3})
    register_units(session.homunculus, mob())

    assert {:ok, cast} =
             CastingHandler.begin(session, @sbr44, 2, {:unit, {:mob, @mob_gid}})

    assert_receive {:miss_packet, %DamageDealt{}}
    refute_receive {:"$gen_cast", {:combat, {:apply_damage, _, _}}}
    assert cast.homunculus.intimacy_hundredths == 40_000
    assert cast.homunculus.sp == 99
    assert cast.homunculus.cooldowns[@sbr44] > System.monotonic_time(:millisecond)
  end

  test "an intercepted S.B.R.44 settles resources without a miss or connected-hit effect" do
    test_pid = self()

    Mimic.stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
      send(test_pid, {:combat_packet, packet})
      :ok
    end)

    reject(&HitCalculations.calculate_hit_result/2)
    reject(&Persistence.load_for_character/1)
    reject(&Persistence.save_semantic/2)
    reject(&DamageApplication.prepare_unit_damage/5)
    reject(&DamageApplication.apply_unit_damage/6)
    reject(&OnHitEffects.after_hit/4)

    session = session(intimacy_hundredths: 40_000, learned_skills: %{@sbr44 => 3})
    register_units(session.homunculus, mob())
    :ok = StatusStorage.apply_status(:mob, @mob_gid, :sc_autoguard, val1: 10)
    :rand.seed(:exsss, {1, 1, 1})

    assert {:ok, cast} =
             CastingHandler.begin(session, @sbr44, 2, {:unit, {:mob, @mob_gid}})

    # A blocked hit still broadcasts the guard packet the client renders the block
    # from: a zero-damage DamageDealt on the normal swing type. What must not
    # happen is the miss packet (lucky-dodge type) or any damage delivery.
    assert_receive {:combat_packet, %DamageDealt{damage: 0, div: 1, type: @attack_type_normal}}
    refute_receive {:combat_packet, %DamageDealt{type: @attack_type_lucky_dodge}}
    refute_receive {:"$gen_cast", {:combat, {:apply_damage, _, _}}}
    assert cast.homunculus.intimacy_hundredths == 40_000
    assert cast.homunculus.sp == 99
    assert cast.homunculus.cooldowns[@sbr44] > System.monotonic_time(:millisecond)
    clear_units()
  end

  test "stale targets and intimacy persistence failure prevent every connected-hit effect" do
    {character, row} = insert_filir(40_000)

    session =
      session(
        id: row.id,
        owner_character_id: character.id,
        intimacy_hundredths: 40_000,
        learned_skills: %{@sbr44 => 3}
      )

    register_units(session.homunculus, mob())
    UnitRegistry.unregister_unit(:mob, @mob_gid)

    assert {:error, :target_not_found, ^session} =
             CastingHandler.begin(session, @sbr44, 1, {:unit, {:mob, @mob_gid}})

    register_units(session.homunculus, mob())
    expect(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)
    Mimic.stub(Persistence, :load_for_character, fn _owner_id -> row end)
    Mimic.stub(Persistence, :save_semantic, fn _row, _attrs -> {:error, :database_down} end)
    reject(&DamageApplication.prepare_unit_damage/5)
    reject(&DamageApplication.apply_unit_damage/6)
    reject(&OnHitEffects.after_hit/4)
    reject(&Broadcast.to_in_range/5)

    assert {:error, :database_down, ^session} =
             CastingHandler.begin(session, @sbr44, 1, {:unit, {:mob, @mob_gid}})

    refute_receive {:"$gen_cast", {:combat, {:apply_damage, _, _}}}
    assert session.homunculus.sp == 100
    assert session.homunculus.cooldowns == %{}
    assert session.homunculus.intimacy_hundredths == 40_000
  end

  test "a connected S.B.R.44 hit persists and commits before external damage dispatch" do
    {character, row} = insert_filir(40_000)

    session =
      session(
        id: row.id,
        owner_character_id: character.id,
        intimacy_hundredths: 40_000,
        learned_skills: %{@sbr44 => 3}
      )

    register_units(session.homunculus, mob())
    test_pid = self()

    Mimic.stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet ->
      assert Repo.get!(Homunculus, row.id).intimacy_hundredths == 100
      assert {:ok, {HomunculusState, committed, _pid}} = UnitRegistry.get_unit(:homunculus, @gid)
      assert {committed.sp, committed.intimacy_hundredths} == {99, 100}
      send(test_pid, :delivered_after_commit)
      :ok
    end)

    assert {:ok, cast} =
             CastingHandler.begin(session, @sbr44, 3, {:unit, {:mob, @mob_gid}})

    assert_receive :delivered_after_commit
    assert_receive {:"$gen_cast", {:combat, {:apply_damage, 120_000, {:homunculus, @gid}}}}
    assert cast.homunculus.intimacy_hundredths == 100
    assert cast.homunculus.sp == 99
    assert Repo.get!(Homunculus, row.id).intimacy_hundredths == 100
  end

  defp assert_definition(id, name, max_level, target_type, range, costs, cooldowns) do
    assert {:ok, definition} = Catalog.by_id(id)
    assert definition.name == name
    assert definition.max_level == max_level
    assert definition.target_type == target_type
    assert definition.range == range
    assert definition.sp_cost == costs
    assert definition.cooldown == cooldowns
  end

  defp duration(1), do: 60_000
  defp duration(3), do: 50_000
  defp duration(5), do: 40_000

  defp session(opts) do
    homunculus = %HomunculusState{
      id: Keyword.get(opts, :id, 901),
      owner_character_id: Keyword.get(opts, :owner_character_id, 900),
      class_id: 6011,
      name: "Filir",
      lifecycle: :active,
      hp: 1_000,
      max_hp: 1_000,
      sp: Keyword.get(opts, :sp, 100),
      max_sp: 100,
      intimacy_hundredths: Keyword.get(opts, :intimacy_hundredths, 91_000),
      learned_skills: Keyword.fetch!(opts, :learned_skills),
      ai_config: Keyword.get(opts, :ai_config, %{}),
      world_gid: @gid,
      map_name: @map,
      x: 10,
      y: 10,
      race: :brute,
      size: :medium,
      combat_stats: %{
        atk: 0,
        atk_min: 100,
        atk_max: 100,
        def: 0,
        soft_def: 0,
        hit: 10_000,
        flee: 0,
        perfect_dodge: 0,
        critical: 0,
        matk: 0,
        matk_min: 0,
        matk_max: 0,
        mdef: 0,
        soft_mdef: 0,
        hp_regen_rate: 0,
        sp_regen_rate: 0
      }
    }

    owner = %PlayerState{
      character_id: homunculus.owner_character_id,
      map_name: @map,
      x: 10,
      y: 10
    }

    %SessionState{game_state: owner, connection_pid: self(), homunculus: homunculus}
  end

  defp register_units(homunculus, target) do
    register_homunculus(homunculus)
    UnitRegistry.register_unit(:mob, @mob_gid, MobState, target, self())
    SpatialIndex.add_unit(:mob, @mob_gid, target.x, target.y, @map)
  end

  defp register_owner(owner) do
    UnitRegistry.register_unit(:player, owner.character_id, PlayerState, owner, self())
    SpatialIndex.add_unit(:player, owner.character_id, owner.x, owner.y, @map)
  end

  defp register_homunculus(homunculus) do
    UnitRegistry.register_unit(:homunculus, @gid, HomunculusState, homunculus, self())
    SpatialIndex.add_unit(:homunculus, @gid, 10, 10, @map)
  end

  defp clear_units do
    StatusStorage.clear_unit_statuses(:homunculus, @gid)
    StatusStorage.clear_unit_statuses(:mob, @mob_gid)
    UnitRegistry.unregister_unit(:homunculus, @gid)
    UnitRegistry.unregister_unit(:mob, @mob_gid)
  end

  defp mob(x \\ 12) do
    definition = %MobDefinition{
      id: 1,
      aegis_name: "FILIR_TARGET",
      name: "Filir Target",
      level: 1,
      hp: 1_000_000,
      stats: %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
      atk: 0,
      matk: 0,
      def: 0,
      mdef: 0,
      attack_range: 1,
      size: :medium,
      race: :formless,
      element: {:neutral, 1},
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 500
    }

    MobState.new(@mob_gid, definition, %{respawn_time: 0}, @map, x, 10)
  end

  defp auto_skill_config(id, target) do
    config = AiConfig.default([%{id: id, target: target, allowed_thresholds: []}])
    skill = %{config.skills[id] | mode: :auto}
    %{config | stance: :aggressive, skills: %{id => skill}}
  end

  defp insert_filir(intimacy) do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "filir#{uniq}",
        user_pass: "password",
        email: "filir#{uniq}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Filir#{uniq}",
        class: 18,
        last_map: "prontera",
        last_x: 150,
        last_y: 150
      })
      |> Repo.insert()

    {:ok, row} =
      %Homunculus{}
      |> Homunculus.changeset(%{
        character_id: character.id,
        class_id: 6011,
        name: "Filir",
        hp: 1_000,
        max_hp: 1_000,
        sp: 100,
        max_sp: 100,
        intimacy_hundredths: intimacy,
        learned_skills: %{"8012" => 3}
      })
      |> Repo.insert()

    {character, row}
  end
end
