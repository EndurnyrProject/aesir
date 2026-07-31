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

  This module owns the transport only. An accepted selection is routed back to
  the skill that opened the menu through its `Skill.Menu` capability, which does
  the acting.
  """

  require Logger

  alias Aesir.Net.ProductionResult
  alias Aesir.Net.SkillMenu
  alias Aesir.Net.SkillMenuReply
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryStaging
  alias Aesir.ZoneServer.Unit.Player.SessionState

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
    if SessionState.interaction_blocked?(state) do
      state
    else
      MessageRouter.send_to(state.connection_pid, %SkillMenu{
        src_skill_id: skill_id,
        kind: kind,
        entry_ids: entry_ids
      })

      %{
        state
        | pending_skill_menu: %{
            skill_id: skill_id,
            kind: kind,
            entry_ids: entry_ids,
            level: level
          }
      }
    end
  end

  @doc """
  Drops the pending menu, if any. Called from the paths that invalidate an open
  menu: death and warp/map change.

  The warp path is also reached from the script DSL, which builds a partial
  session map (`game_state` + `connection_pid`) rather than a `SessionState`, so
  this leaves a session without the key untouched instead of raising - the same
  tolerance `SkillTextInputHandler.clear/1` has for that caller.
  """
  @spec clear(SessionState.t() | map()) :: SessionState.t() | map()
  def clear(state), do: Map.replace(state, :pending_skill_menu, nil)

  @doc """
  Handles a client `SkillMenuReply` against the pending menu.

  Validates that the reply answers the parked offer and that the selection is one
  of the offered ids, then hands the selection to the skill that opened the menu;
  `selected_id: 0` cancels without running it. Always returns `{:noreply, state}`.
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
      selection = %{id: selected_id, extras: reply.extra_ids}
      {:noreply, accept(state, selection)}
    else
      debug_drop(state, "#{selected_id} was not offered", reply)
      {:noreply, state}
    end
  end

  # The offer is cleared before the skill runs, so a skill that reopens a menu
  # from its own reply parks the new offer rather than having it wiped.
  #
  # The pending `skill_id` was written by the server when it opened the menu, so
  # an unresolvable skill or one lacking the `Skill.Menu` capability is a server
  # bug, not client input, and fails loudly. Only `on_menu_reply/3` returning an
  # error is a real runtime outcome (the selection stopped being valid while the
  # client was deciding); it leaves the session untouched beyond the clear.
  defp accept(
         %{pending_skill_menu: %{skill_id: skill_id, level: level}} = state,
         %{id: selected_id} = selection
       ) do
    cleared = clear(state)

    case menu_module(skill_id).on_menu_reply(state.game_state, selection, level) do
      {:ok, game_state} ->
        game_state = InventoryStaging.drain(state.connection_pid, game_state)
        %{cleared | game_state: drain_production_result(state.connection_pid, game_state)}

      {:error, reason} ->
        Logger.debug(
          "Skill #{skill_id} rejected menu selection #{selected_id} for player " <>
            "#{state.game_state.character_id}: #{inspect(reason)}"
        )

        cleared
    end
  end

  defp drain_production_result(_connection_pid, %{pending_production_result: nil} = game_state),
    do: game_state

  defp drain_production_result(
         connection_pid,
         %{pending_production_result: %{success: success, item_id: item_id}} = game_state
       ) do
    MessageRouter.send_to(connection_pid, %ProductionResult{success: success, item_id: item_id})
    %{game_state | pending_production_result: nil}
  end

  defp menu_module(skill_id) do
    with {:ok, definition} <- Catalog.by_id(skill_id),
         {:ok, module} <- Catalog.menu_module_for(definition.name) do
      module
    else
      :error ->
        raise "skill #{skill_id} parked a SkillMenu but provides no Skill.Menu capability"
    end
  end

  defp debug_drop(state, reason, reply) do
    Logger.debug(
      "Dropping SkillMenuReply #{inspect(reply)} for player " <>
        "#{state.game_state.character_id}: #{reason}"
    )
  end
end
