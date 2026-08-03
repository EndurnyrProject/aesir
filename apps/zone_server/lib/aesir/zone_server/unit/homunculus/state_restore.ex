defmodule Aesir.ZoneServer.Unit.Homunculus.StateRestore do
  @moduledoc """
  Converts one validated durable Homunculus row into its offline aggregate state.
  """

  alias Aesir.Commons.Models.Homunculus
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.Config
  alias Aesir.ZoneServer.Mmo.Homunculus.Catalog
  alias Aesir.ZoneServer.Mmo.Homunculus.SkillTree
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState

  @durable_fields [
    :id,
    :character_id,
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
    :active_remaining_ms
  ]

  @doc "Restores a durable row, rejecting malformed lifecycle, maps, species, and AI configuration."
  @spec restore(Homunculus.t()) :: {:ok, HomunculusState.t()} | {:error, atom()}
  def restore(%Homunculus{} = row) do
    with {:ok, species} <- catalog_row(row.class_id),
         {:ok, lifecycle} <- lifecycle(row.lifecycle),
         {:ok, learned_skills} <- integer_map(row.learned_skills, :positive),
         {:ok, cooldowns} <- integer_map(row.cooldowns, :non_negative),
         :ok <- validate_skills(row.class_id, learned_skills, cooldowns),
         specs <- skill_specs(learned_skills),
         {:ok, ai_config} <- ai_config(row.ai_config, specs),
         :ok <- validate_row(row, lifecycle) do
      state =
        row
        |> Map.from_struct()
        |> Map.take(@durable_fields)
        |> Map.put(:owner_character_id, row.character_id)
        |> Map.delete(:character_id)
        |> Map.put(:lifecycle, lifecycle)
        |> Map.put(:learned_skills, learned_skills)
        |> Map.put(:cooldowns, cooldowns)
        |> Map.put(:ai_config, ai_config)
        |> Map.put(:race, species.race)
        |> Map.put(:element, {species.element, 1})
        |> Map.put(:size, species.size)
        |> Map.put(:attack_delay_ms, species.attack_delay)
        |> put_lifecycle_invariants(lifecycle)

      {:ok, struct!(HomunculusState, state)}
    else
      :error -> {:error, :invalid_species}
      {:error, _reason} = error -> error
      false -> {:error, :invalid_row}
    end
  end

  def restore(_row), do: {:error, :invalid_row}

  defp catalog_row(class_id) do
    case Catalog.by_id(class_id) do
      {:ok, species} -> {:ok, species}
      :error -> :error
    end
  end

  defp lifecycle("active"), do: {:ok, :active}
  defp lifecycle("rested"), do: {:ok, :rested}
  defp lifecycle("dead"), do: {:ok, :dead}
  defp lifecycle(_lifecycle), do: {:error, :invalid_lifecycle}

  defp integer_map(map, value_kind) when is_map(map) do
    Enum.reduce_while(map, {:ok, %{}}, fn {key, value}, {:ok, result} ->
      with {:ok, integer_key} <- positive_key(key),
           true <- valid_value?(value, value_kind),
           false <- Map.has_key?(result, integer_key) do
        {:cont, {:ok, Map.put(result, integer_key, value)}}
      else
        _invalid -> {:halt, {:error, :invalid_map}}
      end
    end)
  end

  defp integer_map(_map, _value_kind), do: {:error, :invalid_map}

  defp positive_key(key) when is_integer(key) and key > 0, do: {:ok, key}

  defp positive_key(key) when is_binary(key) do
    case Integer.parse(key) do
      {integer, ""} when integer > 0 -> {:ok, integer}
      _invalid -> {:error, :invalid_key}
    end
  end

  defp positive_key(_key), do: {:error, :invalid_key}
  defp valid_value?(value, :positive), do: is_integer(value) and value > 0
  defp valid_value?(value, :non_negative), do: is_integer(value) and value >= 0

  defp validate_skills(class_id, learned_skills, cooldowns) do
    allowed = Map.new(SkillTree.for_class(class_id), &{&1.skill_id, &1.max_level})

    with true <- Enum.all?(learned_skills, fn {id, rank} -> rank <= Map.get(allowed, id, 0) end),
         true <- Enum.all?(Map.keys(cooldowns), &Map.has_key?(allowed, &1)) do
      :ok
    else
      _invalid -> {:error, :invalid_skills}
    end
  end

  defp ai_config(config, specs) when config == %{}, do: {:ok, Config.default(specs)}
  defp ai_config(config, specs), do: Config.decode(config, specs)

  defp skill_specs(learned_skills) do
    learned_skills
    |> Map.keys()
    |> Enum.sort()
    |> Enum.map(&%{id: &1, target: :self, allowed_thresholds: [:self_hp, :owner_hp, :target_hp]})
  end

  defp validate_row(row, lifecycle) do
    valid_identity?(row) and valid_resources?(row) and
      valid_lifecycle?(row, lifecycle)
      |> then(&if(&1, do: :ok, else: {:error, :invalid_row}))
  end

  defp valid_identity?(row) do
    positive?(row.id) and positive?(row.character_id) and positive?(row.class_id) and
      is_binary(row.name) and row.name != "" and is_boolean(row.rename_available)
  end

  defp valid_resources?(row) do
    valid_progression?(row) and valid_vitals?(row) and valid_bond?(row) and valid_stats?(row)
  end

  defp valid_progression?(row) do
    positive?(row.level) and row.level <= 99 and non_negative?(row.exp) and
      non_negative?(row.skill_points)
  end

  defp valid_vitals?(row) do
    non_negative?(row.hp) and positive?(row.max_hp) and row.hp <= row.max_hp and
      non_negative?(row.sp) and non_negative?(row.max_sp) and row.sp <= row.max_sp
  end

  defp valid_bond?(row) do
    row.hunger in 0..100 and row.intimacy_hundredths in 0..100_000 and
      non_negative?(row.active_remaining_ms)
  end

  defp valid_stats?(row) do
    Enum.all?([row.str, row.agi, row.vit, row.int, row.dex, row.luk], &non_negative?/1)
  end

  defp valid_lifecycle?(row, :active), do: row.hp > 0
  defp valid_lifecycle?(row, :rested), do: row.hp > 0 and row.active_remaining_ms == 0
  defp valid_lifecycle?(row, :dead), do: row.hp == 0 and row.active_remaining_ms == 0

  defp put_lifecycle_invariants(state, :dead) do
    Map.merge(state, offline_fields(:dead))
  end

  defp put_lifecycle_invariants(state, _living) do
    Map.merge(state, offline_fields(:idle))
  end

  defp offline_fields(action_state) do
    %{
      owner_session_pid: nil,
      world_gid: nil,
      map_name: nil,
      x: nil,
      y: nil,
      action_state: action_state,
      movement_state: :standing,
      target: nil,
      casting: nil
    }
  end

  defp positive?(value), do: is_integer(value) and value > 0
  defp non_negative?(value), do: is_integer(value) and value >= 0
end
