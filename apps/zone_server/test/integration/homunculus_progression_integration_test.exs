defmodule Aesir.ZoneServer.Integration.HomunculusProgressionIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Commons.Models.InventoryItem

  alias Aesir.Net.HomunculusCastSkillCommand
  alias Aesir.Net.HomunculusLearnSkillCommand
  alias Aesir.Net.HomunculusRequest
  alias Aesir.Net.HomunculusResult
  alias Aesir.Net.UseItem

  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Homunculus.ExpTable
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @map "hom_progression_e2e"
  @stone 12_040
  @red_slim_potion 545

  setup :verify_on_exit!
  setup {Aesir.MimicMode, :global}

  setup do
    Mimic.copy(Persistence)
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 100, 100)})
    :ok
  end

  test "a real mob kill crosses a growth boundary, learning persists AI, and reload does not reroll" do
    {:ok, required} = ExpTable.exp_for(2)

    owner =
      owner_session(
        class_id: 6_001,
        level: 2,
        exp: required - 1,
        skill_points: 0,
        learned_skills: %{"8001" => 3},
        catalyst?: true
      )

    before = PlayerSession.get_state(owner.pid).homunculus

    mob =
      start_mob_session(
        map_name: @map,
        position: {before.x + 1, before.y},
        hp: 1,
        max_hp: 1,
        awake: false
      )

    :ok = MobSession.apply_damage(mob.pid, 1, {:homunculus, before.world_gid})

    progressed = eventually_hom(owner.pid, &(&1.level == 3))
    assert progressed.skill_points == 1
    assert progressed.exp == 0
    assert progressed.raw_max_hp > before.raw_max_hp

    cast_skill(owner.pid, 1, 8_001, :self)
    assert_result(1)

    live_after_cast = PlayerSession.get_state(owner.pid)
    now_after_cast = System.monotonic_time(:millisecond)
    cast_active_remaining = live_after_cast.homunculus_runtime.active_deadline_ms - now_after_cast
    cast_cooldown_remaining = live_after_cast.homunculus.cooldowns[8_001] - now_after_cast
    clock_row = Repo.get_by!(Homunculus, character_id: owner.character.id)

    assert cast_active_remaining > 0
    assert cast_active_remaining < 1_800_000
    assert cast_cooldown_remaining > 0
    assert cast_active_remaining <= clock_row.active_remaining_ms
    assert clock_row.active_remaining_ms - cast_active_remaining < 1_000
    assert cast_cooldown_remaining <= clock_row.cooldowns["8001"]
    assert clock_row.cooldowns["8001"] - cast_cooldown_remaining < 1_000

    request(owner.pid, 2, {:learn_skill, %HomunculusLearnSkillCommand{skill_id: 8_002}})
    learned = assert_result(2)
    assert Enum.find(learned.skills, &(&1.skill_id == 8_002)).level == 1
    assert Enum.any?(learned.ai_config.skills, &(&1.skill_id == 8_002))

    learned_row = Repo.get_by!(Homunculus, character_id: owner.character.id)
    assert learned_row.active_remaining_ms == clock_row.active_remaining_ms
    assert learned_row.cooldowns == clock_row.cooldowns

    Process.sleep(50)

    second_mob =
      start_mob_session(
        map_name: @map,
        position: {progressed.x + 1, progressed.y},
        hp: 1,
        max_hp: 1,
        awake: false
      )

    :ok = MobSession.apply_damage(second_mob.pid, 1, {:homunculus, progressed.world_gid})

    assert_eventually(fn ->
      Repo.get_by!(Homunculus, character_id: owner.character.id).exp > 0
    end)

    row = Repo.get_by!(Homunculus, character_id: owner.character.id)
    assert row.level == 3
    assert row.skill_points == 0
    assert row.learned_skills["8002"] == 1
    assert row.active_remaining_ms == clock_row.active_remaining_ms
    assert row.cooldowns == clock_row.cooldowns

    assert Enum.any?(
             row.ai_config["skills"],
             &(&1["skill_id"] == 8_002 and &1["mode"] == "manual")
           )

    persisted_growth = Map.take(row, [:max_hp, :max_sp, :str, :agi, :vit, :int, :dex, :luk])

    kill_session(owner.pid)
    reloaded = start(owner.character |> Repo.reload!() |> Repo.preload(:homunculus))
    restored_session = PlayerSession.get_state(reloaded.pid)
    restored = restored_session.homunculus
    restored_now = System.monotonic_time(:millisecond)

    restored_active_remaining =
      restored_session.homunculus_runtime.active_deadline_ms - restored_now

    restored_cooldown_remaining = restored.cooldowns[8_001] - restored_now

    assert restored_active_remaining > 0
    assert restored_active_remaining <= row.active_remaining_ms
    assert restored_cooldown_remaining > 0
    assert restored_cooldown_remaining <= row.cooldowns["8001"]
    assert restored.level == 3
    assert restored.skill_points == 0
    assert restored.learned_skills[8_002] == 1

    assert Map.take(
             Repo.get_by!(Homunculus, character_id: owner.character.id),
             Map.keys(persisted_growth)
           ) == persisted_growth
  end

  test "Stone of Sage evolves once and update rollback preserves item, form, growth, and cooldowns" do
    evolved_owner =
      owner_session(
        class_id: 6_001,
        intimacy_hundredths: 91_100,
        stone?: true,
        learned_skills: %{"8001" => 3},
        catalyst?: true
      )

    before_session = PlayerSession.get_state(evolved_owner.pid)
    before = before_session.homunculus

    initial_active_remaining =
      before_session.homunculus_runtime.active_deadline_ms -
        System.monotonic_time(:millisecond)

    cast_skill(evolved_owner.pid, 20, 8_001, :self)
    assert_result(20)
    clock_row = Repo.get_by!(Homunculus, character_id: evolved_owner.character.id)

    assert clock_row.active_remaining_ms > 0
    assert initial_active_remaining <= clock_row.active_remaining_ms
    assert clock_row.active_remaining_ms - initial_active_remaining < 1_000
    assert clock_row.cooldowns["8001"] > 0

    Process.sleep(50)

    simulate_incoming_message(evolved_owner.pid, %UseItem{
      index: item_index(evolved_owner.pid, @stone)
    })

    evolved = eventually_hom(evolved_owner.pid, &(&1.class_id == 6_009))
    assert evolved.intimacy_hundredths == 1_000
    assert evolved.raw_max_hp > before.raw_max_hp
    assert Repo.get_by(InventoryItem, char_id: evolved_owner.character.id, nameid: @stone) == nil
    persisted = Repo.get_by!(Homunculus, character_id: evolved_owner.character.id)
    assert persisted.active_remaining_ms == clock_row.active_remaining_ms
    assert persisted.cooldowns == clock_row.cooldowns

    evolved_growth =
      Map.take(persisted, [:class_id, :max_hp, :max_sp, :str, :agi, :vit, :int, :dex, :luk])

    kill_session(evolved_owner.pid)

    restored_session =
      start(evolved_owner.character |> Repo.reload!() |> Repo.preload(:homunculus))

    restored_state = PlayerSession.get_state(restored_session.pid)
    restored = restored_state.homunculus
    restored_now = System.monotonic_time(:millisecond)

    restored_active_remaining =
      restored_state.homunculus_runtime.active_deadline_ms - restored_now

    restored_cooldown_remaining = restored.cooldowns[8_001] - restored_now

    assert restored.class_id == 6_009
    assert restored.intimacy_hundredths == 1_000
    assert restored_active_remaining > 0
    assert restored_active_remaining <= persisted.active_remaining_ms
    assert restored_cooldown_remaining > 0
    assert restored_cooldown_remaining <= persisted.cooldowns["8001"]

    assert Map.take(
             Repo.get_by!(Homunculus, character_id: evolved_owner.character.id),
             Map.keys(evolved_growth)
           ) == evolved_growth

    rollback =
      owner_session(
        class_id: 6_002,
        intimacy_hundredths: 91_100,
        stone?: true,
        cooldowns: %{"8006" => 30_000}
      )

    rollback_before = PlayerSession.get_state(rollback.pid).homunculus

    pre_operation_remaining =
      rollback_before.cooldowns[8_006] - System.monotonic_time(:millisecond)

    assert pre_operation_remaining > 0

    rollback_snapshot =
      Map.take(rollback_before, [
        :class_id,
        :str,
        :agi,
        :vit,
        :int,
        :dex,
        :luk,
        :max_hp,
        :max_sp,
        :raw_str,
        :raw_agi,
        :raw_vit,
        :raw_int,
        :raw_dex,
        :raw_luk,
        :raw_max_hp,
        :raw_max_sp,
        :intimacy_hundredths
      ])

    expect(Persistence, :transition_with_item, fn _, _, _, _, _ ->
      {:error, {:homunculus, :forced_update_failure}}
    end)

    simulate_incoming_message(rollback.pid, %UseItem{index: item_index(rollback.pid, @stone)})
    Process.sleep(100)
    assert PlayerSession.get_state(rollback.pid).homunculus == rollback_before
    :ok = PlayerSession.disconnect(rollback.pid)

    durable_remaining =
      Repo.get_by!(Homunculus, character_id: rollback.character.id).cooldowns["8006"]

    assert durable_remaining <= pre_operation_remaining

    rollback_reloaded = start(rollback.character |> Repo.reload!() |> Repo.preload(:homunculus))
    unchanged = PlayerSession.get_state(rollback_reloaded.pid).homunculus
    restored_remaining = unchanged.cooldowns[8_006] - System.monotonic_time(:millisecond)

    assert Map.take(unchanged, Map.keys(rollback_snapshot)) == rollback_snapshot
    assert restored_remaining > 0
    assert restored_remaining <= durable_remaining

    assert Repo.get_by!(InventoryItem, char_id: rollback.character.id, nameid: @stone).amount == 1
  end

  test "authenticated commands execute one authoritative skill outcome for all four species" do
    lif = owner_session(class_id: 6_001, learned_skills: %{"8001" => 3, "8002" => 1})
    lif_hom = PlayerSession.get_state(lif.pid).homunculus
    cast_skill(lif.pid, 10, 8_002, :self)
    assert_result(10)
    assert StatusStorage.has_status?(:homunculus, lif_hom.world_gid, :sc_avoid)
    assert StatusStorage.has_status?(:player, lif.character.id, :sc_avoid)

    amistr = owner_session(class_id: 6_002, learned_skills: %{"8006" => 1})
    amistr_hom = PlayerSession.get_state(amistr.pid).homunculus
    cast_skill(amistr.pid, 11, 8_006, :self)
    assert_result(11)
    assert StatusStorage.has_status?(:homunculus, amistr_hom.world_gid, :sc_defence)
    assert StatusStorage.has_status?(:player, amistr.character.id, :sc_defence)

    filir = owner_session(class_id: 6_003, learned_skills: %{"8009" => 3, "8010" => 1})
    filir_hom = PlayerSession.get_state(filir.pid).homunculus
    cast_skill(filir.pid, 12, 8_010, :self)
    assert_result(12)
    assert StatusStorage.has_status?(:homunculus, filir_hom.world_gid, :sc_fleet)

    vanil = owner_session(class_id: 6_004, learned_skills: %{"8013" => 1})
    vanil_hom = PlayerSession.get_state(vanil.pid).homunculus

    target =
      start_mob_session(
        map_name: @map,
        position: {vanil_hom.x + 1, vanil_hom.y},
        hp: 20_000,
        max_hp: 20_000,
        awake: false
      )

    cast_skill(vanil.pid, 13, 8_013, {:target_id, target.unit_id})
    assert_result(13)
    assert_eventually(fn -> MobSession.get_state(target.pid).hp < 20_000 end)
  end

  defp cast_skill(pid, id, skill_id, target) do
    wire_target = if target == :self, do: {:self, true}, else: target

    request(pid, id, {
      :cast_skill,
      %HomunculusCastSkillCommand{skill_id: skill_id, level: 1, target: wire_target}
    })
  end

  defp request(pid, id, command) do
    simulate_incoming_message(pid, %HomunculusRequest{request_id: id, command: command})
  end

  defp assert_result(id) do
    assert_receive {:packet_sent, %HomunculusResult{request_id: ^id, success: true, state: state},
                    _},
                   2_000

    state
  end

  defp eventually_hom(pid, predicate) do
    assert_eventually(fn ->
      homunculus = PlayerSession.get_state(pid).homunculus
      homunculus && predicate.(homunculus)
    end)

    PlayerSession.get_state(pid).homunculus
  end

  defp owner_session(opts) do
    character = character_fixture()

    if Keyword.get(opts, :stone?, false) do
      {:ok, _} =
        InventoryPersistence.insert_item(character.id, %{nameid: @stone, amount: 1, identify: 1})
    end

    if Keyword.get(opts, :catalyst?, false) do
      {:ok, _} =
        InventoryPersistence.insert_item(character.id, %{
          nameid: @red_slim_potion,
          amount: 1,
          identify: 1
        })
    end

    insert_homunculus(character.id, opts)
    session = start(Repo.preload(character, :homunculus))
    Map.put(session, :character, character)
  end

  defp start(character) do
    session = start_player_session(character: character, map_name: @map, position: {50, 50})
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    flush_packets()
    session
  end

  defp kill_session(pid) do
    Process.unlink(pid)
    monitor = Process.monitor(pid)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^pid, :killed}, 1_000
  end

  defp item_index(pid, item_id) do
    {index, _} =
      Enum.find(PlayerSession.get_state(pid).game_state.inventory, fn {_index, item} ->
        item.nameid == item_id
      end)

    index + 2
  end

  defp character_fixture do
    suffix = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "homprog#{suffix}",
        user_pass: "password",
        email: "homprog#{suffix}@example.com"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: "HomProg#{suffix}",
      class: 18,
      base_level: 50,
      job_level: 50,
      hp: 5_000,
      max_hp: 5_000,
      sp: 500,
      max_sp: 500,
      last_map: @map,
      last_x: 50,
      last_y: 50
    })
    |> Repo.insert!()
  end

  defp insert_homunculus(character_id, opts) do
    %Homunculus{}
    |> Homunculus.changeset(%{
      character_id: character_id,
      class_id: Keyword.fetch!(opts, :class_id),
      name: "Homunculus",
      lifecycle: "active",
      level: Keyword.get(opts, :level, 50),
      exp: Keyword.get(opts, :exp, 0),
      skill_points: Keyword.get(opts, :skill_points, 0),
      hp: 2_000,
      max_hp: 2_000,
      sp: 500,
      max_sp: 500,
      str: 20,
      agi: 20,
      vit: 20,
      int: 20,
      dex: 100,
      luk: 20,
      intimacy_hundredths: Keyword.get(opts, :intimacy_hundredths, 75_100),
      active_remaining_ms: 1_800_000,
      learned_skills: Keyword.get(opts, :learned_skills, %{}),
      cooldowns: Keyword.get(opts, :cooldowns, %{})
    })
    |> Repo.insert!()
  end
end
