defmodule Aesir.ZoneServer.Integration.RogueGraffitiIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.GroundSkill
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.SkillTextInputReply
  alias Aesir.Net.SkillTextInputRequest
  alias Aesir.Net.SkillUnitSpawn
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.View
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  test "Scribble captures text before publishing and rejects a second pending placement" do
    first = start_caster(98_600)
    second = start_caster(98_601)

    first_request = stage(first, {151, 150})
    second_request = stage(second, {149, 150})

    simulate_incoming_message(first.pid, %SkillTextInputReply{
      request_id: first_request,
      outcome: {:raw_text, <<255, 1, 0, 2>>}
    })

    assert_receive {:packet_sent, %SkillUnitSpawn{group: %{skill_id: 220, message: <<255, 1>>}},
                    _},
                   1_000

    assert eventually(fn ->
             Enum.any?(Storage.all(), &(&1.skill_name == :rg_graffiti))
           end)

    [group] = Enum.filter(Storage.all(), &(&1.skill_name == :rg_graffiti))
    assert %{groups: [%{message: <<255, 1>>}]} = View.snapshot([{group, []}], 0)
    assert PlayerSession.get_state(first.pid).game_state.stats.current_state.sp == 35

    assert Inventory.held_amount(PlayerSession.get_state(first.pid).game_state.inventory, 716) ==
             0

    simulate_incoming_message(second.pid, %SkillTextInputReply{
      request_id: second_request,
      outcome: {:text, "Second"}
    })

    assert eventually(fn ->
             is_nil(PlayerSession.get_state(second.pid).pending_skill_text_input)
           end)

    assert PlayerSession.get_state(second.pid).game_state.stats.current_state.sp == 50

    assert Inventory.held_amount(PlayerSession.get_state(second.pid).game_state.inventory, 716) ==
             1

    group_id = group.group_id

    assert [%{group_id: ^group_id}] =
             Enum.filter(Storage.all(), &(&1.skill_name == :rg_graffiti))
  end

  test "a non-interactive Scribble reuses the player's saved byte buffer" do
    caster = start_caster(98_603)
    game_state = %{PlayerSession.get_state(caster.pid).game_state | skill_message: <<255, 1>>}

    assert {:ok, _caster} = Interpreter.cast(game_state, 220, 1, {:ground, 151, 150})

    assert [%{state: %{message: <<255, 1>>}}] =
             Enum.filter(Storage.all(), &(&1.skill_name == :rg_graffiti))
  end

  test "Piece spends SP and broadcasts its cast without placing a unit" do
    caster = start_caster(98_602)

    simulate_incoming_message(caster.pid, %GroundSkillCast{
      skill_id: 221,
      level: 1,
      x: 150,
      y: 150
    })

    assert_receive {:packet_sent, %GroundSkill{skill_id: 221, x: 150, y: 150}, _}, 1_000

    assert eventually(fn ->
             PlayerSession.get_state(caster.pid).game_state.stats.current_state.sp == 40
           end)

    refute Enum.any?(Storage.all(), &(&1.skill_name == :rg_flaggraffiti))
  end

  defp start_caster(id) do
    account =
      %Account{}
      |> Account.changeset(%{
        userid: "rogue#{id}",
        user_pass: "password",
        email: "rogue#{id}@aesir.test"
      })
      |> Repo.insert!()

    character =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Rogue#{id}",
        class: 17,
        base_level: 50,
        sp: 50,
        max_sp: 50,
        last_map: "prontera",
        last_x: 150,
        last_y: 150,
        save_map: "prontera",
        save_x: 150,
        save_y: 150,
        learned_skills: %{"220" => 1, "221" => 1}
      })
      |> Repo.insert!()

    %InventoryItem{}
    |> InventoryItem.changeset(%{char_id: character.id, nameid: 716, amount: 1, identify: 1})
    |> Repo.insert!()

    start_player_session(character: character, position: {150, 150})
  end

  defp stage(caster, {x, y}) do
    simulate_incoming_message(caster.pid, %GroundSkillCast{skill_id: 220, level: 1, x: x, y: y})

    assert_receive {:packet_sent, %SkillTextInputRequest{request_id: request_id, skill_id: 220},
                    _},
                   1_000

    request_id
  end
end
