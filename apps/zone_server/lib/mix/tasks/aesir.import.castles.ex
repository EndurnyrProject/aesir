defmodule Mix.Tasks.Aesir.Import.Castles do
  @shortdoc "Imports mode-selected WoE First-Edition castle data"
  @moduledoc """
  Converts the mode-selected `castle_db.yml` First-Edition castles into
  our-schema YAML under `apps/zone_server/priv/db/<mode>/castles/fe.yml`.

      mix aesir.import.castles [<rathena_root>] [--mode re|pre-re]

  `<rathena_root>` defaults to `../rathena`. Only the 20 First-Edition castles
  (aldeg/gefg/payg/prtg_cas01-05) are kept. The Emperium-room coordinate comes
  from a maintained 20-row seed table keyed by map. Canonical pre-renewal rows
  omit warp coordinates, so their Aesir GvG respawn coordinates are normalized
  from the matching Renewal castle numeric ID; all other fields remain from the
  selected pre-renewal source. Missing or ambiguous matches are errors, and no
  partial output is written. Re-running against the same checkout is
  deterministic and idempotent.
  """
  use Mix.Task

  alias Mix.Tasks.Aesir.Import

  @emperium_rooms %{
    "aldeg_cas01" => [216, 23],
    "aldeg_cas02" => [213, 23],
    "aldeg_cas03" => [205, 31],
    "aldeg_cas04" => [36, 217],
    "aldeg_cas05" => [27, 101],
    "gefg_cas01" => [197, 181],
    "gefg_cas02" => [176, 178],
    "gefg_cas03" => [244, 166],
    "gefg_cas04" => [174, 177],
    "gefg_cas05" => [194, 184],
    "payg_cas01" => [139, 139],
    "payg_cas02" => [38, 25],
    "payg_cas03" => [269, 265],
    "payg_cas04" => [270, 28],
    "payg_cas05" => [30, 30],
    "prtg_cas01" => [197, 197],
    "prtg_cas02" => [157, 174],
    "prtg_cas03" => [16, 220],
    "prtg_cas04" => [291, 14],
    "prtg_cas05" => [266, 266]
  }

  @seed_maps MapSet.new(Map.keys(@emperium_rooms))

  @impl Mix.Task
  def run(args) do
    {rathena, mode} = Import.parse!(args)
    out_dir = Import.path("castles", mode)
    src = Path.join([rathena, "db", "castle_db.yml"])
    entries = Import.read_mode_filtered!(src, mode)

    entries =
      case mode do
        :renewal -> entries
        :pre_renewal -> normalize_respawns!(entries, Import.read_mode_filtered!(src, :renewal))
      end

    castles = build(entries)

    File.mkdir_p!(out_dir)
    write!(Path.join(out_dir, "fe.yml"), castles)

    Mix.shell().info("castles: #{length(castles)} FE castles -> #{out_dir}")
  end

  @doc false
  @spec build([map()]) :: [map()]
  def build(entries) do
    fe = entries |> Enum.filter(&fe_castle?/1) |> Enum.sort_by(& &1["Id"])

    maps = MapSet.new(fe, & &1["Map"])

    unless length(fe) == MapSet.size(@seed_maps) and MapSet.equal?(maps, @seed_maps) do
      Mix.raise(
        "expected exactly #{MapSet.size(@seed_maps)} First-Edition castles (one per seed map), " <>
          "got #{length(fe)}: " <> inspect(Enum.map(fe, & &1["Map"]))
      )
    end

    Enum.map(fe, &convert/1)
  end

  @doc false
  @spec normalize_respawns!([map()], [map()]) :: [map()]
  def normalize_respawns!(entries, renewal_entries) do
    pre_renewal = retained_castles_by_id!(entries, "pre-renewal")
    renewal = retained_castles_by_id!(renewal_entries, "Renewal")

    validate_matching_ids!(pre_renewal, renewal)

    Enum.map(entries, &if(fe_castle?(&1), do: with_respawn!(&1, renewal), else: &1))
  end

  defp fe_castle?(%{"Type" => "First_Edition", "Map" => map}),
    do: Map.has_key?(@emperium_rooms, map)

  defp fe_castle?(_), do: false

  defp retained_castles_by_id!(entries, source) do
    entries
    |> Enum.filter(&fe_castle?/1)
    |> Enum.reduce(%{}, fn
      %{"Id" => id} = entry, castles when is_integer(id) ->
        if Map.has_key?(castles, id) do
          Mix.raise("duplicate #{source} castle id #{id}")
        else
          Map.put(castles, id, entry)
        end

      entry, _castles ->
        Mix.raise("malformed #{source} castle row: expected integer Id, got #{inspect(entry)}")
    end)
  end

  defp validate_matching_ids!(pre_renewal, renewal) do
    missing = pre_renewal |> Map.keys() |> Kernel.--(Map.keys(renewal)) |> Enum.sort()
    extra = renewal |> Map.keys() |> Kernel.--(Map.keys(pre_renewal)) |> Enum.sort()

    unless missing == [] and extra == [] do
      Mix.raise(
        "Renewal castle ID mismatch: missing #{inspect(missing, charlists: :as_lists)}, " <>
          "extra #{inspect(extra, charlists: :as_lists)}"
      )
    end
  end

  defp with_respawn!(%{"Id" => id} = entry, renewal) do
    if Map.has_key?(entry, "WarpX") or Map.has_key?(entry, "WarpY") do
      Mix.raise("pre-renewal castle id #{id} must not define WarpX or WarpY")
    end

    renewal_entry = Map.fetch!(renewal, id)

    Map.merge(entry, %{
      "WarpX" => positive_coordinate!(renewal_entry, "WarpX", id),
      "WarpY" => positive_coordinate!(renewal_entry, "WarpY", id)
    })
  end

  defp positive_coordinate!(entry, field, id) do
    case Map.fetch(entry, field) do
      {:ok, value} when is_integer(value) and value > 0 -> value
      _ -> Mix.raise("malformed Renewal #{field} for castle id #{id}")
    end
  end

  defp convert(%{"Id" => id, "Map" => map, "Name" => name} = entry) do
    %{
      id: id,
      map: map,
      name: name,
      client_id: Map.fetch!(entry, "ClientId"),
      respawn: [Map.fetch!(entry, "WarpX"), Map.fetch!(entry, "WarpY")],
      emperium: Map.fetch!(@emperium_rooms, map)
    }
  end

  defp write!(path, entries), do: File.write!(path, Ymlr.document!(entries))
end
