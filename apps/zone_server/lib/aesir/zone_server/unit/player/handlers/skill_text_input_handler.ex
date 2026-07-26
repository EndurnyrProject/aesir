defmodule Aesir.ZoneServer.Unit.Player.Handlers.SkillTextInputHandler do
  @moduledoc """
  Owns the capability-gated, single-prompt lifecycle for skill text input.
  """

  alias Aesir.Net.SkillTextInputReply
  alias Aesir.Net.SkillTextInputRequest
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.SessionState.PendingSkillTextInput

  @capability :FEATURE_CAPABILITY_SKILL_TEXT_INPUT
  @max_utf8_bytes 79
  @timeout 60_000
  @max_request_id 18_446_744_073_709_551_615

  @spec input_required?(non_neg_integer()) :: boolean()
  def input_required?(skill_id) do
    with {:ok, %{name: name, target_type: :ground}} <- Catalog.by_id(skill_id),
         {:ok, module} <- Catalog.active_module_for(name),
         {:ok, ^module} <- Catalog.ground_module_for(name) do
      function_exported?(module, :cast_with_input, 5)
    else
      _other -> false
    end
  end

  @spec stage(SessionState.t(), non_neg_integer(), pos_integer(), term()) ::
          {:noreply, SessionState.t()}
  def stage(state, skill_id, level, target) do
    case SkillHandler.cast_gate(state, skill_id) do
      {:ok, ready_state} -> stage_gated(ready_state, skill_id, level, target)
      {:error, reason} -> reject(state, skill_id, reason)
    end
  end

  defp stage_gated(state, skill_id, level, target) do
    cond do
      @capability not in state.client_capabilities ->
        reject(state, skill_id, :unsupported_feature)

      SessionState.interaction_blocked?(state) ->
        reject(state, skill_id, :busy)

      not is_nil(state.pending_skill_menu) ->
        reject(state, skill_id, :busy)

      not is_nil(state.deferred_skill_result) ->
        reject(state, skill_id, :busy)

      true ->
        preflight(state, skill_id, level, target)
    end
  end

  defp preflight(state, skill_id, level, target) do
    case Interpreter.preflight_cast(state.game_state, skill_id, level, target) do
      :ok -> stage_request(state, skill_id, level, target)
      {:error, reason} -> reject(state, skill_id, reason)
    end
  end

  defp stage_request(state, skill_id, level, target) do
    request_id = next_request_id()
    timer_ref = Process.send_after(self(), {:skill_text_input_timeout, request_id}, @timeout)

    pending = %PendingSkillTextInput{
      request_id: request_id,
      skill_id: skill_id,
      level: level,
      target: target,
      timer_ref: timer_ref
    }

    MessageRouter.send_to(state.connection_pid, %SkillTextInputRequest{
      request_id: request_id,
      skill_id: skill_id,
      max_utf8_bytes: @max_utf8_bytes
    })

    {:noreply, %{state | pending_skill_text_input: pending}}
  end

  defp reject(state, skill_id, reason) do
    SkillHandler.report_cast_failure(skill_id, state.game_state.character_id, reason)
    {:noreply, state}
  end

  @spec handle_reply(SkillTextInputReply.t(), SessionState.t()) :: {:noreply, SessionState.t()}
  def handle_reply(
        %SkillTextInputReply{request_id: request_id, outcome: outcome},
        %SessionState{
          pending_skill_text_input: %PendingSkillTextInput{request_id: request_id} = pending
        } = state
      ) do
    state = clear(state)

    if SessionState.interaction_blocked?(state) or not is_nil(state.pending_skill_menu) do
      reject(state, pending.skill_id, :busy)
    else
      handle_outcome(state, pending, outcome)
    end
  end

  def handle_reply(%SkillTextInputReply{}, state), do: {:noreply, state}

  defp handle_outcome(state, _pending, {:cancel, true}), do: {:noreply, state}

  defp handle_outcome(state, pending, {:text, text}) do
    if valid_text?(text) do
      SkillHandler.complete_cast_with_input(
        state,
        pending.skill_id,
        pending.level,
        pending.target,
        text
      )
    else
      {:noreply, state}
    end
  end

  defp handle_outcome(state, _pending, _invalid), do: {:noreply, state}

  @spec handle_timeout(SessionState.t(), non_neg_integer()) :: {:noreply, SessionState.t()}
  def handle_timeout(
        %SessionState{
          pending_skill_text_input: %PendingSkillTextInput{request_id: request_id}
        } = state,
        request_id
      ) do
    {:noreply, clear(state)}
  end

  def handle_timeout(state, _request_id), do: {:noreply, state}

  @spec clear(SessionState.t()) :: SessionState.t()
  def clear(state) do
    case Map.get(state, :pending_skill_text_input) do
      nil ->
        state

      pending ->
        Process.cancel_timer(pending.timer_ref)
        Map.put(state, :pending_skill_text_input, nil)
    end
  end

  defp valid_text?(text) when is_binary(text) do
    byte_size(text) in 1..@max_utf8_bytes and String.valid?(text) and
      not Regex.match?(~r/[\p{Cc}\p{Zl}\p{Zp}]/u, text)
  end

  defp valid_text?(_text), do: false

  defp next_request_id do
    request_id = :erlang.unique_integer([:positive, :monotonic])

    if request_id <= @max_request_id do
      request_id
    else
      raise "skill text request ID space exhausted"
    end
  end
end
