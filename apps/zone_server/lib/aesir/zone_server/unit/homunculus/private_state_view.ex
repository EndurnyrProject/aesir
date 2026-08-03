defmodule Aesir.ZoneServer.Unit.Homunculus.PrivateStateView do
  @moduledoc """
  Pure owner-private protocol projection for a Homunculus aggregate snapshot.
  """

  alias Aesir.Net.HomunculusAiConfig
  alias Aesir.Net.HomunculusAiSkillConfig
  alias Aesir.Net.HomunculusCooldown
  alias Aesir.Net.HomunculusDisplayedStats
  alias Aesir.Net.HomunculusHpRange
  alias Aesir.Net.HomunculusHpThreshold
  alias Aesir.Net.HomunculusPrivateState
  alias Aesir.Net.HomunculusSkillMetadata
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.Config
  alias Aesir.ZoneServer.Mmo.Homunculus.Catalog
  alias Aesir.ZoneServer.Mmo.Homunculus.ExpTable
  alias Aesir.ZoneServer.Mmo.Homunculus.SkillTree
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Unit.Homunculus.Clock
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.HungerHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.ProgressionHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Runtime

  @doc "Builds the complete owner-only wire state at an explicit monotonic time."
  @spec build(HomunculusState.t(), Runtime.t(), integer()) :: HomunculusPrivateState.t()
  def build(%HomunculusState{} = state, %Runtime{} = runtime, now_ms \\ Clock.now_ms()) do
    species = catalog!(state.class_id)
    clocks = durable_clocks!(state, runtime, now_ms)

    %HomunculusPrivateState{
      durable_id: state.id,
      world_gid: protocol_id(state.world_gid),
      name: state.name,
      rename_eligible: state.rename_available,
      species_id: species.base_class_id,
      evolved: species.form == :evolved,
      appearance_id: state.class_id,
      lifecycle: lifecycle(state.lifecycle),
      activity: activity(state),
      current_target_id: target_id(state.target),
      level: state.level,
      exp: state.exp,
      next_exp: next_exp(state.level),
      skill_points: state.skill_points,
      hp: state.hp,
      max_hp: state.max_hp,
      sp: state.sp,
      max_sp: state.max_sp,
      stats: displayed_stats(state),
      hunger: state.hunger,
      intimacy_hundredths: state.intimacy_hundredths,
      intimacy_grade: intimacy_grade(state.intimacy_hundredths),
      food_item_id: food_item_id!(species.food),
      active_remaining_ms: clocks.active_remaining_ms,
      skills: skills(state),
      cooldowns: cooldowns(clocks.cooldowns),
      ai_config: ai_config(state.ai_config)
    }
  end

  defp catalog!(class_id) do
    case Catalog.by_id(class_id) do
      {:ok, species} -> species
      :error -> raise ArgumentError, "unknown Homunculus species #{inspect(class_id)}"
    end
  end

  defp durable_clocks!(state, %Runtime{clocks_online: true} = runtime, now_ms) do
    case Clock.durable_snapshot(
           state.lifecycle,
           runtime.active_deadline_ms,
           state.cooldowns,
           now_ms
         ) do
      {:ok, clocks} -> clocks
      {:error, :invalid_clock_state} -> raise ArgumentError, "invalid Homunculus clock state"
    end
  end

  defp durable_clocks!(state, %Runtime{clocks_online: false}, _now_ms) do
    %{active_remaining_ms: state.active_remaining_ms, cooldowns: state.cooldowns}
  end

  defp lifecycle(:active), do: :HOMUNCULUS_LIFECYCLE_ACTIVE
  defp lifecycle(:rested), do: :HOMUNCULUS_LIFECYCLE_RESTED
  defp lifecycle(:dead), do: :HOMUNCULUS_LIFECYCLE_DEAD

  defp activity(%HomunculusState{lifecycle: :dead}),
    do: :HOMUNCULUS_ACTIVITY_UNSPECIFIED

  defp activity(%HomunculusState{action_state: :moving}), do: :HOMUNCULUS_ACTIVITY_MOVING
  defp activity(%HomunculusState{action_state: :attacking}), do: :HOMUNCULUS_ACTIVITY_ATTACKING
  defp activity(%HomunculusState{action_state: :casting}), do: :HOMUNCULUS_ACTIVITY_CASTING
  defp activity(%HomunculusState{}), do: :HOMUNCULUS_ACTIVITY_IDLE

  defp protocol_id(id) when is_integer(id) and id > 0, do: id
  defp protocol_id(_id), do: 0
  defp target_id({_type, id}), do: protocol_id(id)
  defp target_id(_target), do: 0

  defp next_exp(99), do: 0

  defp next_exp(level) do
    case ExpTable.exp_for(level) do
      {:ok, exp} -> exp
      :error -> raise ArgumentError, "missing Homunculus EXP threshold for level #{level}"
    end
  end

  defp displayed_stats(state) do
    combat = state.combat_stats

    %HomunculusDisplayedStats{
      str: state.str,
      agi: state.agi,
      vit: state.vit,
      int: state.int,
      dex: state.dex,
      luk: state.luk,
      atk: Map.get(combat, :atk, 0),
      matk: Map.get(combat, :matk, 0),
      def: Map.get(combat, :def, 0),
      mdef: Map.get(combat, :mdef, 0),
      hit: Map.get(combat, :hit, 0),
      flee: Map.get(combat, :flee, 0),
      critical: Map.get(combat, :critical, 0),
      aspd: max(100, 200 - div(state.attack_delay_ms, 10))
    }
  end

  defp intimacy_grade(intimacy), do: intimacy_grade_enum(HungerHandler.grade(intimacy))

  defp intimacy_grade_enum(:hate_with_passion),
    do: :HOMUNCULUS_INTIMACY_GRADE_HATE_WITH_PASSION

  defp intimacy_grade_enum(:hate), do: :HOMUNCULUS_INTIMACY_GRADE_HATE
  defp intimacy_grade_enum(:awkward), do: :HOMUNCULUS_INTIMACY_GRADE_AWKWARD
  defp intimacy_grade_enum(:shy), do: :HOMUNCULUS_INTIMACY_GRADE_SHY
  defp intimacy_grade_enum(:neutral), do: :HOMUNCULUS_INTIMACY_GRADE_NEUTRAL
  defp intimacy_grade_enum(:cordial), do: :HOMUNCULUS_INTIMACY_GRADE_CORDIAL
  defp intimacy_grade_enum(:loyal), do: :HOMUNCULUS_INTIMACY_GRADE_LOYAL

  defp food_item_id!(food) do
    case ItemManagement.get_item_by_aegis(food) do
      {:ok, item} -> item.id
      {:error, :item_not_found} -> raise ArgumentError, "unknown Homunculus food #{inspect(food)}"
    end
  end

  defp skills(state) do
    state.class_id
    |> SkillTree.for_class()
    |> Enum.sort_by(& &1.skill_id)
    |> Enum.map(fn entry ->
      %HomunculusSkillMetadata{
        skill_id: entry.skill_id,
        level: Map.get(state.learned_skills, entry.skill_id, 0),
        max_level: entry.max_level,
        learnable: ProgressionHandler.validate_learning(state, entry) == :ok,
        intimacy_required_hundredths: entry.required_intimacy
      }
    end)
  end

  defp cooldowns(cooldowns) do
    cooldowns
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(fn {skill_id, remaining_ms} ->
      %HomunculusCooldown{skill_id: skill_id, remaining_ms: remaining_ms}
    end)
  end

  defp ai_config(%Config{} = config) do
    %HomunculusAiConfig{
      stance: stance(config.stance),
      leash_distance: config.leash_distance,
      join_owner_target: config.join_owner_target,
      retaliate: config.retaliate,
      avoid_bosses: config.avoid_bosses,
      allowed_mob_class_ids: Enum.sort(config.allowed_mob_class_ids),
      denied_mob_class_ids: Enum.sort(config.denied_mob_class_ids),
      auto_feed: config.auto_feed,
      auto_feed_threshold: config.auto_feed_threshold,
      auto_cast_sp_reserve_percent: config.auto_cast_sp_reserve_percent,
      skills:
        config.skills
        |> Enum.sort_by(&elem(&1, 0))
        |> Enum.map(&ai_skill/1)
    }
  end

  defp stance(:passive), do: :HOMUNCULUS_AI_STANCE_PASSIVE
  defp stance(:assist), do: :HOMUNCULUS_AI_STANCE_ASSIST
  defp stance(:aggressive), do: :HOMUNCULUS_AI_STANCE_AGGRESSIVE

  defp ai_skill({skill_id, config}) do
    %HomunculusAiSkillConfig{
      skill_id: skill_id,
      mode: skill_mode(config.mode),
      priority: config.priority,
      self_hp_threshold: hp_threshold(config.self_hp_threshold),
      owner_hp_threshold: hp_threshold(config.owner_hp_threshold),
      target_hp_range: hp_range(config.target_hp_range)
    }
  end

  defp skill_mode(:manual), do: :HOMUNCULUS_AI_SKILL_MODE_MANUAL
  defp skill_mode(:auto), do: :HOMUNCULUS_AI_SKILL_MODE_AUTO
  defp hp_threshold(nil), do: nil
  defp hp_threshold(percent), do: %HomunculusHpThreshold{percent: percent}
  defp hp_range(nil), do: nil

  defp hp_range(%{min_percent: min_percent, max_percent: max_percent}) do
    %HomunculusHpRange{min_percent: min_percent, max_percent: max_percent}
  end
end
