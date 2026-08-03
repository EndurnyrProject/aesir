defmodule Aesir.ZoneServer.Mmo.Homunculus.Catalog do
  @moduledoc """
  Runtime catalog for original and evolved Homunculus class variants.
  """

  alias Aesir.ZoneServer.Mmo.Homunculus.Catalogs

  @class_ids MapSet.new(6001..6016)
  @initial_ids Enum.to_list(6001..6008)
  @stat_names MapSet.new(~w(hp sp str agi vit int dex luk))
  @forms ~w(original evolved)
  @races ~w(demi_human brute formless)
  @elements ~w(neutral)
  @sizes ~w(small medium large)
  @fields ~w(id variant name form base_class_id evolution_class_id food hungry_delay race element size attack_delay stats skills)a
          |> Map.new(&{Atom.to_string(&1), &1})
  @range_fields ~w(base growth_min growth_max evolution_min evolution_max)a
                |> Map.new(&{Atom.to_string(&1), &1})

  @type stat_range :: %{
          base: non_neg_integer(),
          growth_min: non_neg_integer(),
          growth_max: non_neg_integer(),
          evolution_min: non_neg_integer(),
          evolution_max: non_neg_integer()
        }
  @type species :: %{
          id: pos_integer(),
          variant: String.t(),
          name: String.t(),
          form: atom(),
          base_class_id: pos_integer(),
          evolution_class_id: pos_integer(),
          food: String.t(),
          hungry_delay: pos_integer(),
          race: atom(),
          element: atom(),
          size: atom(),
          attack_delay: pos_integer(),
          stats: %{String.t() => stat_range()},
          skills: [pos_integer()]
        }

  @doc "Returns all class variants ordered by class id."
  @spec all() :: [species()]
  def all, do: index().all

  @doc "Looks up a class variant by id."
  @spec by_id(pos_integer()) :: {:ok, species()} | :error
  def by_id(id), do: Map.fetch(index().by_id, id)

  @doc "Returns the exact class ids eligible for initial creation."
  @spec initial_class_ids() :: [pos_integer()]
  def initial_class_ids, do: @initial_ids

  @doc "Reloads and validates all Homunculus runtime catalogs."
  @spec reload() :: :ok
  def reload, do: Catalogs.reload()

  @doc false
  @spec stage() :: map()
  def stage, do: stage(data_path())

  @doc false
  @spec stage(Path.t()) :: map()
  def stage(path) do
    rows = YamlElixir.read_from_file!(path)
    validate!(rows)
    build(rows)
  end

  @doc "Validates a decoded species corpus, raising on incomplete or malformed data."
  @spec validate!([map()]) :: :ok
  def validate!(rows) when is_list(rows) do
    require!(length(rows) == 16, "expected 16 Homunculus class rows")
    ids = MapSet.new(rows, & &1["id"])
    require!(ids == @class_ids, "expected Homunculus class ids 6001..6016")

    Enum.each(rows, &validate_row!(&1, ids))
    :ok
  end

  def validate!(_rows), do: raise(ArgumentError, "Homunculus species data must be a list")

  defp validate_row!(row, ids) do
    required =
      ~w(id variant name form base_class_id evolution_class_id food hungry_delay race element size attack_delay stats skills)

    require!(
      Enum.all?(required, &Map.has_key?(row, &1)),
      "species row is missing required fields"
    )

    require!(is_binary(row["variant"]) and row["variant"] != "", "invalid variant name")
    require!(is_binary(row["name"]) and row["name"] != "", "invalid species name")
    require!(row["form"] in @forms, "invalid Homunculus form")
    require!(row["race"] in @races, "invalid Homunculus race")
    require!(row["element"] in @elements, "invalid Homunculus element")

    require!(
      is_binary(row["size"]) and String.downcase(row["size"]) in @sizes,
      "invalid Homunculus size"
    )

    require!(is_binary(row["food"]) and row["food"] != "", "invalid Homunculus food")
    require!(positive?(row["hungry_delay"]), "invalid Homunculus hunger delay")
    require!(positive?(row["attack_delay"]), "invalid Homunculus attack delay")
    require!(MapSet.member?(ids, row["base_class_id"]), "unknown base class link")
    require!(MapSet.member?(ids, row["evolution_class_id"]), "unknown evolution class link")
    validate_links!(row)
    validate_stats!(row["stats"])

    require!(
      is_list(row["skills"]) and length(row["skills"]) == 4,
      "expected four species skills"
    )

    require!(Enum.all?(row["skills"], &positive?/1), "invalid species skill id")
    require!(length(Enum.uniq(row["skills"])) == 4, "duplicate species skills")
  end

  defp validate_links!(%{"id" => id, "form" => "original"} = row) do
    require!(row["base_class_id"] == id, "original form must link to itself as base")
    require!(row["evolution_class_id"] == id + 8, "original form has invalid evolution link")
  end

  defp validate_links!(%{"id" => id, "form" => "evolved"} = row) do
    require!(row["base_class_id"] == id - 8, "evolved form has invalid base link")
    require!(row["evolution_class_id"] == id, "evolved form must link to itself as evolution")
  end

  defp validate_stats!(stats) when is_map(stats) do
    require!(MapSet.new(Map.keys(stats)) == @stat_names, "expected all eight Homunculus stats")

    Enum.each(stats, fn {_name, range} ->
      values = Enum.map(~w(base growth_min growth_max evolution_min evolution_max), &range[&1])
      require!(Enum.all?(values, &(is_integer(&1) and &1 >= 0)), "invalid Homunculus stat range")
      require!(range["growth_min"] <= range["growth_max"], "growth range is reversed")
      require!(range["evolution_min"] <= range["evolution_max"], "evolution range is reversed")
    end)
  end

  defp validate_stats!(_stats), do: raise(ArgumentError, "Homunculus stats must be a map")

  defp index, do: Catalogs.state(:catalog)

  defp build(rows) do
    all = rows |> Enum.map(&convert/1) |> Enum.sort_by(& &1.id)
    %{all: all, by_id: Map.new(all, &{&1.id, &1})}
  end

  defp convert(row) do
    row
    |> Map.new(fn {key, value} -> {Map.fetch!(@fields, key), convert_value(key, value)} end)
  end

  defp convert_value("form", value),
    do: Map.fetch!(%{"original" => :original, "evolved" => :evolved}, value)

  defp convert_value("race", value),
    do:
      Map.fetch!(
        %{"demi_human" => :demi_human, "brute" => :brute, "formless" => :formless},
        value
      )

  defp convert_value("element", "neutral"), do: :neutral

  defp convert_value("size", value),
    do:
      Map.fetch!(
        %{"small" => :small, "medium" => :medium, "large" => :large},
        String.downcase(value)
      )

  defp convert_value("stats", stats),
    do: Map.new(stats, fn {name, range} -> {name, atomize(range)} end)

  defp convert_value(_key, value), do: value

  defp atomize(map),
    do: Map.new(map, fn {key, value} -> {Map.fetch!(@range_fields, key), value} end)

  defp positive?(value), do: is_integer(value) and value > 0
  defp require!(true, _message), do: :ok
  defp require!(false, message), do: raise(ArgumentError, message)
  defp data_path, do: Application.app_dir(:zone_server, "priv/db/homunculus/species.yml")
end
