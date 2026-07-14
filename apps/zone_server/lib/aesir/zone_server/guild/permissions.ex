defmodule Aesir.ZoneServer.Guild.Permissions do
  @moduledoc """
  Resolves whether a guild member may perform an action. This is the
  structural replacement for party's inline `leader_char_id == requester`
  check: the master (position index 0, `master_char_id`) is always allowed,
  and every other member is gated by the flags of the position they hold.

  Phase 1 gating:

    * `:emblem`, `:positions`, `:assign`, `:notice` — master only (no position
      flag exists for these yet)
    * `:invite` — the member's position `can_invite`
    * `:expel` — the member's position `can_expel`

  A non-member is always denied.
  """
  alias Aesir.ZoneServer.Guild.Position
  alias Aesir.ZoneServer.Guild.State

  @type action :: :invite | :expel | :emblem | :notice | :positions | :assign

  @master_only [:emblem, :notice, :positions, :assign]

  @doc "Whether `char_id` may perform `action` in `state`."
  @spec can?(State.t(), non_neg_integer(), action()) :: boolean()
  def can?(%State{master_char_id: char_id}, char_id, _action), do: true

  def can?(%State{members: members} = state, char_id, action) do
    case Map.get(members, char_id) do
      nil -> false
      _member -> allowed?(state, char_id, action)
    end
  end

  @spec allowed?(State.t(), non_neg_integer(), action()) :: boolean()
  defp allowed?(_state, _char_id, action) when action in @master_only, do: false

  defp allowed?(state, char_id, :invite) do
    match?(%Position{can_invite: true}, State.position_of(state, char_id))
  end

  defp allowed?(state, char_id, :expel) do
    match?(%Position{can_expel: true}, State.position_of(state, char_id))
  end
end
