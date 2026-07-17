defmodule Aesir.ZoneServer.Unit.Player.Handlers.SkillMenuHandler do
  @moduledoc """
  The generic "server offers a list of ids, client picks one" exchange behind the
  skills that open a selection widget (`SA_AUTOSPELL`, `SA_CREATECON`, and the
  future forging/brewing menus).

  `open/5` sends the `SkillMenu` offer and parks it on the session's
  `pending_skill_menu` — the equivalent of rAthena's `menuskill_id`/`menuskill_val`
  pair. `handle_reply/2` accepts exactly the reply that answers the parked offer
  and clears it; anything else (no pending menu, a different `src_skill_id`, an
  id outside the offered set) is dropped with a debug log rather than crashing
  the session, since a reply is client input and may be stale or forged.

  The menu is per-session, not persisted: it is cleared on death and on warp
  (`clear/1`), and disconnect discards it with the session process.

  This module owns the transport only. Acting on an accepted selection is the
  job of the skill that opened the menu.
  """

  require Logger

  alias Aesir.Net.SkillMenu
  alias Aesir.Net.SkillMenuReply
  alias Aesir.ZoneServer.Network.MessageRouter

  @typedoc "The offer parked on the session while the client is deciding."
  @type pending :: %{
          skill_id: non_neg_integer(),
          kind: SkillMenu.Kind.t(),
          entry_ids: [non_neg_integer()],
          level: non_neg_integer()
        }

  @doc """
  Offers `entry_ids` to the client on behalf of `skill_id` and parks the offer on
  the session. `level` is the skill level that opened it, carried through so the
  consumer of the reply does not have to re-read it.

  Replaces any menu already pending: the newest offer is the only one the client
  is showing, and rAthena likewise keeps a single `menuskill_id`.
  """
  @spec open(
          map(),
          non_neg_integer(),
          SkillMenu.Kind.t(),
          [non_neg_integer()],
          non_neg_integer()
        ) :: map()
  def open(state, skill_id, kind, entry_ids, level) do
    MessageRouter.send_to(state.connection_pid, %SkillMenu{
      src_skill_id: skill_id,
      kind: kind,
      entry_ids: entry_ids
    })

    %{
      state
      | pending_skill_menu: %{skill_id: skill_id, kind: kind, entry_ids: entry_ids, level: level}
    }
  end

  @doc """
  Drops the pending menu, if any. Called from the paths that invalidate an open
  menu: death and warp/map change.
  """
  @spec clear(map()) :: map()
  def clear(state), do: Map.put(state, :pending_skill_menu, nil)

  @doc """
  Handles a client `SkillMenuReply` against the pending menu.

  Validates that the reply answers the parked offer and that the selection is one
  of the offered ids; `selected_id: 0` cancels. Always returns `{:noreply, state}`.
  """
  @spec handle_reply(SkillMenuReply.t(), map()) :: {:noreply, map()}
  def handle_reply(%SkillMenuReply{} = reply, %{pending_skill_menu: nil} = state) do
    debug_drop(state, "no menu is pending", reply)
    {:noreply, state}
  end

  def handle_reply(
        %SkillMenuReply{src_skill_id: src_skill_id} = reply,
        %{pending_skill_menu: %{skill_id: pending_skill_id}} = state
      )
      when src_skill_id != pending_skill_id do
    debug_drop(state, "pending menu is skill #{pending_skill_id}", reply)
    {:noreply, state}
  end

  def handle_reply(%SkillMenuReply{selected_id: 0}, state) do
    {:noreply, clear(state)}
  end

  def handle_reply(
        %SkillMenuReply{selected_id: selected_id} = reply,
        %{pending_skill_menu: %{entry_ids: entry_ids}} = state
      ) do
    if selected_id in entry_ids do
      {:noreply, clear(state)}
    else
      debug_drop(state, "#{selected_id} was not offered", reply)
      {:noreply, state}
    end
  end

  defp debug_drop(state, reason, reply) do
    Logger.debug(
      "Dropping SkillMenuReply #{inspect(reply)} for player " <>
        "#{state.game_state.character_id}: #{reason}"
    )
  end
end
