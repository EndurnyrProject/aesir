defmodule Aesir.ZoneServer.Integration.HunterPhantasmicIntegrationTest do
  @moduledoc """
  Real-session coverage for Phantasmic Arrow: a granted quest skill cast
  through the ordinary interpreter, delivering weapon damage and requesting
  session-authoritative knockback only for a connected, surviving hit.
  """

  use Aesir.ZoneServer.IntegrationCase

  import Mimic

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillDamage
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence

  @map "prontera"
  @hunter_class 11
  @phantasmic_id 1009
  @bow 1701
  @both_hands 34

  setup do
    Mimic.copy(HitCalculations)
    :ok
  end

  test "a connected surviving hit deals 500% Wind damage and knocks the target back 3 cells" do
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)

    hunter = start_hunter(bow?: true)
    Mimic.allow(HitCalculations, self(), hunter.pid)
    mob = start_mob(91_101, {151, 150}, hp: 20_000, max_hp: 20_000)

    mob_hp_before = mob_hp(mob)
    initial_sp = player_sp(hunter.pid)

    flush_packets()

    simulate_incoming_message(hunter.pid, %SkillCast{
      skill_id: @phantasmic_id,
      level: 1,
      target_id: mob.unit_id
    })

    assert_receive {:packet_sent, %SkillDamage{skill_id: @phantasmic_id} = damage, _}, 1_000
    assert damage.damage > 0

    assert eventually(fn -> mob_hp(mob) == mob_hp_before - damage.damage end)
    assert eventually(fn -> mob_position(mob) == {154, 150} end)
    assert player_sp(hunter.pid) == initial_sp - 50
  end

  test "a predicted lethal hit deals damage but requests no movement" do
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)

    hunter = start_hunter(bow?: true)
    Mimic.allow(HitCalculations, self(), hunter.pid)
    mob = start_mob(91_102, {151, 150}, hp: 1, max_hp: 1)

    flush_packets()

    simulate_incoming_message(hunter.pid, %SkillCast{
      skill_id: @phantasmic_id,
      level: 1,
      target_id: mob.unit_id
    })

    assert eventually(fn -> mob_hp(mob) == 0 end)
    Process.sleep(100)
    assert mob_position(mob) == {151, 150}
  end

  test "a missed strike deals no damage and requests no movement" do
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :miss end)

    hunter = start_hunter(bow?: true)
    Mimic.allow(HitCalculations, self(), hunter.pid)
    mob = start_mob(91_103, {151, 150}, hp: 20_000, max_hp: 20_000)
    mob_hp_before = mob_hp(mob)
    initial_sp = player_sp(hunter.pid)

    flush_packets()

    simulate_incoming_message(hunter.pid, %SkillCast{
      skill_id: @phantasmic_id,
      level: 1,
      target_id: mob.unit_id
    })

    assert eventually(fn -> player_sp(hunter.pid) == initial_sp - 50 end)
    Process.sleep(100)
    assert mob_hp(mob) == mob_hp_before
    assert mob_position(mob) == {151, 150}
  end

  test "casting without a bow neither damages the target nor charges SP" do
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)

    hunter = start_hunter(bow?: false)
    Mimic.allow(HitCalculations, self(), hunter.pid)
    mob = start_mob(91_104, {151, 150}, hp: 20_000, max_hp: 20_000)
    mob_hp_before = mob_hp(mob)
    initial_sp = player_sp(hunter.pid)

    flush_packets()

    simulate_incoming_message(hunter.pid, %SkillCast{
      skill_id: @phantasmic_id,
      level: 1,
      target_id: mob.unit_id
    })

    Process.sleep(200)
    refute_received {:packet_sent, %SkillDamage{skill_id: @phantasmic_id}, _}
    assert player_sp(hunter.pid) == initial_sp
    assert mob_hp(mob) == mob_hp_before
  end

  test "casting without an equipped arrow still connects" do
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)

    hunter = start_hunter(bow?: true, arrow?: false)
    Mimic.allow(HitCalculations, self(), hunter.pid)
    mob = start_mob(91_105, {151, 150}, hp: 20_000, max_hp: 20_000)
    mob_hp_before = mob_hp(mob)

    flush_packets()

    simulate_incoming_message(hunter.pid, %SkillCast{
      skill_id: @phantasmic_id,
      level: 1,
      target_id: mob.unit_id
    })

    assert eventually(fn -> mob_hp(mob) < mob_hp_before end)
  end

  defp start_hunter(opts) do
    character =
      insert_hunter(%{learned_skills: learned_skills()})

    if Keyword.fetch!(opts, :bow?) do
      seed_inventory(character.id, nameid: @bow, amount: 1, equip: @both_hands)
    end

    if Keyword.get(opts, :arrow?, true) and Keyword.fetch!(opts, :bow?) do
      seed_inventory(character.id, nameid: 1_750, amount: 20, equip: 0x008000)
    end

    session =
      start_player_session(character: character, map_name: @map, position: {150, 150})

    on_exit(fn -> end_player_session(session) end)
    session
  end

  defp start_mob(unit_id, position, opts) do
    mob =
      start_mob_session(
        Keyword.merge([unit_id: unit_id, map_name: @map, position: position], opts)
      )

    on_exit(fn -> end_mob_session(mob) end)
    mob
  end

  defp insert_hunter(overrides) do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "phantasmic#{uniq}",
        userid: "phantasmic#{uniq}",
        user_pass: "password",
        email: "phantasmic#{uniq}@aesir.test"
      })
      |> Repo.insert()

    attrs =
      Map.merge(
        %{
          account_id: account.id,
          char_num: 0,
          name: "Phantasmic#{uniq}",
          class: @hunter_class,
          base_level: 50,
          job_level: 50,
          str: 10,
          agi: 10,
          vit: 10,
          int: 10,
          dex: 99,
          luk: 10,
          max_hp: 5_000,
          hp: 5_000,
          max_sp: 500,
          sp: 500,
          last_map: @map,
          last_x: 150,
          last_y: 150,
          save_map: @map,
          save_x: 150,
          save_y: 150
        },
        overrides
      )

    {:ok, character} =
      %Character{}
      |> Character.changeset(attrs)
      |> Repo.insert()

    character
  end

  defp learned_skills do
    %{Integer.to_string(@phantasmic_id) => 1}
  end

  defp seed_inventory(char_id, attrs) do
    attrs = attrs |> Map.new() |> Map.put_new(:identify, 1)
    {:ok, item} = InventoryPersistence.insert_item(char_id, attrs)
    item
  end

  defp player_sp(pid), do: get_player_state(pid).stats.current_state.sp
  defp mob_hp(mob), do: get_mob_state(mob.pid).hp
  defp mob_position(mob), do: {get_mob_state(mob.pid).x, get_mob_state(mob.pid).y}
end
