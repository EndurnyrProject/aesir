defmodule Aesir.ZoneServer.Integration.LordKnightSkillsTest do
  @moduledoc """
  Live-session acceptance coverage for the Lord Knight kit in Renewal and
  pre-renewal. Network transport alone is faked; skills, combat, statuses and
  equipment use their real session routes.
  """
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ActionRequest
  alias Aesir.Net.CastCancel
  alias Aesir.Net.ChatMessage
  alias Aesir.Net.ChatRequest
  alias Aesir.Net.EquipItem
  alias Aesir.Net.EquipResult
  alias Aesir.Net.ItemUseResult
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Net.SkillDamage
  alias Aesir.Net.UnequipItem
  alias Aesir.Net.UseItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @map "prontera"

  test "Berserk triples maximum HP, fully heals and empties SP through a skill packet" do
    knight = knight()
    before = get_player_state(knight.pid).stats.derived_stats.max_hp

    cast(knight, 359, 1)

    assert eventually(fn ->
             StatusStorage.has_status?(:player, knight.character.id, :sc_berserk) and
               get_player_state(knight.pid).stats.current_state.sp == 0
           end)

    stats = get_player_state(knight.pid).stats
    assert_in_delta stats.derived_stats.max_hp, 3 * before, 1
    assert stats.current_state.hp == stats.derived_stats.max_hp
  end

  test "Berserk rejects item use, area chat, equipment changes and another skill cast" do
    knight =
      knight(
        items: [%{nameid: 501, amount: 2, identify: 1}, %{nameid: 1101, amount: 1, identify: 1}]
      )

    _observer = knight()
    cast(knight, 359, 1)

    assert eventually(fn ->
             StatusStorage.has_status?(:player, knight.character.id, :sc_berserk)
           end)

    assert eventually(fn -> get_player_state(knight.pid).stats.current_state.sp == 0 end)
    assert not Interpreter.can_use_skill?(:player, knight.character.id)
    assert not Interpreter.can_use_item?(:player, knight.character.id)
    assert not Interpreter.can_chat?(:player, knight.character.id)
    assert Interpreter.equip_change_blocked?(:player, knight.character.id)

    inventory = get_player_state(knight.pid).inventory
    {potion_index, _} = Enum.find(inventory, fn {_index, item} -> item.nameid == 501 end)
    {sword_index, _} = Enum.find(inventory, fn {_index, item} -> item.nameid == 1101 end)
    flush_packets()

    simulate_incoming_message(knight.pid, %UseItem{index: PlayerState.client_index(potion_index)})
    assert_receive {:packet_sent, %ItemUseResult{ok: false}, _}, 1_000
    assert get_player_state(knight.pid).inventory[potion_index].amount == 2

    simulate_incoming_message(knight.pid, %EquipItem{
      index: PlayerState.client_index(sword_index),
      position: 2
    })

    assert_receive {:packet_sent, %EquipResult{result: result}, _}, 1_000
    assert result != 0
    assert get_player_state(knight.pid).inventory[sword_index].equip == 0

    message = "#{knight.character.name} : berserk chat"
    simulate_incoming_message(knight.pid, %ChatRequest{message: message})
    refute_receive {:packet_sent, %ChatMessage{message: ^message}, _}, 200

    cast(knight, 355, 1)
    id = knight.character.id
    assert_receive {:packet_sent, %CastCancel{gid: ^id}, _}, 1_000
  end

  test "Berserk ends at 100 HP after direct damage without an expiry penalty" do
    knight = berserk_knight()
    hp = get_player_state(knight.pid).stats.current_state.hp
    PlayerSession.apply_damage(knight.pid, hp - 100)

    assert eventually(fn ->
             state = get_player_state(knight.pid)

             state.stats.current_state.hp == 100 and
               not StatusStorage.has_status?(:player, knight.character.id, :sc_berserk)
           end)
  end

  test "natural Berserk expiry leaves 100 HP; Dispel preserves HP" do
    expired = berserk_knight()

    StatusStorage.update_status(:player, expired.character.id, :sc_berserk, fn entry ->
      %{entry | expires_at: System.monotonic_time(:millisecond) - 1}
    end)

    StatusTickManager.force_tick()

    assert eventually(fn ->
             not StatusStorage.has_status?(:player, expired.character.id, :sc_berserk) and
               get_player_state(expired.pid).stats.current_state.hp == 100
           end)

    dispelled = berserk_knight()
    assert :ok = Dispel.dispel({:player, dispelled.character.id})

    assert eventually(fn ->
             not StatusStorage.has_status?(:player, dispelled.character.id, :sc_berserk) and
               get_player_state(dispelled.pid).stats.current_state.hp > 100
           end)
  end

  test "Parrying intercepts a live mob weapon attack and unequipping ends it" do
    force_hits()
    knight = knight(items: [%{nameid: 1151, amount: 1, identify: 1}])
    index = equip!(knight, 1151, 34)
    mob = target_mob()

    cast(knight, 356, 10)

    assert eventually(fn ->
             StatusStorage.has_status?(:player, knight.character.id, :sc_parrying)
           end)

    assert Enum.any?(1..40, fn _ ->
             Combat.execute_mob_attack(get_mob_state(mob.pid), {:player, knight.character.id}) ==
               :intercepted
           end)

    simulate_incoming_message(knight.pid, %UnequipItem{index: PlayerState.client_index(index)})
    assert eventually(fn -> get_player_state(knight.pid).inventory[index].equip == 0 end)
    refute StatusStorage.has_status?(:player, knight.character.id, :sc_parrying)
  end

  @tag game_mode: :renewal, integration_pre_re: false
  test "Renewal Spiral Pierce displays five hits and roots a live mob" do
    assert_spiral_pierce()
  end

  @tag game_mode: :pre_renewal, integration_re: false
  test "pre-renewal Spiral Pierce displays five hits and uses fixed weapon damage" do
    assert assert_spiral_pierce() == 196
  end

  test "Joint Beat amplifies the next live spear strike after a forced neck break" do
    force_hits()
    knight = knight(items: [%{nameid: 1401, amount: 1, identify: 1}])
    equip!(knight, 1401, 2)
    mob = target_mob(vit: 1)
    id = knight.character.id
    flush_packets()

    cast(knight, 399, 10, mob.unit_id)

    assert_receive {:packet_sent, %SkillDamage{src_id: ^id, skill_id: 399, damage: first}, _},
                   1_000

    assert eventually(fn -> StatusStorage.has_status?(:mob, mob.unit_id, :sc_jointbeat) end)

    first_break = StatusStorage.get_status(:mob, mob.unit_id, :sc_jointbeat).val2
    baseline = if first_break == :neck, do: first / 2, else: first
    assert :ok = Interpreter.remove_status(:mob, mob.unit_id, :sc_jointbeat)

    assert :ok =
             Interpreter.apply_status(:mob, mob.unit_id, :sc_jointbeat,
               val1: 10,
               val2: :neck,
               duration: 30_000,
               caster_id: id,
               source_type: :player
             )

    assert StatusStorage.has_status?(:mob, mob.unit_id, :sc_bleeding)
    Process.sleep(1_100)
    flush_packets()
    cast(knight, 399, 10, mob.unit_id)

    assert_receive {:packet_sent, %SkillDamage{src_id: ^id, skill_id: 399, damage: second}, _},
                   1_000

    assert second > 1.5 * baseline
  end

  test "Head Crush bleeds normal mobs but skips undead and refuses bosses" do
    force_hits()
    knight = knight()
    normal = target_mob(vit: 1)
    undead = target_mob(vit: 1, race: :undead, element: {:undead, 1})
    boss = target_mob(vit: 1, modes: [:boss])
    id = knight.character.id
    flush_packets()

    assert Enum.any?(1..15, fn _ ->
             cast(knight, 398, 5, normal.unit_id)
             assert_receive {:packet_sent, %SkillDamage{src_id: ^id, skill_id: 398}, _}, 1_000
             applied? = StatusStorage.has_status?(:mob, normal.unit_id, :sc_bleeding)
             unless applied?, do: Process.sleep(550)
             applied?
           end)

    Process.sleep(550)
    cast(knight, 398, 5, undead.unit_id)
    assert_receive {:packet_sent, %SkillDamage{src_id: ^id, skill_id: 398}, _}, 1_000
    refute StatusStorage.has_status?(:mob, undead.unit_id, :sc_bleeding)

    Process.sleep(550)
    cast(knight, 398, 5, boss.unit_id)
    assert_receive {:packet_sent, %SkillCastFailed{skill_id: 398}, _}, 1_000
    assert get_mob_state(boss.pid).hp == 100_000
  end

  test "Tension Relax sits, triples live natural healing and ends on standing" do
    relaxed = knight(hp: 1_000, learned_skills: Map.put(learned_skills(), "1", 9))
    baseline = knight(hp: 1_000, learned_skills: Map.put(learned_skills(), "1", 9))
    simulate_incoming_message(baseline.pid, %ActionRequest{action: 2})
    assert eventually(fn -> get_player_state(baseline.pid).action_state == :sitting end)

    cast(relaxed, 358, 1)

    assert eventually(fn ->
             get_player_state(relaxed.pid).action_state == :sitting and
               StatusStorage.has_status?(:player, relaxed.character.id, :sc_tensionrelax)
           end)

    relaxed_hp = get_player_state(relaxed.pid).stats.current_state.hp
    baseline_hp = get_player_state(baseline.pid).stats.current_state.hp

    for _ <- 1..24 do
      send(relaxed.pid, :natural_heal_tick)
      send(baseline.pid, :natural_heal_tick)
    end

    assert eventually(fn ->
             get_player_state(baseline.pid).stats.current_state.hp > baseline_hp
           end)

    normal_gain = get_player_state(baseline.pid).stats.current_state.hp - baseline_hp
    relaxed_gain = get_player_state(relaxed.pid).stats.current_state.hp - relaxed_hp
    assert relaxed_gain >= 3 * normal_gain

    simulate_incoming_message(relaxed.pid, %ActionRequest{action: 3})
    assert eventually(fn -> get_player_state(relaxed.pid).action_state == :idle end)
    StatusTickManager.force_tick()

    assert eventually(fn ->
             not StatusStorage.has_status?(:player, relaxed.character.id, :sc_tensionrelax)
           end)
  end

  defp assert_spiral_pierce do
    force_hits()

    knight = knight(items: [%{nameid: 1401, amount: 1, identify: 1}])
    equip!(knight, 1401, 2)
    mob = target_mob(vit: 1)
    flush_packets()
    cast(knight, 397, 5, mob.unit_id)

    id = knight.character.id

    assert_receive {:packet_sent,
                    %SkillDamage{src_id: ^id, skill_id: 397, div: 5, damage: damage}, _},
                   2_000

    assert damage > 0
    assert eventually(fn -> get_mob_state(mob.pid).hp < 100_000 end)

    assert eventually(fn -> StatusStorage.has_status?(:mob, mob.unit_id, :sc_stop) end)

    %{expires_at: expiry, started_at: started} =
      StatusStorage.get_status(:mob, mob.unit_id, :sc_stop)

    assert expiry - started == 1_000
    damage
  end

  defp force_hits do
    Mimic.copy(HitCalculations)
    Mimic.stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)
  end

  defp target_mob(opts \\ []) do
    mob =
      start_mob_session(
        Keyword.merge(
          [map_name: @map, position: {151, 150}, hp: 100_000, max_hp: 100_000],
          opts
        )
      )

    on_exit(fn -> if Process.alive?(mob.pid), do: end_mob_session(mob) end)
    mob
  end

  defp equip!(knight, item_id, position) do
    {index, _} =
      Enum.find(get_player_state(knight.pid).inventory, fn {_i, item} ->
        item.nameid == item_id
      end)

    simulate_incoming_message(knight.pid, %EquipItem{
      index: PlayerState.client_index(index),
      position: position
    })

    assert eventually(fn -> get_player_state(knight.pid).inventory[index].equip == position end)
    index
  end

  defp learned_skills do
    %{
      "355" => 5,
      "356" => 10,
      "357" => 5,
      "358" => 1,
      "359" => 1,
      "397" => 5,
      "398" => 5,
      "399" => 10
    }
  end

  defp berserk_knight do
    knight = knight()
    cast(knight, 359, 1)

    assert eventually(fn ->
             StatusStorage.has_status?(:player, knight.character.id, :sc_berserk) and
               get_player_state(knight.pid).stats.current_state.sp == 0
           end)

    knight
  end

  defp knight(opts \\ []) do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "lordknight#{uniq}",
        userid: "lordknight#{uniq}",
        user_pass: "password",
        email: "lordknight#{uniq}@aesir.test"
      })
      |> Repo.insert()

    attrs = %{
      account_id: account.id,
      char_num: 0,
      name: "LordKnight#{uniq}",
      class: 4008,
      base_level: 99,
      job_level: 50,
      str: 80,
      agi: 40,
      vit: 40,
      int: 20,
      dex: 99,
      luk: 10,
      hp: 5_000,
      max_hp: 5_000,
      sp: 1_000,
      max_sp: 1_000,
      skill_point: 0,
      learned_skills: learned_skills(),
      last_map: @map,
      last_x: 150,
      last_y: 150,
      save_map: @map,
      save_x: 150,
      save_y: 150
    }

    {:ok, character} =
      %Character{}
      |> Character.changeset(Map.merge(attrs, Map.new(Keyword.delete(opts, :items))))
      |> Repo.insert()

    for item <- Keyword.get(opts, :items, []) do
      {:ok, _} = InventoryPersistence.insert_item(character.id, item)
    end

    session = start_player_session(character: character, position: {150, 150})
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end

  defp cast(knight, skill_id, level, target_id \\ nil) do
    simulate_incoming_message(knight.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: target_id || knight.character.id
    })
  end
end
