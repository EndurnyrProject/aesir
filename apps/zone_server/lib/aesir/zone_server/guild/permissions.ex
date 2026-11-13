defmodule Aesir.ZoneServer.Guild.Permissions do
  @moduledoc """
  Resolves whether a guild member may perform an action. This is the
  structural replacement for party's inline `leader_char_id == requester`
  check: the master (position index 0, `master_char_id`) is always allowed,
  and every other member is gated by the flags of the position they hold.

  Gating:

    * `:emblem`, `:positions`, `:assign` — master only (no position flag
      exists for these)
    * `:invite` — the member's position `can_invite`
    * `:expel` — the member's position `can_expel`
    * `:storage` — the member's position `can_storage`
    * `:notice` — the member's position `can_notice`
    * `:relations` — the member's position `can_relations` (requesting and
      breaking alliances, declaring and removing antagonists)

  A non-member is always denied.
  """
  alias Aesir.ZoneServer.Guild.Position
  alias Aesir.ZoneServer.Guild.State

  @type action ::
          :invite | :expel | :storage | :notice | :relations | :emblem | :positions | :assign

  @master_only [:emblem, :positions, :assign]

  @doc "Whether `char_id` may perform `action` in `state`."
  @spec can?(State.t(), non_neg_integer(), action()) :: boolean()
  def can?(%State{master_char_id: char_id}, char_id, _action), do: true

  def can?(%State{members: members} = state, char_id, action) do
    case Map.get(members, char_id) do
      nil -> false
      _member -> allowed?(State.position_of(state, char_id), action)
    end
  end

  @spec allowed?(Position.t() | nil, action()) :: boolean()
  defp allowed?(_position, action) when action in @master_only, do: false
  defp allowed?(%Position{can_invite: allowed}, :invite), do: allowed
  defp allowed?(%Position{can_expel: allowed}, :expel), do: allowed
  defp allowed?(%Position{can_storage: allowed}, :storage), do: allowed
  defp allowed?(%Position{can_notice: allowed}, :notice), do: allowed
  defp allowed?(%Position{can_relations: allowed}, :relations), do: allowed
  defp allowed?(nil, _action), do: false
end
