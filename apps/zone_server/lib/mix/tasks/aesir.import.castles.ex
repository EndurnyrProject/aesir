defmodule Mix.Tasks.Aesir.Import.Castles do
  @shortdoc "Imports WoE First-Edition castle data into priv/db/re/castles/"
  @moduledoc """
  One-time importer: converts the reference `castle_db.yml` First-Edition
  castles into our-schema YAML at `apps/zone_server/priv/db/re/castles/fe.yml`.

      mix aesir.import.castles [<rathena_root>]

  `<rathena_root>` defaults to `../rathena`. Only the 20 First-Edition castles
  (aldeg/gefg/payg/prtg_cas01-05) are kept; the Emperium-room coordinate, which
  the source does not carry, comes from a maintained 20-row seed table keyed by
  map. Missing input is an error - no partial output is written. Deterministic
  and idempotent: re-running against the same checkout produces an identical
  file.
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
    src = Path.join([rathena, "db", "re", "castle_db.yml"])

    castles = src |> read_body!() |> build()

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

  defp fe_castle?(%{"Type" => "First_Edition", "Map" => map}),
    do: Map.has_key?(@emperium_rooms, map)

  defp fe_castle?(_), do: false

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

  defp read_body!(path) do
    unless File.exists?(path), do: Mix.raise("missing input file: #{path}")

    case YamlElixir.read_from_file!(path) do
      %{"Body" => body} when is_list(body) -> body
      _ -> Mix.raise("expected a Body list in #{path}")
    end
  end

  defp write!(path, entries), do: File.write!(path, Ymlr.document!(entries))
end
