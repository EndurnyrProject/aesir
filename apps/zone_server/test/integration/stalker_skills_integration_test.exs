defmodule Aesir.ZoneServer.Integration.StalkerSkillsIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Bitwise

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ActionRequest
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.StripCommon
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "stalker_skills_test"

  @stalker 4_018
  @swordman 1
  @archer 3
  @chase_walk 389
  @counter_instinct 390
  @divest_all 476

  @right_hand 2
  @left_hand 32
  @armor 16
  @head_top 256
  @ammo 0x8000

  @knife 1_201
  @guard 2_101
  @cotton_shirt 2_301
  @hat 2_220
  @bow 1_701
  @arrow 1_750

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 40, 40)})
    # Players only fight each other on versus ground.
    :ok = MapFlags.set_runtime(@map, :pvp, true)
    Mimic.copy(StripCommon)
    Mimic.copy(HitCalculations)
    stub(StripCommon, :roll_success?, fn _rate -> true end)
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)
    :ok
  end

  describe "Divest All" do
    test "strips every piece a player wears" do
      stalker = start(@stalker, {10, 10}, %{@divest_all => 5})

      target =
        start(@swordman, {11, 10}, %{},
          items: [
            {@knife, @right_hand},
            {@guard, @left_hand},
            {@cotton_shirt, @armor},
            {@hat, @head_top}
          ]
        )

      Mimic.allow(StripCommon, self(), stalker.pid)
      cast(stalker, @divest_all, 5, target.character.id)

      assert eventually(fn ->
               equipment = get_player_state(target.pid).stats.equipment

               {equipment.right_hand, equipment.left_hand, equipment.armor, equipment.head_top} ==
                 {nil, nil, nil, nil}
             end)

      for status <- [:sc_stripweapon, :sc_stripshield, :sc_striparmor, :sc_striphelm] do
        assert StatusStorage.has_status?(:player, target.character.id, status)
      end
    end

    test "a target wearing nothing fails the caster" do
      stalker = start(@stalker, {10, 12}, %{@divest_all => 5})
      target = start(@swordman, {11, 12}, %{})

      Mimic.allow(StripCommon, self(), stalker.pid)
      cast(stalker, @divest_all, 5, target.character.id)

      assert_receive {:packet_sent,
                      %SkillCastFailed{
                        skill_id: @divest_all,
                        reason: :SKILL_CAST_FAILURE_REASON_FAILED
                      }, _channel},
                     1_000
    end

    test "a fully coated target is reported coated and the SP is still spent" do
      stalker = start(@stalker, {10, 14}, %{@divest_all => 5})
      target = start(@swordman, {11, 14}, %{}, items: [{@knife, @right_hand}])

      for status <- [:sc_cp_weapon, :sc_cp_shield, :sc_cp_armor, :sc_cp_helm] do
        :ok = StatusStorage.apply_status(:player, target.character.id, status, duration: 60_000)
      end

      sp_before = current_sp(stalker.pid)
      cast(stalker, @divest_all, 5, target.character.id)

      assert_receive {:packet_sent,
                      %SkillCastFailed{
                        skill_id: @divest_all,
                        reason: :SKILL_CAST_FAILURE_REASON_FULLSTRIP_COATED
                      }, _channel},
                     1_000

      assert current_sp(stalker.pid) == sp_before - 30
      assert get_player_state(target.pid).stats.equipment.right_hand == @knife
    end
  end

  test "Chase Walk drains, grants its STR, and a recast ends it for free" do
    stalker = start(@stalker, {10, 16}, %{@chase_walk => 5})
    id = stalker.character.id
    sp_start = current_sp(stalker.pid)

    cast(stalker, @chase_walk, 5, id)
    assert eventually(fn -> StatusStorage.has_status?(:player, id, :sc_chasewalk) end)
    assert current_sp(stalker.pid) == sp_start - 10

    make_tick_due(id, :sc_chasewalk)
    StatusTickManager.force_tick()

    assert eventually(fn -> current_sp(stalker.pid) == sp_start - 30 end)

    assert eventually(fn ->
             match?(%{val1: 16}, StatusStorage.get_status(:player, id, :sc_chasewalk2))
           end)

    sp_before_recast = current_sp(stalker.pid)
    cast(stalker, @chase_walk, 5, id)

    assert eventually(fn -> not StatusStorage.has_status?(:player, id, :sc_chasewalk) end)
    assert current_sp(stalker.pid) == sp_before_recast
  end

  describe "Counter Instinct" do
    test "halves a dagger player's hit and returns the halved amount" do
      holder = counter_holder({20, 10})
      attacker = start(@swordman, {21, 10}, %{}, items: [{@knife, @right_hand}])
      Mimic.allow(HitCalculations, self(), attacker.pid)

      {holder_hp, attacker_hp} = {hp(holder.pid), hp(attacker.pid)}
      simulate_incoming_message(attacker.pid, %ActionRequest{target_id: holder.character.id})

      assert eventually(fn -> hp(holder.pid) < holder_hp end)
      assert eventually(fn -> holder_hp - hp(holder.pid) == attacker_hp - hp(attacker.pid) end)
      assert %{val3: 2} = StatusStorage.get_status(:player, holder.character.id, :sc_rejectsword)
    end

    test "counters a monster's hit the same way" do
      holder = counter_holder({20, 14})

      mob =
        start_mob_session(
          map_name: @map,
          position: {21, 14},
          hp: 100_000,
          max_hp: 100_000,
          dex: 999,
          atk: 2_000,
          atk2: 2_000,
          modes: [:can_move, :can_attack]
        )

      on_exit(fn -> end_mob_session(mob) end)

      holder_hp = hp(holder.pid)
      assert :ok = Combat.execute_mob_attack(get_mob_state(mob.pid), holder.character.id)

      assert eventually(fn -> hp(holder.pid) < holder_hp end)

      assert eventually(fn ->
               holder_hp - hp(holder.pid) == 100_000 - get_mob_state(mob.pid).hp
             end)
    end

    test "never counters a bow" do
      holder = counter_holder({20, 18})

      attacker =
        start(@archer, {21, 18}, %{},
          items: [{@bow, @right_hand ||| @left_hand}, {@arrow, @ammo}]
        )

      Mimic.allow(HitCalculations, self(), attacker.pid)
      assert get_player_state(attacker.pid).stats.equipment.right_hand == @bow
      {holder_hp, attacker_hp} = {hp(holder.pid), hp(attacker.pid)}

      simulate_incoming_message(attacker.pid, %ActionRequest{target_id: holder.character.id})

      assert eventually(fn -> hp(holder.pid) < holder_hp end)
      assert hp(attacker.pid) == attacker_hp
      assert %{val3: 3} = StatusStorage.get_status(:player, holder.character.id, :sc_rejectsword)
    end
  end

  # A Stalker under Counter Instinct cast through the real skill, its chance
  # pinned to always counter.
  defp counter_holder(position) do
    holder = start(@stalker, position, %{@counter_instinct => 5})
    id = holder.character.id
    cast(holder, @counter_instinct, 5, id)
    assert eventually(fn -> StatusStorage.has_status?(:player, id, :sc_rejectsword) end)
    StatusStorage.update_status(:player, id, :sc_rejectsword, &%{&1 | val2: 100})
    holder
  end

  # Starts the cast and completes it at once when it has a cast bar.
  defp cast(session, skill_id, level, target_id) do
    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: target_id
    })

    case GenServer.call(session.pid, :get_state).game_state.casting do
      %{token: token} -> send(session.pid, {:skill, {:cast_complete, token}})
      _instant -> :ok
    end

    _sync = get_player_state(session.pid)
    :ok
  end

  defp make_tick_due(id, status_id) do
    now = System.monotonic_time(:millisecond)
    StatusStorage.update_status(:player, id, status_id, &%{&1 | next_tick_at: now - 1})
  end

  defp start(class, {x, y}, skills, opts \\ []) do
    character = insert_character(class, skills)

    for {nameid, equip} <- Keyword.get(opts, :items, []) do
      {:ok, _item} =
        InventoryPersistence.insert_item(character.id, %{
          nameid: nameid,
          amount: if(equip == @ammo, do: 100, else: 1),
          identify: 1,
          equip: equip
        })
    end

    session = start_player_session(character: character, map_name: @map, position: {x, y})

    raw =
      :sys.replace_state(session.pid, fn raw ->
        %{raw | game_state: %{raw.game_state | x: x, y: y, map_name: @map}}
      end)

    :ok = UnitRegistry.update_unit_state(:player, character.id, raw.game_state)
    :ok = SpatialIndex.update_unit_position(:player, character.id, x, y, @map)
    on_exit(fn -> end_player_session(session) end)
    session
  end

  defp insert_character(class, skills) do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "stalker#{uniq}",
        userid: "stalker#{uniq}",
        user_pass: "password",
        email: "stalker#{uniq}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Stalker#{uniq}",
        class: class,
        base_level: 99,
        job_level: 50,
        str: 80,
        agi: 1,
        vit: 0,
        int: 10,
        dex: 99,
        luk: 0,
        max_hp: 20_000,
        hp: 20_000,
        max_sp: 2_000,
        sp: 2_000,
        learned_skills: Map.new(skills, fn {id, level} -> {Integer.to_string(id), level} end),
        last_map: @map,
        last_x: 10,
        last_y: 10,
        save_map: @map,
        save_x: 10,
        save_y: 10
      })
      |> Repo.insert()

    character
  end

  defp hp(pid), do: get_player_state(pid).stats.current_state.hp
  defp current_sp(pid), do: get_player_state(pid).stats.current_state.sp
end
