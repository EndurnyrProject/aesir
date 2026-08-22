defmodule Aesir.ZoneServer.Navigation.Target do
  @moduledoc """
  Resolves navigation targets into all acceptable destination candidates.

  Resolution deliberately does not choose among candidates: route cost depends on
  the portal chain, so the router selects the cheapest reachable candidate.
  """

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Navigation.Exclusions
  alias Aesir.ZoneServer.Navigation.SpawnIndex
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @typedoc "A target supplied to server-authoritative navigation."
  @type t ::
          {:coord, String.t(), non_neg_integer(), non_neg_integer()}
          | {:map, String.t()}
          | {:npc, String.t()}
          | {:monster, non_neg_integer()}

  @typedoc "A candidate destination cell, or anywhere on its map."
  @type candidate :: {String.t(), {non_neg_integer(), non_neg_integer()} | :any}

  @typedoc "A target-resolution failure."
  @type error :: :unresolved | :already_there | :excluded

  @doc "Resolves a target to every non-excluded destination candidate."
  @spec resolve(t(), PlayerState.t()) :: {:ok, [candidate(), ...]} | {:error, error()}
  def resolve({:map, map_name}, %PlayerState{map_name: map_name}), do: {:error, :already_there}

  def resolve(target, %PlayerState{}) do
    candidates =
      target
      |> candidates()
      |> Enum.filter(&known_map?/1)
      |> Enum.uniq()

    case candidates do
      [] ->
        {:error, :unresolved}

      _ ->
        case Enum.reject(candidates, &statically_excluded?/1) do
          [] -> {:error, :excluded}
          allowed -> {:ok, allowed}
        end
    end
  end

  @spec candidates(t()) :: [candidate()]
  defp candidates({:coord, map_name, x, y}), do: [{map_name, {x, y}}]
  defp candidates({:map, map_name}), do: [{map_name, :any}]

  defp candidates({:npc, name}) do
    name
    |> npc_placements()
    |> Enum.map(fn %Placement{map: map_name, x: x, y: y} -> {map_name, {x, y}} end)
  end

  defp candidates({:monster, mob_id}) do
    Enum.map(SpawnIndex.maps_for_mob(mob_id), &{&1, :any})
  end

  @spec npc_placements(String.t()) :: [Placement.t()]
  defp npc_placements(name) do
    case Registry.by_name(name) do
      [] -> placements_for_label(name)
      entries -> Enum.map(entries, &elem(&1, 1))
    end
  end

  @spec placements_for_label(String.t()) :: [Placement.t()]
  defp placements_for_label(label) do
    label
    |> Registry.entries_for_label()
    |> Enum.flat_map(fn {_module, gid} ->
      case Registry.module_for_unit(gid) do
        {:ok, {_module, placement}} -> [placement]
        :error -> []
      end
    end)
  end

  @spec known_map?(candidate()) :: boolean()
  defp known_map?({map_name, _destination}), do: MapCache.exists?(map_name)

  @spec statically_excluded?(candidate()) :: boolean()
  defp statically_excluded?({map_name, _destination}),
    do: Exclusions.statically_excluded?(map_name)
end
