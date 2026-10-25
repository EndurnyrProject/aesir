defmodule Mix.Tasks.Aesir.Import.PortalAccess do
  @moduledoc """
  Imports the selected mode's memo-map flags, job-entry restrictions and warp permissions.

      mix aesir.import.portal_access <rathena_root> [--mode re|pre-re]

  Only the portal-required map flags are imported. Enabled NPC configuration
  graphs are traversed in load order, including their map-flag overrides.
  """
  @shortdoc "Imports mode-scoped Warp Portal access data"
  use Mix.Task

  import Bitwise

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Mix.Tasks.Aesir.Import

  @impl Mix.Task
  def run(args) do
    {root, mode} = Import.parse!(args)
    output = Import.path("portal_access.yml", mode)
    data = build(root, mode)
    File.mkdir_p!(Path.dirname(output))
    File.write!(output, Ymlr.Encode.to_s!(data))
    Mix.shell().info("Portal access -> #{output}")
  end

  @doc "Builds access data from a source checkout without writing output."
  @spec build(Path.t(), :renewal | :pre_renewal) :: map()
  def build(root, mode) do
    dir = if mode == :renewal, do: "re", else: "pre-re"
    {files, _seen} = discover(root, "npc/#{dir}/scripts_main.conf", MapSet.new())
    maps = Enum.reduce(files, %{}, &map_flags(&1, root, &2))
    groups = groups(root, "conf/groups.yml", %{})

    %{
      "maps" => maps,
      "jobs" => job_restrictions(Path.join([root, "db", dir, "job_noenter_map.txt"])),
      "groups" =>
        Map.new(groups, fn {id, group} ->
          {to_string(id),
           %{
             "level" => Map.get(group, "Level", 0),
             "any_warp" => any_warp?(id, groups, [])
           }}
        end)
    }
  end

  defp discover(root, path, seen) do
    if MapSet.member?(seen, path) do
      {[], seen}
    else
      discover_file(root, path, MapSet.put(seen, path))
    end
  end

  defp discover_file(root, path, seen) do
    root
    |> Path.join(path)
    |> File.read!()
    |> String.split("\n")
    |> Enum.reduce({[], seen}, fn line, {files, seen} ->
      case Regex.run(~r/^\s*(import|npc):\s*(\S+)/, line) do
        [_, "import", imported] ->
          {added, seen} = discover(root, imported, seen)
          {files ++ added, seen}

        [_, "npc", source] ->
          {files ++ [source], seen}

        _ ->
          {files, seen}
      end
    end)
  end

  defp map_flags(path, root, maps) do
    root
    |> Path.join(path)
    |> File.read!()
    |> String.split("\n")
    |> Enum.reduce(maps, fn line, maps ->
      case Regex.run(
             ~r/^([^\s\/]+)\s+mapflag\s+(nomemo|nowarpto|gvg_te|gvg_te_castle|restricted)(?:\s+(\S+))?/,
             line
           ) do
        [_, map, "restricted", value] ->
          zone = 1 <<< (String.to_integer(value) + 4)

          add_zone(maps, map, zone)

        [_, map, flag | values] ->
          value = values != ["off"]
          Map.update(maps, map, %{flag => value}, &Map.put(&1, flag, value))

        _ ->
          maps
      end
    end)
  end

  defp add_zone(maps, map, zone),
    do:
      Map.update(
        maps,
        map,
        %{"zone" => zone},
        &Map.update(&1, "zone", zone, fn old -> old ||| zone end)
      )

  defp job_restrictions(path) do
    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, jobs ->
      case Regex.run(~r/^\s*(JOB_\w+|\d+)\s*,\s*(\d+)\s*,\s*(\d+)/, line) do
        [_, job, zone, level] ->
          id = job_id!(job)

          Map.put(jobs, to_string(id), %{
            "zone" => String.to_integer(zone),
            "group_level" => String.to_integer(level)
          })

        _ ->
          jobs
      end
    end)
  end

  defp job_id!("JOB_" <> name) do
    name = String.downcase(name)

    Enum.find(AvailableJobs.ids(), fn id ->
      {:ok, atom} = AvailableJobs.job_id_to_name(id)
      Atom.to_string(atom) == name
    end) || raise ArgumentError, "unknown job #{name}"
  end

  defp job_id!(number), do: String.to_integer(number)

  defp groups(root, path, previous) do
    data = YamlElixir.read_from_file!(Path.join(root, path))
    merged = Enum.reduce(data["Body"] || [], previous, &Map.put(&2, &1["Id"], &1))

    Enum.reduce(get_in(data, ["Footer", "Imports"]) || [], merged, fn row, acc ->
      if File.regular?(Path.join(root, row["Path"])),
        do: groups(root, row["Path"], acc),
        else: acc
    end)
  end

  defp any_warp?(id, groups, seen) do
    if id in seen, do: raise(ArgumentError, "group inheritance cycle")
    group = Map.fetch!(groups, id)
    permissions = Map.get(group, "Permissions", %{})

    Map.get(permissions, "any_warp", false) or
      inherited_warp?(group, groups, [id | seen])
  end

  defp inherited_warp?(group, groups, seen) do
    group
    |> Map.get("Inherit", %{})
    |> Enum.filter(fn {_name, enabled} -> enabled end)
    |> Enum.any?(fn {name, _} ->
      {parent_id, _} =
        Enum.find(groups, fn {_id, parent} ->
          String.downcase(parent["Name"]) == String.downcase(name)
        end)

      any_warp?(parent_id, groups, seen)
    end)
  end
end
