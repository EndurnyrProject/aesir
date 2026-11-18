defmodule Aesir.ZoneServer.Guild.State do
  @moduledoc """
  Runtime value stored under the `{:guild, guild_id}` Horde entry. Pure data
  plus small pure helpers; process ownership and mutation live in
  `Aesir.ZoneServer.Guild.Manager`.

  The emblem blob is intentionally not held here: it lives only in Postgres
  and is fetched on demand. Only the `emblem_id` version counter is carried.

  `notice_author`/`notice_posted_at` (unix seconds) say who last edited the
  notice and when, `""` and `0` until the first edit. `activity` is the newest
  entries of the guild's activity log, newest first.
  """

  use TypedStruct

  alias Aesir.ZoneServer.Guild.Activity
  alias Aesir.ZoneServer.Guild.Member
  alias Aesir.ZoneServer.Guild.Position
  alias Aesir.ZoneServer.Guild.Relation

  @base_members 16
  @members_per_extension 6
  @gd_extension 10_004

  typedstruct do
    field :guild_id, non_neg_integer(), enforce: true
    field :name, String.t(), enforce: true
    field :master_char_id, non_neg_integer(), enforce: true
    field :emblem_id, non_neg_integer(), default: 0
    field :notice, %{subject: String.t(), body: String.t()}, default: %{subject: "", body: ""}
    field :notice_author, String.t(), default: ""
    field :notice_posted_at, non_neg_integer(), default: 0
    field :positions, %{non_neg_integer() => Position.t()}, default: %{}
    field :members, %{non_neg_integer() => Member.t()}, default: %{}
    field :level, pos_integer(), default: 1
    field :exp, non_neg_integer(), default: 0
    field :skill_points, non_neg_integer(), default: 0
    field :learned_skills, %{non_neg_integer() => pos_integer()}, default: %{}
    field :relations, %{pos_integer() => Relation.t()}, default: %{}
    field :activity, [Activity.t()], default: []
  end

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

  @doc "Members in slot order, the order the guild's member list is walked in."
  @spec members_by_slot(t()) :: [Member.t()]
  def members_by_slot(%__MODULE__{members: members}),
    do: members |> Map.values() |> Enum.sort_by(& &1.slot)

  @doc "The lowest slot no member holds."
  @spec free_slot(t()) :: non_neg_integer()
  def free_slot(%__MODULE__{members: members}) do
    taken = MapSet.new(members, fn {_char_id, member} -> member.slot end)
    Enum.find(Stream.iterate(0, &(&1 + 1)), &(not MapSet.member?(taken, &1)))
  end

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

  @doc "Whether `other_guild_id` is one of this guild's allies."
  @spec ally?(t(), non_neg_integer() | nil) :: boolean()
  def ally?(_state, nil), do: false

  def ally?(%__MODULE__{relations: relations}, other_guild_id) do
    match?(%Relation{kind: :ally}, Map.get(relations, other_guild_id))
  end
end
