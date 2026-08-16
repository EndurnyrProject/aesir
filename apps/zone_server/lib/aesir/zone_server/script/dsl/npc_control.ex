defmodule Aesir.ZoneServer.Script.Dsl.NpcControl do
  @moduledoc """
  NPC lifecycle and world-control buildins for the script DSL: mob summons
  and kills, map cell flags, mob/player counting, NPC events and timers,
  NPC chat/display/enable/hide/cloak state, and waiting rooms.

  Imported into scripts via the `Aesir.ZoneServer.Script.Dsl` facade.
  """

  alias Aesir.ZoneServer.Script.Dsl.Variables

  require Logger

  alias Aesir.Net.ChatMessage
  alias Aesir.Net.WaitingRoomInfo
  alias Aesir.Net.WaitingRoomRemoved
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.ScriptCells
  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Mmo.WaitingRoom
  alias Aesir.ZoneServer.Npc.Events, as: NpcEvents
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Vars
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

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
  Spawns monsters at random walkable cells inside a rectangle — the
  `areamonster` script-command path.

  `opts` accepts `:mob_id` or `:mob_name` (one is required; `:mob_name` is the
  AEGIS name, matching `MobManagement.get_mob_by_name/1`), `:area` as a
  `{x1, y1, x2, y2}` rectangle (required), `:map` to spawn on an explicit map
  (defaults to the player's map; rAthena `areamonster "map",...` with `"this"`
  meaning the player's map is handled by omitting `:map`), `:amount` (spawn
  count, default 1), `:aggressive` (accepted but deferred), and `:event`
  (optional OnMyMobDead ref, validated like `summon_mob/2`). Each instance
  lands on its own random walkable cell inside the rectangle; an unknown mob,
  map, or spawn failure halts the context.
  """
  @spec summon_mob_area(Ctx.t(), keyword()) :: Ctx.t()
  def summon_mob_area(%Ctx{status: {:error, _}} = ctx, _opts), do: ctx

  def summon_mob_area(%Ctx{} = ctx, opts) do
    case resolve_mob(opts) do
      {:ok, mob_data} -> spawn_mob_area(ctx, mob_data.id, opts)
      {:error, reason} -> Ctx.halt(ctx, reason)
    end
  end

  @doc """
  Kills every mob on `map` that was summoned with the event label `event`
  (rAthena `killmonster`); the special label `"All"` kills every
  script-summoned mob on the map (spawn-table mobs are spared). Killed mobs are
  removed without firing their death event or scheduling a respawn.

  A map-management effect that does not touch player state: the context is
  returned unchanged, and it runs even on a detached ctx. An unloaded map is a
  no-op, matching rAthena.
  """
  @spec killmonster(Ctx.t(), String.t(), String.t()) :: Ctx.t()
  def killmonster(%Ctx{status: {:error, _}} = ctx, _map, _event), do: ctx

  def killmonster(%Ctx{} = ctx, map, "All") do
    MobSupervisor.kill_by_event(map, :all)
    ctx
  end

  def killmonster(%Ctx{} = ctx, map, event) do
    MobSupervisor.kill_by_event(map, event)
    ctx
  end

  @doc """
  Kills every mob on `map`, spawn-table mobs included (rAthena
  `killmonsterall`). Unlike `killmonster/3`, no event filter applies and
  regular map spawns are not spared. Killed mobs are removed without firing
  their death event or scheduling a respawn.

  A map-management effect that does not touch player state: the context is
  returned unchanged, and it runs even on a detached ctx. An unloaded map is
  a no-op, matching rAthena.
  """
  @spec killmonsterall(Ctx.t(), String.t()) :: Ctx.t()
  def killmonsterall(%Ctx{status: {:error, _}} = ctx, _map), do: ctx

  def killmonsterall(%Ctx{} = ctx, map) do
    MobSupervisor.kill_all(map)
    ctx
  end

  @doc """
  Applies the rAthena `setcell` buildin over a rectangular region: `type` is one
  of `:walkable`, `:shootable`, or `:icewall` (other rAthena cell constants warn
  and no-op), and `flag` sets (`1`) or clears (`0`) the trait. A world-effect
  that does not touch player state: the context is returned unchanged and it
  runs even on a detached ctx.
  """
  @spec setcell(
          Ctx.t(),
          String.t(),
          integer(),
          integer(),
          integer(),
          integer(),
          atom(),
          integer()
        ) ::
          Ctx.t()
  def setcell(%Ctx{status: {:error, _}} = ctx, _map, _x1, _y1, _x2, _y2, _type, _flag), do: ctx

  def setcell(%Ctx{} = ctx, map, x1, y1, x2, y2, type, flag) do
    ScriptCells.set(map, {x1, y1}, {x2, y2}, type, flag)
    ctx
  end

  @doc """
  Number of living mobs on `map` that were summoned with the event label
  `event` (rAthena `mobcount`); the special label `"all"` counts every living
  mob on the map. The special map name `"this"` targets the attached player's
  current map. Returns -1 for an unknown map, or for `"this"` on a detached
  ctx. A known map without a running mob supervisor counts 0.
  """
  @spec mobcount(Ctx.t(), String.t(), String.t()) :: integer()
  def mobcount(%Ctx{game_state: nil}, "this", _event), do: -1
  def mobcount(%Ctx{game_state: gs} = ctx, "this", event), do: mobcount(ctx, gs.map_name, event)

  def mobcount(%Ctx{}, map, event) do
    if MapCache.exists?(map) do
      MobSupervisor.count_by_event(map, mobcount_filter(event))
    else
      -1
    end
  end

  defp mobcount_filter("all"), do: :all
  defp mobcount_filter(event), do: event

  @doc """
  Number of connected players currently on `map_name` (rAthena `getmapusers`),
  or -1 when the map is unknown. Pure read over the unit registry; ignores the
  ctx.
  """
  @spec getmapusers(Ctx.t(), String.t()) :: integer()
  def getmapusers(%Ctx{}, map_name) do
    if MapCache.exists?(map_name) do
      UnitRegistry.count_players_on_map(map_name)
    else
      -1
    end
  end

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
  Changes the display of the named NPC (rAthena `setnpcdisplay`): its sprite,
  display name, and/or size, applied to every placement registered under that
  name.

  `opts` accepts `:npc` (the target NPC name, required), `:sprite` (a view
  class id), `:display_name` (the new displayed name), and `:size` (`0` normal,
  `1` small, `2` big). Only the keys present are changed; the rest keep their
  current value. Valid on an attached or detached ctx; an unresolved name logs
  a warning and no-ops.
  """
  @spec set_npc_display(Ctx.t(), keyword()) :: Ctx.t()
  def set_npc_display(%Ctx{status: {:error, _}} = ctx, _opts), do: ctx

  def set_npc_display(%Ctx{} = ctx, opts) do
    name = Keyword.fetch!(opts, :npc)

    overrides =
      opts
      |> Keyword.take([:sprite, :display_name, :size])
      |> Map.new(fn
        {:display_name, value} -> {:name, value}
        {key, value} -> {key, value}
      end)

    each_named(ctx, name, "set_npc_display/2", &NpcSession.set_display(&1, overrides))
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
  Opens a waiting room above the calling NPC. `limit` counts the NPC itself, so
  a limit of 8 admits 7 players. The optional trailing arguments are the event
  label (`"Name::OnLabel"`), the trigger count (defaults to `limit`), an entry
  fee (checked at join and paid on warp), and the minimum/maximum base level.
  Valid on a detached ctx; a second room on the same NPC no-ops.
  """
  @spec waitingroom(
          Ctx.t(),
          String.t(),
          pos_integer(),
          String.t(),
          non_neg_integer() | nil,
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer() | nil
        ) :: Ctx.t()
  def waitingroom(
        %Ctx{} = ctx,
        title,
        limit,
        event_ref \\ "",
        trigger \\ nil,
        zeny \\ 0,
        min_lvl \\ 1,
        max_lvl \\ nil
      ) do
    case {ctx.status, ctx.npc_gid} do
      {{:error, _}, _} ->
        ctx

      {:ok, nil} ->
        warn_no_npc_gid(ctx, "waitingroom/3")

      {:ok, gid} ->
        trigger = trigger || limit
        max_lvl = max_lvl || Config.max_base_level()

        case WaitingRoom.create(gid, title, limit, trigger, event_ref, zeny, min_lvl, max_lvl) do
          :ok ->
            broadcast_room_info(gid)
            ctx

          {:error, :already_exists} ->
            Logger.warning("npc waitingroom/3: gid #{gid} already has a room, no-op")
            ctx
        end
    end
  end

  @doc "Deletes the calling NPC's waiting room."
  @spec delwaitingroom(Ctx.t()) :: Ctx.t()
  def delwaitingroom(%Ctx{} = ctx), do: delwaitingroom(ctx, nil)

  @doc "Deletes the named NPC's waiting room."
  @spec delwaitingroom(Ctx.t(), String.t() | nil) :: Ctx.t()
  def delwaitingroom(%Ctx{status: {:error, _}} = ctx, _name), do: ctx

  def delwaitingroom(%Ctx{} = ctx, name) do
    case room_gid_for(ctx, name) do
      nil ->
        ctx

      gid ->
        members = WaitingRoom.members(gid)
        WaitingRoom.delete(gid)
        Enum.each(members, &kick_member(&1, gid))
        broadcast_room_removed(gid)
        ctx
    end
  end

  @doc "Re-enables the calling NPC's waiting-room event, firing immediately if already met."
  @spec enablewaitingroomevent(Ctx.t()) :: Ctx.t()
  def enablewaitingroomevent(%Ctx{} = ctx), do: enablewaitingroomevent(ctx, nil)

  @doc "Re-enables the named NPC's waiting-room event."
  @spec enablewaitingroomevent(Ctx.t(), String.t() | nil) :: Ctx.t()
  def enablewaitingroomevent(%Ctx{status: {:error, _}} = ctx, _name), do: ctx

  def enablewaitingroomevent(%Ctx{} = ctx, name) do
    case room_gid_for(ctx, name) do
      nil ->
        ctx

      gid ->
        refire_if_due(gid)
        ctx
    end
  end

  @doc "Disables the calling NPC's waiting-room event."
  @spec disablewaitingroomevent(Ctx.t()) :: Ctx.t()
  def disablewaitingroomevent(%Ctx{} = ctx), do: disablewaitingroomevent(ctx, nil)

  @doc "Disables the named NPC's waiting-room event."
  @spec disablewaitingroomevent(Ctx.t(), String.t() | nil) :: Ctx.t()
  def disablewaitingroomevent(%Ctx{status: {:error, _}} = ctx, _name), do: ctx

  def disablewaitingroomevent(%Ctx{} = ctx, name) do
    case room_gid_for(ctx, name) do
      nil ->
        ctx

      gid ->
        WaitingRoom.disable_event(gid)
        ctx
    end
  end

  @doc """
  Warps up to `n` members (default: the trigger count) out of the calling NPC's
  waiting room, longest-waiting first. `map` may be a map name, `:random`, or
  `:save_point`. Each warped account id is recorded in `$@warpwaitingpc` and the
  count in `$@warpwaitingpcnum`.
  """
  @spec warpwaitingpc(Ctx.t(), String.t() | :random | :save_point, integer(), integer()) ::
          Ctx.t()
  def warpwaitingpc(%Ctx{status: {:error, _}} = ctx, _map, _x, _y), do: ctx
  def warpwaitingpc(%Ctx{} = ctx, map, x, y), do: warpwaitingpc(ctx, map, x, y, nil)

  @spec warpwaitingpc(
          Ctx.t(),
          String.t() | :random | :save_point,
          integer(),
          integer(),
          non_neg_integer() | nil
        ) :: Ctx.t()
  def warpwaitingpc(%Ctx{status: {:error, _}} = ctx, _map, _x, _y, _n), do: ctx

  def warpwaitingpc(%Ctx{npc_gid: nil} = ctx, _map, _x, _y, _n),
    do: warn_no_npc_gid(ctx, "warpwaitingpc/4")

  def warpwaitingpc(%Ctx{npc_gid: gid} = ctx, map, x, y, n) do
    case WaitingRoom.get(gid) do
      {:ok, room} ->
        count = n || room.trigger

        account_ids =
          room.members
          |> Enum.take(count)
          |> Enum.map(fn member ->
            warp_member(member, map, x, y, room.zeny)
            member.account_id
          end)

        Vars.put_server_temp("warpwaitingpc", account_ids)
        Vars.put_server_temp("warpwaitingpcnum", length(account_ids))
        ctx

      :error ->
        ctx
    end
  end

  @doc "Kicks the named character from the named NPC's waiting room."
  @spec waitingroomkick(Ctx.t(), String.t(), String.t()) :: Ctx.t()
  def waitingroomkick(%Ctx{status: {:error, _}} = ctx, _npc_name, _char_name), do: ctx

  def waitingroomkick(%Ctx{} = ctx, npc_name, char_name) do
    case room_gid_for(ctx, npc_name) do
      nil ->
        ctx

      gid ->
        case Enum.find(WaitingRoom.members(gid), &(&1.name == char_name)) do
          nil -> :ok
          member -> kick_member(member, gid)
        end

        WaitingRoom.kick(gid, char_name)
        ctx
    end
  end

  @doc "Kicks everyone out of the calling NPC's waiting room."
  @spec kickwaitingroomall(Ctx.t()) :: Ctx.t()
  def kickwaitingroomall(%Ctx{} = ctx), do: kickwaitingroomall(ctx, nil)

  @doc "Kicks everyone out of the named NPC's waiting room."
  @spec kickwaitingroomall(Ctx.t(), String.t() | nil) :: Ctx.t()
  def kickwaitingroomall(%Ctx{status: {:error, _}} = ctx, _name), do: ctx

  def kickwaitingroomall(%Ctx{} = ctx, name) do
    case room_gid_for(ctx, name) do
      nil ->
        ctx

      gid ->
        members = WaitingRoom.members(gid)
        WaitingRoom.kick_all(gid)
        Enum.each(members, &kick_member(&1, gid))
        broadcast_room_info(gid)
        ctx
    end
  end

  @doc """
  Stores the calling NPC's waiting-room members' account ids in
  `.@waitingroom_users` and their count in `.@waitingroom_usercount`.
  """
  @spec getwaitingroomusers(Ctx.t()) :: Ctx.t()
  def getwaitingroomusers(%Ctx{} = ctx), do: getwaitingroomusers(ctx, nil)

  @spec getwaitingroomusers(Ctx.t(), String.t() | nil) :: Ctx.t()
  def getwaitingroomusers(%Ctx{status: {:error, _}} = ctx, _name), do: ctx

  def getwaitingroomusers(%Ctx{} = ctx, name) do
    case room_gid_for(ctx, name) do
      nil ->
        ctx

      gid ->
        account_ids = Enum.map(WaitingRoom.members(gid), & &1.account_id)

        ctx
        |> Variables.set_local(:waitingroom_users, account_ids)
        |> Variables.set_local(:waitingroom_usercount, length(account_ids))
    end
  end

  @doc """
  Reads the calling NPC's waiting-room state for the given info `type` (0 users,
  1 limit, 2 trigger, 3 disabled, 4 title, 5 password, 16 event label, 32 full,
  33 over-trigger), or `-1` when the NPC has no room.
  """
  @spec getwaitingroomstate(Ctx.t(), integer()) :: term()
  def getwaitingroomstate(%Ctx{npc_gid: nil}, _type), do: -1

  def getwaitingroomstate(%Ctx{npc_gid: gid}, type), do: WaitingRoom.state(gid, type)

  @doc "Reads the named NPC's waiting-room state."
  @spec getwaitingroomstate(Ctx.t(), integer(), String.t()) :: term()
  def getwaitingroomstate(%Ctx{} = ctx, type, npc_name) do
    case room_gid_for(ctx, npc_name) do
      nil -> -1
      gid -> WaitingRoom.state(gid, type)
    end
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

  @doc """
  Cloaks the calling NPC, making it invisible (rAthena `cloakonnpc`/`cloakonnpcself`
  without a name). Targets `ctx.npc_gid`; valid on both an attached and a detached
  ctx. A ctx with no `npc_gid` logs a warning and no-ops.

  rAthena distinguishes `OPTION_HIDE` (`hideonnpc`) from `OPTION_CLOAK`
  (`cloakonnpc`); Aesir models both with the single `hidden` flag, so this is
  equivalent to `hideonnpc/1`. See `Npc.Session`'s moduledoc.
  """
  @spec cloakonnpc(Ctx.t()) :: Ctx.t()
  def cloakonnpc(%Ctx{status: {:error, _}} = ctx), do: ctx
  def cloakonnpc(%Ctx{npc_gid: nil} = ctx), do: warn_no_npc_gid(ctx, "cloakonnpc/1")

  def cloakonnpc(%Ctx{npc_gid: gid} = ctx) do
    NpcSession.set_hidden(gid, true)
    ctx
  end

  @doc """
  Cloaks every placement registered under `name` (rAthena `cloakonnpc("Name")`).
  An unresolved name logs a warning and no-ops.
  """
  @spec cloakonnpc(Ctx.t(), String.t()) :: Ctx.t()
  def cloakonnpc(%Ctx{status: {:error, _}} = ctx, _name), do: ctx

  def cloakonnpc(%Ctx{} = ctx, name) do
    each_named(ctx, name, "cloakonnpc/2", &NpcSession.set_hidden(&1, true))
  end

  @doc """
  Un-cloaks the calling NPC (rAthena `cloakoffnpcself` with no name). Targets
  `ctx.npc_gid`; valid on both an attached and a detached ctx. A ctx with no
  `npc_gid` logs a warning and no-ops. In rAthena `cloakoffnpcself` is a
  per-player cloak targeted at the attached player; Aesir's single global
  `hidden` flag collapses this to the same behaviour as `hideoffnpc/1`.
  """
  @spec cloakoffnpcself(Ctx.t()) :: Ctx.t()
  def cloakoffnpcself(%Ctx{status: {:error, _}} = ctx), do: ctx
  def cloakoffnpcself(%Ctx{npc_gid: nil} = ctx), do: warn_no_npc_gid(ctx, "cloakoffnpcself/1")

  def cloakoffnpcself(%Ctx{npc_gid: gid} = ctx) do
    NpcSession.set_hidden(gid, false)
    ctx
  end

  @doc """
  Un-cloaks every placement registered under `name` (rAthena
  `cloakoffnpcself("Name")` — the per-player target is dropped and the concern is
  collapsed to the global `hidden` flag). An unresolved name logs a warning and
  no-ops. Equivalent to `hideoffnpc/2`.
  """
  @spec cloakoffnpcself(Ctx.t(), String.t()) :: Ctx.t()
  def cloakoffnpcself(%Ctx{status: {:error, _}} = ctx, _name), do: ctx

  def cloakoffnpcself(%Ctx{} = ctx, name) do
    each_named(ctx, name, "cloakoffnpcself/2", &NpcSession.set_hidden(&1, false))
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

  defp room_gid_for(ctx, nil), do: ctx.npc_gid

  defp room_gid_for(_ctx, name) do
    case NpcRegistry.by_name(name) do
      [] ->
        Logger.warning("npc waiting room: unknown name #{inspect(name)}")
        nil

      [{_module, placement} | _] ->
        NpcRegistry.entity_id(placement)
    end
  end

  defp refire_if_due(gid) do
    case WaitingRoom.enable_event(gid) do
      {:ok, room} ->
        if WaitingRoom.fire_event?(room), do: NpcEvents.trigger(room.event_ref)

      :error ->
        :ok
    end
  end

  defp broadcast_room_info(gid) do
    with {:ok, room} <- WaitingRoom.get(gid),
         {:ok, {_module, placement}} <- NpcRegistry.module_for_unit(gid) do
      packet = %WaitingRoomInfo{
        room_id: gid,
        title: room.title,
        member_count: length(room.members),
        limit: room.limit,
        public: true
      }

      Broadcast.to_in_range(placement.map, placement.x, placement.y, Config.view_range(), packet)
    else
      _not_found -> :ok
    end
  end

  defp broadcast_room_removed(gid) do
    case NpcRegistry.module_for_unit(gid) do
      {:ok, {_module, placement}} ->
        Broadcast.to_in_range(
          placement.map,
          placement.x,
          placement.y,
          Config.view_range(),
          %WaitingRoomRemoved{room_id: gid}
        )

      :error ->
        :ok
    end
  end

  defp warp_member(%WaitingRoom.Member{char_id: char_id}, map, x, y, zeny) do
    case UnitRegistry.get_player_pid(char_id) do
      {:ok, pid} -> PlayerSession.warp_with_fee(pid, map, x, y, zeny)
      {:error, :not_found} -> :ok
    end
  end

  defp kick_member(%WaitingRoom.Member{char_id: char_id}, room_gid) do
    case UnitRegistry.get_player_pid(char_id) do
      {:ok, pid} -> PlayerSession.kick_from_waiting_room(pid, room_gid)
      {:error, :not_found} -> :ok
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

  defp spawn_mob_area(%Ctx{} = ctx, mob_id, opts) do
    case Keyword.get(opts, :map) do
      nil -> spawn_mob_area_here(ctx, mob_id, opts)
      map -> do_summon_area(ctx, map, mob_id, opts)
    end
  end

  defp spawn_mob_area_here(%Ctx{game_state: gs} = ctx, mob_id, opts) when not is_nil(gs) do
    do_summon_area(ctx, gs.map_name, mob_id, opts)
  end

  defp spawn_mob_area_here(%Ctx{npc_gid: nil} = ctx, _mob_id, _opts),
    do: Ctx.halt(ctx, :no_player)

  defp spawn_mob_area_here(%Ctx{npc_gid: gid} = ctx, mob_id, opts) do
    case NpcRegistry.module_for_unit(gid) do
      {:ok, {_module, placement}} -> do_summon_area(ctx, placement.map, mob_id, opts)
      :error -> Ctx.halt(ctx, :no_player)
    end
  end

  defp do_summon_area(ctx, map_name, mob_id, opts) do
    area = Keyword.fetch!(opts, :area)
    amount = Keyword.get(opts, :amount, 1)

    Enum.reduce_while(1..amount//1, ctx, fn _n, acc ->
      case Coordinator.summon_mob_area(map_name, mob_id, area, summon_opts(opts)) do
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
