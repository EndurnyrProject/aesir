defmodule Aesir.ZoneServer.Guild.Identity do
  @moduledoc """
  Resolves a guild id to the identity triple spawn packets carry for both
  players and NPCs (`guild_id`, `guild_name`, `emblem_id`).
  """

  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState

  @doc """
  Resolves `guild_id` for a spawn packet. A guild-less unit (`guild_id` `0`)
  or a stale/non-live guild entry defaults to an empty name and emblem `0`;
  the real `guild_id` is still carried for a member whose entry is not live.
  """
  @spec resolve(non_neg_integer()) :: {non_neg_integer(), String.t(), non_neg_integer()}
  def resolve(0), do: {0, "", 0}

  def resolve(guild_id) do
    case GuildManager.get(guild_id) do
      {:ok, %GuildState{name: name, emblem_id: emblem_id}} -> {guild_id, name, emblem_id}
      {:error, :not_found} -> {guild_id, "", 0}
    end
  end
end
