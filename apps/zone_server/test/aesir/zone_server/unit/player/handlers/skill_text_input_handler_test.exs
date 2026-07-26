defmodule Aesir.ZoneServer.Unit.Player.Handlers.SkillTextInputHandlerTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.Net.SkillCastFailed
  alias Aesir.Net.SkillTextInputReply
  alias Aesir.Net.SkillTextInputRequest
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillTextInputHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState

  defmodule InputFixtureSkill do
    def cast_with_input(game_state, _target, _level, _definition, _input), do: {:ok, game_state}
    def validate(_game_state, _target, _level, _definition), do: :ok
  end

  setup :verify_on_exit!

  setup do
    stub(Catalog, :by_id, fn 9_001 -> {:ok, definition()} end)
    stub(Catalog, :active_module_for, fn :fixture_input -> {:ok, InputFixtureSkill} end)
    stub(Catalog, :ground_module_for, fn :fixture_input -> {:ok, InputFixtureSkill} end)
    stub(StatusInterpreter, :can_use_skill?, fn :player, 1000, 9_001 -> true end)
    :ok
  end

  test "stages one capable preflighted ground-skill text request" do
    expect(Interpreter, :preflight_cast, fn game_state, 9_001, 1, {:ground, 151, 150} ->
      assert game_state.character_id == 1000
      :ok
    end)

    assert {:noreply, staged} =
             SkillTextInputHandler.stage(state(), 9_001, 1, {:ground, 151, 150})

    assert %SessionState.PendingSkillTextInput{
             request_id: request_id,
             skill_id: 9_001,
             level: 1,
             target: {:ground, 151, 150},
             timer_ref: timer_ref
           } = staged.pending_skill_text_input

    assert request_id in 1..18_446_744_073_709_551_615
    assert is_reference(timer_ref)
    assert Process.read_timer(timer_ref) in 59_000..60_000

    assert_receive {:send, :world,
                    {:skill_text_input_request,
                     %SkillTextInputRequest{
                       request_id: ^request_id,
                       skill_id: 9_001,
                       max_utf8_bytes: 79
                     }}}
  end

  test "successive prompts receive distinct uint64 request IDs" do
    stub(Interpreter, :preflight_cast, fn _game_state, 9_001, 1, {:ground, 151, 150} -> :ok end)

    {:noreply, first} = SkillTextInputHandler.stage(state(), 9_001, 1, {:ground, 151, 150})
    first_id = first.pending_skill_text_input.request_id

    {:noreply, second} =
      first
      |> SkillTextInputHandler.clear()
      |> SkillTextInputHandler.stage(9_001, 1, {:ground, 151, 150})

    second_id = second.pending_skill_text_input.request_id
    assert first_id != second_id
    assert second_id in 1..18_446_744_073_709_551_615
    SkillTextInputHandler.clear(second)
  end

  test "an exactly correlated valid reply clears the prompt and accepts the 79-byte limit" do
    stub(Interpreter, :preflight_cast, fn _game_state, 9_001, 1, {:ground, 151, 150} -> :ok end)
    {:noreply, staged} = SkillTextInputHandler.stage(state(), 9_001, 1, {:ground, 151, 150})
    request_id = staged.pending_skill_text_input.request_id
    text = String.duplicate("a", 79)

    expect(SkillHandler, :complete_cast_with_input, fn cleared,
                                                       9_001,
                                                       1,
                                                       {:ground, 151, 150},
                                                       ^text ->
      assert cleared.pending_skill_text_input == nil
      {:noreply, cleared}
    end)

    reply = %SkillTextInputReply{request_id: request_id, outcome: {:text, text}}
    assert {:noreply, completed} = SkillTextInputHandler.handle_reply(reply, staged)
    assert completed.pending_skill_text_input == nil
  end

  test "an old client is rejected with only the known cast-failure message before preflight" do
    expect(Broadcast, :to_player, fn 1000,
                                     %SkillCastFailed{
                                       skill_id: 9_001,
                                       reason: :SKILL_CAST_FAILURE_REASON_UNSPECIFIED
                                     } ->
      :ok
    end)

    old_client = %{state() | client_capabilities: []}

    assert {:noreply, ^old_client} =
             SkillTextInputHandler.stage(old_client, 9_001, 1, {:ground, 151, 150})

    refute_received {:send, _, {:skill_text_input_request, _}}
  end

  test "SkillHandler diverts an input-capable ground fixture into staging" do
    expect(Interpreter, :preflight_cast, fn _game_state, 9_001, 1, {:ground, 151, 150} -> :ok end)

    assert {:noreply, staged} =
             SkillHandler.handle_use_skill_ground(state(), 9_001, 1, 151, 150)

    assert staged.pending_skill_text_input.skill_id == 9_001
  end

  test "moving with insufficient SP stages nothing and does not stop or mutate movement" do
    stub(Catalog, :by_id, fn 9_001 -> {:ok, definition(sp_cost: [2])} end)

    expect(Broadcast, :to_player, fn 1000,
                                     %SkillCastFailed{
                                       reason: :SKILL_CAST_FAILURE_REASON_INSUFFICIENT_SP
                                     } ->
      :ok
    end)

    initial = moving_state(1)

    assert {:noreply, rejected} =
             SkillHandler.handle_use_skill_ground(initial, 9_001, 1, 151, 150)

    assert rejected == initial
    refute_received {:send, _, {:skill_text_input_request, _}}
    refute_received {:send, _, {:move_stop, _}}
  end

  test "moving without a required catalyst stages nothing and does not stop or mutate movement" do
    stub(Catalog, :by_id, fn 9_001 ->
      {:ok, definition(item_cost: [%{id: 716, amount: 1}])}
    end)

    expect(Broadcast, :to_player, fn 1000,
                                     %SkillCastFailed{
                                       reason: :SKILL_CAST_FAILURE_REASON_MISSING_CATALYST
                                     } ->
      :ok
    end)

    initial = moving_state(10)

    assert {:noreply, rejected} =
             SkillHandler.handle_use_skill_ground(initial, 9_001, 1, 151, 150)

    assert rejected == initial
    refute_received {:send, _, {:skill_text_input_request, _}}
    refute_received {:send, _, {:move_stop, _}}
  end

  test "successful moving staging preserves the entire game state" do
    initial = moving_state(10)

    assert {:noreply, staged} =
             SkillHandler.handle_use_skill_ground(initial, 9_001, 1, 151, 150)

    assert staged.game_state == initial.game_state
    assert staged.pending_skill_text_input.skill_id == 9_001
    refute_received {:send, _, {:move_stop, _}}
    SkillTextInputHandler.clear(staged)
  end

  test "timeout clears only the exactly correlated pending prompt" do
    pending = pending_request(42)
    staged = %{state() | pending_skill_text_input: pending}

    assert {:noreply, unchanged} = SkillTextInputHandler.handle_timeout(staged, 41)
    assert unchanged.pending_skill_text_input == pending

    assert {:noreply, cleared} = SkillTextInputHandler.handle_timeout(staged, 42)
    assert cleared.pending_skill_text_input == nil
  end

  test "a stale mismatched reply preserves the current prompt and timer" do
    pending = pending_request(42)
    staged = %{state() | pending_skill_text_input: pending}
    stale = %SkillTextInputReply{request_id: 41, outcome: {:cancel, true}}

    assert {:noreply, unchanged} = SkillTextInputHandler.handle_reply(stale, staged)
    assert unchanged.pending_skill_text_input == pending
    assert is_integer(Process.read_timer(pending.timer_ref))
  end

  test "matching cancellation and malformed text clear without completing or spending" do
    reject(&SkillHandler.complete_cast_with_input/5)

    invalid_outcomes = [
      {:cancel, true},
      {:cancel, false},
      {:text, ""},
      {:text, String.duplicate("a", 80)},
      {:text, <<255>>},
      {:text, "nul\0byte"},
      {:text, "line\nbreak"},
      {:text, "line\u2028break"},
      {:text, "control\tchar"},
      nil
    ]

    for outcome <- invalid_outcomes do
      staged = %{state() | pending_skill_text_input: pending_request(42)}
      reply = %SkillTextInputReply{request_id: 42, outcome: outcome}
      assert {:noreply, cleared} = SkillTextInputHandler.handle_reply(reply, staged)
      assert cleared.pending_skill_text_input == nil
    end
  end

  test "NPC and pending-text locks reject staging without disturbing either lock" do
    stub(Broadcast, :to_player, fn 1000, %SkillCastFailed{} -> :ok end)
    reject(&Interpreter.preflight_cast/4)

    npc_lock = {self(), make_ref(), 77}
    npc_state = %{state() | interaction_lock: npc_lock}

    assert {:noreply, npc_unchanged} =
             SkillTextInputHandler.stage(npc_state, 9_001, 1, {:ground, 151, 150})

    assert npc_unchanged.interaction_lock == npc_lock

    pending = pending_request(42)
    pending_state = %{state() | pending_skill_text_input: pending}

    assert {:noreply, prompt_unchanged} =
             SkillTextInputHandler.stage(pending_state, 9_001, 1, {:ground, 151, 150})

    assert prompt_unchanged.pending_skill_text_input == pending
    Process.cancel_timer(pending.timer_ref)
  end

  test "a pending skill menu rejects staging and matching completion" do
    reject(&Interpreter.preflight_cast/4)
    reject(&SkillHandler.complete_cast_with_input/5)
    stub(Broadcast, :to_player, fn 1000, %SkillCastFailed{} -> :ok end)

    menu = %{skill_id: 100, kind: :SKILLS, entry_ids: [1], level: 1}
    menu_state = %{state() | pending_skill_menu: menu}

    assert {:noreply, unchanged} =
             SkillTextInputHandler.stage(menu_state, 9_001, 1, {:ground, 151, 150})

    assert unchanged.pending_skill_menu == menu
    refute_received {:send, _, {:skill_text_input_request, _}}

    pending = pending_request(42)
    staged = %{menu_state | pending_skill_text_input: pending}

    assert {:noreply, rejected} =
             SkillTextInputHandler.handle_reply(
               %SkillTextInputReply{request_id: 42, outcome: {:text, "hello"}},
               staged
             )

    assert rejected.pending_skill_text_input == nil
    assert rejected.pending_skill_menu == menu
  end

  test "matching reply clears without commit when an interaction lock appeared" do
    reject(&Interpreter.complete_cast_with_input/5)
    stub(Broadcast, :to_player, fn 1000, %SkillCastFailed{} -> :ok end)

    pending = pending_request(42)
    lock = {self(), make_ref(), 0x6000_0000}
    staged = %{state() | pending_skill_text_input: pending, interaction_lock: lock}

    assert {:noreply, rejected} =
             SkillTextInputHandler.handle_reply(
               %SkillTextInputReply{request_id: 42, outcome: {:text, "hello"}},
               staged
             )

    assert rejected.pending_skill_text_input == nil
    assert rejected.interaction_lock == lock
    assert rejected.game_state == staged.game_state
  end

  test "revalidation failure clears the matching prompt without mutating caster state" do
    stub(Interpreter, :preflight_cast, fn _game_state, 9_001, 1, {:ground, 151, 150} -> :ok end)

    expect(Interpreter, :complete_cast_with_input, fn _game_state,
                                                      9_001,
                                                      1,
                                                      {:ground, 151, 150},
                                                      "hello" ->
      {:error, :on_cooldown}
    end)

    stub(Broadcast, :to_player, fn 1000, %SkillCastFailed{} -> :ok end)

    initial = state()
    {:noreply, staged} = SkillTextInputHandler.stage(initial, 9_001, 1, {:ground, 151, 150})
    request_id = staged.pending_skill_text_input.request_id

    assert {:noreply, rejected} =
             SkillTextInputHandler.handle_reply(
               %SkillTextInputReply{request_id: request_id, outcome: {:text, "hello"}},
               staged
             )

    assert rejected.pending_skill_text_input == nil
    assert rejected.game_state == initial.game_state
  end

  test "PlayerSession routes the staged-input timeout inside the session writer" do
    staged = %{state() | pending_skill_text_input: pending_request(42)}

    assert {:noreply, cleared} =
             PlayerSession.handle_info({:skill_text_input_timeout, 42}, staged)

    assert cleared.pending_skill_text_input == nil
  end

  defp pending_request(request_id) do
    %SessionState.PendingSkillTextInput{
      request_id: request_id,
      skill_id: 9_001,
      level: 1,
      target: {:ground, 151, 150},
      timer_ref: Process.send_after(self(), :unused_timeout, 60_000)
    }
  end

  defp state do
    %SessionState{
      game_state: %PlayerState{character_id: 1000, action_state: :idle},
      connection_pid: self(),
      client_capabilities: [:FEATURE_CAPABILITY_SKILL_TEXT_INPUT]
    }
  end

  defp moving_state(sp) do
    game_state = %PlayerState{
      character_id: 1000,
      action_state: :moving,
      movement_state: :moving,
      walk_path: [{151, 150}],
      x: 150,
      y: 150,
      map_name: "prontera",
      inventory: %{},
      skill_cooldowns: %{},
      act_delay_until: 0,
      stats: %{
        base_stats: %{dex: 1, int: 1},
        current_state: %{hp: 100, sp: sp},
        derived_stats: %{max_hp: 100, max_sp: 100},
        progression: %{learned_skills: %{9_001 => 1}}
      }
    }

    %{state() | game_state: game_state}
  end

  defp definition(fields \\ []) do
    struct!(
      %Definition{
        id: 9_001,
        name: :fixture_input,
        display_name: "Fixture Input",
        max_level: 1,
        target_type: :ground,
        range: 3,
        sp_cost: [1]
      },
      fields
    )
  end
end
