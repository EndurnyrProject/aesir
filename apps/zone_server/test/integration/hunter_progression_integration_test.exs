defmodule Aesir.ZoneServer.Integration.HunterProgressionIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Bitwise

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.LearnSkill
  alias Aesir.Net.LearnSkillResult
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcTalk
  alias Aesir.Net.SkillList
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry

  @hunter_class 11
  @merchant_class 5
  @missing_prerequisite 4
  @max_level 3
  @falcon_bit Option.id(:falcon)
  @status_id :sc_falcon
  @job_change_position {210, 210}
  @skill_reset_position {211, 210}

  defmodule HunterToMerchantNpc do
    @moduledoc false
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 210, y: 210, dir: 0, sprite: 58, name: "Merchant Master"}]

    @impl true
    def on_talk(ctx), do: ctx |> jobchange(5) |> mes("Done") |> close()
  end

  defmodule HunterSkillResetNpc do
    @moduledoc false
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 211, y: 210, dir: 0, sprite: 58, name: "Skill Reset"}]

    @impl true
    def on_talk(ctx), do: ctx |> reset_skills() |> mes("Skills reset") |> close()
  end

  setup do
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    NpcRegistry.reload([HunterToMerchantNpc, HunterSkillResetNpc])
    :ok
  end

  test "the real learning handler enforces Hunter prerequisites, inherited Archer access, and limits" do
    falcon = catalog_id(:ht_falcon)
    land_mine = catalog_id(:ht_landmine)

    character = insert_hunter(%{skill_point: 30})

    session =
      start_player_session(character: character, map_name: "prontera", position: {150, 150})

    on_exit(fn -> end_player_session(session) end)
    flush_packets()

    simulate_incoming_message(session.pid, %LearnSkill{skill_id: falcon})

    assert_receive {:packet_sent,
                    %LearnSkillResult{
                      skill_id: ^falcon,
                      ok: false,
                      reason: @missing_prerequisite
                    }, _},
                   1_000

    for _ <- 1..3, do: learn(session.pid, catalog_id(:ac_owl))
    learn(session.pid, catalog_id(:ac_vulture))
    learn(session.pid, catalog_id(:ac_concentration))
    for _ <- 1..5, do: learn(session.pid, land_mine)
    learn(session.pid, catalog_id(:ht_beastbane))
    learn(session.pid, falcon)
    for _ <- 1..5, do: learn(session.pid, catalog_id(:ht_blitzbeat))
    learn(session.pid, catalog_id(:ht_steelcrow))
    learn(session.pid, catalog_id(:ht_detecting))
    learn(session.pid, catalog_id(:ht_removetrap))
    learn(session.pid, catalog_id(:ht_springtrap))

    simulate_incoming_message(session.pid, %LearnSkill{skill_id: land_mine})

    assert_receive {:packet_sent,
                    %LearnSkillResult{skill_id: ^land_mine, ok: false, reason: @max_level}, _},
                   1_000

    progression = get_player_state(session.pid).stats.progression

    assert progression.learned_skills == %{
             catalog_id(:ac_owl) => 3,
             catalog_id(:ac_vulture) => 1,
             catalog_id(:ac_concentration) => 1,
             land_mine => 5,
             catalog_id(:ht_beastbane) => 1,
             falcon => 1,
             catalog_id(:ht_blitzbeat) => 5,
             catalog_id(:ht_steelcrow) => 1,
             catalog_id(:ht_detecting) => 1,
             catalog_id(:ht_removetrap) => 1,
             catalog_id(:ht_springtrap) => 1
           }
  end

  test "skill reset drops Falconry and clears the Falcon option, status, and persistence" do
    {x, y} = @skill_reset_position

    character =
      insert_hunter(%{
        option: @falcon_bit,
        learned_skills: falcon_learned_skills(),
        last_x: x,
        last_y: y,
        save_x: x,
        save_y: y
      })

    session = start_player_session(character: character, map_name: "prontera", position: {x, y})
    on_exit(fn -> end_player_session(session) end)

    assert band(get_player_state(session.pid).option, @falcon_bit) != 0
    assert StatusStorage.has_status?(:player, character.id, @status_id)
    flush_packets()

    gid = NpcRegistry.entity_id(%Placement{map: "prontera", x: x, y: y, sprite: 58})
    simulate_incoming_message(session.pid, %NpcTalk{npc_id: gid})

    assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE}, _}, 1_000
    assert_receive {:packet_sent, %SkillList{}, _}, 1_000

    reset = get_player_state(session.pid)

    assert band(reset.option, @falcon_bit) == 0
    refute Map.has_key?(reset.stats.progression.learned_skills, catalog_id(:ht_falcon))
    refute StatusStorage.has_status?(:player, character.id, @status_id)

    persisted = Repo.get(Character, character.id)
    assert band(persisted.option, @falcon_bit) == 0
    refute Map.has_key?(persisted.learned_skills, Integer.to_string(catalog_id(:ht_falcon)))
  end

  test "job change drops Falconry and clears the Falcon option, status, and persistence" do
    {x, y} = @job_change_position

    character =
      insert_hunter(%{
        option: @falcon_bit,
        learned_skills: falcon_learned_skills(),
        last_x: x,
        last_y: y,
        save_x: x,
        save_y: y
      })

    session = start_player_session(character: character, map_name: "prontera", position: {x, y})
    on_exit(fn -> end_player_session(session) end)

    assert band(get_player_state(session.pid).option, @falcon_bit) != 0
    assert StatusStorage.has_status?(:player, character.id, @status_id)
    flush_packets()

    gid = NpcRegistry.entity_id(%Placement{map: "prontera", x: x, y: y, sprite: 58})
    simulate_incoming_message(session.pid, %NpcTalk{npc_id: gid})

    assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE}, _}, 1_000
    assert_receive {:packet_sent, %SkillList{}, _}, 1_000

    changed = get_player_state(session.pid)

    assert changed.stats.progression.job_id == @merchant_class
    assert band(changed.option, @falcon_bit) == 0
    refute Map.has_key?(changed.stats.progression.learned_skills, catalog_id(:ht_falcon))
    refute StatusStorage.has_status?(:player, character.id, @status_id)

    persisted = Repo.get(Character, character.id)
    assert band(persisted.option, @falcon_bit) == 0
    refute Map.has_key?(persisted.learned_skills, Integer.to_string(catalog_id(:ht_falcon)))
  end

  defp learn(player_pid, skill_id) do
    simulate_incoming_message(player_pid, %LearnSkill{skill_id: skill_id})
    assert_receive {:packet_sent, %SkillList{}, _}, 1_000
  end

  defp insert_hunter(overrides) do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "hunterprogression#{uniq}",
        userid: "hunterprogression#{uniq}",
        user_pass: "password",
        email: "hunterprogression#{uniq}@aesir.test"
      })
      |> Repo.insert()

    attrs =
      Map.merge(
        %{
          account_id: account.id,
          char_num: 0,
          name: "Hunter#{uniq}",
          class: @hunter_class,
          base_level: 50,
          job_level: 50,
          str: 10,
          agi: 10,
          vit: 10,
          int: 10,
          dex: 10,
          luk: 10,
          last_map: "prontera",
          last_x: 150,
          last_y: 150,
          save_map: "prontera",
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

  defp falcon_learned_skills do
    %{
      Integer.to_string(catalog_id(:ht_beastbane)) => 1,
      Integer.to_string(catalog_id(:ht_falcon)) => 1
    }
  end

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end
end
