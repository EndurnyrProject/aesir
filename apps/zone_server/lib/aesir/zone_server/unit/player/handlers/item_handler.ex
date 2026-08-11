defmodule Aesir.ZoneServer.Unit.Player.Handlers.ItemHandler do
  @moduledoc """
  Handles UseItem: runs a consumable's compiled `on_use` script and consumes one unit.

  Modeled on `SkillLearningHandler`: validates the request, runs the effect
  synchronously inside the player session, commits the resulting state and (only
  on success) consumes exactly one unit of the item. The client is told the
  outcome with an `ItemUseResult` and, on success, an `ItemRemoved` delta for the
  consumed unit. A failure (missing slot, non-usable item, or a halted script)
  consumes nothing and leaves state unchanged.
  """

  require Logger

  alias Aesir.Net.ItemUseResult
  alias Aesir.ZoneServer.Mmo.ItemManagement.CompiledItemScripts
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.ItemEffectHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatsManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerEvents
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  # CompiledItemScripts is created at runtime by ScriptCompiler.compile_all!/1, so
  # it has no source file at compile time; silence the undefined-module warning.
  @compile {:no_warn_undefined, CompiledItemScripts}

  @doc """
  Processes a use-item request for the player session.

  `client_index` is the client-side inventory index (server index + 2).
  """
  @spec handle_use_item(non_neg_integer(), map()) :: {:noreply, map()}
  def handle_use_item(client_index, %{game_state: game_state} = state) do
    server_index = PlayerState.server_index(client_index)

    with {:ok, item} <- fetch_item(game_state.inventory, server_index),
         {:ok, definition} <- fetch_definition(item.nameid),
         :ok <- usable?(definition) do
      run_effect(client_index, server_index, definition.id, state)
    else
      {:error, reason} -> reject(client_index, reason, state)
    end
  end

  defp run_effect(client_index, server_index, item_id, state) do
    original = Ctx.from_session(state, {:item, item_id})
    ctx = CompiledItemScripts.on_use(item_id, original)

    case {ctx.status, ctx.homunculus_effects} do
      {:ok, []} ->
        consume(client_index, server_index, ctx, state)

      {:ok, [effect]} ->
        if %{ctx | homunculus_effects: []} == original do
          ItemEffectHandler.handle(client_index, server_index, effect, state)
        else
          {:noreply, state}
        end

      {{:error, reason}, []} ->
        reject(client_index, reason, state)

      _invalid_homunculus_script ->
        {:noreply, state}
    end
  end

  defp consume(client_index, server_index, ctx, state) do
    char_id = state.game_state.character_id

    case InventoryOps.remove(char_id, ctx.game_state.inventory, server_index, 1) do
      {:ok, new_inventory, _change} ->
        final_gs = %{ctx.game_state | inventory: new_inventory}

        recalced =
          StatusManager.recalculate_after_status_change(%{state | game_state: final_gs})

        committed = StatsManager.update_game_state(recalced, recalced.game_state)

        MessageRouter.send_to(state.connection_pid, InventoryView.item_removed(server_index, 1))

        MessageRouter.send_to(state.connection_pid, %ItemUseResult{
          index: client_index,
          ok: true,
          reason: 0
        })

        PlayerEvents.inventory_changed(char_id)

        {:noreply, committed}

      {:error, reason} ->
        Logger.warning(
          "use_item consume failed for #{char_id} (item #{ctx.source |> elem(1)}): #{inspect(reason)}"
        )

        reject(client_index, reason, state)
    end
  end

  defp reject(client_index, reason, %{connection_pid: connection_pid} = state) do
    MessageRouter.send_to(connection_pid, %ItemUseResult{
      index: client_index,
      ok: false,
      reason: code(reason)
    })

    {:noreply, state}
  end

  @spec fetch_item(%{non_neg_integer() => term()}, integer()) ::
          {:ok, term()} | {:error, :not_found}
  defp fetch_item(inventory, server_index) do
    case PlayerState.get_by_index(inventory, server_index) do
      nil -> {:error, :not_found}
      item -> {:ok, item}
    end
  end

  @spec fetch_definition(integer()) :: {:ok, term()} | {:error, :not_found}
  defp fetch_definition(nameid) do
    case Items.by_id(nameid) do
      {:ok, definition} -> {:ok, definition}
      :error -> {:error, :not_found}
    end
  end

  @spec usable?(term()) :: :ok | {:error, :not_usable}
  defp usable?(%{on_use: nil}), do: {:error, :not_usable}
  defp usable?(%{on_use: _source}), do: :ok

  # Stable uint32 reject codes mirrored by the Lifthrasir client (0 reserved for
  # ok / success, which the success path sends as ItemUseResult{ok: true}).
  @spec code(term()) :: pos_integer()
  defp code(:not_found), do: 1
  defp code(:not_usable), do: 2
  defp code(_reason), do: 3
end
