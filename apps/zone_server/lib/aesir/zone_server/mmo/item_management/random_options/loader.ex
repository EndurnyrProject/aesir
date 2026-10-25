defmodule Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Loader do
  @moduledoc """
  Builds the random option and random option group indexes from the
  `random_options` YAML of the active mode and its import overlay (whole entry
  override by `id`).

  Cache mechanics live in `Aesir.ZoneServer.Mmo.DataLoader`. Plain functions
  only - no process.
  """

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Entry
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Group
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Option

  @type index() :: %{
          options: %{pos_integer() => Option.t()},
          groups: %{pos_integer() => Group.t()},
          group_ids: %{String.t() => pos_integer()}
        }

  @spec load() :: index()
  def load do
    groups = load_domain("random_options/groups.yml", "random_option_groups_v1.etf", &to_group!/1)

    %{
      options: load_domain("random_options/options.yml", "random_options_v1.etf", &to_option!/1),
      groups: groups,
      group_ids: Map.new(groups, fn {id, group} -> {group.name, id} end)
    }
  end

  defp load_domain(domain, cache_file, convert) do
    domain
    |> DataLoader.load(cache_file, fn sources ->
      sources
      |> Enum.flat_map(&DataLoader.parse_file/1)
      |> Enum.map(convert)
      |> DataLoader.merge_by_key(& &1.id)
    end)
    |> Map.new(&{&1.id, &1})
  end

  defp to_option!(%{"id" => id, "name" => name} = row) do
    program =
      case Map.get(row, "script") do
        nil -> nil
        source -> EquipScript.parse!(source)
      end

    %Option{id: id, name: name, program: program}
  end

  defp to_group!(%{"id" => id, "name" => name} = row) do
    %Group{
      id: id,
      name: name,
      slots: row |> Map.fetch!("slots") |> Enum.map(fn slot -> Enum.map(slot, &to_entry!/1) end),
      max_random: Map.fetch!(row, "max_random"),
      random: row |> Map.fetch!("random") |> Enum.map(&to_entry!/1)
    }
  end

  defp to_entry!(entry) do
    %Entry{
      option_id: Map.fetch!(entry, "option"),
      min: Map.fetch!(entry, "min"),
      max: Map.fetch!(entry, "max"),
      param: Map.fetch!(entry, "param"),
      chance: Map.fetch!(entry, "chance")
    }
  end
end
