defmodule Aesir.ZoneServer.Integration.SkillTextInputIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.MoveStop
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillTextInputReply
  alias Aesir.Net.SkillTextInputRequest
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler

  @skill_id 9_001
  @capability :FEATURE_CAPABILITY_SKILL_TEXT_INPUT

  defmodule InputFixtureSkill do
    def __skill_capabilities__, do: [:active, :ground]

    def cast(_game_state, _target, _level, _definition),
      do: {:error, :skill_input_required}

    def cast_with_input(game_state, _target, _level, _definition, input) do
      {:ok, %{game_state | temp_vars: Map.put(game_state.temp_vars, :fixture_input, input)}}
    end

    def validate(_game_state, _target, _level, _definition), do: :ok
  end

  setup :verify_on_exit!

  test "a real session stages, correlates, and commits the fixture input skill" do
    character = insert_character()

    {:ok, session_pid} =
      PlayerSession.start_link(%{
        character: character,
        connection_pid: self(),
        client_capabilities: [@capability]
      })

    session = %{pid: session_pid, character: character}
    on_exit(fn -> end_player_session(session) end)

    definition = %Definition{
      id: @skill_id,
      name: :fixture_input,
      display_name: "Fixture Input",
      max_level: 1,
      target_type: :ground,
      range: 3,
      sp_cost: [1]
    }

    stub(Catalog, :by_id, fn @skill_id -> {:ok, definition} end)
    stub(Catalog, :active_module_for, fn :fixture_input -> {:ok, InputFixtureSkill} end)
    stub(Catalog, :ground_module_for, fn :fixture_input -> {:ok, InputFixtureSkill} end)
    Mimic.allow(Catalog, self(), session.pid)

    flush_packets()
    session_state = PlayerSession.get_state(session.pid)
    assert session_state.client_capabilities == [@capability]
    initial_state = session_state.game_state
    initial_sp = initial_state.stats.current_state.sp

    moving_state = %{
      initial_state
      | action_state: :moving,
        movement_state: :moving,
        walk_path: [{151, 150}]
    }

    :sys.replace_state(session.pid, &%{&1 | game_state: moving_state})
    moving_session = PlayerSession.get_state(session.pid)

    assert {:ok, ^moving_session} = SkillHandler.cast_gate(moving_session, @skill_id)

    assert :ok =
             Interpreter.preflight_cast(moving_state, @skill_id, 1, {:ground, 151, 150})

    simulate_incoming_message(session.pid, %GroundSkillCast{
      skill_id: @skill_id,
      level: 1,
      x: 151,
      y: 150
    })

    assert_receive {:send, :world,
                    {:skill_text_input_request,
                     %SkillTextInputRequest{
                       request_id: request_id,
                       skill_id: @skill_id,
                       max_utf8_bytes: 79
                     }}},
                   1_000

    staged = PlayerSession.get_state(session.pid)
    assert staged.pending_skill_text_input.request_id == request_id
    assert staged.game_state == moving_state
    refute_receive {:send, _channel, {_tag, %MoveStop{}}}

    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: 147,
      level: 1,
      target_id: character.id
    })

    assert eventually(fn ->
             rejected = PlayerSession.get_state(session.pid)

             rejected.pending_skill_text_input.request_id == request_id and
               rejected.game_state.stats.current_state.sp == initial_sp and
               rejected.interaction_lock == nil
           end)

    refute_receive {:send, _channel, {:npc_dialog, _dialog}}

    simulate_incoming_message(session.pid, %SkillTextInputReply{
      request_id: request_id + 1,
      outcome: {:cancel, true}
    })

    assert eventually(fn ->
             PlayerSession.get_state(session.pid).pending_skill_text_input.request_id ==
               request_id
           end)

    simulate_incoming_message(session.pid, %SkillTextInputReply{
      request_id: request_id,
      outcome: {:text, "fixture text"}
    })

    assert_receive {:send, _channel, {_tag, %MoveStop{}}}, 1_000

    assert eventually(fn ->
             state = PlayerSession.get_state(session.pid)

             state.pending_skill_text_input == nil and
               state.game_state.action_state == :idle and
               state.game_state.movement_state == :standing and
               state.game_state.walk_path == [] and
               state.game_state.temp_vars[:fixture_input] == "fixture text" and
               state.game_state.stats.current_state.sp == initial_sp - 1
           end)
  end

  defp insert_character do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "skilltext",
        userid: "skilltext",
        user_pass: "password",
        email: "skilltext@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "SkillText",
        class: 11,
        base_level: 50,
        job_level: 50,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10,
        max_hp: 500,
        hp: 500,
        max_sp: 100,
        sp: 100,
        learned_skills: %{Integer.to_string(@skill_id) => 1},
        last_map: "prontera",
        last_x: 150,
        last_y: 150,
        save_map: "prontera",
        save_x: 150,
        save_y: 150
      })
      |> Repo.insert()

    character
  end

  defp eventually(fun, attempts \\ 40) do
    cond do
      fun.() -> true
      attempts <= 0 -> false
      true -> Process.sleep(25) && eventually(fun, attempts - 1)
    end
  end
end
