defmodule Aesir.ZoneServer.Unit.Player.Handlers.ItemHandler do
  @moduledoc """
  Handles UseItem for card discovery and consumable effects.

  Cards open stateless target discovery without running or consuming anything.
  The existing consumable path validates other items, runs the effect
  synchronously inside the player session and commits the resulting state.
  Ordinary items consume one unit on success; a `delay_consume` item that grants
  a skill waits until the client selects a valid cast before consuming it.
  `ItemUseResult` acknowledges the item use and `ItemRemoved` reports the actual
  consumption. A failed item-use check leaves inventory unchanged.
  """

  require Logger

  alias Aesir.Commons.GameMode
  alias Aesir.Net.ItemUseResult
  alias Aesir.Net.ProgressBarAbort
  alias Aesir.Net.SystemNotice
  alias Aesir.ZoneServer.Mmo.ItemManagement.CompiledItemScripts
  alias Aesir.ZoneServer.Mmo.ItemManagement.Eligibility
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.NoEquip
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.ItemEffectHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.CardHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.FalconHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.HealthHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerEvents
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit

  # CompiledItemScripts is created at runtime by ScriptCompiler.compile_all!/1, so
  # it has no source file at compile time; silence the undefined-module warning.
  @compile {:no_warn_undefined, CompiledItemScripts}

  @doc """
  Processes a use-item request for the player session.

  `client_index` is the client-side inventory index (server index + 2).

  A player trading or vending outside an NPC dialog, or in a chat room, is
  refused with the busy notice and no result. Inside an NPC dialog, a running
  progress bar is cancelled instead of using the item; otherwise the dialog
  refuses the item unless its script allows item use and no work is in
  progress (renewal shows the busy notice). Both send a failed result.
  """
  @spec handle_use_item(non_neg_integer(), map()) :: {:noreply, map()}
  def handle_use_item(client_index, %{game_state: game_state} = state) do
    server_index = PlayerState.server_index(client_index)

    with :ok <- not_busy(state),
         :ok <- item_use_enabled?(state),
         {:ok, item} <- fetch_item(game_state.inventory, server_index),
         {:ok, definition} <- fetch_definition(item.nameid),
         :ok <- item_use_allowed?(game_state) do
      use_definition(definition, client_index, server_index, state)
    else
      :busy ->
        MessageRouter.send_to(state.connection_pid, %SystemNotice{id: :SYSTEM_NOTICE_ID_BUSY})
        {:noreply, state}

      {:error, reason} ->
        reject(client_index, reason, state)
    end
  end

  defp not_busy(%{game_state: game_state} = state) do
    trading? = Map.get(state, :trade) != nil or game_state.action_state == :vending

    if (trading? and not SessionState.npc_dialog?(state)) or game_state.waiting_room != nil,
      do: :busy,
      else: :ok
  end

  defp use_definition(%{type: :card}, _client_index, server_index, state) do
    CardHandler.open_picker(server_index, state)
  end

  defp use_definition(definition, client_index, server_index, state) do
    context = %{
      job_id: state.game_state.stats.progression.job_id,
      base_level: state.game_state.stats.progression.base_level,
      sex: state.game_state.sex
    }

    with :ok <- usable?(definition),
         :ok <- Eligibility.check(definition, context),
         :ok <- map_allows?(definition, state.game_state) do
      run_effect(client_index, server_index, definition, state)
    else
      {:error, reason} -> reject(client_index, reason, state)
    end
  end

  # A Homunculus effect commits the inventory removal and the homunculus row in
  # one DB transaction (Homunculus.Persistence.transition_with_item/5), so it
  # bypasses consume/4 and must be the only thing the script did. Every other
  # staged effect is applied to the session in script order, then consumed here.
  defp run_effect(client_index, server_index, %{id: item_id} = definition, state) do
    original = Ctx.from_session(state, {:item, item_id})
    ctx = CompiledItemScripts.on_use(item_id, original)

    case ctx do
      %Ctx{status: {:error, reason}} ->
        reject(client_index, reason, state)

      %Ctx{session_effects: [{:homunculus, effect}]} ->
        if %{ctx | session_effects: []} == original do
          ItemEffectHandler.handle(client_index, server_index, effect, state)
        else
          reject_invalid_script(client_index, item_id, state)
        end

      %Ctx{session_effects: effects} ->
        apply_item_effects(ctx, effects, definition, client_index, server_index, state)
    end
  end

  defp apply_item_effects(
         ctx,
         effects,
         %{id: item_id, type: type},
         client_index,
         server_index,
         state
       ) do
    pending = List.last(for {:item_skill, id, level, keep?} <- effects, do: {id, level, keep?})
    effects = Enum.reject(effects, &match?({:item_skill, _, _, _}, &1))

    with :ok <- validate_item_skill(pending),
         :ok <- reject_homunculus(effects),
         {:ok, updated} <- apply_session_effects(effects, %{state | game_state: ctx.game_state}) do
      if type == :delay_consume and pending do
        stage_delayed_item_skill(client_index, server_index, item_id, pending, updated)
      else
        consume(
          client_index,
          server_index,
          %{ctx | game_state: updated.game_state},
          updated,
          pending
        )
      end
    else
      {:error, :invalid_script} -> reject_invalid_script(client_index, item_id, state)
      {:error, reason} -> reject(client_index, reason, state)
    end
  end

  @spec apply_session_effects([Ctx.session_effect()], map()) :: {:ok, map()} | {:error, term()}
  defp apply_session_effects(effects, state) do
    Enum.reduce_while(effects, {:ok, state}, fn
      {:falcon, enabled?}, {:ok, acc} ->
        case FalconHandler.set_falcon(acc, enabled?) do
          {:ok, updated} -> {:cont, {:ok, updated}}
          {:error, _reason} = error -> {:halt, error}
        end

      {:script_damage, damage}, {:ok, acc} ->
        {:noreply, updated} = HealthHandler.settle_script_damage(damage, acc)
        {:cont, {:ok, updated}}
    end)
  end

  # A Homunculus effect must be the script's only effect (see run_effect/4).
  defp reject_homunculus(effects) do
    if Enum.any?(effects, &match?({:homunculus, _}, &1)),
      do: {:error, :invalid_script},
      else: :ok
  end

  defp reject_invalid_script(client_index, item_id, state) do
    Logger.warning("use_item item #{item_id} staged an unsupported effect combination")
    reject(client_index, :invalid_script, state)
  end

  defp validate_item_skill(nil), do: :ok

  defp validate_item_skill({id, level, keep?}) when is_boolean(keep?) do
    case Catalog.by_id(id) do
      {:ok, definition} when is_integer(level) and level > 0 and level <= definition.max_level ->
        :ok

      {:ok, _definition} ->
        {:error, :invalid_level}

      :error ->
        {:error, :unknown_skill}
    end
  end

  defp validate_item_skill({_id, _level, _invalid_flag}), do: {:error, :invalid_requirement}

  defp stage_delayed_item_skill(
         client_index,
         server_index,
         item_id,
         {skill_id, level, keep?},
         state
       ) do
    state = StateCommit.commit(state, state.game_state)

    MessageRouter.send_to(state.connection_pid, %ItemUseResult{
      index: client_index,
      ok: true,
      reason: 0
    })

    {{:ok, _gs}, staged} =
      ScriptEffectHandler.apply_op(
        {:stage_item_skill, skill_id, level, {server_index, item_id}, keep?},
        state
      )

    {:noreply, staged}
  end

  defp consume(client_index, server_index, ctx, state, pending) do
    char_id = state.game_state.character_id

    case InventoryOps.remove(char_id, ctx.game_state.inventory, server_index, 1) do
      {:ok, new_inventory, _change} ->
        final_gs = %{ctx.game_state | inventory: new_inventory}

        recalced =
          StatusManager.recalculate_after_status_change(%{state | game_state: final_gs})

        committed = StateCommit.commit(recalced, recalced.game_state)

        MessageRouter.send_to(state.connection_pid, InventoryView.item_removed(server_index, 1))

        MessageRouter.send_to(state.connection_pid, %ItemUseResult{
          index: client_index,
          ok: true,
          reason: 0
        })

        PlayerEvents.inventory_changed(char_id)

        committed = SkillHandler.drain_warp(committed)
        {:noreply, stage_consumed_item_skill(committed, pending)}

      {:error, reason} ->
        Logger.warning(
          "use_item consume failed for #{char_id} (item #{ctx.source |> elem(1)}): #{inspect(reason)}"
        )

        reject(client_index, reason, state)
    end
  end

  defp stage_consumed_item_skill(state, nil), do: state

  defp stage_consumed_item_skill(state, {skill_id, level, keep?}) do
    {{:ok, _gs}, staged} =
      ScriptEffectHandler.apply_op({:stage_item_skill, skill_id, level, keep?}, state)

    staged
  end

  defp reject(client_index, reason, %{connection_pid: connection_pid} = state) do
    if reason == :disabled and GameMode.mode() == :renewal,
      do: MessageRouter.send_to(connection_pid, %SystemNotice{id: :SYSTEM_NOTICE_ID_BUSY})

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

  # An item the map restricts is refused before its effect runs and is not
  # consumed, whatever its consumption type.
  @spec map_allows?(map(), PlayerState.t()) :: :ok | {:error, :restricted_area}
  defp map_allows?(definition, game_state) do
    if NoEquip.restricted?(definition.id, game_state.map_name),
      do: {:error, :restricted_area},
      else: :ok
  end

  # While an NPC dialog holds the player, the first item use cancels a running
  # progress bar; otherwise item use needs the script's item-use flag and no
  # held work flag.
  @spec item_use_enabled?(map()) :: :ok | {:error, :disabled | :progress_bar}
  defp item_use_enabled?(state) do
    cond do
      not SessionState.npc_dialog?(state) ->
        :ok

      Map.get(state, :progress_bar) != nil ->
        MessageRouter.send_to(state.connection_pid, %ProgressBarAbort{
          npc_id: state.progress_bar.npc_gid
        })

        {:error, :progress_bar}

      SessionState.work_in_progress?(state) or not SessionState.npc_item_flag?(state) ->
        {:error, :disabled}

      true ->
        :ok
    end
  end

  @spec item_use_allowed?(PlayerState.t()) :: :ok | {:error, :status_blocked}
  defp item_use_allowed?(%PlayerState{character_id: character_id}) do
    if Interpreter.can_use_item?(:player, character_id),
      do: :ok,
      else: {:error, :status_blocked}
  end

  # Stable uint32 reject codes mirrored by the Lifthrasir client (0 reserved for
  # ok / success, which the success path sends as ItemUseResult{ok: true}).
  @spec code(term()) :: pos_integer()
  defp code(:not_found), do: 1
  defp code(:not_usable), do: 2
  defp code(:disabled), do: 4
  defp code(:progress_bar), do: 4
  defp code(:restricted_area), do: 5
  defp code(:status_blocked), do: 3
  defp code(_reason), do: 3
end
