defmodule Aesir.ZoneServer.Guild.State do
  @moduledoc """
  Runtime value stored under the `{:guild, guild_id}` Horde entry. Pure data
  plus small pure helpers; process ownership and mutation live in
  `Aesir.ZoneServer.Guild.Manager`.

  The emblem blob is intentionally not held here: it lives only in Postgres
  and is fetched on demand. Only the `emblem_id` version counter is carried.
  """

  alias Aesir.ZoneServer.Guild.Member
  alias Aesir.ZoneServer.Guild.Position

  @max_members 16

  @enforce_keys [:guild_id, :name, :master_char_id]
  defstruct guild_id: nil,
            name: nil,
            master_char_id: nil,
            emblem_id: 0,
            notice: %{subject: "", body: ""},
            positions: %{},
            members: %{}

  @type t() :: %__MODULE__{
          guild_id: non_neg_integer(),
          name: String.t(),
          master_char_id: non_neg_integer(),
          emblem_id: non_neg_integer(),
          notice: %{subject: String.t(), body: String.t()},
          positions: %{non_neg_integer() => Position.t()},
          members: %{non_neg_integer() => Member.t()}
        }

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
