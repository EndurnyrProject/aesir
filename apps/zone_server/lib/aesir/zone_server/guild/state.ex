defmodule Aesir.ZoneServer.Guild.State do
  @moduledoc """
  Runtime value stored under the `{:guild, guild_id}` Horde entry. Pure data
  plus small pure helpers; process ownership and mutation live in
  `Aesir.ZoneServer.Guild.Manager`.

  The emblem blob is intentionally not held here: it lives only in Postgres
  and is fetched on demand. Only the `emblem_id` version counter is carried.
  """
  use TypedStruct

  alias Aesir.ZoneServer.Guild.Member
  alias Aesir.ZoneServer.Guild.Position

  @max_members 16

  typedstruct do
    field :guild_id, non_neg_integer(), enforce: true
    field :name, String.t(), enforce: true
    field :master_char_id, non_neg_integer(), enforce: true
    field :emblem_id, non_neg_integer(), default: 0
    field :notice, %{subject: String.t(), body: String.t()}, default: %{subject: "", body: ""}
    field :positions, %{non_neg_integer() => Position.t()}, default: %{}
    field :members, %{non_neg_integer() => Member.t()}, default: %{}
  end

  @doc "Total number of members, online or offline."
  @spec member_count(t()) :: non_neg_integer()
  def member_count(%__MODULE__{members: members}), do: map_size(members)

  @doc "Whether the guild is at the fixed member cap (16)."
  @spec full?(t()) :: boolean()
  def full?(%__MODULE__{} = state), do: member_count(state) >= @max_members

  @doc "The `Position` a member currently holds, or `nil` if not a member."
  @spec position_of(t(), non_neg_integer()) :: Position.t() | nil
  def position_of(%__MODULE__{members: members, positions: positions}, char_id) do
    case Map.get(members, char_id) do
      %Member{position_index: index} -> Map.get(positions, index)
      nil -> nil
    end
  end
end
