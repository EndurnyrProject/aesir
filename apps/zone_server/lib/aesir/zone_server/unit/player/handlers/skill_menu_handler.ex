defmodule Aesir.ZoneServer.Unit.Player.Handlers.SkillMenuHandler do
  @moduledoc """
  The generic "server offers a list of ids, client picks one" exchange behind the
  skills that open a selection widget (`SA_AUTOSPELL`, `SA_CREATECON`, Pharmacy)
  and behind the production list item scripts open (`produce`, `src_skill_id` 0).

  `open/5` sends the `SkillMenu` offer and parks it on the session's
  `pending_skill_menu` — the equivalent of rAthena's `menuskill_id`/`menuskill_val`
  pair. `handle_reply/2` accepts exactly the reply that answers the parked offer
  and clears it; anything else (no pending menu, a different `src_skill_id`, an
  id outside the offered set) is dropped with a debug log rather than crashing
  the session, since a reply is client input and may be stale or forged. A
  production list is the exception to the offered set: its selection is
  re-checked against the list's trigger instead (`Produce.on_menu_reply/4`).

  The menu is per-session, not persisted: it is cleared on death and on warp
  (`clear/1`), and disconnect discards it with the session process. A labelled
  menu's work lock is separate from its descriptor: any reply releases the
  work lock, while a skill may retain its descriptor without showing failure.

  This module owns the transport only. An accepted selection is routed back to
  the skill that opened the menu through its `Skill.Menu` capability, which does
  the acting.
  """

  require Logger

  alias Aesir.Net.ProductionResult
  alias Aesir.Net.SkillMenu
  alias Aesir.Net.SkillMenuReply
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Produce
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryStaging
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.Invincibility
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit

  @typedoc "A `SkillMenu.Kind` enum value."
  @type kind :: :SKILLS | :ITEMS | :INVENTORY_SLOTS | :OPTIONS

  @typedoc "The offer parked on the session while the client is deciding."
  @type pending :: %{
          optional(:context) => map(),
          optional(:work_in_progress?) => boolean(),
          skill_id: non_neg_integer(),
          kind: kind(),
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
          kind(),
          [non_neg_integer()],
          non_neg_integer()
        ) :: map()
  def open(state, skill_id, kind, entry_ids, level),
    do: open(state, skill_id, kind, entry_ids, level, [])

  @doc "Opens a menu with optional labels and server-owned reply context."
  @spec open(
          map(),
          non_neg_integer(),
          kind(),
          [non_neg_integer()],
          non_neg_integer(),
          keyword()
        ) :: map()
  def open(state, skill_id, kind, entry_ids, level, opts) do
    if SessionState.interaction_blocked?(state) do
      state
    else
      MessageRouter.send_to(state.connection_pid, %SkillMenu{
        src_skill_id: skill_id,
        kind: kind,
        entry_ids: entry_ids,
        labels: Keyword.get(opts, :labels, [])
      })

      %{
        state
        | pending_skill_menu:
            %{skill_id: skill_id, kind: kind, entry_ids: entry_ids, level: level}
            |> Map.merge(Map.new(Keyword.take(opts, [:context])))
      }
    end
  end

  @doc """
  Opens the production list an item's `produce` script asks for (see
  `Produce`), parked with `trigger` as its level. An empty list is sent without
  replacing the open menu, and nothing is sent while a production list is open.
  """
  @spec open_produce(map(), integer()) :: map()
  def open_produce(%{pending_skill_menu: %{skill_id: menu_id}} = state, _trigger)
      when menu_id == 0,
      do: state

  def open_produce(state, trigger) do
    open_menu_skill_id =
      case state.pending_skill_menu do
        nil -> 0
        %{skill_id: skill_id} -> skill_id
      end

    case Produce.offer(state.game_state, trigger, open_menu_skill_id) do
      [] ->
        state
        |> open(Produce.menu_id(), :ITEMS, [], trigger)
        |> Map.put(:pending_skill_menu, state.pending_skill_menu)

      product_ids ->
        open(state, Produce.menu_id(), :ITEMS, product_ids, trigger)
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
  `cancel: true` closes it without running it. Always returns `{:noreply, state}`.

  The selection is validated against the offered ids rather than against a
  sentinel value, so an `INVENTORY_SLOTS` menu can offer inventory slot 0 - which
  a `selected_id: 0` cancel sentinel would have swallowed.
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
    state = release_work_lock(state)
    debug_drop(state, "pending menu is skill #{pending_skill_id}", reply)
    {:noreply, state}
  end

  def handle_reply(reply, %{pending_skill_menu: %{kind: :OPTIONS}} = state) do
    state = release_work_lock(state)

    if options_reply_allowed?(state) do
      handle_selection(reply, Invincibility.stop(state))
    else
      {:noreply, clear(state)}
    end
  end

  def handle_reply(reply, state), do: handle_selection(reply, state)

  defp handle_selection(
         %SkillMenuReply{cancel: true},
         %{pending_skill_menu: %{kind: :OPTIONS}} = state
       ) do
    module = menu_module(state.pending_skill_menu.skill_id)

    cleared =
      if function_exported?(module, :on_menu_cancel, 1) do
        StateCommit.commit(clear(state), module.on_menu_cancel(state.game_state))
      else
        clear(state)
      end

    {:noreply, cleared}
  end

  defp handle_selection(%SkillMenuReply{cancel: true}, state), do: {:noreply, clear(state)}

  # A production list re-checks the selected product against its trigger
  # instead of the listed ids, so any product the trigger allows is accepted.
  defp handle_selection(
         %SkillMenuReply{selected_id: selected_id} = reply,
         %{pending_skill_menu: %{skill_id: 0}} = state
       ) do
    {:noreply, accept(state, %{id: selected_id, extras: reply.extra_ids})}
  end

  defp handle_selection(
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
  # bug, not client input, and fails loudly. Only a menu callback returning an
  # error is a real runtime outcome (the selection stopped being valid while the
  # client was deciding); it leaves the session untouched beyond the clear.
  defp accept(
         %{pending_skill_menu: %{skill_id: skill_id, level: level}} = state,
         %{id: selected_id} = selection
       ) do
    cleared = clear(state)
    module = menu_module(skill_id)

    case menu_reply(module, state, selection, level) do
      {:ok, game_state} ->
        game_state = InventoryStaging.drain(state.connection_pid, game_state)
        StateCommit.commit(cleared, drain_production_result(state.connection_pid, game_state))

      {:silent, game_state} ->
        StateCommit.commit(cleared, InventoryStaging.drain(state.connection_pid, game_state))

      {:pending, game_state} ->
        StateCommit.commit(state, game_state)

      {:failed, game_state, reason} ->
        game_state = InventoryStaging.drain(state.connection_pid, game_state)
        SkillHandler.report_cast_failure(skill_id, state.game_state.character_id, reason)
        StateCommit.commit(cleared, game_state)

      {:error, reason} ->
        Logger.debug(
          "Skill #{skill_id} rejected menu selection #{selected_id} for player " <>
            "#{state.game_state.character_id}: #{inspect(reason)}"
        )

        SkillHandler.report_cast_failure(
          failure_skill_id(skill_id, state.game_state),
          state.game_state.character_id,
          reason
        )

        cleared
    end
  end

  # A production list has no skill of its own: its failure names the skill the
  # player is casting, if any.
  defp failure_skill_id(0, %{casting: %{skill_id: skill_id}}), do: skill_id
  defp failure_skill_id(0, _game_state), do: 0
  defp failure_skill_id(skill_id, _game_state), do: skill_id

  defp menu_reply(module, state, selection, level) do
    if function_exported?(module, :on_menu_reply, 4) do
      module.on_menu_reply(state.game_state, selection, level, %{
        homunculus: Map.get(state, :homunculus),
        menu: state.pending_skill_menu,
        trading?: Map.get(state, :trade) != nil
      })
    else
      module.on_menu_reply(state.game_state, selection, level)
    end
  end

  defp release_work_lock(%{pending_skill_menu: %{kind: :OPTIONS} = menu} = state),
    do: %{state | pending_skill_menu: Map.put(menu, :work_in_progress?, false)}

  defp release_work_lock(state), do: state

  defp options_reply_allowed?(%{game_state: player} = state) do
    storage? = player.storage != nil or Map.get(state, :guild_storage_ctx) != nil
    free_body? = StatusDisplay.spawn_state(:player, player.character_id).body_state in [0, 7]

    can_act? =
      Map.get(state, :interaction_lock) == nil and player.waiting_room == nil and
        not PlayerState.vending?(player) and Map.get(state, :trade) == nil and free_body?

    (storage? or can_act?) and StatusInterpreter.can_use_skill?(:player, player.character_id)
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

  defp menu_module(0), do: Produce

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
