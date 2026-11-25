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

  require Logger

  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
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

  @doc """
  Starts a catch with the item being used as the lure and the normal flag (the
  `pet` command with no arguments). Outside an item script there is no item
  being used, so the command fails.
  """
  @spec catchpet(Ctx.t()) :: Ctx.t()
  def catchpet(%Ctx{status: {:error, _}} = ctx), do: ctx
  def catchpet(%Ctx{source: {:item, item_id}} = ctx), do: catchpet(ctx, item_id, 0)
  def catchpet(%Ctx{} = ctx), do: Ctx.fail(ctx, :catchpet, :no_lure)

  @doc "Starts a catch with `lure_id` and the normal flag."
  @spec catchpet(Ctx.t(), pos_integer()) :: Ctx.t()
  def catchpet(%Ctx{} = ctx, lure_id), do: catchpet(ctx, lure_id, 0)

  @doc """
  Starts a catch with `lure_id` and `flag`: 0 the lure must be the pet's taming
  item, 1 any mob that is not status-immune, 2 any mob. An unknown lure fails
  the command; a flag outside `0..2` is logged and kept, and catches like 2.

  In an item script the catch is staged and starts once the item is spent;
  elsewhere it is applied through the player session.
  """
  @spec catchpet(Ctx.t(), pos_integer(), integer()) :: Ctx.t()
  def catchpet(%Ctx{status: {:error, _}} = ctx, _lure_id, _flag), do: ctx

  def catchpet(%Ctx{} = ctx, lure_id, flag) when is_integer(lure_id) and is_integer(flag) do
    if flag not in 0..2, do: Logger.error("catchpet: invalid value '#{flag}' for flag")

    case Items.by_id(lure_id) do
      {:ok, _definition} -> stage_pet_effect(ctx, {:catchpet, lure_id, flag})
      :error -> Ctx.fail(ctx, :catchpet, :invalid_lure)
    end
  end

  @doc """
  Opens the egg list (the `bpet` command). Staged in an item script like
  `catchpet/3`, so the list opens once the item is spent.
  """
  @spec birthpet(Ctx.t()) :: Ctx.t()
  def birthpet(%Ctx{status: {:error, _}} = ctx), do: ctx
  def birthpet(%Ctx{} = ctx), do: stage_pet_effect(ctx, {:birthpet})

  defp stage_pet_effect(%Ctx{session_pid: nil, source: {:item, _}} = ctx, op),
    do: stage_session_effect(ctx, {:pet, op})

  defp stage_pet_effect(ctx, op), do: apply_op(ctx, op)

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
  @spec heal(Ctx.t(), hp: integer() | Range.t(), sp: integer() | Range.t()) :: Ctx.t()
  def heal(ctx, opts), do: vitals(ctx, fn -> {:heal, amount(opts, :hp), amount(opts, :sp)} end)

  @doc """
  Heals the player by HP/SP amounts scaled by their item recovery bonuses and
  statuses (the `itemheal` command), for the item whose script runs (`nil` from
  an NPC script). Takes the same `opts` as `heal/2`.

  A thrown potion's script (`{:potion_pitch, item_id}` source) heals no one: it
  stages the rolled amounts as `{:potion_pitch, :flat, hp, sp}` for the thrower.
  Its plain `heal`, unlike these two, is not redirected: it heals the thrower.
  """
  @spec item_heal(Ctx.t(), hp: integer() | Range.t(), sp: integer() | Range.t()) :: Ctx.t()
  def item_heal(%Ctx{source: {:potion_pitch, _item_id}} = ctx, opts),
    do: pitch(ctx, :flat, opts)

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

  A thrown potion's script stages the percents as `{:potion_pitch, :percent,
  hp, sp}` instead.
  """
  @spec percent_heal(Ctx.t(), hp: integer() | Range.t(), sp: integer() | Range.t()) :: Ctx.t()
  def percent_heal(%Ctx{source: {:potion_pitch, _item_id}} = ctx, opts),
    do: pitch(ctx, :percent, opts)

  def percent_heal(ctx, opts),
    do: vitals(ctx, fn -> {:percent_heal, amount(opts, :hp), amount(opts, :sp)} end)

  defp pitch(%Ctx{status: {:error, _}} = ctx, _kind, _opts), do: ctx

  defp pitch(ctx, kind, opts),
    do: stage_session_effect(ctx, {:potion_pitch, kind, amount(opts, :hp), amount(opts, :sp)})

  defp vitals(%Ctx{status: {:error, _}} = ctx, _op), do: ctx

  # `heal` is not redirected to the target of a thrown potion: it heals the
  # thrower, whose state the throw commits (no client push here).
  defp vitals(%Ctx{source: {:potion_pitch, _}} = ctx, op) do
    {game_state, damage} = ScriptVitals.apply(op.(), ctx.game_state)
    stage_script_damage(%{ctx | game_state: game_state}, damage)
  end

  defp vitals(%Ctx{game_state: nil} = ctx, _op), do: Ctx.halt(ctx, :no_player)

  defp vitals(%Ctx{source: {:item, _}} = ctx, op) do
    {game_state, damage} = ScriptVitals.apply(op.(), ctx.game_state)
    ScriptVitals.sync(ctx.connection_pid, ctx.game_state, game_state)
    stage_script_damage(%{ctx | game_state: game_state}, damage)
  end

  defp vitals(%Ctx{} = ctx, op), do: apply_op(ctx, op.())

  defp stage_script_damage(ctx, nil), do: ctx
  defp stage_script_damage(ctx, damage), do: stage_session_effect(ctx, {:script_damage, damage})

  defp amount(opts, key), do: opts |> Keyword.get(key, 0) |> roll()

  defp healing_item({:item, item_id}), do: item_id
  defp healing_item({:npc, _module}), do: nil

  @doc """
  Applies a status effect to the player for `duration_ms` with strength `val`.

  `val` is either a single `val1` or a four-integer list carrying `val1` through
  `val4`, as used by multi-value consumable statuses.

  Starts it as the `sc_start` script command does, with the player as its own
  source: an item script lands at `rate` (per 10000) through the status
  defense, with the duration kept (`SCSTART_NOTICKDEF`), unless the script gave
  an explicit `flag` (`SCSTART_*` bits); an NPC script's start cannot be avoided
  (`SCSTART_NOAVOID`).

  The status lives in external storage. An inline item context reconciles its
  owning session immediately, so later reads and heals see the new maxima and
  modifiers. A detached ctx has no unit to start it on, so the command does
  nothing and the script goes on.
  """
  @spec sc_start(
          Ctx.t(),
          atom(),
          non_neg_integer(),
          integer() | [integer()],
          0..10_000,
          non_neg_integer() | nil
        ) ::
          Ctx.t()
  def sc_start(ctx, status, duration_ms, val, rate \\ 10_000, flag \\ nil)

  def sc_start(%Ctx{status: {:error, _}} = ctx, _status, _duration_ms, _val, _rate, _flag),
    do: ctx

  def sc_start(%Ctx{game_state: nil} = ctx, _status, _duration_ms, _val, _rate, _flag), do: ctx

  def sc_start(%Ctx{} = ctx, status, duration_ms, val, rate, flag) do
    flag = flag || default_start_flag(ctx.source)

    params =
      val
      |> start_values()
      |> Keyword.merge(
        caster_id: ctx.char_id,
        duration: duration_ms,
        success_rate: min(rate, 10_000) / 100
      )
      |> put_start_flag(:no_avoid, flag, @scstart_noavoid)
      |> put_start_flag(:no_tick_def, flag, @scstart_notickdef)
      |> put_start_flag(:no_rate_def, flag, @scstart_noratedef)

    events =
      case StatusInterpreter.apply_status_with_events(:player, ctx.char_id, status, params) do
        {:ok, committed} -> committed
        {:error, _reason, committed} -> committed
      end

    refresh_item_status(ctx, events)
  end

  defp refresh_item_status(%Ctx{source: {:item, _}, session_state: state} = ctx, events)
       when not is_nil(state) do
    {:ok, ctx} = Ctx.update_session(ctx, &{:ok, StatusManager.refresh_events(&1, events)})
    ctx
  end

  defp refresh_item_status(ctx, _events), do: ctx

  defp start_values([val1, val2, val3, val4]),
    do: [val1: val1, val2: val2, val3: val3, val4: val4]

  defp start_values(val1) when is_integer(val1), do: [val1: val1]

  defp default_start_flag({:npc, _module}), do: @scstart_noavoid
  defp default_start_flag(_item), do: @scstart_notickdef

  defp put_start_flag(params, key, flag, bit),
    do: if(band(flag, bit) != 0, do: Keyword.put(params, key, true), else: params)

  @doc """
  Removes a status effect from the player and reconciles committed inline mutations.

  Canonical status-removal op, pairing with `sc_start/4`. A detached ctx has no
  unit to remove it from, so the command does nothing and the script goes on.
  """
  @spec sc_end(Ctx.t(), atom()) :: Ctx.t()
  def sc_end(%Ctx{status: {:error, _}} = ctx, _status), do: ctx
  def sc_end(%Ctx{game_state: nil} = ctx, _status), do: ctx

  def sc_end(%Ctx{} = ctx, status) do
    {:ok, events} = StatusInterpreter.remove_status_with_events(:player, ctx.char_id, status, [])
    refresh_item_status(ctx, events)
  end

  @doc """
  Removes a status effect from the player. Alias for `sc_end/2`.

  Inherits `sc_end/2`'s no-op on a detached ctx (pure delegation).
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
  pushing the refreshed experience/stat state to the client. A negative amount,
  or both amounts zero, fails the command and the script goes on.
  """
  @spec getexp(Ctx.t(), non_neg_integer(), non_neg_integer()) :: Ctx.t()
  def getexp(%Ctx{status: {:error, _}} = ctx, _base_exp, _job_exp), do: ctx

  def getexp(%Ctx{} = ctx, base_exp, job_exp) when base_exp < 0 or job_exp < 0,
    do: Ctx.fail(ctx, :getexp, :negative_exp)

  def getexp(%Ctx{} = ctx, 0, 0), do: Ctx.fail(ctx, :getexp, :no_exp)
  def getexp(%Ctx{} = ctx, base_exp, job_exp), do: apply_op(ctx, {:getexp, base_exp, job_exp})

  @doc """
  Resets the attached player's levels according to `type` (`resetlvl`):

  - `1` resets base/job levels, experience, skills, allocated stats, and options.
  - `2` resets base/job levels, experience, and skills, preserving allocated stats.
  - `3` resets only base level and base experience.
  - `4` resets job level, job experience, and skills.

  An invalid type, or an active cart, fails the command and the script goes on.
  """
  @spec resetlvl(Ctx.t(), integer()) :: Ctx.t()
  def resetlvl(%Ctx{status: {:error, _}} = ctx, _type), do: ctx
  def resetlvl(%Ctx{} = ctx, type), do: apply_op(ctx, {:reset_level, type})

  @doc """
  Changes the player's job through the session seam, recomputing job-dependent
  stats and refreshing the client's sprite/skill window. Accepts either a
  numeric job id or a job name atom (as `Job_*` constants transpile to). A job
  that does not resolve, or a change the player does not qualify for, fails the
  command and the script goes on.
  """
  @spec jobchange(Ctx.t(), non_neg_integer() | atom()) :: Ctx.t()
  def jobchange(%Ctx{status: {:error, _}} = ctx, _job), do: ctx

  def jobchange(%Ctx{} = ctx, job_id) when is_integer(job_id),
    do: apply_op(ctx, {:change_job, job_id})

  def jobchange(%Ctx{} = ctx, job_name) when is_atom(job_name) do
    case AvailableJobs.job_name_to_id(job_name) do
      {:ok, job_id} -> apply_op(ctx, {:change_job, job_id})
      {:error, reason} -> Ctx.fail(ctx, :jobchange, reason)
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
  Gives the player a cart (`setcart`) through the session seam: `type` 0
  removes it, any other type from 1 to 13 mounts a cart of that type or, with a
  cart mounted, changes it to that type. A type outside 0..13 does nothing.
  Mounting or changing requires `MC_PUSHCART` learned; a rejected mount reports
  to the client as a `CartMountResult` and the script goes on. Removal with a
  non-empty cart is a no-op (Aesir never discards cart items). Halts
  `:no_player` on a detached ctx.
  """
  @spec setcart(Ctx.t(), non_neg_integer()) :: Ctx.t()
  def setcart(ctx, type \\ 1)
  def setcart(%Ctx{status: {:error, _}} = ctx, _type), do: ctx
  def setcart(%Ctx{} = ctx, type), do: apply_op(ctx, {:setcart, type})

  @doc """
  Mounts or dismounts the Peco-Peco through the session seam (rAthena
  `setriding`). Mounting requires `KN_RIDING` learned; a rejected mount fails
  the command and the script goes on. Dismounting is always a no-op success,
  mounted or not. Halts `:no_player` on a detached ctx.
  """
  @spec set_riding(Ctx.t(), boolean()) :: Ctx.t()
  def set_riding(%Ctx{status: {:error, _}} = ctx, _riding?), do: ctx
  def set_riding(%Ctx{} = ctx, riding?), do: apply_op(ctx, {:set_riding, riding?})

  @doc """
  Equips or dismisses the Falcon. NPC scripts use the session seam; item scripts
  stage the toggle for their owning session's item handler. A zero or `false` flag
  dismisses; any other value equips, matching rAthena truthiness.
  """
  @spec setfalcon(Ctx.t(), boolean() | integer()) :: Ctx.t()
  def setfalcon(%Ctx{status: {:error, _}} = ctx, _flag), do: ctx

  def setfalcon(%Ctx{source: {:item, _}} = ctx, flag),
    do: stage_session_effect(ctx, {:falcon, Rathena.truthy?(flag)})

  def setfalcon(%Ctx{} = ctx, flag), do: apply_op(ctx, {:set_falcon, Rathena.truthy?(flag)})

  @doc """
  Attaches the script to the online player with `account_id` (rAthena
  `attachrid`), so subsequent commands, reads and dialog target that player.

  The player the script is attached to is let go, as `script_detach_rid`
  does (the dialog the script took over there holds them again, or they are
  free), then the target's session attaches the script the way the
  reference's `script_attach_state` does, taking over the dialog holding
  them, if any (`PlayerSession.attach_script/4`). Without `force` (default
  on) a player held by a script refuses at once, and the script stays with
  its player. A forced attach waits while the target's script runs between
  two waits, so letting the old player go first keeps two scripts forcing
  their way onto each other's players from waiting on each other.
  Re-attaching to that same player changes nothing.

  Returns `{ctx, 1}` with the ctx re-pointed at the target (its session,
  snapshot, connection and the monitor the script's waits watch), or
  `{ctx, 0}` when the account is offline, has no character in this zone, or
  refused. A target gone while a forced attach waits leaves the script with
  no player. An item script running inline in its player session cannot hand
  that session to another, so the command fails there (no item script uses
  it).
  """
  @spec attachrid(Ctx.t(), integer(), boolean() | integer()) :: {Ctx.t(), 0 | 1}
  def attachrid(%Ctx{} = ctx, account_id), do: attachrid(ctx, account_id, true)

  def attachrid(%Ctx{status: {:error, _}} = ctx, _account_id, _force), do: {ctx, 0}

  def attachrid(%Ctx{session_state: state} = ctx, _account_id, _force) when state != nil,
    do: {Ctx.fail(ctx, :attachrid, :inline_script), 0}

  def attachrid(%Ctx{} = ctx, account_id, force) do
    with {:ok, char_id} <- UnitRegistry.get_char_id_by_account(account_id),
         {:ok, {_module, _game_state, pid}} when is_pid(pid) <-
           UnitRegistry.get_unit(:player, char_id) do
      attach_to(ctx, {char_id, account_id, pid}, Rathena.truthy?(force))
    else
      _offline -> {ctx, 0}
    end
  end

  defp attach_to(%Ctx{session_pid: pid} = ctx, {_char_id, _account_id, pid}, force?) do
    case PlayerSession.attach_script(pid, self(), ctx.npc_gid, force?) do
      {:ok, target} -> {%{ctx | game_state: target.game_state}, 1}
      _busy_or_gone -> {ctx, 0}
    end
  end

  defp attach_to(ctx, {_char_id, _account_id, pid} = player, true) do
    ctx = release_player(ctx)

    case PlayerSession.attach_script(pid, self(), ctx.npc_gid, true) do
      {:ok, target} -> {repoint(ctx, player, target), 1}
      _gone -> {Ctx.detach(ctx), 0}
    end
  end

  defp attach_to(ctx, {_char_id, _account_id, pid} = player, false) do
    case PlayerSession.attach_script(pid, self(), ctx.npc_gid, false) do
      {:ok, target} -> {ctx |> release_player() |> repoint(player, target), 1}
      _busy_or_gone -> {ctx, 0}
    end
  end

  defp release_player(ctx) do
    if ctx.session_pid, do: PlayerSession.detach_script(ctx.session_pid, self())
    if ctx.session_ref, do: Process.demonitor(ctx.session_ref, [:flush])
    ctx
  end

  defp repoint(ctx, {char_id, account_id, pid}, target) do
    %{
      ctx
      | char_id: char_id,
        account_id: account_id,
        game_state: target.game_state,
        session_pid: pid,
        connection_pid: target.connection_pid,
        session_ref: Process.monitor(pid)
    }
  end

  defp roll(lo..hi//_step), do: lo + :rand.uniform(hi - lo + 1) - 1
  defp roll(amount) when is_integer(amount), do: amount
end
