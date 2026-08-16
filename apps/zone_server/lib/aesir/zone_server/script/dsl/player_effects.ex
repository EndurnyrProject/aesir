defmodule Aesir.ZoneServer.Script.Dsl.PlayerEffects do
  @moduledoc """
  Player-state effect buildins for the script DSL: HP/SP heals, status effect
  application/removal, Homunculus effect staging, save point, experience
  grants, job changes, storage, cart/mount/falcon toggles, and script
  re-attachment to another player.

  Imported into scripts via the `Aesir.ZoneServer.Script.Dsl` facade.
  """

  import Aesir.ZoneServer.Script.Dsl.Internal, only: [apply_op: 2]

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl.Internal
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @typedoc "An HP/SP heal amount: a flat integer or a `lo..hi` range to roll within."
  @type amount :: integer() | Range.t()

  @doc "Stages a Homunculus evolution for atomic item handling."
  @spec homevolution(Ctx.t()) :: Ctx.t()
  def homevolution(%Ctx{status: {:error, _}} = ctx), do: ctx
  def homevolution(%Ctx{} = ctx), do: stage_homunculus_effect(ctx, :homunculus_evolution)

  @doc "Stages a positive fixed-point Homunculus intimacy increase for atomic item handling."
  @spec add_homunculus_intimacy(Ctx.t(), pos_integer()) :: Ctx.t()
  def add_homunculus_intimacy(%Ctx{status: {:error, _}} = ctx, amount)
      when is_integer(amount) and amount > 0,
      do: ctx

  def add_homunculus_intimacy(%Ctx{} = ctx, amount) when is_integer(amount) and amount > 0,
    do: stage_homunculus_effect(ctx, {:homunculus_intimacy, amount})

  defp stage_homunculus_effect(ctx, effect) do
    Map.update!(ctx, :homunculus_effects, &(&1 ++ [effect]))
  end

  @doc """
  Restores HP and/or SP by the given amounts, clamped to the player's maxima.

  `opts` accepts `:hp` and `:sp`, each a flat integer or a `lo..hi` range from
  which a value is rolled. The new value is pushed to the client and persisted.
  Halts `:no_player` on a detached ctx.
  """
  @spec heal(Ctx.t(), keyword()) :: Ctx.t()
  def heal(%Ctx{status: {:error, _}} = ctx, _opts), do: ctx
  def heal(%Ctx{game_state: nil} = ctx, _opts), do: Ctx.halt(ctx, :no_player)

  def heal(%Ctx{} = ctx, opts) do
    hp = opts |> Keyword.get(:hp, 0) |> roll() |> scale_consumable_recovery(ctx, :hp)
    sp = opts |> Keyword.get(:sp, 0) |> roll() |> scale_consumable_recovery(ctx, :sp)

    apply_heal(ctx, fn current, _max -> current + hp end, fn current, _max -> current + sp end)
  end

  @doc """
  Restores HP and/or SP by a percentage of the player's maxima.

  `opts` accepts `:hp` and `:sp` as integer percents applied to `max_hp`/`max_sp`.
  Halts `:no_player` on a detached ctx.
  """
  @spec percent_heal(Ctx.t(), keyword()) :: Ctx.t()
  def percent_heal(%Ctx{status: {:error, _}} = ctx, _opts), do: ctx
  def percent_heal(%Ctx{game_state: nil} = ctx, _opts), do: Ctx.halt(ctx, :no_player)

  def percent_heal(%Ctx{} = ctx, opts) do
    apply_heal(
      ctx,
      fn current, max -> current + div(max * Keyword.get(opts, :hp, 0), 100) end,
      fn current, max -> current + div(max * Keyword.get(opts, :sp, 0), 100) end
    )
  end

  @doc """
  Applies a status effect to the player for `duration_ms` with strength `val`.

  The status lives in external storage, not in `game_state`, so the context is
  returned unchanged. Halts `:no_player` on a detached ctx — there is no
  `char_id` to key the status storage on.
  """
  @spec sc_start(Ctx.t(), atom(), non_neg_integer(), integer()) :: Ctx.t()
  def sc_start(%Ctx{status: {:error, _}} = ctx, _status, _duration_ms, _val), do: ctx

  def sc_start(%Ctx{game_state: nil} = ctx, _status, _duration_ms, _val),
    do: Ctx.halt(ctx, :no_player)

  def sc_start(%Ctx{} = ctx, status, duration_ms, val) do
    StatusInterpreter.apply_status(:player, ctx.char_id, status, val1: val, duration: duration_ms)
    ctx
  end

  @doc """
  Removes a status effect from the player. Returns the context unchanged.

  Canonical status-removal op, pairing with `sc_start/4`. Halts `:no_player`
  on a detached ctx (otherwise this would silently succeed: a `nil` `char_id`
  looks up nothing in status storage and reports `:ok`).
  """
  @spec sc_end(Ctx.t(), atom()) :: Ctx.t()
  def sc_end(%Ctx{status: {:error, _}} = ctx, _status), do: ctx
  def sc_end(%Ctx{game_state: nil} = ctx, _status), do: Ctx.halt(ctx, :no_player)

  def sc_end(%Ctx{} = ctx, status) do
    StatusInterpreter.remove_status(:player, ctx.char_id, status)
    ctx
  end

  @doc """
  Removes a status effect from the player. Alias for `sc_end/2`.

  Inherits `sc_end/2`'s `:no_player` halt on a detached ctx (pure delegation).
  """
  @spec cure(Ctx.t(), atom()) :: Ctx.t()
  def cure(%Ctx{} = ctx, status), do: sc_end(ctx, status)

  @doc """
  Sets the player's save (respawn) point to `map`,`x`,`y` — the destination
  they return to on death. Mirrors rAthena's `savepoint`.
  """
  @spec savepoint(Ctx.t(), String.t(), non_neg_integer(), non_neg_integer()) :: Ctx.t()
  def savepoint(%Ctx{status: {:error, _}} = ctx, _map, _x, _y), do: ctx
  def savepoint(%Ctx{} = ctx, map, x, y), do: apply_op(ctx, {:set_save_point, map, x, y})

  @doc """
  Grants `base_exp` base experience and `job_exp` job experience through the
  session seam (rAthena `getexp`), leveling the player as the gain warrants and
  pushing the refreshed experience/stat state to the client.
  """
  @spec getexp(Ctx.t(), non_neg_integer(), non_neg_integer()) :: Ctx.t()
  def getexp(%Ctx{status: {:error, _}} = ctx, _base_exp, _job_exp), do: ctx
  def getexp(%Ctx{} = ctx, base_exp, job_exp), do: apply_op(ctx, {:getexp, base_exp, job_exp})

  @doc """
  Changes the player's job through the session seam, recomputing job-dependent
  stats and refreshing the client's sprite/skill window. Accepts either a
  numeric job id or a job name atom (as `Job_*` constants transpile to). Halts
  `:unknown_job` when the job does not resolve to a known job.
  """
  @spec jobchange(Ctx.t(), non_neg_integer() | atom()) :: Ctx.t()
  def jobchange(%Ctx{status: {:error, _}} = ctx, _job), do: ctx

  def jobchange(%Ctx{} = ctx, job_id) when is_integer(job_id),
    do: apply_op(ctx, {:change_job, job_id})

  def jobchange(%Ctx{} = ctx, job_name) when is_atom(job_name) do
    case AvailableJobs.job_name_to_id(job_name) do
      {:ok, job_id} -> apply_op(ctx, {:change_job, job_id})
      {:error, reason} -> Ctx.halt(ctx, reason)
    end
  end

  @doc """
  Opens the account storage window through the session seam (rAthena
  `openstorage`). Never halts: a gate failure (missing `NV_BASIC`) is reported
  to the client as a `StorageResult`, not a script error.

  Call `openstorage` immediately before `close` so the NPC dialog does not
  linger alongside the storage window.
  """
  @spec openstorage(Ctx.t()) :: Ctx.t()
  def openstorage(%Ctx{status: {:error, _}} = ctx), do: ctx
  def openstorage(%Ctx{} = ctx), do: apply_op(ctx, {:openstorage})

  @doc """
  Gives the player a cart (rAthena `setcart`): mounts the pushcart through the
  session seam, or removes it when `type` is `0`. Mounting requires
  `MC_PUSHCART` learned; a rejected mount reports to the client as a
  `CartMountResult` and never halts the script, matching rAthena's silent
  failure. Cart sprite tiers are not modelled — any non-zero `type` mounts the
  first tier, and mounting while already mounted is a no-op. Removal with a
  non-empty cart is also a no-op (Aesir never discards cart items). Halts
  `:no_player` on a detached ctx.
  """
  @spec setcart(Ctx.t(), non_neg_integer()) :: Ctx.t()
  def setcart(ctx, type \\ 1)
  def setcart(%Ctx{status: {:error, _}} = ctx, _type), do: ctx
  def setcart(%Ctx{} = ctx, type), do: apply_op(ctx, {:setcart, type})

  @doc """
  Mounts or dismounts the Peco-Peco through the session seam (rAthena
  `setriding`). Mounting requires `KN_RIDING` learned; unlike `setcart/2`'s
  silent failure, a rejected mount halts the script (mirrors `pay_zeny/2` on
  insufficient zeny) since a script that keeps going assumes the mount
  succeeded. Dismounting is always a no-op success, mounted or not. Halts
  `:no_player` on a detached ctx.
  """
  @spec set_riding(Ctx.t(), boolean()) :: Ctx.t()
  def set_riding(%Ctx{status: {:error, _}} = ctx, _riding?), do: ctx
  def set_riding(%Ctx{} = ctx, riding?), do: apply_op(ctx, {:set_riding, riding?})

  @doc """
  Equips or dismisses the Falcon through the session seam. A zero flag
  dismisses; every non-zero integer equips, matching rAthena truthiness.
  """
  @spec setfalcon(Ctx.t(), integer()) :: Ctx.t()
  def setfalcon(%Ctx{status: {:error, _}} = ctx, _flag), do: ctx
  def setfalcon(%Ctx{} = ctx, flag), do: apply_op(ctx, {:set_falcon, flag != 0})

  @doc """
  Re-attaches the script to a different online player by account id (rAthena
  `attachrid`), so subsequent commands and reads target that player.

  Returns `{ctx, 1}` on success — ctx re-pointed at the target's session and
  game state — or `{ctx, 0}` when the account is offline or has no character
  in this zone. `force` is accepted for rAthena compatibility but has no
  effect: Aesir has no notion of a player being attached to another script,
  so an online target can always be re-attached.

  The interaction coroutine still monitors its original session (its
  `session_ref` is untouched), and `connection_pid` is left `nil` since the
  target's connection is not tracked in the unit registry. `attachrid` is
  intended for server-side state mutations (`give_item`, `set_char_var`,
  `warp`, …) routed through `apply_op` on the re-pointed `session_pid`, not
  for dialog or direct client sends to the target.
  """
  @spec attachrid(Ctx.t(), integer(), boolean()) :: {Ctx.t(), 0 | 1}
  def attachrid(%Ctx{} = ctx, account_id), do: attachrid(ctx, account_id, true)

  def attachrid(%Ctx{status: {:error, _}} = ctx, _account_id, _force), do: {ctx, 0}

  def attachrid(%Ctx{} = ctx, account_id, _force) do
    case UnitRegistry.get_char_id_by_account(account_id) do
      {:ok, char_id} ->
        case UnitRegistry.get_unit(:player, char_id) do
          {:ok, {_module, game_state, pid}} when is_pid(pid) ->
            {%{
               ctx
               | char_id: char_id,
                 account_id: account_id,
                 game_state: game_state,
                 session_pid: pid,
                 connection_pid: nil
             }, 1}

          _ ->
            {ctx, 0}
        end

      {:error, _} ->
        {ctx, 0}
    end
  end

  # Consumable recovery: +5%/Potion Research level, +2%/VIT (HP) or +2%/INT (SP),
  # plus the flat item_heal_rate and the per-item add_item_heal equipment bonuses
  # on HP; floored integer percent.
  defp scale_consumable_recovery(
         amount,
         %Ctx{source: {:item, item_id}, game_state: %{stats: stats}} = ctx,
         resource
       ) do
    potion_research_rate = 5 * Internal.learned_level(ctx.game_state, :am_learningpotion)

    stat_rate =
      case resource do
        :hp ->
          2 * PlayerStats.get_effective_stat(stats, :vit) +
            PlayerStats.get_item_heal_rate(stats) +
            PlayerStats.get_equipment_modifier(stats, {:add_item_heal, item_id})

        :sp ->
          2 * PlayerStats.get_effective_stat(stats, :int)
      end

    div(amount * (100 + potion_research_rate + stat_rate), 100)
  end

  defp scale_consumable_recovery(amount, %Ctx{}, _resource), do: amount

  defp apply_heal(%Ctx{} = ctx, hp_fun, sp_fun) do
    stats = ctx.game_state.stats
    current = stats.current_state
    max_hp = stats.derived_stats.max_hp
    max_sp = stats.derived_stats.max_sp

    hp_delta = scale_received_heal(hp_fun.(current.hp, max_hp) - current.hp, ctx.char_id)
    new_hp = Internal.clamp(current.hp + hp_delta, max_hp)
    new_sp = Internal.clamp(sp_fun.(current.sp, max_sp), max_sp)

    new_state = %{current | hp: new_hp, sp: new_sp}
    game_state = %{ctx.game_state | stats: %{stats | current_state: new_state}}

    sync_hp(ctx, current.hp, new_hp)
    sync_sp(ctx, current.sp, new_sp)

    %{ctx | game_state: game_state}
  end

  # Scales the healed HP delta (never SP) by the target's `received_heal_rate`
  # (SC_INCHEALRATE) before it is applied. Only
  # positive deltas are scaled; item/script heals never subtract HP here.
  defp scale_received_heal(delta, _char_id) when delta <= 0, do: delta

  defp scale_received_heal(delta, char_id) do
    rate =
      :player
      |> ModifierCalculator.get_all_modifiers(char_id)
      |> Map.get(:received_heal_rate, 0)

    div(delta * (100 + rate), 100)
  end

  defp sync_hp(_ctx, same, same), do: :ok

  defp sync_hp(ctx, _old, new_hp) do
    StatusSync.send_param(ctx.connection_pid, StatusParams.hp(), new_hp)
    CharacterPersistence.update_stats(ctx.char_id, %{hp: new_hp}, async: true)
  end

  defp sync_sp(_ctx, same, same), do: :ok

  defp sync_sp(ctx, _old, new_sp) do
    StatusSync.send_param(ctx.connection_pid, StatusParams.sp(), new_sp)
    CharacterPersistence.update_stats(ctx.char_id, %{sp: new_sp}, async: true)
  end

  defp roll(lo..hi//_step), do: lo + :rand.uniform(hi - lo + 1) - 1
  defp roll(amount) when is_integer(amount), do: amount
end
