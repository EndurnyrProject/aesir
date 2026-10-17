defmodule Aesir.ZoneServer.Script.Dsl.PlayerEffects do
  @moduledoc """
  Player-state effect buildins for the script DSL: HP/SP heals, status effect
  application/removal, Homunculus effect staging, save point, experience
  grants, job changes, storage, cart/mount/falcon toggles, and script
  re-attachment to another player.

  Imported into scripts via the `Aesir.ZoneServer.Script.Dsl` facade.
  """

  import Aesir.ZoneServer.Script.Dsl.Internal, only: [apply_op: 2]
  import Bitwise, only: [band: 2]

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Player.ScriptVitals
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @scstart_noavoid 0x01
  @scstart_notickdef 0x02
  @scstart_noratedef 0x08

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

  defp stage_homunculus_effect(ctx, effect),
    do: stage_session_effect(ctx, {:homunculus, effect})

  defp stage_session_effect(ctx, effect),
    do: Map.update!(ctx, :session_effects, &(&1 ++ [effect]))

  @doc """
  Heals or damages the player by flat HP/SP amounts (the `heal` command): no
  recovery bonus applies and Frenzy does not stop it; a negative amount is
  passive damage that can kill.

  `opts` accepts `:hp` and `:sp`, each an integer or a `lo..hi` range rolled
  once. See `percent_heal/2` for how the heal reaches the player.
  """
  @spec heal(Ctx.t(), keyword()) :: Ctx.t()
  def heal(ctx, opts), do: vitals(ctx, fn -> {:heal, amount(opts, :hp), amount(opts, :sp)} end)

  @doc """
  Heals the player by HP/SP amounts scaled by their item recovery bonuses and
  statuses (the `itemheal` command), for the item whose script runs (`nil` from
  an NPC script). Takes the same `opts` as `heal/2`.
  """
  @spec item_heal(Ctx.t(), keyword()) :: Ctx.t()
  def item_heal(ctx, opts) do
    vitals(ctx, fn ->
      {:item_heal, healing_item(ctx.source), amount(opts, :hp), amount(opts, :sp)}
    end)
  end

  @doc """
  Heals or damages the player by percents of their maxima (the `percentheal`
  command); a negative percent is passive damage that only kills at -100 HP.

  An item script, which runs inside its player's session, applies the HP/SP
  change to its own state at once and stages any HP damage for the session to
  settle (status reactions, death) after the script; an NPC script applies the
  heal through the player's session. Halts `:no_player` on a detached ctx.
  """
  @spec percent_heal(Ctx.t(), keyword()) :: Ctx.t()
  def percent_heal(ctx, opts),
    do: vitals(ctx, fn -> {:percent_heal, amount(opts, :hp), amount(opts, :sp)} end)

  defp vitals(%Ctx{status: {:error, _}} = ctx, _op), do: ctx
  defp vitals(%Ctx{game_state: nil} = ctx, _op), do: Ctx.halt(ctx, :no_player)

  defp vitals(%Ctx{source: {:item, _}} = ctx, op) do
    {game_state, damage} = ScriptVitals.apply(op.(), ctx.game_state)
    ScriptVitals.sync(ctx.connection_pid, ctx.game_state, game_state)
    ctx = %{ctx | game_state: game_state}

    if damage, do: stage_session_effect(ctx, {:script_damage, damage}), else: ctx
  end

  defp vitals(%Ctx{} = ctx, op), do: apply_op(ctx, op.())

  defp amount(opts, key), do: opts |> Keyword.get(key, 0) |> roll()

  defp healing_item({:item, item_id}), do: item_id
  defp healing_item({:npc, _module}), do: nil

  @doc """
  Applies a status effect to the player for `duration_ms` with strength `val`.

  Starts it as the `sc_start` script command does, with the player as its own
  source: an item script lands at `rate` (per 10000) through the status
  defense, with the duration kept (`SCSTART_NOTICKDEF`), unless the script gave
  an explicit `flag` (`SCSTART_*` bits); an NPC script's start cannot be avoided
  (`SCSTART_NOAVOID`).

  The status lives in external storage, not in `game_state`, so the context is
  returned unchanged. Halts `:no_player` on a detached ctx — there is no
  `char_id` to key the status storage on.
  """
  @spec sc_start(
          Ctx.t(),
          atom(),
          non_neg_integer(),
          integer(),
          0..10_000,
          non_neg_integer() | nil
        ) ::
          Ctx.t()
  def sc_start(ctx, status, duration_ms, val, rate \\ 10_000, flag \\ nil)

  def sc_start(%Ctx{status: {:error, _}} = ctx, _status, _duration_ms, _val, _rate, _flag),
    do: ctx

  def sc_start(%Ctx{game_state: nil} = ctx, _status, _duration_ms, _val, _rate, _flag),
    do: Ctx.halt(ctx, :no_player)

  def sc_start(%Ctx{} = ctx, status, duration_ms, val, rate, flag) do
    flag = flag || default_start_flag(ctx.source)

    params =
      [val1: val, duration: duration_ms, success_rate: min(rate, 10_000) / 100]
      |> put_start_flag(:no_avoid, flag, @scstart_noavoid)
      |> put_start_flag(:no_tick_def, flag, @scstart_notickdef)
      |> put_start_flag(:no_rate_def, flag, @scstart_noratedef)

    StatusInterpreter.apply_status(:player, ctx.char_id, status, params)
    ctx
  end

  defp default_start_flag({:npc, _module}), do: @scstart_noavoid
  defp default_start_flag(_item), do: @scstart_notickdef

  defp put_start_flag(params, key, flag, bit),
    do: if(band(flag, bit) != 0, do: Keyword.put(params, key, true), else: params)

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
  Resets the attached player's levels according to `type` (`resetlvl`):

  - `1` resets base/job levels, experience, skills, allocated stats, and options.
  - `2` resets base/job levels, experience, and skills, preserving allocated stats.
  - `3` resets only base level and base experience.
  - `4` resets job level, job experience, and skills.

  Invalid types halt the script with `:invalid_reset_type`.
  """
  @spec resetlvl(Ctx.t(), integer()) :: Ctx.t()
  def resetlvl(%Ctx{status: {:error, _}} = ctx, _type), do: ctx
  def resetlvl(%Ctx{} = ctx, type), do: apply_op(ctx, {:reset_level, type})

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
  Opens the guild storage window through the session seam. Never halts:
  access-gate failures are reported to the client as a `StorageResult`, not a
  script error.

  Call `guildopenstorage` immediately before `close` so the NPC dialog does not
  linger alongside the storage window.
  """
  @spec guildopenstorage(Ctx.t()) :: Ctx.t()
  def guildopenstorage(%Ctx{status: {:error, _}} = ctx), do: ctx
  def guildopenstorage(%Ctx{} = ctx), do: apply_op(ctx, {:guildopenstorage})

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
  Equips or dismisses the Falcon. NPC scripts use the session seam; item scripts
  stage the toggle for their owning session's item handler. A zero flag dismisses;
  every non-zero integer equips, matching rAthena truthiness.
  """
  @spec setfalcon(Ctx.t(), integer()) :: Ctx.t()
  def setfalcon(%Ctx{status: {:error, _}} = ctx, _flag), do: ctx

  def setfalcon(%Ctx{source: {:item, _}} = ctx, flag),
    do: stage_session_effect(ctx, {:falcon, flag != 0})

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

  defp roll(lo..hi//_step), do: lo + :rand.uniform(hi - lo + 1) - 1
  defp roll(amount) when is_integer(amount), do: amount
end
