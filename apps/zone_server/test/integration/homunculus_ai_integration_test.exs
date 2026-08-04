defmodule Aesir.ZoneServer.Integration.HomunculusAiIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus

  alias Aesir.Net.ActionRequest
  alias Aesir.Net.DamageDealt
  alias Aesir.Net.HomunculusCastSkillCommand
  alias Aesir.Net.HomunculusInspectCommand
  alias Aesir.Net.HomunculusPrivateState
  alias Aesir.Net.HomunculusReplaceAiCommand
  alias Aesir.Net.HomunculusRequest
  alias Aesir.Net.HomunculusResult

  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @map "hom_ai_e2e"

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 100, 100)})
    :ok
  end

  test "natural 500ms ticks keep passive idle, assist the owner's target, and acquire aggressively" do
    passive = owner_session()
    passive_hom = PlayerSession.get_state(passive.pid).homunculus
    passive_mob = dormant_mob(passive_hom)
    replace_stance(passive.pid, 1, :HOMUNCULUS_AI_STANCE_PASSIVE)
    flush_packets()
    Process.sleep(650)
    assert MobSession.get_state(passive_mob.pid).hp == 10_000
    assert PlayerSession.get_state(passive.pid).homunculus.target == nil
    passive_gid = passive_hom.world_gid
    refute_receive {:packet_sent, %DamageDealt{src_id: ^passive_gid}, _}, 50

    assist = owner_session()
    assist_hom = PlayerSession.get_state(assist.pid).homunculus
    assist_mob = dormant_mob(assist_hom)
    replace_stance(assist.pid, 2, :HOMUNCULUS_AI_STANCE_ASSIST)
    flush_packets()

    simulate_incoming_message(assist.pid, %ActionRequest{target_id: assist_mob.unit_id, action: 7})

    assist_src = assist_hom.world_gid
    assist_target = assist_mob.unit_id

    assert_receive {:packet_sent, %DamageDealt{src_id: ^assist_src, target_id: ^assist_target},
                    _},
                   2_000

    aggressive = owner_session()
    aggressive_hom = PlayerSession.get_state(aggressive.pid).homunculus
    aggressive_mob = dormant_mob(aggressive_hom)
    replace_stance(aggressive.pid, 3, :HOMUNCULUS_AI_STANCE_AGGRESSIVE)
    flush_packets()

    aggressive_src = aggressive_hom.world_gid

    assert_receive {:packet_sent,
                    %DamageDealt{src_id: ^aggressive_src, target_id: aggressive_target}, _},
                   2_000

    assert aggressive_target in [passive_mob.unit_id, assist_mob.unit_id, aggressive_mob.unit_id]
  end

  test "one natural aggressive tick executes at most one intent and one private publication" do
    owner = owner_session()
    hom = PlayerSession.get_state(owner.pid).homunculus
    first = dormant_mob(hom, 1)
    second = dormant_mob(hom, 2)
    replace_stance(owner.pid, 10, :HOMUNCULUS_AI_STANCE_AGGRESSIVE)
    flush_packets()

    assert_receive {:packet_sent, %DamageDealt{src_id: src, target_id: target}, _}, 1_000
    assert src == hom.world_gid
    assert target in [first.unit_id, second.unit_id]
    assert_receive {:packet_sent, %HomunculusPrivateState{world_gid: ^src}, _}, 500
    refute_receive {:packet_sent, %HomunculusPrivateState{world_gid: ^src}, _}, 200
    refute_receive {:packet_sent, %DamageDealt{src_id: ^src}, _}, 200
  end

  test "a Homunculus cooldown established by a command survives reconnect without a full reset" do
    owner = owner_session()

    request(owner.pid, 20, {
      :cast_skill,
      %HomunculusCastSkillCommand{skill_id: 8_002, level: 1, target: {:self, true}}
    })

    state = assert_result(20)
    cooldown = Enum.find(state.cooldowns, &(&1.skill_id == 8_002)).remaining_ms
    assert cooldown > 0

    :ok = PlayerSession.disconnect(owner.pid)
    reloaded = start(owner.character |> Repo.reload!() |> Repo.preload(:homunculus))
    restored = inspect_state(reloaded.pid, 21)
    remaining = Enum.find(restored.cooldowns, &(&1.skill_id == 8_002)).remaining_ms
    assert remaining > 0
    assert remaining <= cooldown
  end

  defp replace_stance(pid, request_id, stance) do
    current = inspect_state(pid, request_id + 100)
    replacement = %{current.ai_config | stance: stance}
    request(pid, request_id, {:replace_ai, %HomunculusReplaceAiCommand{config: replacement}})
    replaced = assert_result(request_id)
    assert replaced.ai_config.stance == stance
    replaced
  end

  defp inspect_state(pid, request_id) do
    request(pid, request_id, {:inspect, %HomunculusInspectCommand{}})
    assert_result(request_id)
  end

  defp request(pid, request_id, command) do
    simulate_incoming_message(pid, %HomunculusRequest{request_id: request_id, command: command})
  end

  defp assert_result(request_id) do
    assert_receive {:packet_sent,
                    %HomunculusResult{request_id: ^request_id, success: true, state: state}, _},
                   1_000

    state
  end

  defp dormant_mob(homunculus, offset \\ 1) do
    start_mob_session(
      map_name: @map,
      position: {homunculus.x + offset, homunculus.y},
      hp: 10_000,
      max_hp: 10_000,
      awake: false
    )
  end

  defp owner_session do
    character = character_fixture()
    insert_homunculus(character.id)
    session = start(Repo.preload(character, :homunculus))
    Map.put(session, :character, character)
  end

  defp start(character) do
    session = start_player_session(character: character, map_name: @map, position: {50, 50})
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    flush_packets()
    session
  end

  defp character_fixture do
    suffix = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "homai#{suffix}",
        user_pass: "password",
        email: "homai#{suffix}@example.com"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: "HomAi#{suffix}",
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

  defp insert_homunculus(character_id) do
    %Homunculus{}
    |> Homunculus.changeset(%{
      character_id: character_id,
      class_id: 6_001,
      name: "Lif",
      lifecycle: "active",
      level: 50,
      hp: 2_000,
      max_hp: 2_000,
      sp: 500,
      max_sp: 500,
      str: 50,
      agi: 20,
      vit: 20,
      int: 20,
      dex: 200,
      luk: 20,
      active_remaining_ms: 1_800_000,
      learned_skills: %{"8001" => 3, "8002" => 1},
      ai_config: %{}
    })
    |> Repo.insert!()
  end
end
