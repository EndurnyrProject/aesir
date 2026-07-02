defmodule Aesir.ZoneServer.Party.State do
  @moduledoc """
  Runtime value stored under the `{:party, party_id}` Horde entry (design
  "Runtime state (zone_server)"). Pure data plus small pure helpers; process
  ownership and mutation live in `Aesir.ZoneServer.Party.Manager`.
  """
  use TypedStruct

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Party.Member

  typedstruct do
    field :party_id, non_neg_integer(), enforce: true
    field :name, String.t(), enforce: true
    field :leader_char_id, non_neg_integer(), enforce: true
    field :exp_share, boolean(), enforce: true
    field :members, %{non_neg_integer() => Member.t()}, default: %{}
  end

  @doc "Members currently online."
  @spec online_members(t()) :: [Member.t()]
  def online_members(%__MODULE__{members: members}) do
    members
    |> Map.values()
    |> Enum.filter(& &1.online)
  end

  @doc """
  Base-level spread (max - min) over online members. `0` when fewer than two
  members are online, matching the auto-disable gate (design "Level/presence
  tracking") which only makes sense with two or more comparable levels.
  """
  @spec level_spread(t()) :: non_neg_integer()
  def level_spread(%__MODULE__{} = state) do
    case online_members(state) do
      online when length(online) < 2 ->
        0

      online ->
        {min, max} = Enum.map(online, & &1.base_level) |> Enum.min_max()
        max - min
    end
  end

  @doc "Total number of members, online or offline."
  @spec member_count(t()) :: non_neg_integer()
  def member_count(%__MODULE__{members: members}), do: map_size(members)

  @doc "Whether the party is at `Aesir.ZoneServer.Config.max_party/0` capacity."
  @spec full?(t()) :: boolean()
  def full?(%__MODULE__{} = state) do
    member_count(state) >= Config.max_party()
  end

  @doc """
  Whether `account_id` already owns a character in the party, given a map of
  each existing member's `char_id => account_id`. Account ids live on
  `Character`, not `Party.Member`, so callers (party-mutation code with DB/
  registry access) must supply this mapping; this module stays pure.
  """
  @spec same_account?(%{non_neg_integer() => non_neg_integer()}, non_neg_integer()) :: boolean()
  def same_account?(member_account_ids, account_id) do
    account_id in Map.values(member_account_ids)
  end
end
