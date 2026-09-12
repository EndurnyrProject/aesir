defmodule Aesir.ZoneServer.Content.Npc.Woe.FlagOwner do
  @moduledoc """
  Shared owner-resolution helpers for the castle flag NPCs
  (`OutsideFlag`/`InsideFlag`): both display the owning guild's emblem
  through `guild_id/1`, and a flag's own castle map is recovered from the
  hidden fragment of its `unique_name` rather than its `map` (outside flags
  stand on the shared guild field map, not the castle itself).
  """

  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Npc.Placement

  @doc """
  Recovers the castle map from a flag's `"<name>#<map>#<n>"` unique name.
  """
  @spec castle_map(Placement.t()) :: {:ok, String.t()} | :error
  def castle_map(%Placement{unique_name: unique_name}) do
    case String.split(unique_name, "#") do
      [_name, map, _index] -> {:ok, map}
      _other -> :error
    end
  end

  @doc """
  The id of the guild currently owning the flag's castle, `0` when the
  castle is unowned or the unique name does not resolve to an FE castle map.
  """
  @spec guild_id(Placement.t()) :: non_neg_integer()
  def guild_id(%Placement{} = placement) do
    with {:ok, map} <- castle_map(placement),
         {:ok, castle} <- CastleDb.by_map(map) do
      CastleStore.owner(castle.id) || 0
    else
      :error -> 0
    end
  end
end
