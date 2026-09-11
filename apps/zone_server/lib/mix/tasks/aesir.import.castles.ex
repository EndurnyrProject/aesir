defmodule Mix.Tasks.Aesir.Import.Castles do
  @shortdoc "Imports mode-selected WoE First-Edition castle data"
  @moduledoc """
  Converts the mode-selected `castle_db.yml` First-Edition castles into
  our-schema YAML under `apps/zone_server/priv/db/<mode>/castles/fe.yml`.

      mix aesir.import.castles [<rathena_root>] [--mode re|pre-re]

  `<rathena_root>` defaults to `../rathena`. Only the 20 First-Edition castles
  (aldeg/gefg/payg/prtg_cas01-05) are kept. The Emperium-room coordinate and the
  treasure room (box id pair and its 24 cells) come from maintained 20-row seed
  tables keyed by map. Canonical pre-renewal rows
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

  @treasure_rooms %{
    "aldeg_cas01" => %{
      box_id: 1324,
      cells: [
        [115, 226],
        [122, 226],
        [115, 219],
        [122, 219],
        [116, 225],
        [117, 225],
        [118, 225],
        [119, 225],
        [120, 225],
        [121, 225],
        [121, 224],
        [121, 223],
        [121, 222],
        [121, 221],
        [121, 220],
        [120, 220],
        [119, 220],
        [118, 220],
        [117, 220],
        [116, 220],
        [116, 221],
        [116, 222],
        [116, 223],
        [116, 224]
      ]
    },
    "aldeg_cas02" => %{
      box_id: 1326,
      cells: [
        [134, 231],
        [135, 231],
        [135, 230],
        [134, 230],
        [132, 233],
        [133, 233],
        [134, 233],
        [135, 233],
        [136, 233],
        [137, 233],
        [137, 232],
        [137, 231],
        [137, 230],
        [137, 229],
        [137, 228],
        [136, 228],
        [135, 228],
        [134, 228],
        [133, 228],
        [132, 228],
        [132, 229],
        [132, 230],
        [132, 231],
        [132, 232]
      ]
    },
    "aldeg_cas03" => %{
      box_id: 1328,
      cells: [
        [224, 269],
        [225, 269],
        [225, 268],
        [224, 268],
        [222, 271],
        [223, 271],
        [224, 271],
        [225, 271],
        [226, 271],
        [227, 271],
        [227, 270],
        [227, 269],
        [227, 268],
        [227, 267],
        [227, 266],
        [226, 266],
        [225, 266],
        [224, 266],
        [223, 266],
        [222, 266],
        [222, 267],
        [222, 268],
        [222, 269],
        [222, 270]
      ]
    },
    "aldeg_cas04" => %{
      box_id: 1330,
      cells: [
        [84, 13],
        [85, 13],
        [85, 12],
        [84, 12],
        [82, 15],
        [83, 15],
        [84, 15],
        [85, 15],
        [86, 15],
        [87, 15],
        [87, 14],
        [87, 13],
        [87, 12],
        [87, 11],
        [87, 10],
        [86, 10],
        [85, 10],
        [84, 10],
        [83, 10],
        [82, 10],
        [82, 11],
        [82, 12],
        [82, 13],
        [82, 14]
      ]
    },
    "aldeg_cas05" => %{
      box_id: 1332,
      cells: [
        [61, 12],
        [62, 12],
        [62, 11],
        [61, 11],
        [59, 14],
        [60, 14],
        [61, 14],
        [62, 14],
        [63, 14],
        [64, 14],
        [64, 13],
        [64, 12],
        [64, 11],
        [64, 10],
        [64, 9],
        [63, 9],
        [62, 9],
        [61, 9],
        [60, 9],
        [59, 9],
        [59, 10],
        [59, 11],
        [59, 12],
        [59, 13]
      ]
    },
    "gefg_cas01" => %{
      box_id: 1334,
      cells: [
        [153, 113],
        [154, 113],
        [154, 112],
        [153, 112],
        [151, 115],
        [152, 115],
        [153, 115],
        [154, 115],
        [155, 115],
        [156, 115],
        [156, 114],
        [156, 113],
        [156, 112],
        [156, 111],
        [156, 110],
        [155, 110],
        [154, 110],
        [153, 110],
        [152, 110],
        [151, 110],
        [151, 111],
        [151, 112],
        [151, 113],
        [151, 114]
      ]
    },
    "gefg_cas02" => %{
      box_id: 1336,
      cells: [
        [139, 115],
        [140, 115],
        [140, 114],
        [139, 114],
        [137, 117],
        [138, 117],
        [139, 117],
        [140, 117],
        [141, 117],
        [142, 117],
        [142, 116],
        [142, 115],
        [142, 114],
        [142, 113],
        [142, 112],
        [141, 112],
        [140, 112],
        [139, 112],
        [138, 112],
        [137, 112],
        [137, 113],
        [137, 114],
        [137, 115],
        [137, 116]
      ]
    },
    "gefg_cas03" => %{
      box_id: 1338,
      cells: [
        [269, 291],
        [270, 291],
        [270, 290],
        [269, 290],
        [267, 293],
        [268, 293],
        [269, 293],
        [270, 293],
        [271, 293],
        [272, 293],
        [272, 292],
        [272, 291],
        [272, 290],
        [272, 289],
        [272, 288],
        [271, 288],
        [270, 288],
        [269, 288],
        [268, 288],
        [267, 288],
        [267, 289],
        [267, 290],
        [267, 291],
        [267, 292]
      ]
    },
    "gefg_cas04" => %{
      box_id: 1340,
      cells: [
        [115, 119],
        [116, 119],
        [116, 118],
        [115, 118],
        [113, 121],
        [114, 121],
        [115, 121],
        [116, 121],
        [117, 121],
        [118, 121],
        [118, 120],
        [118, 119],
        [118, 118],
        [118, 117],
        [118, 116],
        [117, 116],
        [116, 116],
        [115, 116],
        [114, 116],
        [113, 116],
        [113, 117],
        [113, 118],
        [113, 119],
        [113, 120]
      ]
    },
    "gefg_cas05" => %{
      box_id: 1342,
      cells: [
        [143, 110],
        [144, 110],
        [144, 109],
        [143, 109],
        [141, 112],
        [142, 112],
        [143, 112],
        [144, 112],
        [145, 112],
        [146, 112],
        [146, 111],
        [146, 110],
        [146, 109],
        [146, 108],
        [146, 107],
        [145, 107],
        [144, 107],
        [143, 107],
        [142, 107],
        [141, 107],
        [141, 108],
        [141, 109],
        [141, 110],
        [141, 111]
      ]
    },
    "payg_cas01" => %{
      box_id: 1344,
      cells: [
        [289, 10],
        [292, 10],
        [292, 7],
        [289, 7],
        [288, 11],
        [289, 11],
        [290, 11],
        [291, 11],
        [292, 11],
        [293, 11],
        [293, 10],
        [293, 9],
        [293, 8],
        [293, 7],
        [293, 6],
        [292, 6],
        [291, 6],
        [290, 6],
        [289, 6],
        [288, 6],
        [288, 7],
        [288, 8],
        [288, 9],
        [288, 10]
      ]
    },
    "payg_cas02" => %{
      box_id: 1346,
      cells: [
        [143, 146],
        [146, 146],
        [146, 143],
        [143, 143],
        [142, 147],
        [143, 147],
        [144, 147],
        [145, 147],
        [146, 147],
        [147, 147],
        [147, 146],
        [147, 145],
        [147, 144],
        [147, 143],
        [147, 142],
        [146, 142],
        [145, 142],
        [144, 142],
        [143, 142],
        [142, 142],
        [142, 143],
        [142, 144],
        [142, 145],
        [142, 146]
      ]
    },
    "payg_cas03" => %{
      box_id: 1348,
      cells: [
        [158, 169],
        [159, 169],
        [159, 168],
        [158, 168],
        [156, 171],
        [157, 171],
        [158, 171],
        [159, 171],
        [160, 171],
        [161, 171],
        [161, 170],
        [161, 169],
        [161, 168],
        [161, 167],
        [161, 166],
        [160, 166],
        [159, 166],
        [158, 166],
        [157, 166],
        [156, 166],
        [156, 167],
        [156, 168],
        [156, 169],
        [156, 170]
      ]
    },
    "payg_cas04" => %{
      box_id: 1350,
      cells: [
        [146, 48],
        [147, 48],
        [147, 47],
        [146, 47],
        [144, 50],
        [145, 50],
        [146, 50],
        [147, 50],
        [148, 50],
        [149, 50],
        [149, 49],
        [149, 48],
        [149, 47],
        [149, 46],
        [149, 45],
        [148, 45],
        [147, 45],
        [146, 45],
        [145, 45],
        [144, 45],
        [144, 46],
        [144, 47],
        [144, 48],
        [144, 49]
      ]
    },
    "payg_cas05" => %{
      box_id: 1352,
      cells: [
        [155, 134],
        [158, 134],
        [158, 131],
        [155, 131],
        [154, 135],
        [155, 135],
        [156, 135],
        [157, 135],
        [158, 135],
        [159, 135],
        [159, 134],
        [159, 133],
        [159, 132],
        [159, 131],
        [159, 130],
        [158, 130],
        [157, 130],
        [156, 130],
        [155, 130],
        [154, 130],
        [154, 131],
        [154, 132],
        [154, 133],
        [154, 134]
      ]
    },
    "prtg_cas01" => %{
      box_id: 1354,
      cells: [
        [10, 209],
        [11, 209],
        [11, 208],
        [10, 208],
        [8, 211],
        [9, 211],
        [10, 211],
        [11, 211],
        [12, 211],
        [13, 211],
        [13, 210],
        [13, 209],
        [13, 208],
        [13, 207],
        [13, 206],
        [12, 206],
        [11, 206],
        [10, 206],
        [9, 206],
        [8, 206],
        [8, 207],
        [8, 208],
        [8, 209],
        [8, 210]
      ]
    },
    "prtg_cas02" => %{
      box_id: 1356,
      cells: [
        [201, 228],
        [202, 228],
        [202, 227],
        [201, 227],
        [199, 230],
        [200, 230],
        [201, 230],
        [202, 230],
        [203, 230],
        [204, 230],
        [204, 229],
        [204, 228],
        [204, 227],
        [204, 226],
        [204, 225],
        [203, 225],
        [202, 225],
        [201, 225],
        [200, 225],
        [199, 225],
        [199, 226],
        [199, 227],
        [199, 228],
        [199, 229]
      ]
    },
    "prtg_cas03" => %{
      box_id: 1358,
      cells: [
        [187, 132],
        [188, 132],
        [188, 131],
        [187, 131],
        [185, 134],
        [186, 134],
        [187, 134],
        [188, 134],
        [189, 134],
        [190, 134],
        [190, 133],
        [190, 132],
        [190, 131],
        [190, 130],
        [190, 129],
        [189, 129],
        [188, 129],
        [187, 129],
        [186, 129],
        [185, 129],
        [185, 130],
        [185, 131],
        [185, 132],
        [185, 133]
      ]
    },
    "prtg_cas04" => %{
      box_id: 1360,
      cells: [
        [269, 162],
        [270, 162],
        [270, 161],
        [269, 161],
        [267, 164],
        [268, 164],
        [269, 164],
        [270, 164],
        [271, 164],
        [272, 164],
        [272, 163],
        [272, 162],
        [272, 161],
        [272, 160],
        [272, 159],
        [271, 159],
        [270, 159],
        [269, 159],
        [268, 159],
        [267, 159],
        [267, 160],
        [267, 161],
        [267, 162],
        [267, 163]
      ]
    },
    "prtg_cas05" => %{
      box_id: 1362,
      cells: [
        [275, 178],
        [276, 178],
        [276, 177],
        [275, 177],
        [273, 180],
        [274, 180],
        [275, 180],
        [276, 180],
        [277, 180],
        [278, 180],
        [278, 179],
        [278, 178],
        [278, 177],
        [278, 176],
        [278, 175],
        [277, 175],
        [276, 175],
        [275, 175],
        [274, 175],
        [273, 175],
        [273, 176],
        [273, 177],
        [273, 178],
        [273, 179]
      ]
    }
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
      emperium: Map.fetch!(@emperium_rooms, map),
      treasure: Map.fetch!(@treasure_rooms, map)
    }
  end

  defp write!(path, entries), do: File.write!(path, Ymlr.document!(entries))
end
