defmodule Aesir.ZoneServer.Integration.BardActiveSkillsIntegrationTest do
  @moduledoc """
  Real-session coverage for Bard's bounded active-skill paths. The corresponding
  real MobSession Frost Joker timer is covered by `mob_cast_integration_test.exs`.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.Respawn
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Net.SkillDamage
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @map "bard_active_a"
  @other_map "bard_active_b"
  @bard_class 19
  @musical_strike 316
  @dissonance 317
  @frost_joker 318
  @pang_voice 1010
  @violin 1901
  @arrow 1750
  @right_hand 2
  @ammo 0x008000

  setup do
    Mimic.copy(HitCalculations)
    Mimic.copy(Resistance)
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)
    stub(Resistance, :roll_success, fn effective_rate -> effective_rate > 0 end)

    map_cache = EtsTable.table_for(:map_cache)
    :ets.insert(map_cache, {@map, MapData.new(@map, 200, 200)})
    :ets.insert(map_cache, {@other_map, MapData.new(@other_map, 200, 200)})

    :ok
  end

  setup {Aesir.MimicMode, :global}

  test "Musical Strike spends and persists one arrow for one aggregate two-hit presentation" do
    target = start_target({151, 150}, hp: 50_000)
    invalid = start_bard([@musical_strike], name: "NoArrow", instrument?: true)
    invalid_sp = player_sp(invalid.pid)

    flush_packets()
    cast(invalid, @musical_strike, target.unit_id)

    assert_receive {:packet_sent,
                    %SkillCastFailed{
                      skill_id: @musical_strike,
                      reason: :SKILL_CAST_FAILURE_REASON_NO_AMMO
                    }, _},
                   1_000

    assert equipped_arrow_amount(invalid.pid) == 0
    assert persisted_arrow_amount(invalid.character.id) == 0
    assert player_sp(invalid.pid) == invalid_sp
    assert mob_hp(target) == 50_000

    end_player_session(invalid)
    assert eventually(fn -> not Process.alive?(invalid.pid) end)

    bard = start_bard([@musical_strike], instrument?: true, arrows: 3)
    flush_packets()
    cast(bard, @musical_strike, target.unit_id)

    assert_receive {:packet_sent,
                    %SkillDamage{
                      skill_id: @musical_strike,
                      target_id: target_id,
                      div: 2,
                      damage: damage
                    }, _},
                   2_000

    assert target_id == target.unit_id
    assert damage > 0
    refute_receive {:packet_sent, %SkillDamage{skill_id: @musical_strike}, _}, 200

    assert eventually(fn -> mob_hp(target) == 50_000 - damage end)
    assert eventually(fn -> equipped_arrow_amount(bard.pid) == 2 end)
    assert eventually(fn -> persisted_arrow_amount(bard.character.id) == 2 end)
  end

  test "Dissonance deals one immediate splash and leaves no skill-unit state" do
    bard = start_bard([@dissonance], instrument?: true)
    target = start_target({151, 150}, hp: 50_000)

    flush_packets()
    cast(bard, @dissonance, bard.character.id)

    assert_receive {:packet_sent,
                    %SkillDamage{
                      skill_id: @dissonance,
                      target_id: target_id,
                      div: 1,
                      damage: damage
                    }, _},
                   2_000

    assert target_id == target.unit_id
    assert damage > 0
    assert eventually(fn -> mob_hp(target) == 50_000 - damage end)
    refute_receive {:packet_sent, %SkillDamage{skill_id: @dissonance}, _}, 200

    assert Storage.all() == []
    assert table_rows(:skill_unit_due_index) == []
    assert table_rows(:skill_unit_expiry_index) == []
    assert table_rows(:skill_units) == []
  end

  test "Pang Voice applies confusion and bleeding through the ordinary status path" do
    bard = start_bard([@pang_voice])
    target = start_target({151, 150}, hp: 50_000)

    cast(bard, @pang_voice, target.unit_id)

    assert eventually(fn ->
             StatusStorage.has_status?(:mob, target.unit_id, :sc_confusion) and
               StatusStorage.has_status?(:mob, target.unit_id, :sc_bleeding)
           end)

    for status <- [:sc_confusion, :sc_bleeding] do
      assert %{source_id: source_id, expires_at: expires_at} =
               StatusStorage.get_status(:mob, target.unit_id, status)

      assert source_id == bard.character.id
      assert expires_at > System.monotonic_time(:millisecond)
    end
  end

  test "Frost Joker's real player timer survives walking" do
    bard = start_bard([@frost_joker])
    target = start_target({151, 150}, hp: 50_000)
    initial_sp = player_sp(bard.pid)

    cast(bard, @frost_joker, bard.character.id, 5)
    assert eventually(fn -> player_sp(bard.pid) == initial_sp - 20 end)

    simulate_incoming_message(bard.pid, %MoveRequest{dest_x: 150, dest_y: 151})
    assert eventually(fn -> player_position(bard.pid) == {150, 151} end)

    assert eventually(
             fn -> StatusStorage.has_status?(:mob, target.unit_id, :sc_freeze) end,
             4_000
           )
  end

  test "Frost Joker's real player timers cancel on every lifecycle boundary" do
    death = frost_pair("Death", {140, 140})
    disconnect = frost_pair("Disconnect", {145, 140})
    cross_map = frost_pair("CrossMap", {150, 140})
    same_map = frost_pair("SameMap", {155, 140})

    pairs = [death, disconnect, cross_map, same_map]

    Enum.each(pairs, fn %{bard: bard} ->
      initial_sp = player_sp(bard.pid)
      cast(bard, @frost_joker, bard.character.id, 5)
      assert eventually(fn -> player_sp(bard.pid) == initial_sp - 20 end)
    end)

    hp = get_player_state(death.bard.pid).stats.current_state.hp
    PlayerSession.apply_damage(death.bard.pid, hp, nil)
    assert eventually(fn -> get_player_state(death.bard.pid).action_state == :dead end)
    simulate_incoming_message(death.bard.pid, %Respawn{type: 0})
    assert eventually(fn -> get_player_state(death.bard.pid).action_state == :idle end)

    end_player_session(disconnect.bard)
    assert eventually(fn -> not Process.alive?(disconnect.bard.pid) end)

    PlayerSession.warp(cross_map.bard.pid, @other_map, 160, 160)
    assert eventually(fn -> get_player_state(cross_map.bard.pid).map_name == @other_map end)

    PlayerSession.warp(same_map.bard.pid, @map, 160, 140)
    assert eventually(fn -> player_position(same_map.bard.pid) == {160, 140} end)

    Process.sleep(3_200)

    Enum.each(pairs, fn %{target: target} ->
      refute StatusStorage.has_status?(:mob, target.unit_id, :sc_freeze)
    end)
  end

  defp frost_pair(name, {x, y}) do
    bard = start_bard([@frost_joker], name: name, position: {x, y})
    target = start_target({x + 1, y}, hp: 50_000)
    %{bard: bard, target: target}
  end

  defp start_bard(skill_ids, opts \\ []) do
    position = Keyword.get(opts, :position, {150, 150})
    character = insert_bard(Keyword.get(opts, :name, "Bard"), skill_ids, position)

    if Keyword.get(opts, :instrument?, false) do
      seed_inventory(character.id, nameid: @violin, amount: 1, equip: @right_hand)
    end

    case Keyword.get(opts, :arrows, 0) do
      0 -> :ok
      amount -> seed_inventory(character.id, nameid: @arrow, amount: amount, equip: @ammo)
    end

    session = start_player_session(character: character, map_name: @map, position: position)
    on_exit(fn -> end_player_session(session) end)
    session
  end

  defp start_target(position, opts) do
    target =
      start_mob_session(
        unit_id: System.unique_integer([:positive]),
        map_name: @map,
        position: position,
        hp: Keyword.fetch!(opts, :hp),
        max_hp: Keyword.fetch!(opts, :hp),
        vit: 0,
        luk: 0
      )

    on_exit(fn ->
      StatusStorage.clear_unit_statuses(:mob, target.unit_id)
      end_mob_session(target)
    end)

    target
  end

  defp insert_bard(name, skill_ids, {x, y}) do
    unique = System.unique_integer([:positive])
    userid = "bardactive#{unique}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: "M",
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert()

    learned_skills = Map.new(skill_ids, &{Integer.to_string(&1), 5})

    {:ok, character} =
      %{
        account_id: account.id,
        char_num: 0,
        name: "#{name}#{unique}",
        class: @bard_class,
        base_level: 99,
        job_level: 50,
        str: 20,
        agi: 20,
        vit: 20,
        int: 20,
        dex: 99,
        luk: 20,
        hp: 5_000,
        max_hp: 5_000,
        sp: 500,
        max_sp: 500,
        learned_skills: learned_skills,
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

  defp seed_inventory(char_id, attrs) do
    attrs = attrs |> Map.new() |> Map.put_new(:identify, 1)
    {:ok, item} = InventoryPersistence.insert_item(char_id, attrs)
    item
  end

  defp cast(session, skill_id, target_id, level \\ 1) do
    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: target_id
    })
  end

  defp equipped_arrow_amount(pid) do
    pid
    |> get_player_state()
    |> Map.fetch!(:inventory)
    |> Map.values()
    |> Enum.find_value(0, fn
      %InventoryItem{nameid: @arrow, equip: @ammo, amount: amount} -> amount
      _item -> nil
    end)
  end

  defp persisted_arrow_amount(character_id) do
    character_id
    |> InventoryPersistence.load_inventory()
    |> Enum.find_value(0, fn
      %InventoryItem{nameid: @arrow, equip: @ammo, amount: amount} -> amount
      _item -> nil
    end)
  end

  defp table_rows(name) do
    name
    |> EtsTable.table_for()
    |> :ets.tab2list()
  end

  defp player_sp(pid), do: get_player_state(pid).stats.current_state.sp
  defp player_position(pid), do: then(get_player_state(pid), &{&1.x, &1.y})
  defp mob_hp(target), do: get_mob_state(target.pid).hp
end
