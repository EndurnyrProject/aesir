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
  alias Aesir.ZoneServer.Guild.Relation

  @base_members 16
  @members_per_extension 6
  @gd_extension 10_004

  @enforce_keys [:guild_id, :name, :master_char_id]
  defstruct guild_id: nil,
            name: nil,
            master_char_id: nil,
            emblem_id: 0,
            notice: %{subject: "", body: ""},
            positions: %{},
            members: %{},
            level: 1,
            exp: 0,
            skill_points: 0,
            learned_skills: %{},
            skill_cooldowns: %{},
            relations: %{}

  @type t() :: %__MODULE__{
          guild_id: non_neg_integer(),
          name: String.t(),
          master_char_id: non_neg_integer(),
          emblem_id: non_neg_integer(),
          notice: %{subject: String.t(), body: String.t()},
          positions: %{non_neg_integer() => Position.t()},
          members: %{non_neg_integer() => Member.t()},
          level: pos_integer(),
          exp: non_neg_integer(),
          skill_points: non_neg_integer(),
          learned_skills: %{non_neg_integer() => pos_integer()},
          skill_cooldowns: %{non_neg_integer() => integer()},
          relations: %{pos_integer() => Relation.t()}
        }

  @doc "Total number of members, online or offline."
  @spec member_count(t()) :: non_neg_integer()
  def member_count(%__MODULE__{members: members}), do: map_size(members)

  @doc "Member capacity: 16 base plus 6 per Guild Extension level."
  @spec max_members(t()) :: pos_integer()
  def max_members(%__MODULE__{} = state) do
    @base_members + @members_per_extension * skill_level(state, @gd_extension)
  end

  @doc "Whether the guild is at its current member capacity."
  @spec full?(t()) :: boolean()
  def full?(%__MODULE__{} = state), do: member_count(state) >= max_members(state)

  @doc "The guild's learned level for a guild skill, `0` when unlearned."
  @spec skill_level(t(), non_neg_integer()) :: non_neg_integer()
  def skill_level(%__MODULE__{learned_skills: skills}, skill_id),
    do: Map.get(skills, skill_id, 0)

  @doc "The `Position` a member currently holds, or `nil` if not a member."
  @spec position_of(t(), non_neg_integer()) :: Position.t() | nil
  def position_of(%__MODULE__{members: members, positions: positions}, char_id) do
    case Map.get(members, char_id) do
      %Member{position_index: index} -> Map.get(positions, index)
      nil -> nil
    end
  end

  @doc "This guild's allies."
  @spec allies(t()) :: [Relation.t()]
  def allies(%__MODULE__{} = state), do: relations_of_kind(state, :ally)

  @doc "This guild's antagonists."
  @spec antagonists(t()) :: [Relation.t()]
  def antagonists(%__MODULE__{} = state), do: relations_of_kind(state, :antagonist)

  @doc "Whether `other_guild_id` is one of this guild's allies."
  @spec ally?(t(), non_neg_integer() | nil) :: boolean()
  def ally?(_state, nil), do: false

  def ally?(%__MODULE__{relations: relations}, other_guild_id) do
    match?(%Relation{kind: :ally}, Map.get(relations, other_guild_id))
  end

  @doc "Number of relations of the given kind."
  @spec relation_count(t(), Relation.kind()) :: non_neg_integer()
  def relation_count(%__MODULE__{} = state, kind) do
    state |> relations_of_kind(kind) |> length()
  end

  defp relations_of_kind(%__MODULE__{relations: relations}, kind) do
    relations
    |> Map.values()
    |> Enum.filter(&(&1.kind == kind))
  end
end
