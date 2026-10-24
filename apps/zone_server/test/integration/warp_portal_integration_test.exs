defmodule Aesir.ZoneServer.Integration.WarpPortalIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ChatMessage
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.MapMove
  alias Aesir.Net.MemoRequest
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.SkillMenu
  alias Aesir.Net.SkillMenuReply
  alias Aesir.Net.SkillUnitSpawn
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage

  test "memo persistence, menu settlement and portal arrival run through their owning sessions" do
    suffix = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "portal#{suffix}",
        user_pass: "password",
        email: "portal#{suffix}@aesir.test"
      })
      |> Repo.insert!()

    character =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Portal#{suffix}",
        class: 4,
        base_level: 60,
        job_level: 50,
        int: 50,
        hp: 500,
        max_hp: 500,
        sp: 400,
        max_sp: 500,
        last_map: "prontera",
        last_x: 150,
        last_y: 150,
        save_map: "izlude",
        save_x: 40,
        save_y: 50,
        learned_skills: %{"27" => 4}
      })
      |> Repo.insert!()

    gemstone =
      %InventoryItem{}
      |> InventoryItem.changeset(%{char_id: character.id, nameid: 717, amount: 1, identify: 1})
      |> Repo.insert!()

    player =
      start_player_session(character: character, map_name: "prontera", position: {150, 150})

    on_exit(fn -> end_player_session(player) end)
    flush_packets()
    sp = get_player_state(player.pid).stats.current_state.sp

    simulate_incoming_message(player.pid, %MemoRequest{})

    assert_receive {:packet_sent,
                    %ChatMessage{message: "Saved location as a Memo Point for Warp skill."}, _},
                   1000

    assert Repo.get!(Character, character.id).memo_points == [
             %{"map" => "prontera", "x" => 150, "y" => 150}
           ]

    simulate_incoming_message(player.pid, %GroundSkillCast{skill_id: 27, level: 2, x: 151, y: 150})

    assert_receive {:packet_sent,
                    %SkillMenu{
                      src_skill_id: 27,
                      kind: :OPTIONS,
                      entry_ids: [0, 1],
                      labels: ["izlude", "prontera"]
                    }, _},
                   2000

    assert get_player_state(player.pid).stats.current_state.sp == sp - 32
    assert Repo.get!(InventoryItem, gemstone.id).amount == 1

    simulate_incoming_message(player.pid, %MoveRequest{dest_x: 149, dest_y: 150})

    assert_eventually(fn ->
      state = get_player_state(player.pid)
      {state.x, state.y} == {149, 150}
    end)

    simulate_incoming_message(player.pid, %SkillMenuReply{src_skill_id: 27, selected_id: 1})

    assert_receive {:packet_sent,
                    %SkillUnitSpawn{
                      group: %{group_id: group_id, phase: :SKILL_UNIT_PHASE_OPENING}
                    }, _},
                   1000

    assert Repo.get(InventoryItem, gemstone.id) == nil
    assert get_player_state(player.pid).stats.current_state.sp == sp - 32

    assert_receive {:packet_sent,
                    %SkillUnitSpawn{
                      group: %{group_id: ^group_id, phase: :SKILL_UNIT_PHASE_ACTIVE}
                    }, _},
                   3000

    simulate_incoming_message(player.pid, %MoveRequest{dest_x: 151, dest_y: 150})
    assert_receive {:packet_sent, %MapMove{map_name: "prontera", x: 150, y: 150}, _}, 1000
    assert_eventually(fn -> Storage.get(group_id).state.uses == 9 end)

    assert get_player_state(player.pid).memo_points ==
             Repo.get!(Character, character.id).memo_points
  end
end
