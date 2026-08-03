defmodule Aesir.ZoneServer.Mmo.Homunculus.Ai.Config do
  @moduledoc """
  Validated, durable configuration for fixed Homunculus AI behavior.
  """

  @type stance :: :passive | :assist | :aggressive
  @type skill_mode :: :manual | :auto
  @type threshold :: :self_hp | :owner_hp | :target_hp
  @type skill_spec :: %{
          id: pos_integer(),
          target: :self | :owner | :enemy,
          allowed_thresholds: MapSet.t(threshold()) | [threshold()]
        }
  @type skill_config :: %{
          mode: skill_mode(),
          priority: 1..100,
          self_hp_threshold: 1..100 | nil,
          owner_hp_threshold: 1..100 | nil,
          target_hp_range: %{min_percent: 0..100, max_percent: 0..100} | nil
        }

  @enforce_keys [
    :stance,
    :leash_distance,
    :join_owner_target,
    :retaliate,
    :avoid_bosses,
    :allowed_mob_class_ids,
    :denied_mob_class_ids,
    :auto_feed,
    :auto_feed_threshold,
    :auto_cast_sp_reserve_percent,
    :skills
  ]
  defstruct stance: :assist,
            leash_distance: 10,
            join_owner_target: true,
            retaliate: true,
            avoid_bosses: true,
            allowed_mob_class_ids: [],
            denied_mob_class_ids: [],
            auto_feed: false,
            auto_feed_threshold: 11,
            auto_cast_sp_reserve_percent: 20,
            skills: %{}

  @type t() :: %__MODULE__{
          stance: stance(),
          leash_distance: 2..14,
          join_owner_target: boolean(),
          retaliate: boolean(),
          avoid_bosses: boolean(),
          allowed_mob_class_ids: [pos_integer()],
          denied_mob_class_ids: [pos_integer()],
          auto_feed: boolean(),
          auto_feed_threshold: 1..75,
          auto_cast_sp_reserve_percent: 0..100,
          skills: %{optional(pos_integer()) => skill_config()}
        }

  @config_keys ~w(stance leash_distance join_owner_target retaliate avoid_bosses allowed_mob_class_ids denied_mob_class_ids auto_feed auto_feed_threshold auto_cast_sp_reserve_percent skills)
  @skill_keys ~w(skill_id mode priority self_hp_threshold owner_hp_threshold target_hp_range)

  @doc "Returns the fixed global defaults."
  @spec default() :: t()
  def default, do: default([])

  @doc "Returns fixed defaults with one manual row per supplied skill specification."
  @spec default([skill_spec()]) :: t()
  def default(skill_specs) do
    case skill_specs(skill_specs) do
      {:ok, specs} -> build_default(specs)
      :error -> raise ArgumentError, "invalid Homunculus AI skill specifications"
    end
  end

  @doc "Decodes one complete persisted or wire-derived AI replacement."
  @spec decode(term(), [skill_spec()]) :: {:ok, t()} | {:error, :invalid_ai_config}
  def decode(config, skill_specs) when is_map(config) and is_list(skill_specs) do
    with {:ok, specs} <- skill_specs(skill_specs),
         true <- MapSet.new(Map.keys(config)) == MapSet.new(@config_keys),
         {:ok, stance} <- stance(config["stance"]),
         true <- config["leash_distance"] in 2..14,
         true <- is_boolean(config["join_owner_target"]),
         true <- is_boolean(config["retaliate"]),
         true <- is_boolean(config["avoid_bosses"]),
         true <- valid_ids?(config["allowed_mob_class_ids"]),
         true <- valid_ids?(config["denied_mob_class_ids"]),
         true <- is_boolean(config["auto_feed"]),
         true <- config["auto_feed_threshold"] in 1..75,
         true <- config["auto_cast_sp_reserve_percent"] in 0..100,
         {:ok, skills} <- skills(config["skills"], specs) do
      {:ok,
       %__MODULE__{
         stance: stance,
         leash_distance: config["leash_distance"],
         join_owner_target: config["join_owner_target"],
         retaliate: config["retaliate"],
         avoid_bosses: config["avoid_bosses"],
         allowed_mob_class_ids: Enum.sort(config["allowed_mob_class_ids"]),
         denied_mob_class_ids: Enum.sort(config["denied_mob_class_ids"]),
         auto_feed: config["auto_feed"],
         auto_feed_threshold: config["auto_feed_threshold"],
         auto_cast_sp_reserve_percent: config["auto_cast_sp_reserve_percent"],
         skills: skills
       }}
    else
      _ -> {:error, :invalid_ai_config}
    end
  end

  def decode(_config, _skill_specs), do: {:error, :invalid_ai_config}

  @doc "Encodes AI configuration as a canonical string-key persistence map."
  @spec encode(t()) :: map()
  def encode(%__MODULE__{} = config) do
    %{
      "stance" => Atom.to_string(config.stance),
      "leash_distance" => config.leash_distance,
      "join_owner_target" => config.join_owner_target,
      "retaliate" => config.retaliate,
      "avoid_bosses" => config.avoid_bosses,
      "allowed_mob_class_ids" => Enum.sort(config.allowed_mob_class_ids),
      "denied_mob_class_ids" => Enum.sort(config.denied_mob_class_ids),
      "auto_feed" => config.auto_feed,
      "auto_feed_threshold" => config.auto_feed_threshold,
      "auto_cast_sp_reserve_percent" => config.auto_cast_sp_reserve_percent,
      "skills" => config.skills |> Enum.sort_by(&elem(&1, 0)) |> Enum.map(&encode_skill/1)
    }
  end

  defp build_default(specs) do
    %__MODULE__{
      stance: :assist,
      leash_distance: 10,
      join_owner_target: true,
      retaliate: true,
      avoid_bosses: true,
      allowed_mob_class_ids: [],
      denied_mob_class_ids: [],
      auto_feed: false,
      auto_feed_threshold: 11,
      auto_cast_sp_reserve_percent: 20,
      skills: Map.new(specs, fn {id, _spec} -> {id, manual_skill()} end)
    }
  end

  defp skill_specs(specs) when is_list(specs) do
    result =
      Enum.reduce_while(specs, %{}, fn spec, acc ->
        case skill_spec(spec) do
          {:ok, {id, spec}} when not is_map_key(acc, id) -> {:cont, Map.put(acc, id, spec)}
          _ -> {:halt, :error}
        end
      end)

    if is_map(result), do: {:ok, result}, else: :error
  end

  defp skill_specs(_specs), do: :error

  defp skill_spec(%{id: id, target: target, allowed_thresholds: thresholds})
       when is_integer(id) and id > 0 and target in [:self, :owner, :enemy] do
    with {:ok, thresholds} <- threshold_set(thresholds),
         true <- MapSet.subset?(thresholds, MapSet.new([:self_hp, :owner_hp, :target_hp])) do
      {:ok, {id, %{target: target, allowed_thresholds: thresholds}}}
    else
      _ -> :error
    end
  end

  defp skill_spec(_spec), do: :error

  defp stance("passive"), do: {:ok, :passive}
  defp stance("assist"), do: {:ok, :assist}
  defp stance("aggressive"), do: {:ok, :aggressive}
  defp stance(_value), do: :error

  defp skills(rows, specs) when is_list(rows) do
    with true <- Enum.all?(rows, &is_map/1),
         {:ok, decoded} <- decode_rows(rows, specs),
         true <- Map.keys(decoded) |> MapSet.new() == Map.keys(specs) |> MapSet.new() do
      {:ok, decoded}
    else
      _ -> :error
    end
  end

  defp skills(_rows, _specs), do: :error

  defp decode_rows(rows, specs) do
    decoded = Enum.map(rows, &skill_row(&1, specs))

    with true <- Enum.all?(decoded, &match?({:ok, _}, &1)),
         rows <- Enum.map(decoded, fn {:ok, row} -> row end),
         ids <- Enum.map(rows, &elem(&1, 0)),
         true <- length(ids) == length(Enum.uniq(ids)) do
      {:ok, Map.new(rows)}
    else
      _ -> :error
    end
  end

  defp skill_row(row, specs) do
    with true <- MapSet.new(Map.keys(row)) == MapSet.new(@skill_keys),
         skill_id when is_map_key(specs, skill_id) <- row["skill_id"],
         {:ok, mode} <- mode(row["mode"]),
         true <- row["priority"] in 1..100,
         true <- upper_threshold?(row["self_hp_threshold"]),
         true <- upper_threshold?(row["owner_hp_threshold"]),
         true <- target_range?(row["target_hp_range"]),
         true <- applicable?(row, specs[skill_id], mode) do
      {:ok,
       {skill_id,
        %{
          mode: mode,
          priority: row["priority"],
          self_hp_threshold: row["self_hp_threshold"],
          owner_hp_threshold: row["owner_hp_threshold"],
          target_hp_range: normalize_range(row["target_hp_range"])
        }}}
    else
      _ -> :error
    end
  end

  defp mode("manual"), do: {:ok, :manual}
  defp mode("auto"), do: {:ok, :auto}
  defp mode(_value), do: :error

  defp applicable?(row, %{allowed_thresholds: allowed_thresholds}, :auto) do
    allowed?(row["self_hp_threshold"], :self_hp, allowed_thresholds) and
      allowed?(row["owner_hp_threshold"], :owner_hp, allowed_thresholds) and
      allowed?(row["target_hp_range"], :target_hp, allowed_thresholds)
  end

  defp applicable?(row, _spec, :manual) do
    row["self_hp_threshold"] == nil and row["owner_hp_threshold"] == nil and
      row["target_hp_range"] == nil
  end

  defp allowed?(nil, _threshold, _allowed_thresholds), do: true

  defp allowed?(_value, threshold, allowed_thresholds),
    do: MapSet.member?(allowed_thresholds, threshold)

  defp threshold_set(thresholds) when is_list(thresholds), do: {:ok, MapSet.new(thresholds)}
  defp threshold_set(%MapSet{} = thresholds), do: {:ok, thresholds}
  defp threshold_set(_thresholds), do: :error

  defp valid_ids?(ids) when is_list(ids) do
    Enum.all?(ids, &(is_integer(&1) and &1 > 0)) and length(ids) == length(Enum.uniq(ids))
  end

  defp valid_ids?(_ids), do: false
  defp upper_threshold?(nil), do: true
  defp upper_threshold?(value), do: value in 1..100

  defp target_range?(nil), do: true

  defp target_range?(%{"min_percent" => min_percent, "max_percent" => max_percent} = range) do
    MapSet.new(Map.keys(range)) == MapSet.new(~w(min_percent max_percent)) and
      min_percent in 0..100 and max_percent in 0..100 and min_percent <= max_percent
  end

  defp target_range?(_range), do: false

  defp normalize_range(nil), do: nil

  defp normalize_range(%{"min_percent" => min_percent, "max_percent" => max_percent}) do
    %{min_percent: min_percent, max_percent: max_percent}
  end

  defp encode_range(nil), do: nil

  defp encode_range(%{min_percent: min_percent, max_percent: max_percent}) do
    %{"min_percent" => min_percent, "max_percent" => max_percent}
  end

  defp encode_skill({skill_id, config}) do
    %{
      "skill_id" => skill_id,
      "mode" => Atom.to_string(config.mode),
      "priority" => config.priority,
      "self_hp_threshold" => config.self_hp_threshold,
      "owner_hp_threshold" => config.owner_hp_threshold,
      "target_hp_range" => encode_range(config.target_hp_range)
    }
  end

  defp manual_skill do
    %{
      mode: :manual,
      priority: 50,
      self_hp_threshold: nil,
      owner_hp_threshold: nil,
      target_hp_range: nil
    }
  end
end
