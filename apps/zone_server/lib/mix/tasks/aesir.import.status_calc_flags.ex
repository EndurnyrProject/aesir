defmodule Mix.Tasks.Aesir.Import.StatusCalcFlags do
  @shortdoc "Imports canonical status calculation flags for the selected mode"
  @moduledoc """
  Imports official status selections into the mode-scoped calculation catalog.

      mix aesir.import.status_calc_flags [<source_root>] [--mode re|pre-re]

  Explicit aliases retain split runtime status identities. Unknown flags and
  colliding identities fail instead of creating an incomplete catalog.
  """
  use Mix.Task

  alias Aesir.ZoneServer.Mmo.StatusEffect.CalcFlags
  alias Mix.Tasks.Aesir.Import

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    {root, mode} = Import.parse!(args)
    source = Path.join(root, "db/status.yml")
    other_mode = if mode == :renewal, do: :pre_renewal, else: :renewal
    active = source |> Import.read_mode_filtered!(mode) |> convert!()
    active_ids = MapSet.new(active, & &1["id"])

    unavailable =
      source
      |> Import.read_mode_filtered!(other_mode)
      |> convert!()
      |> Enum.reject(&MapSet.member?(active_ids, &1["id"]))
      |> Enum.map(&Map.merge(&1, %{"available" => false, "flags" => []}))

    rows = Enum.sort_by(active ++ unavailable, & &1["id"])
    CalcFlags.validate_aliases!(Enum.map(rows, & &1["id"]))
    output = Import.path("status_calc_flags.yml", mode)
    File.mkdir_p!(Path.dirname(output))
    File.write!(output, Ymlr.document!(rows))
    Mix.shell().info("status calculation flags: #{length(rows)} -> #{output}")
  end

  @doc "Converts source rows into deterministic, validated runtime selections."
  @spec convert!([map()]) :: [map()]
  def convert!(rows) do
    rows
    |> Enum.flat_map(fn row ->
      source = Map.fetch!(row, "Status")
      flags = CalcFlags.normalize_flags!(Map.get(row, "CalcFlags", %{}))

      for id <- CalcFlags.ids_for_source(source) do
        %{
          "id" => id,
          "flags" => flags,
          "scripted" => not is_nil(row["Script"]),
          "available" => true
        }
      end
    end)
    |> Enum.reduce(%{}, fn row, index ->
      id = row["id"]
      if Map.has_key?(index, id), do: raise(ArgumentError, "colliding status identity #{id}")
      Map.put(index, id, row)
    end)
    |> Map.values()
    |> Enum.sort_by(& &1["id"])
  end
end
