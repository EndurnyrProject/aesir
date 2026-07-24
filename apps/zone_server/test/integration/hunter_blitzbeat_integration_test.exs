defmodule Aesir.ZoneServer.Integration.HunterBlitzbeatIntegrationTest do
  @moduledoc """
  Real-session coverage for manual and automatic Blitz Beat. Manual delivery
  traverses the ordinary timed skill interpreter; automatic delivery starts at
  a confirmed ordinary bow hit, queues through the generic deferred-skill
  message, and reaches the same captured-center BF_MISC splash path.
  """

  use Aesir.ZoneServer.IntegrationCase

  import Mimic

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ActionRequest
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillDamage
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtBlitzbeat
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence

  @map "prontera"
  @hunter_class 11
  @falcon_bit Option.id(:falcon)
  @vulture_id 44
  @falcon_id 127
  @steel_crow_id 128
  @blitz_id 129
  @bow 1701
  @arrow 1750
  @both_hands 34
  @ammo 0x008000

  setup do
    Mimic.copy(HitCalculations)
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)

    Mimic.copy(HtBlitzbeat)

    stub(HtBlitzbeat, :after_normal_hit, fn player_state, hit ->
      HtBlitzbeat.after_normal_hit(player_state, hit, rng: fn 1_000 -> 0 end)
    end)

    :ok
  end

  test "manual cast charges SP after its real cast time and splashes with level divisions" do
    hunter = start_hunter(job_level: 50, bow?: false)
    primary = start_mob(91_001, {158, 150})
    secondary = start_mob(91_002, {157, 150})
    outside = start_mob(91_003, {156, 150})

    primary_hp = mob_hp(primary)
    secondary_hp = mob_hp(secondary)
    outside_hp = mob_hp(outside)
    initial_sp = player_sp(hunter.pid)

    flush_packets()

    simulate_incoming_message(hunter.pid, %SkillCast{
      skill_id: @blitz_id,
      level: 5,
      target_id: primary.unit_id
    })

    assert eventually(fn -> get_player_state(hunter.pid).action_state == :casting end)
    assert player_sp(hunter.pid) == initial_sp

    assert eventually(fn -> mob_hp(primary) < primary_hp and mob_hp(secondary) < secondary_hp end)
    assert player_sp(hunter.pid) == initial_sp - 22
    assert mob_hp(outside) == outside_hp

    assert_receive {:packet_sent, %SkillDamage{skill_id: @blitz_id, target_id: target_id, div: 5},
                    _},
                   1_000

    assert target_id in [primary.unit_id, secondary.unit_id]

    assert_receive {:packet_sent,
                    %SkillDamage{skill_id: @blitz_id, target_id: other_target_id, div: 5}, _},
                   1_000

    assert other_target_id in [primary.unit_id, secondary.unit_id]
    assert other_target_id != target_id
  end

  test "confirmed bow hit auto-procs at the Hunter cap without SP, cast, cooldown, or recursion" do
    hunter = start_hunter(job_level: 11, bow?: true)
    primary = start_mob(91_011, {151, 150}, hp: 1, max_hp: 1)
    secondary = start_mob(91_012, {152, 150})

    secondary_hp = mob_hp(secondary)
    initial_sp = player_sp(hunter.pid)

    flush_packets()
    simulate_incoming_message(hunter.pid, %ActionRequest{target_id: primary.unit_id, action: 0})

    assert eventually(fn -> mob_hp(primary) == 0 end)
    assert eventually(fn -> mob_hp(secondary) < secondary_hp end)

    state = get_player_state(hunter.pid)
    assert state.stats.current_state.sp == initial_sp
    assert state.casting == nil
    refute Map.has_key?(state.skill_cooldowns, @blitz_id)

    packets = collect_packets_of_type(SkillDamage, 300)

    assert Enum.any?(packets, &(&1.skill_id == @blitz_id and &1.target_id == secondary.unit_id))
    assert Enum.all?(packets, &(&1.skill_id == @blitz_id and &1.div == 2))

    target_ids = Enum.map(packets, & &1.target_id)
    assert target_ids == Enum.uniq(target_ids)
    assert Enum.all?(target_ids, &(&1 in [primary.unit_id, secondary.unit_id]))
  end

  defp start_hunter(opts) do
    character =
      insert_hunter(%{
        job_level: Keyword.fetch!(opts, :job_level),
        learned_skills: learned_skills(),
        option: @falcon_bit
      })

    if Keyword.fetch!(opts, :bow?) do
      seed_inventory(character.id, nameid: @bow, amount: 1, equip: @both_hands)
      seed_inventory(character.id, nameid: @arrow, amount: 20, equip: @ammo)
    end

    session =
      start_player_session(character: character, map_name: @map, position: {150, 150})

    Mimic.allow(HtBlitzbeat, self(), session.pid)
    on_exit(fn -> end_player_session(session) end)
    session
  end

  defp start_mob(unit_id, position, opts \\ []) do
    mob =
      start_mob_session(
        Keyword.merge(
          [unit_id: unit_id, map_name: @map, position: position, hp: 20_000, max_hp: 20_000],
          opts
        )
      )

    on_exit(fn -> end_mob_session(mob) end)
    mob
  end

  defp insert_hunter(overrides) do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "blitz#{uniq}",
        userid: "blitz#{uniq}",
        user_pass: "password",
        email: "blitz#{uniq}@aesir.test"
      })
      |> Repo.insert()

    attrs =
      Map.merge(
        %{
          account_id: account.id,
          char_num: 0,
          name: "Blitz#{uniq}",
          class: @hunter_class,
          base_level: 50,
          job_level: 50,
          str: 10,
          agi: 99,
          vit: 10,
          int: 10,
          dex: 99,
          luk: 3,
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
    %{
      Integer.to_string(@vulture_id) => 3,
      Integer.to_string(@falcon_id) => 1,
      Integer.to_string(@steel_crow_id) => 10,
      Integer.to_string(@blitz_id) => 5
    }
  end

  defp seed_inventory(char_id, attrs) do
    attrs = attrs |> Map.new() |> Map.put_new(:identify, 1)
    {:ok, item} = InventoryPersistence.insert_item(char_id, attrs)
    item
  end

  defp player_sp(pid), do: get_player_state(pid).stats.current_state.sp
  defp mob_hp(mob), do: get_mob_state(mob.pid).hp

  defp eventually(fun, attempts \\ 80) do
    cond do
      fun.() -> true
      attempts <= 0 -> false
      true -> Process.sleep(50) && eventually(fun, attempts - 1)
    end
  end
end
