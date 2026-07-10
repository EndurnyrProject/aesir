defmodule Aesir.ZoneServer.Script.Dsl do
  @moduledoc """
  The item/NPC scripting DSL: the effect and read primitives every script uses.

  Functions are plain and take the script `Ctx` first so they can be `import`ed
  into a generated module or called directly from an NPC module. They split into
  two groups:

  - **Effects** (`(ctx, args) -> ctx`) short-circuit when `ctx.status` is already
    an error, perform their subsystem side effect synchronously inside the player
    session, thread the resulting `PlayerState` back into `ctx.game_state`, and
    halt the context with `Ctx.halt/2` on a subsystem error.
  - **Reads** (`(ctx) -> value`) pull a value out of `ctx.game_state` and ignore
    status.
  """

  require Logger

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.StatusParams
  alias Aesir.Net.ChatMessage
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Npc.Events, as: NpcEvents
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Todo
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.Handlers.RefineOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.SpecialEffect

  @typedoc "An HP/SP heal amount: a flat integer or a `lo..hi` range to roll within."
  @type amount :: integer() | Range.t()

  @typedoc "The dialog frame kind, mirroring the `NpcDialog.Expect` proto enum."
  @type expect :: :NEXT | :MENU | :INPUT_INT | :INPUT_STR | :CLOSE

  @typedoc "One inventory item's refine state and eligibility, from `refine_targets/1`."
  @type refine_target :: %{
          index: non_neg_integer(),
          nameid: integer(),
          name: String.t(),
          refine: non_neg_integer(),
          refinable?: boolean()
        }

  @typedoc "The ore/zeny/blessing cost of one refine attempt, from `refine_cost/3`."
  @type refine_cost :: %{
          ore_nameid: integer() | nil,
          ore_amount: non_neg_integer(),
          zeny: non_neg_integer(),
          blessing_amount: non_neg_integer()
        }

  @max_refine RefineDatabase.max_refine()
  @refine_ore_amount 1

  # Idle deadline for a blocking dialog suspension. The client freezes the
  # player during a dialog, so a `receive` that never returns means the player
  # abandoned the window; the interaction exits and the session clears the lock.
  # Read from app env at call time so tests can shrink it.
  @default_dialog_idle_timeout :timer.seconds(60)

  @spec dialog_idle_timeout() :: timeout()
  defp dialog_idle_timeout do
    Application.get_env(:zone_server, :dialog_idle_timeout, @default_dialog_idle_timeout)
  end

  @doc """
  Appends a line to the context's dialog page buffer and returns the context.

  Pure: composes with `|>` and sends nothing. The buffered lines flush, joined
  with `"\\n"`, at the next terminal dialog op (`next/1`, `select/2`, `input/2`,
  `close/1`). Halts `:no_player` on a detached ctx (no player to dialog with)
  without buffering the line.
  """
  @spec mes(Ctx.t(), String.t()) :: Ctx.t()
  def mes(%Ctx{game_state: nil} = ctx, _text), do: Ctx.halt(ctx, :no_player)
  def mes(%Ctx{page: page} = ctx, text), do: %{ctx | page: page ++ [text]}

  @doc """
  Flushes the buffered page as a `NEXT` frame, blocks for the client's
  acknowledgement, clears the buffer, and returns the context.

  Halts `:no_player` on a detached ctx without flushing or blocking.
  """
  @spec next(Ctx.t()) :: Ctx.t()
  def next(%Ctx{game_state: nil} = ctx), do: Ctx.halt(ctx, :no_player)

  def next(%Ctx{} = ctx) do
    flush(ctx, :NEXT, [])
    await(ctx, :continue)
    %{ctx | page: []}
  end

  @doc """
  Flushes the buffered page as a `MENU` frame with `options`, blocks for the
  client's choice, and returns `{ctx, choice}`.

  `choice` is the 1-based index the client selected; a cancel/ESC response
  yields `0`. The page buffer is cleared. On a detached ctx, halts `:no_player`
  and returns `{ctx, nil}` without flushing or blocking.
  """
  @spec select(Ctx.t(), [String.t()]) :: {Ctx.t(), non_neg_integer() | nil}
  def select(%Ctx{game_state: nil} = ctx, _options), do: {Ctx.halt(ctx, :no_player), nil}

  def select(%Ctx{} = ctx, options) do
    flush(ctx, :MENU, options)
    {%{ctx | page: []}, await(ctx, :choice)}
  end

  @doc """
  Flushes the buffered page as an input frame, blocks for the client's value,
  and returns `{ctx, value}`.

  `kind` is `:int` (an `INPUT_INT` frame returning a number) or `:string` (an
  `INPUT_STR` frame returning a string). The page buffer is cleared. On a
  detached ctx, halts `:no_player` and returns `{ctx, nil}` without flushing or
  blocking.
  """
  @spec input(Ctx.t(), :int | :string) :: {Ctx.t(), integer() | String.t() | nil}
  def input(%Ctx{game_state: nil} = ctx, _kind), do: {Ctx.halt(ctx, :no_player), nil}

  def input(%Ctx{} = ctx, :int) do
    flush(ctx, :INPUT_INT, [])
    {%{ctx | page: []}, await(ctx, :number)}
  end

  def input(%Ctx{} = ctx, :string) do
    flush(ctx, :INPUT_STR, [])
    {%{ctx | page: []}, await(ctx, :input)}
  end

  @doc """
  Flushes any remaining buffered page as a `CLOSE` frame and returns the context.

  Does not block: the script returns and the interaction process exits `:normal`.
  Halts `:no_player` on a detached ctx without flushing.
  """
  @spec close(Ctx.t()) :: Ctx.t()
  def close(%Ctx{game_state: nil} = ctx), do: Ctx.halt(ctx, :no_player)

  def close(%Ctx{} = ctx) do
    flush(ctx, :CLOSE, [])
    %{ctx | page: []}
  end

  @spec flush(Ctx.t(), expect(), [String.t()]) :: :ok
  defp flush(%Ctx{} = ctx, expect, options) do
    dialog = %NpcDialog{
      npc_id: ctx.npc_gid,
      text: Enum.join(ctx.page, "\n"),
      expect: expect,
      options: options
    }

    MessageRouter.send_to(ctx.connection_pid, dialog)
  end

  # The single shared blocking receive for every suspending dialog primitive.
  #
  # Blocks until an NpcInteract for this NPC carrying the expected response arm
  # arrives, returning the arm's value. A message for a different npc_id, or
  # carrying an unexpected response arm, is dropped and the wait continues.
  # Three paths end the wait by exiting the interaction process (which, via the
  # session's monitor, clears the lock): a `cancel`/ESC for this NPC at any
  # suspension point (design §Part 2 "cancel/ESC … clear the lock" — promptly,
  # not only on menus), the session dying — observed through the monitor the
  # interaction holds in `ctx.session_ref` — and the idle deadline for an
  # abandoned window. (Sphinx Mask's "No deal" is an explicit menu option, a
  # `:choice`, not an ESC, so uniform exit-on-cancel does not lose any flow.)
  @spec await(Ctx.t(), atom()) :: term()
  defp await(%Ctx{npc_gid: gid, session_ref: session_ref} = ctx, expected) do
    receive do
      {:npc_interact, %NpcInteract{npc_id: ^gid, response: {^expected, value}}} ->
        value

      {:npc_interact, %NpcInteract{npc_id: ^gid, response: {:cancel, _}}} ->
        exit(:normal)

      {:npc_interact, %NpcInteract{}} ->
        await(ctx, expected)

      {:DOWN, ^session_ref, :process, _pid, _reason} ->
        exit(:normal)
    after
      # Exit :normal (not a custom reason) so the abandoned-window cleanup
      # doesn't spam the supervisor's task-terminated error log. The session
      # clears the lock on the monitor :DOWN regardless of reason.
      dialog_idle_timeout() -> exit(:normal)
    end
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
    apply_heal(ctx, fn current, _max -> current + roll(Keyword.get(opts, :hp, 0)) end, fn
      current, _max -> current + roll(Keyword.get(opts, :sp, 0))
    end)
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
  Plays a one-shot `EF_*` visual effect on the player, shown to every player in
  view range (rAthena `specialeffect2`).

  Purely cosmetic, so the context is returned unchanged and a detached ctx (no
  player to originate the effect from) is a silent no-op rather than a halt — a
  missing sprite burst must never abort the surrounding script.
  """
  @spec specialeffect2(Ctx.t(), atom()) :: Ctx.t()
  def specialeffect2(%Ctx{status: {:error, _}} = ctx, _effect), do: ctx
  def specialeffect2(%Ctx{game_state: nil} = ctx, _effect), do: ctx

  def specialeffect2(%Ctx{} = ctx, effect) do
    SpecialEffect.play({:player, ctx.char_id}, effect, :area)
    ctx
  end

  @doc """
  Relocates the player.

  - `{map, x, y}` — to an explicit cell. Halts on `:map_not_found`.
  - `:random` — to a random walkable cell on the current map (fly wing).
  - `:save_point` — to the player's save point (butterfly wing).

  Halts on a resolution or warp error. Halts `:no_player` on a detached ctx
  (there is no player to relocate).
  """
  @spec warp(Ctx.t(), {String.t(), non_neg_integer(), non_neg_integer()} | :random | :save_point) ::
          Ctx.t()
  def warp(%Ctx{} = ctx, {map, x, y}), do: warp(ctx, map, x, y)

  def warp(%Ctx{status: {:error, _}} = ctx, :random), do: ctx
  def warp(%Ctx{game_state: nil} = ctx, :random), do: Ctx.halt(ctx, :no_player)

  def warp(%Ctx{game_state: game_state} = ctx, :random) do
    with {:ok, map_data} <- MapCache.get(game_state.map_name),
         {:ok, {x, y}} <- MapData.random_walkable_cell(map_data) do
      warp(ctx, game_state.map_name, x, y)
    else
      {:error, reason} -> Ctx.halt(ctx, reason)
    end
  end

  def warp(%Ctx{status: {:error, _}} = ctx, :save_point), do: ctx
  def warp(%Ctx{game_state: nil} = ctx, :save_point), do: Ctx.halt(ctx, :no_player)

  def warp(%Ctx{game_state: game_state} = ctx, :save_point) do
    warp(ctx, game_state.save_map, game_state.save_x, game_state.save_y)
  end

  @spec warp(Ctx.t(), String.t(), non_neg_integer(), non_neg_integer()) :: Ctx.t()
  def warp(%Ctx{status: {:error, _}} = ctx, _map, _x, _y), do: ctx
  def warp(%Ctx{game_state: nil} = ctx, _map, _x, _y), do: Ctx.halt(ctx, :no_player)

  def warp(%Ctx{} = ctx, map, x, y) do
    session = %{game_state: ctx.game_state, connection_pid: ctx.connection_pid}

    case WarpHandler.warp(session, map, x, y) do
      {:ok, %{game_state: new_game_state}} -> %{ctx | game_state: new_game_state}
      {:error, reason} -> Ctx.halt(ctx, reason)
    end
  end

  @doc """
  Sets the player's save (respawn) point to `map`,`x`,`y` — the destination
  they return to on death. Mirrors rAthena's `savepoint`.
  """
  @spec savepoint(Ctx.t(), String.t(), non_neg_integer(), non_neg_integer()) :: Ctx.t()
  def savepoint(%Ctx{status: {:error, _}} = ctx, _map, _x, _y), do: ctx
  def savepoint(%Ctx{} = ctx, map, x, y), do: apply_op(ctx, {:set_save_point, map, x, y})

  @doc """
  Casts a skill programmatically on the player.

  `skill_id_or_name` is a skill id or its catalog name atom. `opts` accepts
  `:level` (default 1) and `:target` (default `:self`). Halts on a cast error or
  an unknown skill name. Halts `:no_player` on a detached ctx.
  """
  @spec itemskill(Ctx.t(), integer() | atom(), keyword()) :: Ctx.t()
  def itemskill(%Ctx{status: {:error, _}} = ctx, _skill, _opts), do: ctx
  def itemskill(%Ctx{game_state: nil} = ctx, _skill, _opts), do: Ctx.halt(ctx, :no_player)

  def itemskill(%Ctx{} = ctx, skill_id_or_name, opts) do
    level = Keyword.get(opts, :level, 1)
    target = Keyword.get(opts, :target, :self)

    with {:ok, skill_id} <- resolve_skill_id(skill_id_or_name),
         {:ok, new_game_state} <- SkillInterpreter.cast(ctx.game_state, skill_id, level, target) do
      %{ctx | game_state: new_game_state}
    else
      {:error, reason} -> Ctx.halt(ctx, reason)
    end
  end

  @doc """
  Spawns a monster on the player's current map, registered so it is attackable.

  `opts` accepts `:mob_id` or `:mob_name` (one is required; `:mob_name` is the
  AEGIS name, matching `MobManagement.get_mob_by_name/1`), `:at` as a `{x, y}`
  tuple or `:random` for a random walkable cell (defaults to the player's
  current position), `:map` to spawn on an explicit map instead of the
  player's (rAthena `monster "map",...`; with `:map`, `:at` defaults to
  `:random` and an unknown map halts `:map_not_found`), `:amount` (spawn
  count, default 1), `:aggressive` (accepted but deferred in Phase 1, kept
  for the Dead Branch interface), and `:event` (optional, a `"Name::OnLabel"`
  ref — rAthena OnMyMobDead — run with the killer attached if the mob is
  later killed by a player; a malformed ref logs a warning and is dropped,
  the mob still spawns without it). Halts on an unknown mob or a spawn
  failure; returns the context unchanged on success.

  Detached-capable: on a detached ctx, `:map`/`:at` still apply, but the
  default map and position come from `ctx.npc_gid`'s own placement
  (`Npc.Registry.module_for_unit/1`) instead of a player. Without `:map`,
  halts `:no_player` when `ctx.npc_gid` is `nil` or doesn't resolve — there
  is nowhere to spawn.
  """
  @spec summon_mob(Ctx.t(), keyword()) :: Ctx.t()
  def summon_mob(%Ctx{status: {:error, _}} = ctx, _opts), do: ctx

  def summon_mob(%Ctx{} = ctx, opts) do
    case resolve_mob(opts) do
      {:ok, mob_data} -> spawn_mob_at(ctx, mob_data.id, opts)
      {:error, reason} -> Ctx.halt(ctx, reason)
    end
  end

  @doc """
  Spawns a random monster from the catalog, like `summon_mob/2` with a rolled id.

  `opts` accepts `:at`, `:map`, `:amount`, `:aggressive`, and `:event` (see
  `summon_mob/2`). Halts with `:no_mobs` if the catalog is empty.
  Detached-capable, same reasoning as `summon_mob/2`.
  """
  @spec summon_random_mob(Ctx.t(), keyword()) :: Ctx.t()
  def summon_random_mob(%Ctx{status: {:error, _}} = ctx, _opts), do: ctx

  def summon_random_mob(%Ctx{} = ctx, opts) do
    case MobManagement.get_all_mobs() do
      [] -> Ctx.halt(ctx, :no_mobs)
      mobs -> spawn_mob_at(ctx, Enum.random(mobs).id, opts)
    end
  end

  @doc """
  The player's current zeny. Pure read over the ctx snapshot.
  """
  @spec zeny(Ctx.t()) :: non_neg_integer()
  def zeny(%Ctx{game_state: nil}), do: no_player!("zeny/1")
  def zeny(%Ctx{game_state: gs}), do: gs.zeny

  @doc """
  Debits `amount` zeny through the session seam, pushing the change to the
  client and persisting it. Halts `:not_enough_zeny` when the player is short
  (debiting nothing).
  """
  @spec pay_zeny(Ctx.t(), non_neg_integer()) :: Ctx.t()
  def pay_zeny(%Ctx{status: {:error, _}} = ctx, _amount), do: ctx
  def pay_zeny(%Ctx{} = ctx, amount), do: apply_op(ctx, {:pay_zeny, amount})

  @doc """
  Credits `amount` zeny through the session seam, clamped at the zeny cap,
  pushing the change to the client and persisting it. Never fails.
  """
  @spec credit_zeny(Ctx.t(), non_neg_integer()) :: Ctx.t()
  def credit_zeny(%Ctx{status: {:error, _}} = ctx, _amount), do: ctx
  def credit_zeny(%Ctx{} = ctx, amount), do: apply_op(ctx, {:credit_zeny, amount})

  @doc """
  Gives `qty` of item `item_id` through the session seam (persisting and
  emitting `ItemAdded`). Halts on a full/overweight inventory.
  """
  @spec give_item(Ctx.t(), integer(), pos_integer()) :: Ctx.t()
  def give_item(%Ctx{status: {:error, _}} = ctx, _item_id, _qty), do: ctx
  def give_item(%Ctx{} = ctx, item_id, qty), do: apply_op(ctx, {:give_item, item_id, qty})

  @doc """
  Removes `qty` of item `item_id` through the session seam (persisting and
  emitting `ItemRemoved`). Halts `:not_enough_items` when the player holds fewer.
  """
  @spec delitem(Ctx.t(), integer(), pos_integer()) :: Ctx.t()
  def delitem(%Ctx{status: {:error, _}} = ctx, _item_id, _qty), do: ctx
  def delitem(%Ctx{} = ctx, item_id, qty), do: apply_op(ctx, {:delitem, item_id, qty})

  @doc """
  Total quantity of item `item_id` the player holds. Pure read over the snapshot.
  """
  @spec count_item(Ctx.t(), integer()) :: non_neg_integer()
  def count_item(%Ctx{game_state: nil}, _item_id), do: no_player!("count_item/2")

  def count_item(%Ctx{game_state: gs}, item_id),
    do: Inventory.held_amount(gs.inventory, item_id)

  @doc """
  Lists every refinable equip in inventory with its current refine state. Pure
  read over `ctx.game_state` + `RefineDatabase`; no session round-trip.
  """
  @spec refine_targets(Ctx.t()) :: [refine_target()]
  def refine_targets(%Ctx{game_state: nil}), do: no_player!("refine_targets/1")

  def refine_targets(%Ctx{game_state: gs}) do
    gs.inventory
    |> Enum.flat_map(&to_refine_target/1)
    |> Enum.sort_by(& &1.index)
  end

  @spec to_refine_target({non_neg_integer(), InventoryItem.t()}) :: [refine_target()]
  defp to_refine_target({index, %InventoryItem{nameid: nameid, refine: refine} = item}) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, %ItemDefinition{refineable: true, name: name} = item_def} ->
        [
          %{
            index: index,
            nameid: nameid,
            name: name,
            refine: refine,
            refinable?: refine_eligible?(item, item_def)
          }
        ]

      _not_refinable ->
        []
    end
  end

  @doc """
  Whether the inventory item at `index` is currently refinable (a refineable
  item type, below `MAX_REFINE`). Pure read; `false` for a missing index.
  """
  @spec refinable?(Ctx.t(), non_neg_integer()) :: boolean()
  def refinable?(%Ctx{game_state: nil}, _index), do: no_player!("refinable?/2")

  def refinable?(%Ctx{game_state: gs}, index) do
    case Map.get(gs.inventory, index) do
      %InventoryItem{nameid: nameid} = item ->
        case ItemManagement.get_item_by_id(nameid) do
          {:ok, item_def} -> refine_eligible?(item, item_def)
          {:error, _reason} -> false
        end

      nil ->
        false
    end
  end

  @doc """
  The success rate, as a display-friendly `0..100` percent, of refining the
  item at `index` with `cost_type` — the yml `Rate/100` for the attempt going
  `refine -> refine + 1`. Pure read. `0` when the item is not currently
  refinable or `cost_type` has no entry at this level.
  """
  @spec refine_rate(Ctx.t(), non_neg_integer(), RefineDatabase.cost_type()) :: 0..100
  def refine_rate(%Ctx{game_state: nil}, _index, _cost_type), do: no_player!("refine_rate/3")

  def refine_rate(%Ctx{} = ctx, index, cost_type) do
    case fetch_process(ctx, index, cost_type) do
      {:ok, _level_info, chance} -> div(chance.rate, 100)
      :error -> 0
    end
  end

  @doc """
  The ore/zeny/blessing cost of attempting to refine the item at `index` with
  `cost_type`. Pure read; an ineligible item or missing process data returns an
  all-zero cost with a `nil` ore.
  """
  @spec refine_cost(Ctx.t(), non_neg_integer(), RefineDatabase.cost_type()) :: refine_cost()
  def refine_cost(%Ctx{game_state: nil}, _index, _cost_type), do: no_player!("refine_cost/3")

  def refine_cost(%Ctx{} = ctx, index, cost_type) do
    case fetch_process(ctx, index, cost_type) do
      {:ok, level_info, chance} ->
        %{
          ore_nameid: chance.material_nameid,
          ore_amount: @refine_ore_amount,
          zeny: chance.price,
          blessing_amount: level_info.blessing_amount
        }

      :error ->
        %{ore_nameid: nil, ore_amount: 0, zeny: 0, blessing_amount: 0}
    end
  end

  @doc """
  Attempts to refine the item at inventory `index` using `cost_type` through
  the session seam (ore + zeny, and a Blacksmith Blessing when `use_blessing?`
  is requested and available). Unlike other effect ops, returns the tagged
  `RefineOps` outcome directly instead of folding an updated `ctx` — the script
  branches on the result to drive the rest of the dialog.

  The expected `nameid` at `index` is captured here and threaded into the op as
  a TOCTOU guard: `RefineOps` re-reads the item under the single-writer and
  rejects with `{:error, :no_item}` if the slot changed since the script chose
  it (e.g. from `refine_targets/1`). A missing item at `index` is rejected the
  same way without a session round-trip.

  ponytail: because this returns the tagged result instead of an updated
  `ctx`, a script that keeps dialoging after a successful refine (`mes`/`next`)
  sees the pre-refine `ctx.game_state` (stale zeny/inventory/refine level) —
  fine for branching on the outcome, not fine for a follow-up line that reads
  those values. A real refine NPC will need a refreshed `ctx`; add one if/when
  that NPC is written (Task 10 or later).

  Returns `{:error, :no_player}` on a detached ctx (there is no inventory to
  refine), same tagged-result shape as any other rejection.
  """
  @spec refine(Ctx.t(), non_neg_integer(), RefineDatabase.cost_type(), boolean()) ::
          RefineOps.result()
  def refine(ctx, index, cost_type, use_blessing? \\ false)

  def refine(%Ctx{status: {:error, reason}}, _index, _cost_type, _use_blessing?),
    do: {:error, reason}

  def refine(%Ctx{game_state: nil}, _index, _cost_type, _use_blessing?), do: {:error, :no_player}

  def refine(%Ctx{game_state: gs, session_pid: session_pid}, index, cost_type, use_blessing?) do
    case Map.get(gs.inventory, index) do
      %InventoryItem{nameid: nameid} ->
        GenServer.call(
          session_pid,
          {:script_apply, {:refine, index, nameid, cost_type, use_blessing?}}
        )

      nil ->
        {:error, :no_item}
    end
  end

  @spec refine_eligible?(InventoryItem.t(), ItemDefinition.t()) :: boolean()
  defp refine_eligible?(
         %InventoryItem{refine: refine},
         %ItemDefinition{refineable: true} = item_def
       ) do
    refine < @max_refine and
      match?({:ok, _group, _item_level}, RefineDatabase.group_and_level(item_def))
  end

  defp refine_eligible?(%InventoryItem{}, %ItemDefinition{}), do: false

  @spec fetch_process(Ctx.t(), non_neg_integer(), RefineDatabase.cost_type()) ::
          {:ok, RefineDatabase.level_info(), RefineDatabase.chance()} | :error
  defp fetch_process(%Ctx{game_state: gs}, index, cost_type) do
    with %InventoryItem{} = item <- Map.get(gs.inventory, index),
         {:ok, item_def} <- ItemManagement.get_item_by_id(item.nameid),
         true <- refine_eligible?(item, item_def),
         {:ok, group, item_level} <- RefineDatabase.group_and_level(item_def),
         level_info when not is_nil(level_info) <-
           RefineDatabase.level_info(group, item_level, item.refine + 1),
         {:ok, chance} <- Map.fetch(level_info.chances, cost_type) do
      {:ok, level_info, chance}
    else
      _not_refinable -> :error
    end
  end

  @doc """
  Reads the permanent char variable `key`, defaulting an unset var to `default`
  (`0` matching rAthena). Keys are atoms in scripts, stored string-keyed in the
  jsonb-backed `vars` map, so the lookup normalizes the atom to a string.
  """
  @spec get_char_var(Ctx.t(), atom(), term()) :: term()
  def get_char_var(ctx, key, default \\ 0)
  def get_char_var(%Ctx{game_state: nil}, _key, _default), do: no_player!("get_char_var/3")

  def get_char_var(%Ctx{game_state: gs}, key, default) do
    Map.get(gs.vars, to_string(key), default)
  end

  @doc """
  Sets the permanent char variable `key` to `value` through the session seam,
  which mutates `PlayerState.vars` and persists `%{vars: vars}` async. Never
  fails. The key is stringified at the jsonb boundary.
  """
  @spec set_char_var(Ctx.t(), atom(), term()) :: Ctx.t()
  def set_char_var(%Ctx{status: {:error, _}} = ctx, _key, _value), do: ctx
  def set_char_var(%Ctx{} = ctx, key, value), do: apply_op(ctx, {:set_char_var, key, value})

  @doc """
  Stub for an rAthena buildin with no Aesir implementation yet.

  Transpiled scripts call this in place of the unsupported command; reaching it
  raises `NotImplementedError` naming the buildin, which ends the interaction
  (a supervised Task) without harming the player session. The raise is
  indirect (see `Todo`) so generated `ctx = todo(...)` lines do not trip the
  compiler's no_return inference.
  """
  @spec todo(Ctx.t(), atom(), [term()]) :: Ctx.t()
  def todo(%Ctx{} = ctx, buildin, args) do
    Todo.call!(buildin, args)
    ctx
  end

  @doc """
  Reads the session temp variable `key` (rAthena `@var`), defaulting an unset
  var to `default` (`0` matching rAthena). Temp vars live on `PlayerState` for
  the session's lifetime and are never persisted.
  """
  @spec get_temp_var(Ctx.t(), atom(), term()) :: term()
  def get_temp_var(ctx, key, default \\ 0)
  def get_temp_var(%Ctx{game_state: nil}, _key, _default), do: no_player!("get_temp_var/3")

  def get_temp_var(%Ctx{game_state: gs}, key, default) do
    Map.get(gs.temp_vars, to_string(key), default)
  end

  @doc """
  Sets the session temp variable `key` to `value` through the session seam.
  Never fails and never persists; the var vanishes on logout.
  """
  @spec set_temp_var(Ctx.t(), atom(), term()) :: Ctx.t()
  def set_temp_var(%Ctx{status: {:error, _}} = ctx, _key, _value), do: ctx
  def set_temp_var(%Ctx{} = ctx, key, value), do: apply_op(ctx, {:set_temp_var, key, value})

  @doc """
  Sets the script-local variable `key` (rAthena `.@var`). Pure Ctx update; the
  value lives only for the duration of the running script.
  """
  @spec set_local(Ctx.t(), atom(), term()) :: Ctx.t()
  def set_local(%Ctx{status: {:error, _}} = ctx, _key, _value), do: ctx
  def set_local(%Ctx{vars: vars} = ctx, key, value), do: %{ctx | vars: Map.put(vars, key, value)}

  @doc """
  Reads the script-local variable `key`, defaulting an unset var to `default`
  (`0` matching rAthena).
  """
  @spec get_local(Ctx.t(), atom(), term()) :: term()
  def get_local(%Ctx{vars: vars}, key, default \\ 0), do: Map.get(vars, key, default)

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
  Fires `"Name::OnLabel"` as a detached, fire-and-forget event (rAthena
  `donpcevent`). Delegates to `Npc.Events.trigger/1`: an unresolved name or
  undeclared label logs a warning and no-ops. Returns `ctx` unchanged; valid
  on both an attached and a detached ctx, since it touches no player state.
  """
  @spec donpcevent(Ctx.t(), String.t()) :: Ctx.t()
  def donpcevent(%Ctx{status: {:error, _}} = ctx, _ref), do: ctx

  def donpcevent(%Ctx{} = ctx, ref) do
    NpcEvents.trigger(ref)
    ctx
  end

  @doc """
  Runs `"Name::OnLabel"` as a brand-new attached `Script.Interaction` for the
  *current* player (rAthena `doevent`). Resolves `name` through
  `Npc.Registry.by_name/1`; rAthena `doevent` targets exactly one NPC, so the
  first placement registered under `name` is used, logging a warning if the
  name maps to several. The new interaction's ctx is built fresh (own
  page/vars, `npc_gid` set to the target) but shares the current player's
  identity — char/account/connection/session — the same way a click builds
  one (see `NpcInteractionHandler.handle_talk/2`).

  Halts `{:error, :no_player}` on a detached ctx: there is no live player
  session for the new interaction to attach to. Also halts `{:error,
  :no_player}` when `ctx.session_pid` is `nil` even with `game_state` present
  — an item-script ctx's shape (`Ctx.from_session/2` runs inline on the
  session, never through a cross-process call) — since the new interaction
  needs a real session pid to monitor; starting one against `nil` would
  monitor nothing, never register as an interaction lock, and kill the
  interaction on its first blocking dialog primitive. Mirrors `apply_op/2`'s
  `session_pid` discriminator.

  The spawned interaction is an independent coroutine from the one calling
  `doevent`, not a subroutine: content should call `doevent` as its final
  act, since interleaving dialog between the two would race the client.
  """
  @spec doevent(Ctx.t(), String.t()) :: Ctx.t()
  def doevent(%Ctx{status: {:error, _}} = ctx, _ref), do: ctx
  def doevent(%Ctx{game_state: nil} = ctx, _ref), do: Ctx.halt(ctx, :no_player)

  def doevent(%Ctx{session_pid: nil} = ctx, _ref) do
    Logger.warning("npc doevent: ctx has no session_pid, no-op")
    Ctx.halt(ctx, :no_player)
  end

  def doevent(%Ctx{} = ctx, ref) do
    case split_ref(ref) do
      {:ok, name, label} ->
        dispatch_doevent(ctx, name, label)

      :error ->
        Logger.warning("npc doevent: malformed ref #{inspect(ref)}")
        ctx
    end
  end

  @doc """
  Arms the calling NPC's own timer, starting its session if needed (rAthena
  `initnpctimer`). Targets `ctx.npc_gid`; valid on both an attached and a
  detached ctx, since it mutates NPC state, not player state. A ctx with no
  `npc_gid` (e.g. an item script) logs a warning and no-ops.
  """
  @spec initnpctimer(Ctx.t()) :: Ctx.t()
  def initnpctimer(%Ctx{status: {:error, _}} = ctx), do: ctx
  def initnpctimer(%Ctx{npc_gid: nil} = ctx), do: warn_no_npc_gid(ctx, "initnpctimer/1")

  def initnpctimer(%Ctx{npc_gid: gid} = ctx) do
    NpcSession.init_timer(gid)
    ctx
  end

  @doc """
  Arms the timer of every placement registered under `name` (rAthena
  `initnpctimer("Name")`) — the per-placement timer model applies to every
  duplicate sharing the name, not just the first. An unresolved name logs a
  warning and no-ops.
  """
  @spec initnpctimer(Ctx.t(), String.t()) :: Ctx.t()
  def initnpctimer(%Ctx{status: {:error, _}} = ctx, _name), do: ctx

  def initnpctimer(%Ctx{} = ctx, name) do
    each_named(ctx, name, "initnpctimer/2", &NpcSession.init_timer/1)
  end

  @doc """
  Cancels the calling NPC's own pending timer fire and freezes its elapsed
  time (rAthena `stopnpctimer`). Targets `ctx.npc_gid`; valid on both an
  attached and a detached ctx. A ctx with no `npc_gid` logs a warning and
  no-ops.
  """
  @spec stopnpctimer(Ctx.t()) :: Ctx.t()
  def stopnpctimer(%Ctx{status: {:error, _}} = ctx), do: ctx
  def stopnpctimer(%Ctx{npc_gid: nil} = ctx), do: warn_no_npc_gid(ctx, "stopnpctimer/1")

  def stopnpctimer(%Ctx{npc_gid: gid} = ctx) do
    NpcSession.stop_timer(gid)
    ctx
  end

  @doc """
  Cancels the pending timer fire of every placement registered under `name`
  (rAthena `stopnpctimer("Name")`). An unresolved name logs a warning and
  no-ops.
  """
  @spec stopnpctimer(Ctx.t(), String.t()) :: Ctx.t()
  def stopnpctimer(%Ctx{status: {:error, _}} = ctx, _name), do: ctx

  def stopnpctimer(%Ctx{} = ctx, name) do
    each_named(ctx, name, "stopnpctimer/2", &NpcSession.stop_timer/1)
  end

  @doc """
  Reads the calling NPC's own timer's elapsed milliseconds (rAthena
  `getnpctimer`). Targets `ctx.npc_gid`; a pure read that ignores
  `ctx.status` and does not raise on a detached ctx, since npc timer state
  is not player state. A ctx with no `npc_gid` logs a warning and returns `0`.
  """
  @spec getnpctimer(Ctx.t()) :: non_neg_integer()
  def getnpctimer(%Ctx{npc_gid: nil} = ctx) do
    warn_no_npc_gid(ctx, "getnpctimer/1")
    0
  end

  def getnpctimer(%Ctx{npc_gid: gid}), do: NpcSession.get_timer(gid)

  @doc """
  Reads the timer of the first placement registered under `name` (rAthena
  `getnpctimer("Name")`), logging a warning if `name` maps to several
  (same per-placement timer model as `initnpctimer/2`). An unresolved name
  logs a warning and returns `0`.
  """
  @spec getnpctimer(Ctx.t(), String.t()) :: non_neg_integer()
  def getnpctimer(%Ctx{}, name) do
    case NpcRegistry.by_name(name) do
      [] ->
        Logger.warning("npc getnpctimer/2: unknown name #{inspect(name)}")
        0

      [{_module, placement} | _rest] = entries ->
        warn_if_ambiguous(entries, name, "getnpctimer/2")
        NpcSession.get_timer(NpcRegistry.entity_id(placement))
    end
  end

  @doc """
  Broadcasts overhead chat from the NPC to every player within view range of
  its placement (rAthena `npctalk`). Resolves the NPC's map/x/y through
  `Npc.Registry.module_for_unit/1` — the NPC's own placement, not any
  player's position — so this behaves identically whether `ctx` is attached
  or detached; it mutates no player state.

  Unlike player chat (`ChatHandler`), where the client already typed the
  `"Name : text"` prefix into the wire message before the server ever sees
  it, an NPC has no client-typed input to echo, and the client does not
  render a display name from `gid` on its own. The `"Name : text"` prefix
  (rAthena's overhead-chat format) is therefore built here from the
  placement's `name`, matching what the client already expects to display
  verbatim for a `ChatMessage`.

  A ctx with no `npc_gid` (e.g. an item script), or a `npc_gid` that does not
  resolve to a registered placement, logs a warning and no-ops. Always
  returns `ctx`.
  """
  @spec npctalk(Ctx.t(), String.t()) :: Ctx.t()
  def npctalk(%Ctx{status: {:error, _}} = ctx, _text), do: ctx
  def npctalk(%Ctx{npc_gid: nil} = ctx, _text), do: warn_no_npc_gid(ctx, "npctalk/2")

  def npctalk(%Ctx{npc_gid: gid} = ctx, text) do
    case NpcRegistry.module_for_unit(gid) do
      {:ok, {_module, placement}} ->
        packet = %ChatMessage{gid: gid, message: "#{placement.name} : #{text}"}

        Broadcast.to_in_range(
          placement.map,
          placement.x,
          placement.y,
          Config.view_range(),
          packet
        )

        ctx

      :error ->
        Logger.warning("npc npctalk/2: gid #{gid} not registered, no-op")
        ctx
    end
  end

  @doc """
  Enables the calling NPC, restoring its visibility and clickability (rAthena
  `enablenpc`). Targets `ctx.npc_gid`; valid on both an attached and a
  detached ctx, since it mutates NPC state, not player state. A ctx with no
  `npc_gid` logs a warning and no-ops.

  Independent of the `hidden` flag set by `hideonnpc`/`hideoffnpc` — an NPC
  is visible only when enabled and not hidden (see `Npc.Session`'s moduledoc).
  """
  @spec enablenpc(Ctx.t()) :: Ctx.t()
  def enablenpc(%Ctx{status: {:error, _}} = ctx), do: ctx
  def enablenpc(%Ctx{npc_gid: nil} = ctx), do: warn_no_npc_gid(ctx, "enablenpc/1")

  def enablenpc(%Ctx{npc_gid: gid} = ctx) do
    NpcSession.set_enabled(gid, true)
    ctx
  end

  @doc """
  Enables every placement registered under `name` (rAthena
  `enablenpc("Name")`) — applies to every duplicate sharing the name, not
  just the first. An unresolved name logs a warning and no-ops.
  """
  @spec enablenpc(Ctx.t(), String.t()) :: Ctx.t()
  def enablenpc(%Ctx{status: {:error, _}} = ctx, _name), do: ctx

  def enablenpc(%Ctx{} = ctx, name) do
    each_named(ctx, name, "enablenpc/2", &NpcSession.set_enabled(&1, true))
  end

  @doc """
  Disables the calling NPC, making it invisible and unclickable (rAthena
  `disablenpc`). Targets `ctx.npc_gid`; valid on both an attached and a
  detached ctx. A ctx with no `npc_gid` logs a warning and no-ops.

  Independent of the `hidden` flag — see `enablenpc/1`.
  """
  @spec disablenpc(Ctx.t()) :: Ctx.t()
  def disablenpc(%Ctx{status: {:error, _}} = ctx), do: ctx
  def disablenpc(%Ctx{npc_gid: nil} = ctx), do: warn_no_npc_gid(ctx, "disablenpc/1")

  def disablenpc(%Ctx{npc_gid: gid} = ctx) do
    NpcSession.set_enabled(gid, false)
    ctx
  end

  @doc """
  Disables every placement registered under `name` (rAthena
  `disablenpc("Name")`). An unresolved name logs a warning and no-ops.
  """
  @spec disablenpc(Ctx.t(), String.t()) :: Ctx.t()
  def disablenpc(%Ctx{status: {:error, _}} = ctx, _name), do: ctx

  def disablenpc(%Ctx{} = ctx, name) do
    each_named(ctx, name, "disablenpc/2", &NpcSession.set_enabled(&1, false))
  end

  @doc """
  Hides the calling NPC, making it invisible and unclickable regardless of
  its `enabled` flag (rAthena `hideonnpc`). Targets `ctx.npc_gid`; valid on
  both an attached and a detached ctx. A ctx with no `npc_gid` logs a
  warning and no-ops.
  """
  @spec hideonnpc(Ctx.t()) :: Ctx.t()
  def hideonnpc(%Ctx{status: {:error, _}} = ctx), do: ctx
  def hideonnpc(%Ctx{npc_gid: nil} = ctx), do: warn_no_npc_gid(ctx, "hideonnpc/1")

  def hideonnpc(%Ctx{npc_gid: gid} = ctx) do
    NpcSession.set_hidden(gid, true)
    ctx
  end

  @doc """
  Hides every placement registered under `name` (rAthena
  `hideonnpc("Name")`). An unresolved name logs a warning and no-ops.
  """
  @spec hideonnpc(Ctx.t(), String.t()) :: Ctx.t()
  def hideonnpc(%Ctx{status: {:error, _}} = ctx, _name), do: ctx

  def hideonnpc(%Ctx{} = ctx, name) do
    each_named(ctx, name, "hideonnpc/2", &NpcSession.set_hidden(&1, true))
  end

  @doc """
  Un-hides the calling NPC (rAthena `hideoffnpc`). Targets `ctx.npc_gid`;
  valid on both an attached and a detached ctx. A ctx with no `npc_gid` logs
  a warning and no-ops.

  Restores visibility only if the NPC is also enabled — a disabled, hidden
  NPC stays invisible after `hideoffnpc` until `enablenpc` runs too.
  """
  @spec hideoffnpc(Ctx.t()) :: Ctx.t()
  def hideoffnpc(%Ctx{status: {:error, _}} = ctx), do: ctx
  def hideoffnpc(%Ctx{npc_gid: nil} = ctx), do: warn_no_npc_gid(ctx, "hideoffnpc/1")

  def hideoffnpc(%Ctx{npc_gid: gid} = ctx) do
    NpcSession.set_hidden(gid, false)
    ctx
  end

  @doc """
  Un-hides every placement registered under `name` (rAthena
  `hideoffnpc("Name")`). An unresolved name logs a warning and no-ops.
  """
  @spec hideoffnpc(Ctx.t(), String.t()) :: Ctx.t()
  def hideoffnpc(%Ctx{status: {:error, _}} = ctx, _name), do: ctx

  def hideoffnpc(%Ctx{} = ctx, name) do
    each_named(ctx, name, "hideoffnpc/2", &NpcSession.set_hidden(&1, false))
  end

  @spec dispatch_doevent(Ctx.t(), String.t(), String.t()) :: Ctx.t()
  defp dispatch_doevent(ctx, name, label) do
    case NpcRegistry.by_name(name) do
      [] ->
        Logger.warning("npc doevent: unknown name #{inspect(name)}")
        ctx

      [{module, placement} | _rest] = entries ->
        warn_if_ambiguous(entries, name, "doevent/2")
        gid = NpcRegistry.entity_id(placement)
        start_attached_event(ctx, module, gid, label, name)
        ctx
    end
  end

  @spec start_attached_event(Ctx.t(), module(), non_neg_integer(), String.t(), String.t()) :: :ok
  defp start_attached_event(ctx, module, gid, label, name) do
    target_ctx = build_event_ctx(ctx, module, gid)

    case NpcEvents.trigger_attached(gid, label, target_ctx, ctx.session_pid) do
      {:ok, _pid} ->
        :ok

      {:error, reason} ->
        Logger.warning("npc doevent: #{inspect(name)} #{inspect(reason)} for #{inspect(label)}")
    end
  end

  @spec build_event_ctx(Ctx.t(), module(), non_neg_integer()) :: Ctx.t()
  defp build_event_ctx(%Ctx{} = ctx, module, gid) do
    base_ctx =
      Ctx.from_session(
        %{game_state: ctx.game_state, connection_pid: ctx.connection_pid},
        {:npc, module.npc_id()}
      )

    %{base_ctx | npc_gid: gid}
  end

  @spec split_ref(String.t()) :: {:ok, String.t(), String.t()} | :error
  defp split_ref(ref) do
    case String.split(ref, "::", parts: 2) do
      [name, label] -> {:ok, name, label}
      _malformed -> :error
    end
  end

  @spec each_named(Ctx.t(), String.t(), String.t(), (non_neg_integer() -> any())) :: Ctx.t()
  defp each_named(ctx, name, op, fun) do
    case NpcRegistry.by_name(name) do
      [] ->
        Logger.warning("npc #{op}: unknown name #{inspect(name)}")

      entries ->
        Enum.each(entries, fn {_module, placement} -> fun.(NpcRegistry.entity_id(placement)) end)
    end

    ctx
  end

  @spec warn_if_ambiguous([NpcRegistry.entry()], String.t(), String.t()) :: :ok
  defp warn_if_ambiguous([_single], _name, _op), do: :ok

  defp warn_if_ambiguous(entries, name, op) do
    Logger.warning(
      "npc #{op}: #{inspect(name)} maps to #{length(entries)} placements, using the first"
    )
  end

  @spec warn_no_npc_gid(Ctx.t(), String.t()) :: Ctx.t()
  defp warn_no_npc_gid(ctx, op) do
    Logger.warning("npc #{op}: ctx has no npc_gid, no-op")
    ctx
  end

  # Raises for a read op called on a detached ctx (no player attached). Reads
  # return bare values, not a Ctx, so they cannot carry a `{:error, :no_player}`
  # status the way effect ops do; the raise crashes only the calling supervised
  # Task, mirroring rAthena's "player not attached" script error.
  @spec no_player!(String.t()) :: no_return()
  defp no_player!(op) do
    raise ArgumentError, "#{op} requires a player attached to the ctx, but ctx is detached"
  end

  # Routes a state-mutating op through the single-writer session (always a
  # cross-process GenServer.call from the interaction, never a self-call), then
  # folds the authoritative game_state back into ctx or halts on error. A
  # detached ctx has no session to call, so it halts `:no_player` instead.
  @spec apply_op(Ctx.t(), tuple()) :: Ctx.t()
  defp apply_op(%Ctx{session_pid: nil} = ctx, _op), do: Ctx.halt(ctx, :no_player)

  defp apply_op(%Ctx{session_pid: session_pid} = ctx, op) do
    case GenServer.call(session_pid, {:script_apply, op}) do
      {:ok, game_state} -> %{ctx | game_state: game_state}
      {:error, reason} -> Ctx.halt(ctx, reason)
    end
  end

  @doc "The player's base level."
  @spec base_level(Ctx.t()) :: non_neg_integer()
  def base_level(%Ctx{game_state: nil}), do: no_player!("base_level/1")
  def base_level(%Ctx{game_state: gs}), do: gs.stats.progression.base_level

  @doc "The player's job level."
  @spec job_level(Ctx.t()) :: non_neg_integer()
  def job_level(%Ctx{game_state: nil}), do: no_player!("job_level/1")
  def job_level(%Ctx{game_state: gs}), do: gs.stats.progression.job_level

  @doc "The player's job as an atom."
  @spec class(Ctx.t()) :: atom()
  def class(%Ctx{game_state: nil}), do: no_player!("class/1")

  def class(%Ctx{game_state: gs}) do
    {:ok, job} = JobManagement.get_job_by_id(gs.stats.progression.job_id)
    job.name
  end

  # NV_BASIC level a Novice must reach to change into a first job.
  @basic_skill_job_req 9

  @doc """
  Whether the player meets the Basic Skill requirement to change job — a learned
  `NV_BASIC` at level #{@basic_skill_job_req} (rAthena `F_CanChangeJob`).
  """
  @spec can_change_job?(Ctx.t()) :: boolean()
  def can_change_job?(%Ctx{game_state: nil}), do: no_player!("can_change_job?/1")

  def can_change_job?(%Ctx{game_state: gs}) do
    case Catalog.by_name(:nv_basic) do
      {:ok, %{id: id}} ->
        Learned.learned_level(gs.stats.progression.learned_skills, id) >= @basic_skill_job_req

      :error ->
        false
    end
  end

  @doc """
  `strcharinfo(type)`: the character's name (type `0`) or current map (type `3`).
  rAthena's party/guild info types are not modelled and return an empty string.
  """
  @spec char_name(Ctx.t(), integer()) :: String.t()
  def char_name(%Ctx{game_state: nil}, _type), do: no_player!("char_name/2")
  def char_name(%Ctx{game_state: gs}, 0), do: gs.character_name
  def char_name(%Ctx{game_state: gs}, 3), do: gs.map_name
  def char_name(%Ctx{}, _type), do: ""

  @doc "The display name of a job, given its class atom or id (rAthena `jobname`)."
  @spec job_name(Ctx.t(), atom() | integer()) :: String.t()
  def job_name(%Ctx{}, job) when is_atom(job), do: humanize_job(job)

  def job_name(%Ctx{}, job_id) when is_integer(job_id) do
    case JobManagement.get_job_by_id(job_id) do
      {:ok, job} -> humanize_job(job.name)
      {:error, _} -> ""
    end
  end

  defp humanize_job(name) do
    name |> to_string() |> String.split("_") |> Enum.map_join(" ", &String.capitalize/1)
  end

  @doc "The player's sex."
  @spec sex(Ctx.t()) :: String.t()
  def sex(%Ctx{game_state: nil}), do: no_player!("sex/1")
  def sex(%Ctx{game_state: gs}), do: gs.sex

  @doc "The player's current HP."
  @spec hp(Ctx.t()) :: non_neg_integer()
  def hp(%Ctx{game_state: nil}), do: no_player!("hp/1")
  def hp(%Ctx{game_state: gs}), do: gs.stats.current_state.hp

  @doc "The player's current SP."
  @spec sp(Ctx.t()) :: non_neg_integer()
  def sp(%Ctx{game_state: nil}), do: no_player!("sp/1")
  def sp(%Ctx{game_state: gs}), do: gs.stats.current_state.sp

  @doc "The player's maximum HP."
  @spec max_hp(Ctx.t()) :: non_neg_integer()
  def max_hp(%Ctx{game_state: nil}), do: no_player!("max_hp/1")
  def max_hp(%Ctx{game_state: gs}), do: gs.stats.derived_stats.max_hp

  @doc "The player's current carried weight."
  @spec weight(Ctx.t()) :: non_neg_integer()
  def weight(%Ctx{game_state: nil}), do: no_player!("weight/1")
  def weight(%Ctx{game_state: gs}), do: Weight.current_weight(gs.inventory)

  @doc "The player's position as `{x, y, map_name}`."
  @spec position(Ctx.t()) :: {integer(), integer(), String.t()}
  def position(%Ctx{game_state: nil}), do: no_player!("position/1")
  def position(%Ctx{game_state: gs}), do: {gs.x, gs.y, gs.map_name}

  @doc "Whether the player has an item with `item_id` equipped."
  @spec is_equipped(Ctx.t(), integer()) :: boolean()
  # credo:disable-for-next-line Credo.Check.Readability.PredicateFunctionNames
  def is_equipped(%Ctx{game_state: nil}, _item_id), do: no_player!("is_equipped/2")

  # credo:disable-for-next-line Credo.Check.Readability.PredicateFunctionNames
  def is_equipped(%Ctx{game_state: gs}, item_id) do
    gs.inventory
    |> Inventory.equipped_items()
    |> Enum.any?(fn {_index, %InventoryItem{nameid: nameid}} -> nameid == item_id end)
  end

  defp apply_heal(%Ctx{} = ctx, hp_fun, sp_fun) do
    stats = ctx.game_state.stats
    current = stats.current_state
    max_hp = stats.derived_stats.max_hp
    max_sp = stats.derived_stats.max_sp

    new_hp = clamp(hp_fun.(current.hp, max_hp), max_hp)
    new_sp = clamp(sp_fun.(current.sp, max_sp), max_sp)

    new_state = %{current | hp: new_hp, sp: new_sp}
    game_state = %{ctx.game_state | stats: %{stats | current_state: new_state}}

    sync_hp(ctx, current.hp, new_hp)
    sync_sp(ctx, current.sp, new_sp)

    %{ctx | game_state: game_state}
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

  defp clamp(value, max), do: value |> min(max) |> max(0)

  defp roll(lo..hi//_step), do: lo + :rand.uniform(hi - lo + 1) - 1
  defp roll(amount) when is_integer(amount), do: amount

  defp resolve_skill_id(skill_id) when is_integer(skill_id), do: {:ok, skill_id}

  defp resolve_skill_id(name) when is_atom(name) do
    case Catalog.by_name(name) do
      {:ok, definition} -> {:ok, definition.id}
      :error -> {:error, :unknown_skill}
    end
  end

  defp resolve_mob(opts) do
    case {Keyword.get(opts, :mob_id), Keyword.get(opts, :mob_name)} do
      {id, _} when is_integer(id) -> MobManagement.get_mob_by_id(id)
      {_, name} when is_binary(name) -> MobManagement.get_mob_by_name(name)
      _ -> {:error, :mob_not_found}
    end
  end

  defp spawn_mob_at(%Ctx{} = ctx, mob_id, opts) do
    case Keyword.get(opts, :map) do
      nil -> spawn_mob_here(ctx, mob_id, opts)
      map -> do_summon(ctx, map, Keyword.get(opts, :at, :random), mob_id, opts)
    end
  end

  defp spawn_mob_here(%Ctx{game_state: gs} = ctx, mob_id, opts) when not is_nil(gs) do
    do_summon(ctx, gs.map_name, Keyword.get(opts, :at, {gs.x, gs.y}), mob_id, opts)
  end

  defp spawn_mob_here(%Ctx{npc_gid: nil} = ctx, _mob_id, _opts), do: Ctx.halt(ctx, :no_player)

  defp spawn_mob_here(%Ctx{npc_gid: gid} = ctx, mob_id, opts) do
    case NpcRegistry.module_for_unit(gid) do
      {:ok, {_module, placement}} ->
        at = Keyword.get(opts, :at, {placement.x, placement.y})
        do_summon(ctx, placement.map, at, mob_id, opts)

      :error ->
        Ctx.halt(ctx, :no_player)
    end
  end

  defp do_summon(ctx, map_name, at, mob_id, opts) do
    {x, y} = summon_coords(at)
    amount = Keyword.get(opts, :amount, 1)

    Enum.reduce_while(1..amount//1, ctx, fn _n, acc ->
      case Coordinator.summon_mob(map_name, mob_id, x, y, summon_opts(opts)) do
        {:ok, _instance_id} -> {:cont, acc}
        {:error, reason} -> {:halt, Ctx.halt(acc, reason)}
      end
    end)
  end

  # The coordinator reads a non-positive coordinate as "random walkable cell"
  # (rAthena mob_once_spawn semantics), so :random encodes as {0, 0}.
  defp summon_coords(:random), do: {0, 0}
  defp summon_coords({x, y}), do: {x, y}

  defp summon_opts(opts) do
    [aggressive: aggressive?(opts)]
    |> maybe_put_event(Keyword.get(opts, :event))
  end

  defp maybe_put_event(base_opts, nil), do: base_opts

  defp maybe_put_event(base_opts, event) do
    case validate_event_ref(event) do
      {:ok, ref} ->
        Keyword.put(base_opts, :event, ref)

      :error ->
        Logger.warning("summon_mob: malformed event ref #{inspect(event)}, ignoring")
        base_opts
    end
  end

  # rAthena OnMyMobDead only ever targets "Name::OnLabel" — the bare-label
  # form some rAthena events accept is out of scope (design decision, Task 11).
  defp validate_event_ref(ref) do
    case split_ref(ref) do
      {:ok, name, label} when name != "" and label != "" -> {:ok, ref}
      _malformed -> :error
    end
  end

  defp aggressive?(opts), do: Keyword.get(opts, :aggressive, false)
end
