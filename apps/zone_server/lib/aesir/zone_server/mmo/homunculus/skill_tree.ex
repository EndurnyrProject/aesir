defmodule Aesir.ZoneServer.Mmo.Homunculus.SkillTree do
  @moduledoc """
  Runtime skill trees for every original and evolved Homunculus class variant.
  """

  alias Aesir.ZoneServer.Mmo.Homunculus.Catalogs

  @class_ids MapSet.new(6001..6016)
  @forms ~w(any evolved)
  @fields ~w(class_id skill_id skill max_level required_level required_intimacy form requires)a
          |> Map.new(&{Atom.to_string(&1), &1})
  @requirement_fields ~w(skill_id level)a |> Map.new(&{Atom.to_string(&1), &1})

  @type requirement :: %{skill_id: pos_integer(), level: pos_integer()}
  @type entry :: %{
          class_id: pos_integer(),
          skill_id: pos_integer(),
          skill: String.t(),
          max_level: pos_integer(),
          required_level: non_neg_integer(),
          required_intimacy: non_neg_integer(),
          form: atom(),
          requires: [requirement()]
        }

  @doc "Returns all skill-tree rows ordered by class and skill id."
  @spec all() :: [entry()]
  def all, do: index().all

  @doc "Returns the complete skill tree for a class variant."
  @spec for_class(pos_integer()) :: [entry()]
  def for_class(class_id), do: Map.get(index().by_class, class_id, [])

  @doc "Looks up a skill-tree entry for a class variant."
  @spec entry(pos_integer(), pos_integer()) :: {:ok, entry()} | :error
  def entry(class_id, skill_id), do: Map.fetch(index().by_key, {class_id, skill_id})

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
    validate!(rows, @class_ids)
    build(rows)
  end

  @doc "Validates decoded skill trees, raising on missing classes, bad gates, or bad prerequisites."
  @spec validate!([map()], MapSet.t(pos_integer())) :: :ok
  def validate!(rows, class_ids \\ @class_ids)

  def validate!(rows, class_ids) when is_list(rows) do
    require!(length(rows) == 64, "expected 64 Homunculus skill-tree rows")

    require!(
      MapSet.new(rows, & &1["class_id"]) == class_ids,
      "skill trees do not cover every class"
    )

    grouped = Enum.group_by(rows, & &1["class_id"])

    Enum.each(grouped, fn {class_id, entries} ->
      require!(length(entries) == 4, "class #{class_id} must have four skills")
      ids = MapSet.new(entries, & &1["skill_id"])
      max_levels = Map.new(entries, &{&1["skill_id"], &1["max_level"]})
      require!(MapSet.size(ids) == 4, "class #{class_id} has duplicate skills")
      Enum.each(entries, &validate_entry!(&1, max_levels))
    end)

    :ok
  end

  def validate!(_rows, _class_ids),
    do: raise(ArgumentError, "Homunculus skill-tree data must be a list")

  defp validate_entry!(entry, max_levels) do
    required =
      ~w(class_id skill_id skill max_level required_level required_intimacy form requires)

    require!(
      Enum.all?(required, &Map.has_key?(entry, &1)),
      "skill-tree row is missing required fields"
    )

    require!(positive?(entry["class_id"]), "invalid skill-tree class id")
    require!(positive?(entry["skill_id"]), "invalid Homunculus skill id")
    require!(is_binary(entry["skill"]) and entry["skill"] != "", "invalid Homunculus skill name")
    require!(positive?(entry["max_level"]), "invalid Homunculus skill maximum")
    require!(non_negative?(entry["required_level"]), "invalid Homunculus required level")
    require!(entry["required_intimacy"] in 0..100_000, "invalid Homunculus intimacy gate")
    require!(entry["form"] in @forms, "invalid Homunculus skill form")
    require!(is_list(entry["requires"]), "Homunculus prerequisites must be a list")

    prerequisite_ids = Enum.map(entry["requires"], & &1["skill_id"])

    require!(
      length(prerequisite_ids) == length(Enum.uniq(prerequisite_ids)),
      "duplicate prerequisites"
    )

    Enum.each(entry["requires"], fn requirement ->
      required_max = Map.get(max_levels, requirement["skill_id"])
      require!(required_max != nil, "prerequisite is outside its class tree")
      require!(positive?(requirement["level"]), "invalid prerequisite level")
      require!(requirement["level"] <= required_max, "unreachable prerequisite")
    end)
  end

  defp index, do: Catalogs.state(:skill_tree)

  defp build(rows) do
    all = rows |> Enum.map(&convert/1) |> Enum.sort_by(&{&1.class_id, &1.skill_id})

    %{
      all: all,
      by_class: Enum.group_by(all, & &1.class_id),
      by_key: Map.new(all, &{{&1.class_id, &1.skill_id}, &1})
    }
  end

  defp convert(row) do
    row
    |> Map.new(fn {key, value} -> {Map.fetch!(@fields, key), convert_value(key, value)} end)
  end

  defp convert_value("form", value),
    do: Map.fetch!(%{"any" => :any, "evolved" => :evolved}, value)

  defp convert_value("requires", rows), do: Enum.map(rows, &atomize/1)
  defp convert_value(_key, value), do: value

  defp atomize(map),
    do: Map.new(map, fn {key, value} -> {Map.fetch!(@requirement_fields, key), value} end)

  defp positive?(value), do: is_integer(value) and value > 0
  defp non_negative?(value), do: is_integer(value) and value >= 0
  defp require!(true, _message), do: :ok
  defp require!(false, message), do: raise(ArgumentError, message)
  defp data_path, do: Application.app_dir(:zone_server, "priv/db/re/homunculus/skill_trees.yml")
end
