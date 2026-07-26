defmodule Aesir.ZoneServer.Unit.Player.Handlers.SkillLearningHandler do
  @moduledoc """
  Handles LearnSkill: spends one skill point to learn or raise a skill.

  Modeled on `StatAllocationHandler`: validates the request against the
  server-authoritative `SkillTree`, recalculates stats (a learned passive such as
  `SM_SWORD` changes derived ATK), persists, and syncs the client (the updated
  enriched `SkillList` plus the new skill-point balance). The refreshed list +
  skill-point `ParamChange` are the success ack, so no `LearnSkillResult` is sent
  on success. Failures send a `LearnSkillResult{ok: false}` carrying a stable
  reject code and leave state unchanged (no point spent). Learning or raising
  `KN_CAVALIERMASTERY` while mounted re-applies `SC_RIDING`
  (`MountHandler.recompute/1`) so the ASPD buyback updates immediately instead
  of waiting for a dismount/remount.

  `grant_skill/3` is the separate NPC-script permanent-grant path (rAthena's
  "platinum skill" style `skill <id>,<level>,SKILL_PERM`): it persists
  `learned_skills` and refreshes the `SkillList` the same way, but never
  spends or refunds a skill point and never recomputes derived stats.
  """

  alias Aesir.Commons.StatusParams
  alias Aesir.Net.LearnSkillResult
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Skill.Grant
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.Skills.Knight.KnCavaliermastery
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Player.Handlers.MountHandler
  alias Aesir.ZoneServer.Unit.Player.SkillListView
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync

  @kn_cavaliermastery_id KnCavaliermastery.definition().id

  @doc """
  Processes a learn-skill request for the player session.
  """
  @spec handle_learn_skill(non_neg_integer(), map()) :: {:noreply, map()}
  def handle_learn_skill(skill_id, %{game_state: game_state} = state) do
    case SkillTree.learn(game_state.stats.progression, skill_id) do
      {:ok, progression} ->
        commit(skill_id, progression, state, game_state)

      {:error, reason} ->
        reject(skill_id, reason, state)
    end
  end

  defp commit(skill_id, progression, state, game_state) do
    char_id = game_state.character_id

    stats =
      %{game_state.stats | progression: progression}
      |> Stats.calculate_stats(char_id)

    new_game_state = %{game_state | stats: stats}

    new_state =
      state
      |> StateCommit.commit(new_game_state)
      |> maybe_recompute_riding(skill_id)

    persist(char_id, stats)
    sync(state.connection_pid, progression)

    {:noreply, new_state}
  end

  @spec maybe_recompute_riding(map(), non_neg_integer()) :: map()
  defp maybe_recompute_riding(state, @kn_cavaliermastery_id), do: MountHandler.recompute(state)
  defp maybe_recompute_riding(state, _skill_id), do: state

  @doc """
  Grants `skill_id_or_name` permanently at `level` through the session
  (rAthena's platinum-skill style `skill <id>,<level>,SKILL_PERM`).

  Resolves and validates the grant through `Mmo.Skill.Grant`, keeping the
  greater of the existing and requested learned level (idempotent - a repeat
  or lower-level grant leaves the level unchanged), persists the updated
  `learned_skills`, and pushes a refreshed `SkillList` to the client. Spends
  and refunds no skill points, so no `ParamChange` is sent, and every other
  learned skill is left untouched.

  Returns `{:error, reason}` without mutating `state` when the skill is
  unknown, `level` is out of range, or the definition lacks quest-grant
  metadata (see `Mmo.Skill.Grant.reason/0`).
  """
  @spec grant_skill(integer() | atom(), pos_integer(), map()) ::
          {:ok, map()} | {:error, Grant.reason()}
  def grant_skill(skill_id_or_name, level, %{game_state: game_state} = state) do
    progression = game_state.stats.progression

    case Grant.grant(progression.learned_skills, skill_id_or_name, level) do
      {:ok, learned_skills} ->
        {:ok, commit_grant(learned_skills, state, game_state)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp commit_grant(learned_skills, state, game_state) do
    progression = %{game_state.stats.progression | learned_skills: learned_skills}
    new_game_state = %{game_state | stats: %{game_state.stats | progression: progression}}

    CharacterPersistence.update_character(
      game_state.character_id,
      %{learned_skills: Learned.dump(learned_skills)},
      async: true
    )

    MessageRouter.send_to(state.connection_pid, SkillListView.build(progression))

    %{state | game_state: new_game_state}
  end

  defp reject(skill_id, reason, %{connection_pid: connection_pid} = state) do
    MessageRouter.send_to(connection_pid, %LearnSkillResult{
      skill_id: skill_id,
      ok: false,
      reason: code(reason)
    })

    {:noreply, state}
  end

  defp persist(char_id, stats) do
    CharacterPersistence.update_character(
      char_id,
      %{
        learned_skills: Learned.dump(stats.progression.learned_skills),
        skill_point: stats.progression.skill_point,
        hp: stats.current_state.hp,
        max_hp: stats.derived_stats.max_hp,
        sp: stats.current_state.sp,
        max_sp: stats.derived_stats.max_sp,
        ap: stats.current_state.ap,
        max_ap: stats.derived_stats.max_ap
      },
      async: true
    )
  end

  defp sync(connection_pid, progression) do
    MessageRouter.send_to(connection_pid, SkillListView.build(progression))

    StatusSync.send_params(connection_pid, %{
      StatusParams.skill_point() => progression.skill_point
    })
  end

  # Stable uint32 reject codes mirrored by the Lifthrasir client (0 reserved for
  # ok / success, which the success path acks with the SkillList instead).
  @spec code(SkillTree.reason()) :: pos_integer()
  defp code(:not_in_tree), do: 1
  defp code(:no_skill_points), do: 2
  defp code(:max_level), do: 3
  defp code(:missing_prerequisite), do: 4
  defp code(:level_too_low), do: 5
end
