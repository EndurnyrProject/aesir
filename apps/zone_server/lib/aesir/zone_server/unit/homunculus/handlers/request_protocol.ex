defmodule Aesir.ZoneServer.Unit.Homunculus.Handlers.RequestProtocol do
  @moduledoc """
  Pure wire codec for owner Homunculus requests.

  Validates the request envelope, decodes wire commands into internal command
  terms, maps internal error reasons onto protocol error codes, builds the
  `HomunculusResult` reply, and converts the wire AI config into its persisted
  map shape. Holds no session state and performs no side effects.
  """

  alias Aesir.Net.HomunculusAiConfig
  alias Aesir.Net.HomunculusAiSkillConfig
  alias Aesir.Net.HomunculusAttackCommand
  alias Aesir.Net.HomunculusCastSkillCommand
  alias Aesir.Net.HomunculusDeleteCommand
  alias Aesir.Net.HomunculusFeedCommand
  alias Aesir.Net.HomunculusFollowCommand
  alias Aesir.Net.HomunculusInspectCommand
  alias Aesir.Net.HomunculusLearnSkillCommand
  alias Aesir.Net.HomunculusMoveCommand
  alias Aesir.Net.HomunculusRenameCommand
  alias Aesir.Net.HomunculusReplaceAiCommand
  alias Aesir.Net.HomunculusRequest
  alias Aesir.Net.HomunculusRestCommand
  alias Aesir.Net.HomunculusResult
  alias Aesir.Net.HomunculusStandbyCommand
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.PrivateStateView
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @type outcome :: {:ok, nil} | {:error, atom() | tuple()} | {:stop, term()}

  @doc "Validates the request envelope fields."
  @spec validate_request(HomunculusRequest.t()) :: :ok | {:error, :malformed}
  def validate_request(%HomunculusRequest{request_id: id}) when is_integer(id) and id > 0,
    do: :ok

  def validate_request(%HomunculusRequest{}), do: {:error, :malformed}

  @doc "Decodes one wire command oneof into its internal command term."
  @spec decode_command(term()) :: {:ok, term()} | {:error, :malformed}
  def decode_command({:inspect, %HomunculusInspectCommand{}}), do: {:ok, :inspect}

  def decode_command({:move, %HomunculusMoveCommand{x: x, y: y}})
      when is_integer(x) and is_integer(y),
      do: {:ok, {:move, x, y}}

  def decode_command({:follow, %HomunculusFollowCommand{}}), do: {:ok, :follow}

  def decode_command({:attack, %HomunculusAttackCommand{target_id: id}}) when id > 0,
    do: {:ok, {:attack, id}}

  def decode_command({:standby, %HomunculusStandbyCommand{}}), do: {:ok, :standby}

  def decode_command(
        {:cast_skill, %HomunculusCastSkillCommand{skill_id: id, level: level, target: target}}
      )
      when id > 0 and level > 0 and not is_nil(target),
      do: {:ok, {:cast_skill, id, level, target}}

  def decode_command({:feed, %HomunculusFeedCommand{}}), do: {:ok, :feed}
  def decode_command({:rename, %HomunculusRenameCommand{name: name}}), do: {:ok, {:rename, name}}
  def decode_command({:rest, %HomunculusRestCommand{}}), do: {:ok, :rest}

  def decode_command({:delete, %HomunculusDeleteCommand{confirmed: confirmed}})
      when is_boolean(confirmed),
      do: {:ok, {:delete, confirmed}}

  def decode_command(
        {:replace_ai, %HomunculusReplaceAiCommand{config: %HomunculusAiConfig{} = config}}
      ),
      do: {:ok, {:replace_ai, config}}

  def decode_command({:learn_skill, %HomunculusLearnSkillCommand{skill_id: id}}) when id > 0,
    do: {:ok, {:learn_skill, id}}

  def decode_command(_command), do: {:error, :malformed}

  @doc "Builds the wire result for one executed request outcome."
  @spec build_result(integer(), outcome(), SessionState.t()) :: HomunculusResult.t()
  def build_result(request_id, {:ok, _none}, session) do
    %HomunculusResult{
      request_id: request_id,
      success: true,
      error: :HOMUNCULUS_ERROR_NONE,
      state: private_state(session)
    }
  end

  def build_result(request_id, {:error, reason}, session) do
    %HomunculusResult{
      request_id: request_id,
      success: false,
      error: protocol_error(reason),
      state: private_state(session)
    }
  end

  def build_result(request_id, {:stop, reason}, session) do
    %HomunculusResult{
      request_id: request_id,
      success: false,
      error: protocol_error(reason),
      state: private_state(session)
    }
  end

  @doc "Converts the wire AI config into the persisted map shape."
  @spec ai_persisted_map(HomunculusAiConfig.t()) :: map()
  def ai_persisted_map(%HomunculusAiConfig{} = config) do
    %{
      "stance" => ai_stance(config.stance),
      "leash_distance" => config.leash_distance,
      "join_owner_target" => config.join_owner_target,
      "retaliate" => config.retaliate,
      "avoid_bosses" => config.avoid_bosses,
      "allowed_mob_class_ids" => config.allowed_mob_class_ids,
      "denied_mob_class_ids" => config.denied_mob_class_ids,
      "auto_feed" => config.auto_feed,
      "auto_feed_threshold" => config.auto_feed_threshold,
      "auto_cast_sp_reserve_percent" => config.auto_cast_sp_reserve_percent,
      "skills" => Enum.map(config.skills, &ai_skill_map/1)
    }
  end

  defp private_state(%SessionState{} = session) do
    case session.homunculus do
      nil ->
        nil

      %HomunculusState{} = homunculus ->
        PrivateStateView.build(homunculus, session.homunculus_runtime)
    end
  end

  defp protocol_error(reason) when reason in [:no_companion, :no_homunculus],
    do: :HOMUNCULUS_ERROR_NO_COMPANION

  defp protocol_error(reason)
       when reason in [:malformed, :invalid_command, :invalid_target_shape],
       do: :HOMUNCULUS_ERROR_MALFORMED_COMMAND

  defp protocol_error(reason)
       when reason in [
              :invalid_lifecycle,
              :dead,
              :not_living,
              :invalid_state,
              :owner_dead
            ],
       do: :HOMUNCULUS_ERROR_INVALID_LIFECYCLE

  defp protocol_error(reason)
       when reason in [
              :invalid_destination,
              :invalid_position,
              :out_of_bounds,
              :no_path,
              :invalid_start,
              :invalid_goal,
              :goal_not_walkable
            ],
       do: :HOMUNCULUS_ERROR_INVALID_POSITION

  defp protocol_error(reason)
       when reason in [
              :invalid_target,
              :target_not_found,
              :target_unavailable,
              :target_dead,
              :target_no_pid,
              :wrong_target_type,
              :different_map,
              :owner_not_found,
              :owner_unavailable,
              :mob_unavailable,
              :invalid_castling_endpoint,
              :stale_castling_endpoint
            ],
       do: :HOMUNCULUS_ERROR_INVALID_TARGET

  defp protocol_error(reason)
       when reason in [:out_of_range, :range, :target_out_of_range, :projectile_blocked],
       do: :HOMUNCULUS_ERROR_OUT_OF_RANGE

  defp protocol_error(reason)
       when reason in [
              :invalid_skill,
              :unknown_skill,
              :wrong_species,
              :skill_not_learned,
              :passive_skill
            ],
       do: :HOMUNCULUS_ERROR_SKILL_NOT_LEARNED

  defp protocol_error(reason) when reason in [:invalid_level, :max_rank, :invalid_rank],
    do: :HOMUNCULUS_ERROR_INVALID_SKILL_RANK

  defp protocol_error(:on_cooldown), do: :HOMUNCULUS_ERROR_ON_COOLDOWN
  defp protocol_error(:insufficient_sp), do: :HOMUNCULUS_ERROR_INSUFFICIENT_SP

  defp protocol_error(reason)
       when reason in [:missing_food, :food_item_not_found, :missing_item, :item_not_found],
       do: :HOMUNCULUS_ERROR_MISSING_ITEM

  defp protocol_error(:hp_gate), do: :HOMUNCULUS_ERROR_HP_GATE
  defp protocol_error(:rename_not_allowed), do: :HOMUNCULUS_ERROR_RENAME_NOT_ALLOWED
  defp protocol_error(:invalid_name), do: :HOMUNCULUS_ERROR_INVALID_NAME
  defp protocol_error(:confirmation_required), do: :HOMUNCULUS_ERROR_CONFIRMATION_REQUIRED
  defp protocol_error(:invalid_ai_config), do: :HOMUNCULUS_ERROR_INVALID_AI_CONFIG
  defp protocol_error(:skill_points), do: :HOMUNCULUS_ERROR_INSUFFICIENT_SKILL_POINTS

  defp protocol_error(reason)
       when reason in [
              :level,
              :intimacy,
              :insufficient_intimacy,
              :form,
              :prerequisites,
              :already_evolved
            ],
       do: :HOMUNCULUS_ERROR_PREREQUISITES_NOT_MET

  defp protocol_error(reason)
       when reason in [
              :busy,
              :moving,
              :status_blocked,
              :bio_explosion_pending,
              :attack_rate_limited,
              :homunculus_not_found
            ],
       do: :HOMUNCULUS_ERROR_BUSY

  defp protocol_error({:persistence, _reason}), do: :HOMUNCULUS_ERROR_BUSY
  defp protocol_error(_reason), do: :HOMUNCULUS_ERROR_BUSY

  defp ai_stance(:HOMUNCULUS_AI_STANCE_PASSIVE), do: "passive"
  defp ai_stance(:HOMUNCULUS_AI_STANCE_ASSIST), do: "assist"
  defp ai_stance(:HOMUNCULUS_AI_STANCE_AGGRESSIVE), do: "aggressive"
  defp ai_stance(_stance), do: nil

  defp ai_skill_map(%HomunculusAiSkillConfig{} = skill) do
    %{
      "skill_id" => skill.skill_id,
      "mode" => ai_skill_mode(skill.mode),
      "priority" => skill.priority,
      "self_hp_threshold" => threshold(skill.self_hp_threshold),
      "owner_hp_threshold" => threshold(skill.owner_hp_threshold),
      "target_hp_range" => hp_range(skill.target_hp_range)
    }
  end

  defp ai_skill_map(_skill), do: %{}
  defp ai_skill_mode(:HOMUNCULUS_AI_SKILL_MODE_MANUAL), do: "manual"
  defp ai_skill_mode(:HOMUNCULUS_AI_SKILL_MODE_AUTO), do: "auto"
  defp ai_skill_mode(_mode), do: nil
  defp threshold(nil), do: nil
  defp threshold(%{percent: percent}), do: percent
  defp threshold(_threshold), do: :invalid
  defp hp_range(nil), do: nil

  defp hp_range(%{min_percent: min_percent, max_percent: max_percent}) do
    %{"min_percent" => min_percent, "max_percent" => max_percent}
  end

  defp hp_range(_range), do: :invalid
end
