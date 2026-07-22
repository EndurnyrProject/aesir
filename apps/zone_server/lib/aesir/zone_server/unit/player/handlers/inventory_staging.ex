defmodule Aesir.ZoneServer.Unit.Player.Handlers.InventoryStaging do
  @moduledoc """
  Drains the inventory changes a skill staged on `PlayerState` while it ran.

  A skill's `cast/4` (and `Skill.Menu.on_menu_reply/3`) only ever sees the player
  state, never the connection or the repo, so it records what it did on two
  staging fields instead of acting:

    * `:pending_inventory_persist` — `{old_inventory, new_inventory, change}`
      deltas whose DB write is still owed, staged by the paths that mutate the
      inventory purely (the interpreter's catalyst consumption, ammo, and
      SA_CREATECON's material consumption).
    * `:pending_inventory_notify` — `change` descriptors for rows already
      written through by `InventoryOps.add/6`, owing only an `ItemAdded` packet.

  `drain/2` settles both and clears the fields. It runs on every path that
  commits a skill's work: `SkillHandler.commit_cast/5` for a cast, and
  `SkillMenuHandler` for a menu reply, which produces items without a cast to
  ride on.

  `drain/2` is an exception to the GenServer-native dispatch contract: it takes
  and returns bare `PlayerState`, not session state, as a helper called from
  inside those handlers' dispatch bodies rather than a `handle_cast`/`handle_call`
  clause itself.
  """

  require Logger

  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @doc """
  Writes through the staged persists, emits the staged notifications, and returns
  the game state with both staging fields cleared.

  A failed write is logged and skipped rather than raised: the caller has already
  committed the rest of the skill's effects, and losing the session over a row
  write would cost the player more than the untracked row does.
  """
  @spec drain(pid(), PlayerState.t()) :: PlayerState.t()
  def drain(connection_pid, game_state) do
    game_state
    |> persist()
    |> notify(connection_pid)
  end

  # Each delta is persisted against the snapshot it was computed from; the
  # persisted rows (with real DB ids) are reflected back onto the already-final
  # inventory for the indices that survive.
  defp persist(%{pending_inventory_persist: []} = game_state), do: game_state

  defp persist(%{pending_inventory_persist: deltas} = game_state) do
    char_id = game_state.character_id

    inventory =
      Enum.reduce(deltas, game_state.inventory, fn {old_inv, new_inv, change}, acc ->
        case InventoryOps.apply_change(char_id, old_inv, new_inv, change) do
          {:ok, persisted} ->
            Map.merge(acc, Map.take(persisted, Map.keys(acc)))

          {:error, reason} ->
            Logger.warning("Catalyst persist failed for #{char_id}: #{inspect(reason)}")
            acc
        end
      end)

    %{game_state | inventory: inventory, pending_inventory_persist: []}
  end

  defp notify(%{pending_inventory_notify: []} = game_state, _connection_pid), do: game_state

  defp notify(%{pending_inventory_notify: changes} = game_state, connection_pid) do
    Enum.each(changes, &InventoryManager.notify_added(connection_pid, game_state.inventory, &1))
    %{game_state | pending_inventory_notify: []}
  end
end
