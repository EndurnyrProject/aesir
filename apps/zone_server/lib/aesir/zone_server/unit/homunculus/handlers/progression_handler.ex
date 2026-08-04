defmodule Aesir.ZoneServer.Unit.Homunculus.Handlers.ProgressionHandler do
  @moduledoc """
  Durable Homunculus EXP, skill-learning, and pure evolution transitions.
  """

  alias Aesir.Commons.Models.Homunculus
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.Config
  alias Aesir.ZoneServer.Mmo.Homunculus.Catalog
  alias Aesir.ZoneServer.Mmo.Homunculus.ExpTable
  alias Aesir.ZoneServer.Mmo.Homunculus.Growth
  alias Aesir.ZoneServer.Mmo.Homunculus.SkillTree
  alias Aesir.ZoneServer.Mmo.Homunculus.Stats
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence

  @max_level 99
  @durable_fields [
    :class_id,
    :name,
    :rename_available,
    :level,
    :exp,
    :skill_points,
    :hp,
    :max_hp,
    :sp,
    :max_sp,
    :str,
    :agi,
    :vit,
    :int,
    :dex,
    :luk,
    :hunger,
    :intimacy_hundredths,
    :learned_skills
  ]
  @type opts :: [roll: (non_neg_integer(), non_neg_integer() -> non_neg_integer())]
  @type result :: {:ok, HomunculusState.t()} | {:error, atom() | {:persistence, term()}}

  @doc "Applies Homunculus EXP, persists every rolled level outcome, and returns the new state."
  @spec gain_exp(HomunculusState.t(), non_neg_integer(), opts()) :: result()
  def gain_exp(state, amount, opts \\ [])

  def gain_exp(%HomunculusState{} = state, amount, opts)
      when is_integer(amount) and amount >= 0 do
    state = recompute(state)

    with {:ok, species} <- catalog_row(state.class_id),
         {:ok, progressed} <- advance_levels(%{state | exp: state.exp + amount}, species, opts) do
      persist(state, progressed)
    end
  end

  def gain_exp(%HomunculusState{}, _amount, _opts), do: {:error, :invalid_exp}

  @doc "Learns one rank after validating the current class tree and persists it atomically with AI."
  @spec learn_skill(HomunculusState.t(), pos_integer()) :: result()
  def learn_skill(%HomunculusState{} = state, skill_id) do
    state = recompute(state)

    with {:ok, entry} <- skill_entry(state.class_id, skill_id),
         :ok <- validate_learning(state, entry) do
      learned_skills = Map.update(state.learned_skills, skill_id, 1, &(&1 + 1))
      ai_config = add_manual_ai_row(state.ai_config, skill_id)

      updated = %{
        state
        | skill_points: state.skill_points - 1,
          learned_skills: learned_skills,
          ai_config: ai_config
      }

      persist(state, recompute(updated))
    end
  end

  @doc false
  @spec validate_learning(HomunculusState.t(), SkillTree.entry()) :: :ok | {:error, atom()}
  def validate_learning(%HomunculusState{} = state, entry) do
    with :ok <- require_points(state.skill_points),
         :ok <- require_rank(state.learned_skills, entry),
         :ok <- require_level(state.level, entry.required_level),
         :ok <- require_form(state.class_id, entry.form),
         :ok <- require_intimacy(state.intimacy_hundredths, entry.required_intimacy) do
      require_prerequisites(state.learned_skills, entry.requires)
    end
  end

  @doc "Returns the pure original-to-evolved state transition without consuming or persisting an item."
  @spec evolve(HomunculusState.t(), opts()) :: result()
  def evolve(%HomunculusState{} = state, opts \\ []) do
    state = recompute(state)

    with :ok <- require_active(state),
         :ok <- require_living(state),
         {:ok, original} <- catalog_row(state.class_id),
         :ok <- require_original(original),
         :ok <- require_intimacy(state.intimacy_hundredths, 91_100),
         {:ok, evolved} <- catalog_row(original.evolution_class_id) do
      bonuses = Growth.evolution(evolved, opts)

      evolved_state =
        state
        |> apply_bonuses(bonuses)
        |> Map.put(:class_id, evolved.id)
        |> Map.put(:intimacy_hundredths, 1_000)
        |> Map.put(:race, evolved.race)
        |> Map.put(:element, {evolved.element, 1})
        |> Map.put(:size, evolved.size)
        |> Map.put(:raw_attack_delay_ms, evolved.attack_delay)

      {:ok, recompute(evolved_state)}
    end
  end

  defp advance_levels(%HomunculusState{level: @max_level} = state, _species, _opts),
    do: {:ok, %{state | exp: 0}}

  defp advance_levels(%HomunculusState{} = state, species, opts) do
    case ExpTable.exp_for(state.level) do
      {:ok, required} when state.exp >= required ->
        next_level = state.level + 1
        growth = Growth.level(species, opts)

        state
        |> Map.put(:level, next_level)
        |> Map.put(:exp, state.exp - required)
        |> maybe_grant_skill_point(next_level)
        |> apply_bonuses(growth)
        |> fully_restore()
        |> advance_levels(species, opts)

      {:ok, _required} ->
        {:ok, state}

      :error ->
        {:error, :missing_exp_threshold}
    end
  end

  defp maybe_grant_skill_point(state, level) when rem(level, 3) == 0,
    do: Map.update!(state, :skill_points, &(&1 + 1))

  defp maybe_grant_skill_point(state, _level), do: state

  defp apply_bonuses(state, bonuses) do
    Enum.reduce(bonuses, state, fn
      {:hp, value}, current -> Map.update!(current, :raw_max_hp, &(&1 + value))
      {:sp, value}, current -> Map.update!(current, :raw_max_sp, &(&1 + value))
      {stat, value}, current -> Map.update!(current, raw_stat(stat), &(&1 + value))
    end)
  end

  defp fully_restore(state) do
    effective = recompute(state)
    %{effective | hp: effective.max_hp, sp: effective.max_sp}
  end

  defp recompute(%HomunculusState{lifecycle: :active, world_gid: gid} = state)
       when is_integer(gid) do
    modifiers =
      ModifierCalculator.get_all_modifiers(:homunculus, gid, HomunculusState.get_stats(state))

    Stats.recompute(state, modifiers)
  end

  defp recompute(%HomunculusState{} = state), do: Stats.recompute(state)

  defp raw_stat(:str), do: :raw_str
  defp raw_stat(:agi), do: :raw_agi
  defp raw_stat(:vit), do: :raw_vit
  defp raw_stat(:int), do: :raw_int
  defp raw_stat(:dex), do: :raw_dex
  defp raw_stat(:luk), do: :raw_luk

  @doc false
  @spec persistence_attrs(HomunculusState.t()) :: map()
  def persistence_attrs(%HomunculusState{} = state) do
    state
    |> Map.from_struct()
    |> Map.take(@durable_fields)
    |> Map.put(:max_hp, state.raw_max_hp)
    |> Map.put(:max_sp, state.raw_max_sp)
    |> Map.put(:str, state.raw_str)
    |> Map.put(:agi, state.raw_agi)
    |> Map.put(:vit, state.raw_vit)
    |> Map.put(:int, state.raw_int)
    |> Map.put(:dex, state.raw_dex)
    |> Map.put(:luk, state.raw_luk)
    |> Map.put(:lifecycle, Atom.to_string(state.lifecycle))
    |> Map.put(:ai_config, Config.encode(state.ai_config))
  end

  defp persist(original, updated) do
    case Persistence.load_for_character(original.owner_character_id) do
      %Homunculus{id: id} = row when id == original.id ->
        case Persistence.save_semantic(row, persistence_attrs(updated)) do
          {:ok, _row} -> {:ok, updated}
          {:error, reason} -> {:error, {:persistence, reason}}
        end

      _ ->
        {:error, :not_persisted}
    end
  end

  defp skill_entry(class_id, skill_id) do
    case SkillTree.entry(class_id, skill_id) do
      {:ok, entry} ->
        {:ok, entry}

      :error ->
        if Enum.any?(SkillTree.all(), &(&1.skill_id == skill_id)),
          do: {:error, :wrong_species},
          else: {:error, :invalid_skill}
    end
  end

  defp add_manual_ai_row(%Config{} = config, skill_id) do
    spec = %{id: skill_id, target: :self, allowed_thresholds: []}
    manual = Config.default([spec]).skills[skill_id]
    %{config | skills: Map.put_new(config.skills, skill_id, manual)}
  end

  defp require_points(points) when points > 0, do: :ok
  defp require_points(_points), do: {:error, :skill_points}

  defp require_rank(skills, entry) do
    if Map.get(skills, entry.skill_id, 0) < entry.max_level, do: :ok, else: {:error, :max_rank}
  end

  defp require_level(level, required) when level >= required, do: :ok
  defp require_level(_level, _required), do: {:error, :level}

  defp require_intimacy(intimacy, required) when intimacy >= required, do: :ok
  defp require_intimacy(_intimacy, _required), do: {:error, :intimacy}

  defp require_form(_class_id, :any), do: :ok

  defp require_form(class_id, :evolved) do
    case Catalog.by_id(class_id) do
      {:ok, %{form: :evolved}} -> :ok
      _other -> {:error, :form}
    end
  end

  defp require_prerequisites(skills, requirements) do
    if Enum.all?(requirements, &(Map.get(skills, &1.skill_id, 0) >= &1.level)),
      do: :ok,
      else: {:error, :prerequisites}
  end

  defp require_active(%HomunculusState{lifecycle: :active}), do: :ok
  defp require_active(%HomunculusState{}), do: {:error, :invalid_lifecycle}
  defp require_living(state), do: if(Unit.living?(state), do: :ok, else: {:error, :not_living})
  defp require_original(%{form: :original}), do: :ok
  defp require_original(%{form: :evolved}), do: {:error, :already_evolved}

  defp catalog_row(class_id) do
    case Catalog.by_id(class_id) do
      {:ok, species} -> {:ok, species}
      :error -> {:error, :invalid_species}
    end
  end
end
