defmodule Aesir.ZoneServer.Factory do
  @moduledoc """
  ExMachina factories for zone-server runtime structs (values held in memory, never
  inserted). Persisted rows come from `Aesir.Factory`.

      import Aesir.ZoneServer.Factory

      officer = build(:guild_member, position_index: 5)
      guild = build(:guild_state, members: [officer])

  Each factory fills only the enforced keys; everything else keeps its struct default,
  so a test states the fields it cares about.
  """

  use ExMachina

  alias Aesir.ZoneServer.Guild.Member
  alias Aesir.ZoneServer.Guild.State

  @doc """
  A level 1 guild with no members and no master (`master_char_id: 0`); set the master
  when the test reads it. `members:` takes a list of `Member`s and keys them by
  `char_id`, the shape `State.members` holds.
  """
  @spec guild_state_factory(map()) :: State.t()
  def guild_state_factory(attrs) do
    {members, attrs} = Map.pop(attrs, :members, [])

    %State{
      guild_id: sequence(:guild_state_id, & &1, start_at: 1),
      name: sequence(:guild_state_name, &"Guild #{&1}"),
      master_char_id: 0,
      members: Map.new(members, &{&1.char_id, &1})
    }
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  @doc "An online level 1 member at the Newbie position (19)."
  @spec guild_member_factory() :: Member.t()
  def guild_member_factory do
    %Member{
      char_id: sequence(:guild_member_char_id, & &1, start_at: 1),
      name: sequence(:guild_member_name, &"Member #{&1}"),
      base_level: 1,
      online: true
    }
  end
end
