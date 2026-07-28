defmodule Aesir.ZoneServer.Integration.BardEncoreIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Net.SkillDamage
  alias Aesir.Net.UnequipItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @map "bard_encore"
  @origin {150, 150}
  @bard_class 19
  @adaptation 304
  @encore 305
  @dissonance 317
  @violin 1901
  @right_hand 0x000002
  @garment 0x000004
  @cost_cloak 900_001
  @free_cloak 900_002
  @cooldown_cloak 900_003

  setup do
    Mimic.copy(ItemManagement)

    stub(ItemManagement, :get_item_by_id, fn
      @cost_cloak ->
        {:ok,
         modifier_item(@cost_cloak, [
           {:bonus, :sp_cost_rate, 10},
           {:bonus, {:skill_use_sp_rate, @dissonance}, -20},
           {:bonus, {:skill_use_sp, @dissonance}, 3}
         ])}

      @free_cloak ->
        {:ok,
         modifier_item(@free_cloak, [
           {:bonus, :sp_cost_rate, -100},
           {:bonus, {:skill_cooldown, @dissonance}, -5_000}
         ])}

      @cooldown_cloak ->
        {:ok,
         modifier_item(@cooldown_cloak, [
           {:bonus, {:skill_cooldown, @dissonance}, -5_000}
         ])}

      item_id ->
        call_original(ItemManagement, :get_item_by_id, [item_id])
    end)

    map_cache = EtsTable.table_for(:map_cache)
    :ets.insert(map_cache, {@map, MapData.new(@map, 200, 200)})
    on_exit(fn -> :ets.delete(map_cache, @map) end)

    :ok
  end

  setup {Aesir.MimicMode, :global}

  test "Encore replays one remembered level with its timing, transformed cost, and commitments" do
    bard = start_bard([@adaptation, @encore, @dissonance], modifier: @cost_cloak)
    target = start_target({151, 150})

    cast(bard, @adaptation, 1)

    assert eventually(fn ->
             StatusStorage.has_status?(:player, bard.character.id, :sc_adaptation)
           end)

    wait_for_act_ready(bard.pid)

    initial_sp = player_sp(bard.pid)
    cast(bard, @dissonance, 5)
    original_cast = wait_for_cast(bard.pid, @dissonance)
    original_duration = original_cast.total_until - original_cast.started_at

    assert_receive {:packet_sent, %SkillDamage{skill_id: @dissonance}, _}, 2_000
    assert eventually(fn -> get_player_state(bard.pid).casting == nil end)

    after_original = get_player_state(bard.pid)
    assert after_original.last_song == %{skill_id: @dissonance, level: 5}
    assert initial_sp - after_original.stats.current_state.sp == 32

    wait_for_skill_ready(bard.pid, @dissonance)
    wait_for_act_ready(bard.pid)
    flush_packets()

    before_encore = get_player_state(bard.pid)
    cast(bard, @encore, 1)
    encore_cast = wait_for_cast(bard.pid, @encore)

    assert encore_cast.skill_level == 1
    assert encore_cast.total_until - encore_cast.started_at == original_duration
    assert get_player_state(bard.pid).last_song == %{skill_id: @dissonance, level: 5}

    assert_receive {:packet_sent, %SkillDamage{skill_id: @dissonance}, _}, 2_000
    refute_receive {:packet_sent, %SkillDamage{skill_id: @dissonance}, _}, 200
    assert eventually(fn -> get_player_state(bard.pid).casting == nil end)

    replayed = get_player_state(bard.pid)
    assert before_encore.stats.current_state.sp - replayed.stats.current_state.sp == 14
    assert replayed.skill_cooldowns[@dissonance] > System.monotonic_time(:millisecond)
    assert replayed.skill_cooldowns[@encore] > System.monotonic_time(:millisecond)
    assert replayed.skill_cooldowns[@encore] - replayed.act_delay_until == 9_700
    assert replayed.last_song == %{skill_id: @dissonance, level: 5}
    assert mob_hp(target) < 50_000
  end

  test "zero transformed cost still requires one SP and adds no nominal Encore charge" do
    empty = start_bard([@encore, @dissonance], name: "Empty", sp: 0, modifier: @free_cloak)

    funded =
      start_bard([@encore, @dissonance],
        name: "Funded",
        position: {170, 170},
        sp: 1,
        modifier: @free_cloak
      )

    for bard <- [empty, funded] do
      assert :ok =
               StatusStorage.apply_status(:player, bard.character.id, :sc_adaptation,
                 duration: 10_000
               )

      cast(bard, @dissonance, 1)
    end

    assert eventually(fn ->
             get_player_state(empty.pid).last_song == %{skill_id: @dissonance, level: 1}
           end)

    assert eventually(fn ->
             get_player_state(funded.pid).last_song == %{skill_id: @dissonance, level: 1}
           end)

    wait_for_act_ready(empty.pid)
    wait_for_act_ready(funded.pid)
    flush_packets()

    cast(empty, @encore, 1)

    assert_receive {:packet_sent,
                    %SkillCastFailed{
                      skill_id: @encore,
                      reason: :SKILL_CAST_FAILURE_REASON_INSUFFICIENT_SP
                    }, _},
                   1_000

    empty_state = get_player_state(empty.pid)
    assert empty_state.stats.current_state.sp == 0
    assert empty_state.skill_cooldowns == %{}
    assert player_sp(funded.pid) == 1

    cast(funded, @encore, 1)
    assert wait_for_cast(funded.pid, @encore)
    assert eventually(fn -> get_player_state(funded.pid).casting == nil end)

    funded_state = get_player_state(funded.pid)
    assert funded_state.stats.current_state.sp == 1
    assert Map.has_key?(funded_state.skill_cooldowns, @encore)
  end

  test "a weapon mutation during Encore commits no replay effect, SP, delay, or cooldown" do
    bard = start_bard([@encore, @dissonance], modifier: @cooldown_cloak)
    target = start_target({151, 150})

    cast(bard, @dissonance, 1)
    assert_receive {:packet_sent, %SkillDamage{skill_id: @dissonance}, _}, 2_000

    assert eventually(fn ->
             get_player_state(bard.pid).last_song == %{skill_id: @dissonance, level: 1}
           end)

    wait_for_act_ready(bard.pid)
    flush_packets()

    before = get_player_state(bard.pid)
    hp_before = mob_hp(target)
    cast(bard, @encore, 1)
    assert wait_for_cast(bard.pid, @encore)

    simulate_incoming_message(bard.pid, %UnequipItem{
      index: PlayerState.client_index(instrument_index(bard.pid))
    })

    assert eventually(fn -> get_player_state(bard.pid).stats.equipment.right_hand == nil end)

    assert_receive {:packet_sent,
                    %SkillCastFailed{
                      skill_id: @encore,
                      reason: :SKILL_CAST_FAILURE_REASON_UNSPECIFIED
                    }, _},
                   2_000

    refute_receive {:packet_sent, %SkillDamage{skill_id: @dissonance}, _}, 200
    assert eventually(fn -> get_player_state(bard.pid).casting == nil end)

    failed = get_player_state(bard.pid)
    assert failed.stats.current_state.sp == before.stats.current_state.sp
    assert failed.skill_cooldowns == %{}
    assert failed.act_delay_until == before.act_delay_until
    assert mob_hp(target) == hp_before
  end

  test "relogging clears remembered-song state and Encore fails cleanly" do
    bard = start_bard([@encore, @dissonance], modifier: @cooldown_cloak)

    cast(bard, @dissonance, 1)

    assert eventually(fn ->
             get_player_state(bard.pid).last_song == %{skill_id: @dissonance, level: 1}
           end)

    wait_for_act_ready(bard.pid)
    end_player_session(bard)
    assert eventually(fn -> not Process.alive?(bard.pid) end)

    restored_character = Repo.get!(Character, bard.character.id)

    restored =
      start_player_session(character: restored_character, map_name: @map, position: @origin)

    on_exit(fn -> end_player_session(restored) end)

    initial = get_player_state(restored.pid)
    assert initial.last_song == nil
    flush_packets()
    cast(restored, @encore, 1)

    assert_receive {:packet_sent,
                    %SkillCastFailed{
                      skill_id: @encore,
                      reason: :SKILL_CAST_FAILURE_REASON_UNSPECIFIED
                    }, _},
                   1_000

    failed = get_player_state(restored.pid)
    assert failed.stats.current_state.sp == initial.stats.current_state.sp
    assert failed.skill_cooldowns == %{}
    assert failed.act_delay_until == initial.act_delay_until
    assert failed.last_song == nil
  end

  defp modifier_item(id, program) do
    %ItemDefinition{
      id: id,
      aegis_name: "Encore_Cloak_#{id}",
      name: "Encore Cloak #{id}",
      type: :armor,
      locations: [:garment],
      on_equip: program
    }
  end

  defp start_bard(skill_ids, opts) do
    position = Keyword.get(opts, :position, @origin)
    character = insert_bard(Keyword.get(opts, :name, "Bard"), skill_ids, position, opts)
    seed_inventory(character.id, nameid: @violin, amount: 1, equip: @right_hand)

    if modifier = Keyword.get(opts, :modifier) do
      seed_inventory(character.id, nameid: modifier, amount: 1, equip: @garment)
    end

    session = start_player_session(character: character, map_name: @map, position: position)
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end

  defp start_target(position) do
    target =
      start_mob_session(
        unit_id: System.unique_integer([:positive]),
        map_name: @map,
        position: position,
        hp: 50_000,
        max_hp: 50_000,
        vit: 0,
        luk: 0
      )

    on_exit(fn -> end_mob_session(target) end)
    target
  end

  defp insert_bard(name, skill_ids, {x, y}, opts) do
    unique = System.unique_integer([:positive])
    userid = "encore#{unique}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: "M",
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %{
        account_id: account.id,
        char_num: 0,
        name: "#{name}#{unique}",
        class: @bard_class,
        base_level: 99,
        job_level: 50,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10,
        hp: 5_000,
        max_hp: 5_000,
        sp: Keyword.get(opts, :sp, 500),
        max_sp: 500,
        learned_skills: Map.new(skill_ids, &{Integer.to_string(&1), skill_level(&1)}),
        last_map: @map,
        last_x: x,
        last_y: y,
        save_map: @map,
        save_x: x,
        save_y: y
      }
      |> Character.new()
      |> Repo.insert()

    character
  end

  defp skill_level(@dissonance), do: 5
  defp skill_level(_skill_id), do: 1

  defp seed_inventory(character_id, attrs) do
    attrs = attrs |> Map.new() |> Map.put_new(:identify, 1)
    {:ok, item} = InventoryPersistence.insert_item(character_id, attrs)
    item
  end

  defp cast(session, skill_id, level) do
    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: session.character.id
    })
  end

  defp wait_for_cast(pid, skill_id) do
    assert eventually(fn ->
             match?(%{skill_id: ^skill_id}, get_player_state(pid).casting)
           end)

    get_player_state(pid).casting
  end

  defp wait_for_skill_ready(pid, skill_id) do
    assert eventually(
             fn ->
               state = get_player_state(pid)
               Map.get(state.skill_cooldowns, skill_id, 0) <= System.monotonic_time(:millisecond)
             end,
             6_000
           )
  end

  defp wait_for_act_ready(pid) do
    assert eventually(fn ->
             PlayerState.act_ready?(get_player_state(pid), System.monotonic_time(:millisecond))
           end)
  end

  defp instrument_index(pid) do
    pid
    |> get_player_state()
    |> Map.fetch!(:inventory)
    |> Enum.find_value(fn
      {index, %{nameid: @violin}} -> index
      {_index, _item} -> nil
    end)
  end

  defp player_sp(pid), do: get_player_state(pid).stats.current_state.sp
  defp mob_hp(target), do: get_mob_state(target.pid).hp
end
