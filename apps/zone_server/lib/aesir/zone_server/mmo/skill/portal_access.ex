defmodule Aesir.ZoneServer.Mmo.Skill.PortalAccess do
  @moduledoc "Mode-scoped memo flags, account warp permissions and job-entry restrictions."

  import Bitwise

  alias Aesir.Commons.Auth
  alias Aesir.ZoneServer.Db.Source
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.JobManagement.Jobs
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @key __MODULE__
  @flags [:nomemo, :nowarpto, :gvg_te, :gvg_te_castle]

  @doc "Reloads the mode-scoped portal access data."
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@key, load())
    :ok
  end

  @doc "Returns static memo and training-edition flags for the shared map flag layer."
  @spec map_flags() :: %{String.t() => map()}
  def map_flags do
    Map.new(index()["maps"], fn {map, values} ->
      flags =
        for flag <- @flags,
            Map.has_key?(values, Atom.to_string(flag)),
            into: %{},
            do: {flag, Map.fetch!(values, Atom.to_string(flag))}

      {map, flags}
    end)
  end

  @doc "Returns the account group's effective warp permission and ranking level."
  @spec permissions(PlayerState.t()) :: %{any_warp: boolean(), level: non_neg_integer()}
  def permissions(%PlayerState{account_id: account_id}) do
    group_id = if account_id, do: Auth.get_account!(account_id).group_id, else: 0
    group = Map.get(index()["groups"], to_string(group_id), %{})
    %{any_warp: Map.get(group, "any_warp", false), level: Map.get(group, "level", 0)}
  end

  @doc "Checks the destination's map data and the entering player's job restriction."
  @spec allowed?(PlayerState.t(), String.t()) :: boolean()
  def allowed?(%PlayerState{} = player, map_name) do
    case MapCache.get(map_name) do
      {:error, :not_found} -> true
      {:ok, map} -> allowed_on_map?(player, map_name, map)
    end
  end

  defp allowed_on_map?(player, map_name, map) do
    job_id = player_job_id(player.stats)

    with true <- is_binary(map.cells),
         {:ok, _job} <- Jobs.by_id(job_id) do
      restriction = Map.get(index()["jobs"], to_string(job_id), %{})
      level = if restriction == %{}, do: 0, else: permissions(player).level
      static_zone = get_in(index(), ["maps", map_name, "zone"]) || 0
      job_allowed?(restriction, level, MapFlags.flags(map_name), static_zone ||| (map.zone || 0))
    else
      _ -> false
    end
  end

  defp player_job_id(%{progression: %{job_id: id}}) when is_integer(id), do: id
  defp player_job_id(_stats), do: 0

  @doc "Evaluates a job's zone mask, including the strict group-level bypass."
  @spec job_allowed?(map(), non_neg_integer(), map(), non_neg_integer()) :: boolean()
  def job_allowed?(restriction, group_level, flags, zone) do
    mask = Map.get(restriction, "zone", 0)
    bypass = Map.get(restriction, "group_level", 0)
    te? = Enum.any?([:gvg_te, :gvg_te_castle], &Map.get(flags, &1, false))
    gvg? = Enum.any?([:gvg, :gvg_castle], &Map.get(flags, &1, false))
    pvp? = Map.get(flags, :pvp, false)
    battleground? = Map.get(flags, :battleground, false)
    normal? = not Enum.any?([pvp?, gvg?, te?, battleground?])
    zones = [{1, normal?}, {2, pvp?}, {4, gvg?}, {8, battleground?}, {16, te?}, {zone, true}]
    restricted? = Enum.any?(zones, fn {bits, active?} -> active? and band(mask, bits) != 0 end)

    mask == 0 or group_level > bypass or not restricted?
  end

  defp index do
    case :persistent_term.get(@key, nil) do
      nil ->
        data = load()
        :persistent_term.put(@key, data)
        data

      data ->
        data
    end
  end

  defp load do
    "portal_access.yml"
    |> Source.sources()
    |> Enum.map(&YamlElixir.read_from_file!/1)
    |> Enum.reduce(%{"maps" => %{}, "jobs" => %{}, "groups" => %{}}, fn data, acc ->
      Map.merge(acc, data, fn _key, old, new -> Map.merge(old, new) end)
    end)
  end
end
