defmodule Aesir.ZoneServer.Integration.HunterPlatinumPhantasmicIntegrationTest do
  @moduledoc """
  End-to-end platinum grant: the generated `F_GetPlatinumSkills` function runs
  against a real Hunter `PlayerSession`, permanently granting the Archer and
  Hunter quest skills without spending points, and the same session then casts
  the granted Phantasmic Arrow through the ordinary interpreter path.
  """

  use Aesir.ZoneServer.IntegrationCase

  import Mimic

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillDamage
  alias Aesir.Repo
  alias Aesir.ZoneServer.Content.Npc.Functions.FGetplatinumskills
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence

  @map "prontera"
  @hunter_class 11
  @first_aid_id 142
  @making_arrow_id 147
  @charge_arrow_id 148
  @phantasmic_id 1009
  @bow 1701
  @both_hands 34

  setup do
    Mimic.copy(HitCalculations)
    :ok
  end

  test "the generated function grants through a real session and the granted skill casts" do
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)

    hunter = start_hunter()
    Mimic.allow(HitCalculations, self(), hunter.pid)
    mob = start_mob(92_101, {151, 150}, hp: 20_000, max_hp: 20_000)

    initial_points = skill_points(hunter.pid)
    refute Map.has_key?(learned(hunter.pid), @phantasmic_id)

    assert {%Ctx{status: :ok} = ctx, nil} = FGetplatinumskills.call(platinum_ctx(hunter), [])

    granted = learned(hunter.pid)
    assert granted[@first_aid_id] == 1
    assert granted[@making_arrow_id] == 1
    assert granted[@charge_arrow_id] == 1
    assert granted[@phantasmic_id] == 1
    refute Map.has_key?(granted, 144)
    assert skill_points(hunter.pid) == initial_points

    assert {%Ctx{status: :ok}, nil} =
             FGetplatinumskills.call(%{ctx | game_state: get_player_state(hunter.pid)}, [])

    assert learned(hunter.pid) == granted

    mob_hp_before = mob_hp(mob)
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
  end

  defp platinum_ctx(hunter) do
    game_state = get_player_state(hunter.pid)

    %Ctx{
      char_id: game_state.character_id,
      account_id: game_state.account_id,
      connection_pid: self(),
      game_state: game_state,
      source: {:npc, 0},
      session_pid: hunter.pid
    }
  end

  defp start_hunter do
    character = insert_hunter()
    seed_inventory(character.id, nameid: @bow, amount: 1, equip: @both_hands)

    session = start_player_session(character: character, map_name: @map, position: {150, 150})
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

  defp insert_hunter do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "platinum#{uniq}",
        userid: "platinum#{uniq}",
        user_pass: "password",
        email: "platinum#{uniq}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Platinum#{uniq}",
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
      })
      |> Repo.insert()

    character
  end

  defp seed_inventory(char_id, attrs) do
    attrs = attrs |> Map.new() |> Map.put_new(:identify, 1)
    {:ok, item} = InventoryPersistence.insert_item(char_id, attrs)
    item
  end

  defp learned(pid), do: get_player_state(pid).stats.progression.learned_skills
  defp skill_points(pid), do: get_player_state(pid).stats.progression.skill_point
  defp mob_hp(mob), do: get_mob_state(mob.pid).hp
  defp mob_position(mob), do: {get_mob_state(mob.pid).x, get_mob_state(mob.pid).y}

  defp eventually(fun, attempts \\ 80) do
    cond do
      fun.() -> true
      attempts <= 0 -> false
      true -> Process.sleep(50) && eventually(fun, attempts - 1)
    end
  end
end
