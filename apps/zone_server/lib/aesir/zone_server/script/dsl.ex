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

  import Bitwise

  require Logger

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.StatusParams
  alias Aesir.Net.ChatMessage
  alias Aesir.Net.Cutin
  alias Aesir.Net.NavigateTo
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.Net.ProgressBar
  alias Aesir.Net.SkillEffect
  alias Aesir.Net.SoundEffect
  alias Aesir.Net.Viewpoint
  alias Aesir.Net.WaitingRoomInfo
  alias Aesir.Net.WaitingRoomRemoved
  alias Aesir.ZoneServer.Announcement
  alias Aesir.ZoneServer.Announcement.Flags
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.ScriptCells
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ClientItemType
  alias Aesir.ZoneServer.Mmo.ItemManagement.CompiledItemScripts
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Group
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.ItemGroupPool
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Roller
  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.JobManagement.JobLineage
  alias Aesir.ZoneServer.Mmo.JobManagement.JobMapid
  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.WaitingRoom
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Npc.Events, as: NpcEvents
  alias Aesir.ZoneServer.Npc.QuestInfo, as: NpcQuestInfo
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Npc.SkillCaster
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena
  alias Aesir.ZoneServer.Script.Todo
  alias Aesir.ZoneServer.Script.Vars
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Emote
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor
  alias Aesir.ZoneServer.Unit.Player.Handlers.RefineOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.QuestLog
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.SpecialEffect
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # CompiledItemScripts is created at runtime by ScriptCompiler.compile_all!/1
  # (it does not exist at compile time); `consumeitem/2` dispatches into it.
  @compile {:no_warn_undefined, CompiledItemScripts}

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
  @npcskill_min_stat 1
  @npcskill_max_stat 255

  # Idle deadline for a blocking dialog suspension. The client freezes the
  # player during a dialog, so a `receive` that never returns means the player
  # abandoned the window; the interaction exits and the session clears the lock.
  # Read from app env at call time so tests can shrink it.
  @default_dialog_idle_timeout :timer.seconds(60)

  @spec dialog_idle_timeout() :: timeout()
  defp dialog_idle_timeout do
    Application.get_env(:zone_server, :dialog_idle_timeout, @default_dialog_idle_timeout)
  end

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
  Casts a supportive skill from the running NPC on the attached player.

  `skill` accepts a catalog name, numeric id, or string name; `level` is
  clamped to the skill's maximum (a non-positive level warns and no-ops). `stat_point` and `npc_level` supply the
  synthetic caster stats, each clamped to `1..255`. A successful cast sends a
  skill-effect visual sourced from the NPC. Unknown or unsupported skills, cast
  failures, and a missing NPC leave the context unchanged; a detached ctx halts
  `:no_player`.
  """
  @spec npcskill(Ctx.t(), atom() | integer() | String.t(), integer(), integer(), integer()) ::
          Ctx.t()
  def npcskill(%Ctx{status: {:error, _}} = ctx, _skill, _level, _stat_point, _npc_level), do: ctx

  def npcskill(%Ctx{game_state: nil} = ctx, _skill, _level, _stat_point, _npc_level),
    do: Ctx.halt(ctx, :no_player)

  def npcskill(%Ctx{npc_gid: nil} = ctx, skill, _level, _stat_point, _npc_level) do
    Logger.warning("npcskill called without an NPC for #{inspect(skill)}")
    ctx
  end

  def npcskill(%Ctx{} = ctx, skill, level, stat_point, npc_level) do
    with {:ok, definition} <- resolve_npcskill_definition(skill),
         caster <-
           SkillCaster.new(
             ctx.npc_gid,
             clamp_npcskill_stat(stat_point),
             clamp_npcskill_stat(npc_level),
             {ctx.game_state.x, ctx.game_state.y},
             ctx.game_state.map_name
           ),
         {:ok, _} <- SkillInterpreter.npc_cast(caster, definition.id, level, {:unit, ctx.char_id}) do
      Broadcast.to_in_range(
        ctx.game_state.map_name,
        ctx.game_state.x,
        ctx.game_state.y,
        Config.view_range(),
        %SkillEffect{
          skill_id: definition.id,
          level: min(level, definition.max_level),
          src_id: ctx.npc_gid,
          target_id: ctx.char_id,
          result: 1
        }
      )
    else
      :error ->
        Logger.warning(
          "npcskill failed for #{inspect(skill)} from NPC #{ctx.npc_gid}: unknown skill"
        )

      {:error, reason} ->
        Logger.warning("npcskill failed for #{inspect(skill)} from NPC #{ctx.npc_gid}: #{reason}")
    end

    ctx
  end

  @doc """
  Plays a skill's visual effect on the attached player, shown to every player
  in view range (rAthena `skilleffect`). `skill` accepts a numeric id (sent
  verbatim, matching an un-cataloged skill's client-side animation) or a
  catalog name atom/string; `level` is passed through. The optional rAthena
  target argument is dropped — the effect always plays on the invoking
  player. Purely cosmetic, so a detached ctx or an unresolvable name is a
  silent no-op rather than a halt.
  """
  @spec skilleffect(Ctx.t(), atom() | integer() | String.t(), integer()) :: Ctx.t()
  def skilleffect(%Ctx{status: {:error, _}} = ctx, _skill, _level), do: ctx
  def skilleffect(%Ctx{game_state: nil} = ctx, _skill, _level), do: ctx

  def skilleffect(%Ctx{} = ctx, skill, level) do
    case skilleffect_id(skill) do
      {:ok, skill_id} ->
        Broadcast.to_in_range(
          ctx.game_state.map_name,
          ctx.game_state.x,
          ctx.game_state.y,
          Config.view_range(),
          %SkillEffect{
            skill_id: skill_id,
            level: max(level, 0),
            src_id: ctx.char_id,
            target_id: ctx.char_id,
            result: 1
          }
        )

      :error ->
        Logger.warning("skilleffect: unknown skill #{inspect(skill)}, skipping")
    end

    ctx
  end

  # Numeric ids pass through so a skill the server has not implemented still
  # shows its client-side animation; names resolve via the skill catalog.
  defp skilleffect_id(skill) when is_integer(skill), do: {:ok, skill}
  defp skilleffect_id(skill) when is_atom(skill), do: catalog_skill_id(skill)

  defp skilleffect_id(skill) when is_binary(skill) do
    skill
    |> String.downcase()
    |> String.to_existing_atom()
    |> catalog_skill_id()
  rescue
    ArgumentError -> :error
  end

  defp skilleffect_id(_skill), do: :error

  defp catalog_skill_id(name) do
    case Catalog.by_name(name) do
      {:ok, definition} -> {:ok, definition.id}
      :error -> :error
    end
  end

  defp resolve_npcskill_definition(skill) when is_atom(skill), do: Catalog.by_name(skill)
  defp resolve_npcskill_definition(skill) when is_integer(skill), do: Catalog.by_id(skill)

  defp resolve_npcskill_definition(skill) when is_binary(skill) do
    skill
    |> String.downcase()
    |> String.to_existing_atom()
    |> Catalog.by_name()
  rescue
    ArgumentError -> :error
  end

  defp resolve_npcskill_definition(_skill), do: :error

  defp clamp_npcskill_stat(value), do: value |> max(@npcskill_min_stat) |> min(@npcskill_max_stat)

  @doc """
  Returns the attached player's current look value for a rAthena look type
  (rAthena `getlook`). Cosmetic slots read the persisted character
  appearance (`hair`, `head_bottom`, `head_mid`, `hair_color`,
  `clothes_color`, `robe`); the equipment-driven slots (`LOOK_WEAPON`,
  `LOOK_HEAD_TOP`, `LOOK_SHIELD`) read the current equipment views. Look
  types with no Aesir representation (`LOOK_SHOES`, `LOOK_BODY`,
  `LOOK_BODY2`, unknown ids) return `-1`, matching rAthena's fallback for
  unhandled types.
  """
  @spec getlook(Ctx.t(), non_neg_integer()) :: integer()
  def getlook(%Ctx{game_state: nil}, _type), do: no_player!("getlook/2")

  def getlook(%Ctx{game_state: gs}, type) do
    case type do
      2 -> PlayerStats.weapon_view(gs.stats.equipment)
      4 -> PlayerStats.head_top_view(gs.stats.equipment)
      8 -> PlayerStats.shield_view(gs.stats.equipment)
      _ -> cosmetic_look(gs, type)
    end
  end

  # Persisted appearance fields; any other look type has no Aesir state and
  # reads as `-1` (rAthena's unhandled-type fallback).
  defp cosmetic_look(gs, type) do
    case type do
      1 -> gs.hair
      3 -> gs.head_bottom
      5 -> gs.head_mid
      6 -> gs.hair_color
      7 -> gs.clothes_color
      12 -> gs.robe
      _ -> -1
    end
  end

  @doc """
  Sets one of the player's persisted look values (rAthena `setlook`),
  routed through the single-writer session so the Character is persisted and
  the new look is pushed to the player and nearby observers. Supported look
  types are exactly the appearance fields the Character stores: `LOOK_HAIR`
  (1), `LOOK_HEAD_BOTTOM` (3), `LOOK_HEAD_MID` (5), `LOOK_HAIR_COLOR` (6),
  `LOOK_CLOTHES_COLOR` (7) and `LOOK_ROBE` (12). Hair/color values are
  clamped to the rAthena battle-config defaults (style 0-23, hair color 0-9,
  cloth color 0-4); other slots clamp to non-negative. Equipment-driven
  slots and no-op types are ignored, mirroring rAthena's own `LOOK_SHOES`
  no-op.
  """
  @spec setlook(Ctx.t(), non_neg_integer(), integer()) :: Ctx.t()
  def setlook(%Ctx{status: {:error, _}} = ctx, _type, _value), do: ctx
  def setlook(%Ctx{game_state: nil} = ctx, _type, _value), do: Ctx.halt(ctx, :no_player)

  def setlook(%Ctx{} = ctx, type, value) when type in [1, 3, 5, 6, 7, 12],
    do: apply_op(ctx, {:set_look, type, clamp_look(type, value)})

  def setlook(%Ctx{} = ctx, type, _value) do
    Logger.warning("setlook: no settable state for look type #{inspect(type)}, ignoring")
    ctx
  end

  # rAthena clamps hair/color/cloth in `pc_changelook` to battle-config
  # defaults; Aesir has no battle config, so the rAthena defaults stand in.
  # The remaining settable slots have no upper bound but must be non-negative
  # for the uint32 `SpriteChange` field.
  defp clamp_look(1, value), do: clamp(value, 23)
  defp clamp_look(6, value), do: clamp(value, 9)
  defp clamp_look(7, value), do: clamp(value, 4)
  defp clamp_look(_type, value), do: max(value, 0)

  @doc """
  Plays a one-shot `EF_*` visual effect on the player, shown to every player in
  view range (rAthena `specialeffect2`).

  `effect` is an `:ef_*` atom or a raw numeric effect id. Purely cosmetic, so
  the context is returned unchanged and a detached ctx (no player to originate
  the effect from) is a silent no-op rather than a halt — a missing sprite
  burst must never abort the surrounding script.
  """
  @spec specialeffect2(Ctx.t(), atom() | non_neg_integer()) :: Ctx.t()
  def specialeffect2(%Ctx{status: {:error, _}} = ctx, _effect), do: ctx
  def specialeffect2(%Ctx{game_state: nil} = ctx, _effect), do: ctx

  def specialeffect2(%Ctx{} = ctx, effect) do
    SpecialEffect.play({:player, ctx.char_id}, effect, :area)
    ctx
  end

  @doc """
  Plays a one-shot `EF_*` visual effect anchored on the NPC running the script,
  shown to every player in view range of the NPC's placement (rAthena
  `specialeffect`, self-anchored form — the trailing send-target and named-NPC
  arguments are dropped).

  `effect` is an `:ef_*` atom or a raw numeric effect id. Purely cosmetic, so
  the context is returned unchanged and a detached ctx (no `npc_gid` to
  originate the effect from) is a silent no-op rather than a halt — a missing
  sprite burst must never abort the surrounding script. Resolves the NPC's
  position through `SpatialIndex`, the same anchor `emotion/2` uses.
  """
  @spec specialeffect(Ctx.t(), atom() | non_neg_integer()) :: Ctx.t()
  def specialeffect(%Ctx{status: {:error, _}} = ctx, _effect), do: ctx
  def specialeffect(%Ctx{npc_gid: nil} = ctx, _effect), do: ctx

  def specialeffect(%Ctx{npc_gid: gid} = ctx, effect) do
    SpecialEffect.play({:npc, gid}, effect, :area)
    ctx
  end

  @doc """
  Places a marker on the invoking player's minimap (rAthena `viewpoint`,
  packet `ZC_COMPASS`). `type` is the action (`0` remove / `1` display /
  `2` display and clear other markers), `x`/`y` the cell, `id` the marker
  slot, and `color` a `0xRRGGBB` value.

  Sent only to the invoking player, so a detached ctx (no player to send to)
  is a silent no-op rather than a halt — a missing marker must never abort the
  surrounding script. The marker is anchored on the running NPC (`npc_gid`), or
  `0` when the script has none (an item/floating context).
  """
  @spec viewpoint(Ctx.t(), integer(), integer(), integer(), integer(), integer()) :: Ctx.t()
  def viewpoint(%Ctx{status: {:error, _}} = ctx, _type, _x, _y, _id, _color), do: ctx
  def viewpoint(%Ctx{char_id: nil} = ctx, _type, _x, _y, _id, _color), do: ctx

  def viewpoint(%Ctx{char_id: char_id, npc_gid: gid} = ctx, type, x, y, id, color) do
    Broadcast.to_player(char_id, %Viewpoint{
      npc_id: gid || 0,
      type: type,
      x: x,
      y: y,
      id: id,
      color: color
    })

    ctx
  end

  @doc """
  Registers a quest-icon bubble on the running NPC (rAthena `questinfo`,
  packet `ZC_QUEST_NOTIFY_EFFECT`). Called from an `OnInit` handler with no
  player attached: it records the icon on the NPC's `npc_gid` rather than
  sending anything, and `Aesir.ZoneServer.Unit.Player.QuestInfoView` later
  evaluates it per player.

  `icon` is an `e_questinfo_types` value (`QTYPE_*`, `9999` clears), `color` an
  `e_questinfo_markcolor` value (`QMARK_*`, default `0`/none), and `condition`
  an optional `(Ctx.t() -> boolean())` predicate evaluated against each
  player's state (a bubble with no condition always shows). Multiple calls on
  one NPC accumulate in declaration order; the first passing entry wins.

  A no-op on a halted ctx or one with no NPC (`npc_gid` nil).
  """
  @spec questinfo(
          Ctx.t(),
          non_neg_integer(),
          non_neg_integer(),
          (Ctx.t() -> boolean()) | nil
        ) :: Ctx.t()
  def questinfo(ctx, icon, color \\ 0, condition \\ nil)
  def questinfo(%Ctx{status: {:error, _}} = ctx, _icon, _color, _condition), do: ctx
  def questinfo(%Ctx{npc_gid: nil} = ctx, _icon, _color, _condition), do: ctx

  def questinfo(%Ctx{npc_gid: gid} = ctx, icon, color, condition) do
    case NpcRegistry.module_for_unit(gid) do
      {:ok, {_module, placement}} ->
        NpcQuestInfo.register(
          gid,
          placement.map,
          placement.x,
          placement.y,
          icon,
          color,
          condition
        )

      :error ->
        :ok
    end

    ctx
  end

  @doc """
  Shows a cutscene illustration overlay on the invoking player's screen
  (rAthena `cutin`, packet `ZC_SHOW_IMAGE`). `image` is the illustration
  bitmap name (empty with `type` `255` clears every displayed cutin); `type`
  is the position (`0` bottom-left / `1` bottom-mid / `2` bottom-right /
  `3`-`4` centered / `255` clear).

  Sent only to the invoking player, so a detached ctx (no player to send to)
  is a silent no-op rather than a halt — a missing illustration must never
  abort the surrounding script.
  """
  @spec cutin(Ctx.t(), String.t(), non_neg_integer()) :: Ctx.t()
  def cutin(%Ctx{status: {:error, _}} = ctx, _image, _type), do: ctx
  def cutin(%Ctx{char_id: nil} = ctx, _image, _type), do: ctx

  def cutin(%Ctx{char_id: char_id} = ctx, image, type) do
    Broadcast.to_player(char_id, %Cutin{image: image, type: type})
    ctx
  end

  @doc """
  Plays a one-shot sound effect for the invoking player (rAthena
  `soundeffect`, packet `ZC_SOUND`). `name` is the `.wav` filename played from
  the client's audio directory; `type` selects the playback source (`0` =
  `data/wav`).

  Sent only to the invoking player, so a detached ctx (no player to send to)
  is a silent no-op rather than a halt — a missing sound must never abort the
  surrounding script.
  """
  @spec soundeffect(Ctx.t(), String.t(), non_neg_integer()) :: Ctx.t()
  def soundeffect(%Ctx{status: {:error, _}} = ctx, _name, _type), do: ctx
  def soundeffect(%Ctx{char_id: nil} = ctx, _name, _type), do: ctx

  def soundeffect(%Ctx{char_id: char_id} = ctx, name, type) do
    Broadcast.to_player(char_id, %SoundEffect{name: name, type: type})
    ctx
  end

  @doc """
  Opens the navigation window / starts navigation toward a map coordinate or
  tracked monster (rAthena `navigateto`, packet `ZC_NAVIGATION`). `flag` is the
  allowed-transport-services value (`0` none, `1` airship, `10` scroll, `100`
  kafra); `hide_window` suppresses the window when true. With `monster_id` set,
  the coordinates are ignored and the client tracks that monster instead.

  Sent only to the invoking player, so a detached ctx (no player to send to) is
  a silent no-op rather than a halt — a missing navigation target must never
  abort the surrounding script. The navigation itself is entirely client-side;
  the script continues immediately.
  """
  @spec navigateto(
          Ctx.t(),
          String.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          boolean(),
          non_neg_integer()
        ) :: Ctx.t()
  def navigateto(%Ctx{status: {:error, _}} = ctx, _map, _x, _y, _flag, _hide_window, _monster_id),
    do: ctx

  def navigateto(%Ctx{char_id: nil} = ctx, _map, _x, _y, _flag, _hide_window, _monster_id),
    do: ctx

  def navigateto(%Ctx{char_id: char_id} = ctx, map, x, y, flag, hide_window, monster_id) do
    Broadcast.to_player(char_id, %NavigateTo{
      map: map,
      x: x,
      y: y,
      flag: flag,
      hide_window: hide_window,
      monster_id: monster_id
    })

    ctx
  end

  @doc """
  Shows an emote bubble over the NPC running the script (rAthena `emotion`,
  self-anchored form — the targeted second-`gid` form is deferred).

  Purely cosmetic, so the context is returned unchanged and a detached ctx (no
  `npc_gid` to originate the emote from) is a silent no-op rather than a halt —
  a missing emote bubble must never abort the surrounding script.
  """
  @spec emotion(Ctx.t(), atom() | non_neg_integer()) :: Ctx.t()
  def emotion(%Ctx{status: {:error, _}} = ctx, _emote), do: ctx
  def emotion(%Ctx{npc_gid: nil} = ctx, _emote), do: ctx

  def emotion(%Ctx{npc_gid: gid} = ctx, emote) do
    Emote.show({:npc, gid}, emote)
    ctx
  end

  @area_size 14

  @doc """
  Broadcasts `text` with the rAthena `announce` semantics.

  The numeric `flag` is decoded (`Flags.decode/2`) into a scope, a color, and an
  area anchor source; `color` overrides the flag's color bits when non-zero.
  Delivery is a pure side-effect (no player-state mutation, no session
  round-trip): global scope always fires, but map/area/self need the player (or,
  for an NPC-anchored area, the `npc_gid`) — a detached ctx that cannot resolve
  the anchor is a silent no-op returning ctx unchanged. `source_name` is always
  blank; `announce` never auto-prefixes a name.
  """
  @spec announce(Ctx.t(), String.t(), non_neg_integer()) :: Ctx.t()
  def announce(%Ctx{} = ctx, text, flag), do: announce(ctx, text, flag, 0)

  @spec announce(Ctx.t(), String.t(), non_neg_integer(), non_neg_integer() | String.t()) ::
          Ctx.t()
  def announce(%Ctx{status: {:error, _}} = ctx, _text, _flag, _color), do: ctx

  def announce(%Ctx{} = ctx, text, flag, color) do
    %{scope: scope, color: resolved_color, source: source} = Flags.decode(flag, to_color(color))
    opts = build_opts(text, resolved_color, scope)
    dispatch_announce(ctx, scope, source, opts)
    ctx
  end

  @doc """
  Broadcasts `text` to every player on the named `map` (rAthena `mapannounce`).

  Scope is forced to the map regardless of the caller's position, so it works
  from a detached ctx; the `flag` only supplies the color (custom `color`
  overrides). Display style is `:CENTER`.
  """
  @spec mapannounce(Ctx.t(), String.t(), String.t(), non_neg_integer()) :: Ctx.t()
  def mapannounce(%Ctx{} = ctx, map, text, flag), do: mapannounce(ctx, map, text, flag, 0)

  @spec mapannounce(
          Ctx.t(),
          String.t(),
          String.t(),
          non_neg_integer(),
          non_neg_integer() | String.t()
        ) ::
          Ctx.t()
  def mapannounce(%Ctx{status: {:error, _}} = ctx, _map, _text, _flag, _color), do: ctx

  def mapannounce(%Ctx{} = ctx, map, text, flag, color) do
    %{color: resolved_color} = Flags.decode(flag, to_color(color))
    Announcement.to_map(map, build_opts(text, resolved_color, :map))
    ctx
  end

  @doc """
  Broadcasts `text` to players inside the rectangle `{x0, y0, x1, y1}` on the
  named `map` (rAthena `areaannounce`).

  Takes an explicit map and rectangle, so it works from a detached ctx; the
  `flag` only supplies the color (custom `color` overrides). Display style is
  `:CENTER`.
  """
  @spec areaannounce(
          Ctx.t(),
          String.t(),
          integer(),
          integer(),
          integer(),
          integer(),
          String.t(),
          non_neg_integer()
        ) :: Ctx.t()
  def areaannounce(%Ctx{} = ctx, map, x0, y0, x1, y1, text, flag) do
    areaannounce(ctx, map, x0, y0, x1, y1, text, flag, 0)
  end

  @spec areaannounce(
          Ctx.t(),
          String.t(),
          integer(),
          integer(),
          integer(),
          integer(),
          String.t(),
          non_neg_integer(),
          non_neg_integer() | String.t()
        ) :: Ctx.t()
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def areaannounce(
        %Ctx{status: {:error, _}} = ctx,
        _map,
        _x0,
        _y0,
        _x1,
        _y1,
        _text,
        _flag,
        _color
      ) do
    ctx
  end

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def areaannounce(%Ctx{} = ctx, map, x0, y0, x1, y1, text, flag, color) do
    %{color: resolved_color} = Flags.decode(flag, to_color(color))
    Announcement.to_area(map, {x0, y0, x1, y1}, build_opts(text, resolved_color, :area))
    ctx
  end

  @doc """
  Legacy global broadcast alias (rAthena `broadcast`): always global scope. The
  `flag` only supplies the color (custom `color` overrides).
  """
  @spec broadcast(Ctx.t(), String.t(), non_neg_integer()) :: Ctx.t()
  def broadcast(%Ctx{} = ctx, text, flag), do: broadcast(ctx, text, flag, 0)

  @spec broadcast(Ctx.t(), String.t(), non_neg_integer(), non_neg_integer() | String.t()) ::
          Ctx.t()
  def broadcast(%Ctx{status: {:error, _}} = ctx, _text, _flag, _color), do: ctx

  def broadcast(%Ctx{} = ctx, text, flag, color) do
    %{color: resolved_color} = Flags.decode(flag, to_color(color))
    Announcement.to_all(build_opts(text, resolved_color, :all))
    ctx
  end

  # rAthena's dispbottom default color (COLOR_LIGHT_GREEN).
  @dispbottom_color 0x00FF00

  @doc """
  Shows `text` in the invoking player's chat box (rAthena `dispbottom`).
  `color` is a `0xRRGGBB` value, defaulting to rAthena's light green.
  Delivered through `Announcement.to_self/2` with the `:LOCAL` style — the
  chat-box arm of the broadcast packet. Purely cosmetic, so a detached ctx
  (no player to message) is a silent no-op rather than a halt.
  """
  @spec dispbottom(Ctx.t(), String.t(), non_neg_integer() | String.t()) :: Ctx.t()
  def dispbottom(ctx, text, color \\ @dispbottom_color)
  def dispbottom(%Ctx{status: {:error, _}} = ctx, _text, _color), do: ctx
  def dispbottom(%Ctx{char_id: nil} = ctx, _text, _color), do: ctx

  def dispbottom(%Ctx{char_id: char_id} = ctx, text, color) do
    Announcement.to_self(char_id, %{
      text: text,
      color: to_color(color),
      style: :LOCAL,
      source_name: ""
    })

    ctx
  end

  # rAthena announce/broadcast colors arrive either as an integer or, in the
  # airship/event scripts, as a `"0xRRGGBB"` hex string; `Flags.decode/2` and the
  # broadcast packet both want an integer, so normalize here. An unparseable
  # value falls back to `0` (derive the color from the flag bits).
  @spec to_color(non_neg_integer() | String.t()) :: non_neg_integer()
  defp to_color(color) when is_integer(color), do: color
  defp to_color("0x" <> hex), do: parse_color_base(hex, 16)
  defp to_color("0X" <> hex), do: parse_color_base(hex, 16)
  defp to_color(color) when is_binary(color), do: parse_color_base(color, 10)

  defp parse_color_base(digits, base) do
    case Integer.parse(digits, base) do
      {n, ""} when n >= 0 -> n
      _ -> 0
    end
  end

  defp build_opts(text, color, scope) do
    %{text: text, color: color, style: Flags.style_for(scope), source_name: ""}
  end

  defp dispatch_announce(_ctx, :all, _source, opts), do: Announcement.to_all(opts)

  defp dispatch_announce(%Ctx{game_state: nil}, :map, _source, _opts), do: :ok

  defp dispatch_announce(%Ctx{game_state: game_state}, :map, _source, opts) do
    Announcement.to_map(game_state.map_name, opts)
  end

  defp dispatch_announce(%Ctx{game_state: nil}, :self, _source, _opts), do: :ok

  defp dispatch_announce(%Ctx{char_id: char_id}, :self, _source, opts) do
    Announcement.to_self(char_id, opts)
  end

  defp dispatch_announce(%Ctx{} = ctx, :area, source, opts) do
    case area_anchor(ctx, source) do
      {:ok, map, {ax, ay}} ->
        rect = {ax - @area_size, ay - @area_size, ax + @area_size, ay + @area_size}
        Announcement.to_area(map, rect, opts)

      :error ->
        :ok
    end
  end

  defp area_anchor(%Ctx{game_state: nil}, :pc), do: :error

  defp area_anchor(%Ctx{game_state: game_state}, :pc) do
    {:ok, game_state.map_name, {game_state.x, game_state.y}}
  end

  defp area_anchor(%Ctx{npc_gid: nil}, :npc), do: :error

  defp area_anchor(%Ctx{npc_gid: npc_gid}, :npc) do
    case NpcRegistry.module_for_unit(npc_gid) do
      {:ok, {_module, placement}} -> {:ok, placement.map, {placement.x, placement.y}}
      :error -> :error
    end
  end

  @doc """
  Logs `message` to the server log (rAthena `logmes`), prefixed with the
  invoking player's identity when attached, or the running NPC's gid when
  detached. Purely observational: the context is returned unchanged and it runs
  even on a detached ctx (rAthena logs via the NPC when no player is present).
  """
  @spec logmes(Ctx.t(), String.t()) :: Ctx.t()
  def logmes(%Ctx{status: {:error, _}} = ctx, _message), do: ctx

  def logmes(%Ctx{game_state: nil, npc_gid: gid} = ctx, message) do
    Logger.info("[npc log] npc=#{gid}: #{message}")
    ctx
  end

  def logmes(%Ctx{game_state: gs} = ctx, message) do
    Logger.info("[npc log] #{gs.character_name}[#{gs.account_id}]: #{message}")
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
    case Cell.random_traversable(game_state.map_name) do
      {:ok, {x, y}} -> warp(ctx, game_state.map_name, x, y)
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
  Warps every player inside the rectangle `{x1,y1}`–`{x2,y2}` on `from_map` to
  `to_map` at `{x3,y3}` (rAthena `areawarp`). The area-destination form
  (adding `x4,y4`) relocates each player to a random cell inside that
  rectangle instead of a fixed point.

  A world effect that does not touch the attached player's state: the context
  is returned unchanged and it runs even on a detached ctx. An offline or
  unknown target is skipped, matching rAthena's success-on-absence.
  """
  @spec areawarp(
          Ctx.t(),
          String.t(),
          integer(),
          integer(),
          integer(),
          integer(),
          String.t(),
          integer(),
          integer()
        ) :: Ctx.t()
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def areawarp(%Ctx{status: {:error, _}} = ctx, _from, _x1, _y1, _x2, _y2, _to, _x3, _y3),
    do: ctx

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def areawarp(%Ctx{} = ctx, from_map, x1, y1, x2, y2, to_map, x3, y3) do
    warp_players_in_area(from_map, x1, y1, x2, y2, fn _ -> {to_map, x3, y3} end)
    ctx
  end

  @spec areawarp(
          Ctx.t(),
          String.t(),
          integer(),
          integer(),
          integer(),
          integer(),
          String.t(),
          integer(),
          integer(),
          integer(),
          integer()
        ) :: Ctx.t()
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def areawarp(
        %Ctx{status: {:error, _}} = ctx,
        _from,
        _x1,
        _y1,
        _x2,
        _y2,
        _to,
        _x3,
        _y3,
        _x4,
        _y4
      ),
      do: ctx

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def areawarp(%Ctx{} = ctx, from_map, x1, y1, x2, y2, to_map, x3, y3, x4, y4) do
    dx_min = min(x3, x4)
    dx_max = max(x3, x4)
    dy_min = min(y3, y4)
    dy_max = max(y3, y4)

    warp_players_in_area(from_map, x1, y1, x2, y2, fn _ ->
      {to_map, Enum.random(dx_min..dx_max), Enum.random(dy_min..dy_max)}
    end)

    ctx
  end

  @doc """
  Warps a specific player by character id (rAthena `warpchar`). The three-arg
  form targets the attached player (equivalent to `warp/4`); the four-arg form
  targets `char_id`, casting a warp to that player's session when they are
  online and no-oping otherwise (rAthena returns success for an offline
  target). "Random"/"SavePoint" string targets are not supported.
  """
  @spec warpchar(Ctx.t(), String.t(), non_neg_integer(), non_neg_integer()) :: Ctx.t()
  def warpchar(%Ctx{status: {:error, _}} = ctx, _map, _x, _y), do: ctx
  def warpchar(%Ctx{} = ctx, map, x, y), do: warp(ctx, map, x, y)

  @spec warpchar(Ctx.t(), String.t(), non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          Ctx.t()
  def warpchar(%Ctx{status: {:error, _}} = ctx, _map, _x, _y, _char_id), do: ctx

  def warpchar(%Ctx{} = ctx, map, x, y, char_id) do
    if char_id == ctx.char_id do
      warp(ctx, map, x, y)
    else
      case UnitRegistry.get_player_pid(char_id) do
        {:ok, pid} -> PlayerSession.warp(pid, map, x, y)
        {:error, :not_found} -> :ok
      end

      ctx
    end
  end

  defp warp_players_in_area(from_map, x1, y1, x2, y2, destination) do
    from_map
    |> SpatialIndex.get_players_in_area(x1, y1, x2, y2)
    |> Enum.each(fn char_id ->
      case UnitRegistry.get_player_pid(char_id) do
        {:ok, pid} ->
          {map, x, y} = destination.(char_id)
          PlayerSession.warp(pid, map, x, y)

        {:error, :not_found} ->
          :ok
      end
    end)
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

  The item is the cost, so this runs through `SkillInterpreter.item_cast/4`: the
  player need not have learned the skill and no SP, zeny, catalyst or ammo is
  required or charged.
  """
  @spec itemskill(Ctx.t(), integer() | atom(), keyword()) :: Ctx.t()
  def itemskill(%Ctx{status: {:error, _}} = ctx, _skill, _opts), do: ctx
  def itemskill(%Ctx{game_state: nil} = ctx, _skill, _opts), do: Ctx.halt(ctx, :no_player)

  def itemskill(%Ctx{} = ctx, skill_id_or_name, opts) do
    level = Keyword.get(opts, :level, 1)
    target = Keyword.get(opts, :target, :self)

    with {:ok, skill_id} <- resolve_skill_id(skill_id_or_name),
         {:ok, new_game_state} <-
           SkillInterpreter.item_cast(ctx.game_state, skill_id, level, target) do
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

  @doc "Rolls and grants every result from an item group."
  @spec get_group_item(Ctx.t(), atom()) :: Ctx.t()
  def get_group_item(%Ctx{status: {:error, _}} = ctx, _group_key), do: ctx

  def get_group_item(%Ctx{} = ctx, group_key) do
    case ItemGroups.fetch(group_key) do
      {:ok, group} ->
        group
        |> Roller.roll_full()
        |> stamp_group_key(group_key)
        |> then(&commit_grants(ctx, &1))

      :error ->
        Ctx.halt(ctx, :unknown_item_group)
    end
  end

  @doc "Rolls and grants `qty` results from one item-group subgroup."
  @spec get_rand_group_item(Ctx.t(), atom(), pos_integer(), non_neg_integer()) :: Ctx.t()
  def get_rand_group_item(%Ctx{status: {:error, _}} = ctx, _group_key, _qty, _sub), do: ctx

  def get_rand_group_item(%Ctx{} = ctx, group_key, qty, sub)
      when is_integer(qty) and qty > 0 and is_integer(sub) and sub >= 0 do
    case ItemGroups.fetch(group_key) do
      {:ok, group} ->
        group
        |> Roller.roll_n(sub, qty)
        |> stamp_group_key(group_key)
        |> then(&commit_grants(ctx, &1))

      :error ->
        Ctx.halt(ctx, :unknown_item_group)
    end
  end

  @doc "Returns one item id from a subgroup without depleting shared-pool state."
  @spec group_rand_item(Ctx.t(), atom(), non_neg_integer()) :: pos_integer()
  def group_rand_item(%Ctx{}, group_key, sub) do
    with {:ok, group} <- ItemGroups.fetch(group_key),
         {:ok, item_id} <- Roller.pick_id(group, sub) do
      item_id
    else
      :error ->
        raise ArgumentError,
              "group_rand_item/3 cannot resolve item group #{inspect(group_key)} subgroup #{sub}"
    end
  end

  @doc "Commits concrete item-group grants through the current script context."
  @spec commit_grants(Ctx.t(), [Group.grant()]) :: Ctx.t()
  def commit_grants(%Ctx{} = ctx, []), do: ctx
  def commit_grants(%Ctx{status: {:error, _}} = ctx, _grants), do: ctx

  def commit_grants(%Ctx{session_pid: session_pid} = ctx, grants) when is_pid(session_pid) do
    case apply_op(ctx, {:give_items_atomic, grants}) do
      %Ctx{status: {:error, :insufficient_space}} = halted ->
        rollback_pool(grants)
        Ctx.halt(halted, :inventory_full)

      %Ctx{status: {:error, _reason}} = halted ->
        rollback_pool(grants)
        halted

      %Ctx{} = committed ->
        maybe_announce(committed, grants)
    end
  end

  def commit_grants(%Ctx{session_pid: nil, game_state: nil} = ctx, _grants),
    do: Ctx.halt(ctx, :no_player)

  def commit_grants(%Ctx{session_pid: nil, game_state: game_state} = ctx, grants) do
    case Inventory.give_many(
           ctx.char_id,
           game_state.inventory,
           game_state.stats,
           grants
         ) do
      {:ok, inventory} ->
        maybe_announce(%{ctx | game_state: %{game_state | inventory: inventory}}, grants)

      {:error, :insufficient_space} ->
        rollback_pool(grants)
        Ctx.halt(ctx, :inventory_full)
    end
  end

  @spec stamp_group_key([Group.grant()], atom()) :: [Group.grant()]
  defp stamp_group_key(grants, group_key),
    do: Enum.map(grants, &Map.put(&1, :group_key, group_key))

  @spec rollback_pool([Group.grant()]) :: :ok
  defp rollback_pool(grants) do
    Enum.each(grants, fn
      %{group_key: group_key, drawn: {sub, item_ids}} ->
        ItemGroupPool.rollback(group_key, sub, item_ids)

      _grant ->
        :ok
    end)
  end

  @spec maybe_announce(Ctx.t(), [Group.grant()]) :: Ctx.t()
  defp maybe_announce(ctx, grants) do
    Enum.each(grants, fn
      %{announced?: true, item_id: item_id} ->
        opts = build_opts("Obtained item #{item_id}.", 0, :all)
        dispatch_announce(ctx, :all, :pc, opts)

      _grant ->
        :ok
    end)

    ctx
  end

  @doc """
  Gives one identified item signed by an online character through the session seam.
  Halts if the target is offline or unknown, or if the inventory cannot hold it.
  """
  @spec get_named_item(Ctx.t(), integer(), String.t() | integer()) :: Ctx.t()
  def get_named_item(%Ctx{status: {:error, _}} = ctx, _item_id, _target), do: ctx

  def get_named_item(%Ctx{} = ctx, item_id, target),
    do: apply_op(ctx, {:get_named_item, item_id, target})

  @doc """
  Gives one time-limited rental item through the session seam.
  """
  @spec give_item_rental(Ctx.t(), integer(), pos_integer(), keyword()) :: Ctx.t()
  def give_item_rental(ctx, item_id, seconds, opts \\ [])

  def give_item_rental(%Ctx{status: {:error, _}} = ctx, _id, _secs, _opts), do: ctx

  def give_item_rental(%Ctx{} = ctx, item_id, seconds, opts),
    do: apply_op(ctx, {:give_item_rental, item_id, seconds, opts})

  @doc """
  Gives `qty` of item `item_id` through the session seam with an account or
  character binding.
  """
  @spec give_item_bound(Ctx.t(), integer(), pos_integer(), :account | :char | 1 | 4) :: Ctx.t()
  def give_item_bound(%Ctx{status: {:error, _}} = ctx, _item_id, _qty, _bound), do: ctx

  def give_item_bound(%Ctx{} = ctx, item_id, qty, bound),
    do: apply_op(ctx, {:give_item_bound, item_id, qty, bound_value(bound)})

  defp bound_value(:account), do: 1
  defp bound_value(:char), do: 4
  defp bound_value(1), do: 1
  defp bound_value(4), do: 4

  @doc """
  Removes `qty` of item `item_id` through the session seam (persisting and
  emitting `ItemRemoved`). Halts `:not_enough_items` when the player holds fewer.
  """
  @spec delitem(Ctx.t(), integer(), pos_integer()) :: Ctx.t()
  def delitem(%Ctx{status: {:error, _}} = ctx, _item_id, _qty), do: ctx
  def delitem(%Ctx{} = ctx, item_id, qty), do: apply_op(ctx, {:delitem, item_id, qty})

  @doc """
  Removes the equipment worn in equip `slot` (rAthena `delequip`) through the
  session seam: the item is unequipped first (appearance broadcast, stats
  recompute), then its inventory row is deleted. An empty or unknown slot is a
  no-op. Like the other granting/removing effects the value rAthena returns is
  not exposed. Halts `:no_player` on a detached ctx.
  """
  @spec delequip(Ctx.t(), integer()) :: Ctx.t()
  def delequip(%Ctx{status: {:error, _}} = ctx, _slot), do: ctx

  def delequip(%Ctx{} = ctx, slot) do
    case equipped_index(ctx, slot) do
      {index, %InventoryItem{nameid: nameid}} -> apply_op(ctx, {:delequip, index, nameid})
      nil -> ctx
    end
  end

  @doc """
  Raises the equipment worn in equip `slot` by `up` refine levels (default `1`,
  rAthena `successrefitem`), clamped to `MAX_REFINE`, through the session seam
  with no ore/zeny cost. The item's refine is persisted and combat stats
  recalculated when it was equipped. An empty/unknown slot is a no-op (the
  value rAthena returns is not exposed, matching the other statement effects).
  Halts `:no_player` on a detached ctx.
  """
  @spec successrefitem(Ctx.t(), integer(), pos_integer()) :: Ctx.t()
  def successrefitem(ctx, slot, up \\ 1)

  def successrefitem(%Ctx{status: {:error, _}} = ctx, _slot, _up), do: ctx

  def successrefitem(%Ctx{} = ctx, slot, up) do
    case equipped_index(ctx, slot) do
      {index, %InventoryItem{nameid: nameid}} ->
        apply_op(ctx, {:successrefitem, index, nameid, up})

      nil ->
        ctx
    end
  end

  @doc """
  Destroys the equipment worn in equip `slot` (rAthena `failedrefitem`) through
  the session seam, as a forced refine failure irrecoverably breaks the item.
  The removal is persisted and combat stats recalculated when it was equipped.
  An empty/unknown slot is a no-op (the value rAthena returns is not exposed,
  matching the other statement effects). Halts `:no_player` on a detached ctx.
  """
  @spec failedrefitem(Ctx.t(), integer()) :: Ctx.t()
  def failedrefitem(%Ctx{status: {:error, _}} = ctx, _slot), do: ctx

  def failedrefitem(%Ctx{} = ctx, slot) do
    case equipped_index(ctx, slot) do
      {index, %InventoryItem{nameid: nameid}} -> apply_op(ctx, {:failedrefitem, index, nameid})
      nil -> ctx
    end
  end

  @doc """
  Suppresses inventory item use for the player through the session seam
  (rAthena `disable_items` / `disableitemuse`): while active, item-use requests
  are rejected until cleared by a later script or a fresh session. Used by
  shop/item-exchange NPCs so the player cannot consume items mid-dialog. Haltst
  `:no_player` on a detached ctx.
  """
  @spec disable_items(Ctx.t()) :: Ctx.t()
  def disable_items(%Ctx{status: {:error, _}} = ctx), do: ctx
  def disable_items(%Ctx{} = ctx), do: apply_op(ctx, {:disable_items})

  @doc """
  Gives `qty` of item `item_id` with explicit attributes through the session
  seam (rAthena `getitem2`): `identify`, `refine`, and the four card values
  (`card1`..`card4` map to `card0`..`card3`). The element attribute has no
  Aesir inventory field and is accepted-but-ignored, as documented. Halts
  `:no_player` on a detached ctx.
  """
  @spec getitem2(
          Ctx.t(),
          integer(),
          pos_integer(),
          0 | 1,
          non_neg_integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer()
        ) :: Ctx.t()
  # The rAthena `getitem2` buildin carries nine positional args (id, count,
  # identify, refine, attr, four cards); the arity is inherent.
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def getitem2(
        %Ctx{status: {:error, _}} = ctx,
        _item,
        _qty,
        _identify,
        _refine,
        _attr,
        _card1,
        _card2,
        _card3,
        _card4
      ),
      do: ctx

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def getitem2(
        %Ctx{} = ctx,
        item,
        qty,
        identify,
        refine,
        _attr,
        card1,
        card2,
        card3,
        card4
      ) do
    attrs = %{
      identify: identify,
      refine: refine,
      card0: card1,
      card1: card2,
      card2: card3,
      card3: card4
    }

    apply_op(ctx, {:give_item2, item, qty, attrs})
  end

  @doc """
  Runs item `item_id`'s use script on the invoking player (rAthena
  `consumeitem`). The player need not possess the item and nothing is removed
  from inventory — only the item's `on_use` effect runs (inns use this to feed
  stat-food buffs). Delegates to the same compiled item scripts the item-use
  path runs, so the effect (`sc_start`, `heal`, …) applies through the normal
  DSL seams; an item with no `on_use` is a no-op.
  """
  @spec consumeitem(Ctx.t(), integer()) :: Ctx.t()
  def consumeitem(%Ctx{status: {:error, _}} = ctx, _item_id), do: ctx
  def consumeitem(%Ctx{} = ctx, item_id), do: CompiledItemScripts.on_use(item_id, ctx)

  @doc """
  Unequips every item the invoking player has equipped (rAthena `nude`) through
  the session seam, sending each takeoff ack, recomputing stats, and
  broadcasting the appearance changes. Returns the context unchanged when
  nothing is equipped. Halts `:no_player` on a detached ctx.
  """
  @spec nude(Ctx.t()) :: Ctx.t()
  def nude(%Ctx{status: {:error, _}} = ctx), do: ctx
  def nude(%Ctx{} = ctx), do: apply_op(ctx, {:nude})

  @doc """
  Clears the broken flag on the equipment at inventory `index` through the
  session seam (rAthena `repair`), re-syncing the now-normal row to the client.
  Idempotent: a missing or already-normal row is a no-op success. Never
  re-equips the item - the player re-wears it manually.
  """
  @spec repair(Ctx.t(), non_neg_integer()) :: Ctx.t()
  def repair(%Ctx{status: {:error, _}} = ctx, _index), do: ctx
  def repair(%Ctx{} = ctx, index), do: apply_op(ctx, {:repair, index})

  @doc """
  Clears the broken flag on every broken equipment through the session seam
  (rAthena `repairall`), re-syncing each repaired row to the client. Idempotent
  when nothing is broken. Never re-equips.
  """
  @spec repairall(Ctx.t()) :: Ctx.t()
  def repairall(%Ctx{status: {:error, _}} = ctx), do: ctx
  def repairall(%Ctx{} = ctx), do: apply_op(ctx, {:repairall})

  @doc """
  Item id of the `n`-th broken equipment in the player's inventory (1-indexed,
  slot order; rAthena `getbrokenid`), or 0 when fewer than `n` items are
  broken. Pure read over the snapshot.
  """
  @spec getbrokenid(Ctx.t(), integer()) :: non_neg_integer()
  def getbrokenid(%Ctx{game_state: nil}, _n), do: no_player!("getbrokenid/2")

  def getbrokenid(%Ctx{game_state: gs}, n) when is_integer(n) and n >= 1 do
    gs.inventory
    |> Enum.sort_by(fn {index, _item} -> index end)
    |> Enum.filter(fn {_index, item} -> item.attribute == 1 end)
    |> Enum.at(n - 1)
    |> case do
      {_index, item} -> item.nameid
      nil -> 0
    end
  end

  def getbrokenid(%Ctx{}, _n), do: 0

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
  Pauses the running script for `ms` milliseconds while keeping the player
  attached (rAthena `sleep2`), then resumes. Runs inside the interaction
  coroutine, so only this script waits - the player session is untouched. If
  the player session died while sleeping, halts `{:error, :no_player}` instead
  of resuming. A non-positive duration warns and skips the pause.
  """
  @spec sleep2(Ctx.t(), integer()) :: Ctx.t()
  def sleep2(%Ctx{status: {:error, _}} = ctx, _ms), do: ctx
  def sleep2(%Ctx{game_state: nil} = ctx, _ms), do: Ctx.halt(ctx, :no_player)

  def sleep2(%Ctx{} = ctx, ms) when is_integer(ms) and ms > 0 do
    Process.sleep(ms)

    if ctx.session_pid == nil or Process.alive?(ctx.session_pid) do
      ctx
    else
      Ctx.halt(ctx, :no_player)
    end
  end

  def sleep2(%Ctx{} = ctx, ms) do
    Logger.warning("sleep2: non-positive duration #{inspect(ms)}, skipping")
    ctx
  end

  @doc """
  Displays a progress bar over the attached character's head for `seconds`
  then blocks until the client reports completion.
  Blocks like the other dialog primitives: the interaction suspends on a
  `receive` until the client signals completion (`NpcInteract.progress`); a
  moving character makes the client cancel instead, ending the script (the same
  cancel path `select`'s ESC uses). Halts `:no_player` on a detached ctx.
  """
  @spec progressbar(Ctx.t(), String.t(), integer()) :: Ctx.t()
  def progressbar(%Ctx{status: {:error, _}} = ctx, _color, _seconds), do: ctx
  def progressbar(%Ctx{game_state: nil} = ctx, _color, _seconds), do: Ctx.halt(ctx, :no_player)

  def progressbar(%Ctx{char_id: char_id} = ctx, _color, seconds)
      when is_integer(seconds) and seconds > 0 do
    Broadcast.to_player(char_id, %ProgressBar{seconds: seconds})
    await(ctx, :progress)
    ctx
  end

  def progressbar(%Ctx{} = ctx, _color, seconds) do
    Logger.warning("progressbar: non-positive duration #{inspect(seconds)}, skipping")
    ctx
  end

  @doc """
  Grants `base_exp` base experience and `job_exp` job experience through the
  session seam (rAthena `getexp`), leveling the player as the gain warrants and
  pushing the refreshed experience/stat state to the client.
  """
  @spec getexp(Ctx.t(), non_neg_integer(), non_neg_integer()) :: Ctx.t()
  def getexp(%Ctx{status: {:error, _}} = ctx, _base_exp, _job_exp), do: ctx
  def getexp(%Ctx{} = ctx, base_exp, job_exp), do: apply_op(ctx, {:getexp, base_exp, job_exp})

  @doc """
  Total quantity of item `item_id` the player holds. Pure read over the snapshot.
  """
  @spec count_item(Ctx.t(), integer()) :: non_neg_integer()
  def count_item(%Ctx{game_state: nil}, _item_id), do: no_player!("count_item/2")

  def count_item(%Ctx{game_state: gs}, item_id),
    do: Inventory.held_amount(gs.inventory, item_id)

  @doc """
  Accepts quest `quest_id` through the session seam (`setquest`, `quest_add`).
  Halts `:already_started`/`:unknown_quest` when the quest is already held or
  absent from `quest_db`, leaving the log untouched.
  """
  @spec setquest(Ctx.t(), QuestLog.quest_id()) :: Ctx.t()
  def setquest(%Ctx{status: {:error, _}} = ctx, _quest_id), do: ctx
  def setquest(%Ctx{} = ctx, quest_id), do: apply_op(ctx, {:setquest, quest_id})

  @doc """
  Removes quest `quest_id` from the log through the session seam (`erasequest`,
  `quest_delete`). Halts `:not_started` when the quest isn't held.
  """
  @spec erasequest(Ctx.t(), QuestLog.quest_id()) :: Ctx.t()
  def erasequest(%Ctx{status: {:error, _}} = ctx, _quest_id), do: ctx
  def erasequest(%Ctx{} = ctx, quest_id), do: apply_op(ctx, {:erasequest, quest_id})

  @doc """
  Forces quest `quest_id` to `:complete` through the session seam
  (`completequest`, `quest_update_status`), preserving its counters. Halts
  `:not_started` when the quest isn't active/inactive.
  """
  @spec completequest(Ctx.t(), QuestLog.quest_id()) :: Ctx.t()
  def completequest(%Ctx{status: {:error, _}} = ctx, _quest_id), do: ctx
  def completequest(%Ctx{} = ctx, quest_id), do: apply_op(ctx, {:completequest, quest_id})

  @doc """
  Atomically swaps active/inactive quest `old_id` for fresh quest `new_id`
  through the session seam (`changequest`, `quest_change`). Halts on any of
  `QuestLog.change/3`'s error reasons, leaving the log untouched.
  """
  @spec changequest(Ctx.t(), QuestLog.quest_id(), QuestLog.quest_id()) :: Ctx.t()
  def changequest(%Ctx{status: {:error, _}} = ctx, _old_id, _new_id), do: ctx

  def changequest(%Ctx{} = ctx, old_id, new_id),
    do: apply_op(ctx, {:changequest, old_id, new_id})

  @doc """
  Checks quest `quest_id`'s state, `mode` defaulting to `:havequest`
  (`checkquest`, `QuestLog.check/3`). Pure read over the ctx snapshot; a
  never-started quest returns `-1` - the normal "not started yet" branch, not
  an error.
  """
  @spec checkquest(Ctx.t(), QuestLog.quest_id(), :havequest | :playtime | :hunting) ::
          -1 | 0 | 1 | 2
  def checkquest(ctx, quest_id, mode \\ :havequest)
  def checkquest(%Ctx{game_state: nil}, _quest_id, _mode), do: no_player!("checkquest/3")

  def checkquest(%Ctx{game_state: gs}, quest_id, mode),
    do: QuestLog.check(gs.quest_log, quest_id, mode)

  @doc """
  Alias of `checkquest/2,3` over the same `QuestLog.check/3` core (rAthena
  `questprogress`).
  """
  @spec questprogress(Ctx.t(), QuestLog.quest_id(), :havequest | :playtime | :hunting) ::
          -1 | 0 | 1 | 2
  def questprogress(ctx, quest_id, mode \\ :havequest)
  def questprogress(%Ctx{} = ctx, quest_id, mode), do: checkquest(ctx, quest_id, mode)

  @doc """
  Whether quest `quest_id` has been begun: `0` never, `1` inactive/active, `2`
  complete (`isbegin_quest`, `QuestLog.is_begin/2`).
  """
  @spec isbegin_quest(Ctx.t(), QuestLog.quest_id()) :: 0 | 1 | 2
  def isbegin_quest(%Ctx{game_state: nil}, _quest_id), do: no_player!("isbegin_quest/2")
  def isbegin_quest(%Ctx{game_state: gs}, quest_id), do: QuestLog.is_begin(gs.quest_log, quest_id)

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
        PlayerSession.script_apply(
          session_pid,
          {:refine, index, nameid, cost_type, use_blessing?}
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
  Reads the `$` server permanent variable `name` (server-wide, Postgres-backed),
  defaulting an unset var to `default` (`0` matching rAthena).
  """
  @spec get_server_var(Ctx.t(), String.t(), term()) :: term()
  def get_server_var(ctx, name, default \\ 0)
  def get_server_var(%Ctx{}, name, default), do: Vars.get_server(name, default)

  @doc """
  Sets the `$` server permanent variable `name` to `value`, persisted
  write-through and visible to every server sharing the database. Never fails.
  """
  @spec set_server_var(Ctx.t(), String.t(), term()) :: Ctx.t()
  def set_server_var(%Ctx{status: {:error, _}} = ctx, _name, _value), do: ctx

  def set_server_var(%Ctx{} = ctx, name, value) do
    Vars.put_server(name, value)
    ctx
  end

  @doc """
  Reads the `$@` server temp variable `name` (server-wide, in-memory), defaulting
  an unset var to `default`. Cleared on server restart.
  """
  @spec get_server_temp_var(Ctx.t(), String.t(), term()) :: term()
  def get_server_temp_var(ctx, name, default \\ 0)
  def get_server_temp_var(%Ctx{}, name, default), do: Vars.get_server_temp(name, default)

  @doc "Sets the `$@` server temp variable `name` to `value`. Never persists."
  @spec set_server_temp_var(Ctx.t(), String.t(), term()) :: Ctx.t()
  def set_server_temp_var(%Ctx{status: {:error, _}} = ctx, _name, _value), do: ctx

  def set_server_temp_var(%Ctx{} = ctx, name, value) do
    Vars.put_server_temp(name, value)
    ctx
  end

  @doc """
  Reads the account variable `name` (rAthena `#`/`##`, keyed by the attached
  account), defaulting an unset var — or a player-less context — to `default`.
  The `name` carries its scope sigil so `#foo` and `##foo` stay distinct.
  """
  @spec get_account_var(Ctx.t(), String.t(), term()) :: term()
  def get_account_var(ctx, name, default \\ 0)
  def get_account_var(%Ctx{account_id: nil}, _name, default), do: default

  def get_account_var(%Ctx{account_id: account_id}, name, default),
    do: Vars.get_account(account_id, name, default)

  @doc """
  Sets the account variable `name` to `value`, persisted write-through against
  the attached account. A no-op (never fails) when no player is attached.
  """
  @spec set_account_var(Ctx.t(), String.t(), term()) :: Ctx.t()
  def set_account_var(%Ctx{status: {:error, _}} = ctx, _name, _value), do: ctx
  def set_account_var(%Ctx{account_id: nil} = ctx, _name, _value), do: ctx

  def set_account_var(%Ctx{account_id: account_id} = ctx, name, value) do
    Vars.put_account(account_id, name, value)
    ctx
  end

  @doc """
  Reads the `.` NPC variable `name` (shared across every placement of the
  running NPC script, server-lifetime, in-memory), defaulting an unset var to
  `default`.
  """
  @spec get_npc_var(Ctx.t(), String.t(), term()) :: term()
  def get_npc_var(ctx, name, default \\ 0)
  def get_npc_var(%Ctx{source: source}, name, default), do: Vars.get_npc(source, name, default)

  @doc "Sets the `.` NPC variable `name` to `value`. Never persists."
  @spec set_npc_var(Ctx.t(), String.t(), term()) :: Ctx.t()
  def set_npc_var(%Ctx{status: {:error, _}} = ctx, _name, _value), do: ctx

  def set_npc_var(%Ctx{source: source} = ctx, name, value) do
    Vars.put_npc(source, name, value)
    ctx
  end

  @doc """
  Reads a variable whose full name — scope sigil and optional `[N]` array
  element — is only known at runtime (rAthena `getd("…")`). The name
  dispatches to the same backing store as static access, so a dynamically
  built name reads exactly what a statically written one would. Unset whole
  vars default to `0`/`""` by the name's trailing `$`; indexed names read the
  element (padding when the base holds a non-list). Instance scope (`'`) has
  no store and raises via `Todo`, matching static instance access.
  """
  @spec getd(Ctx.t(), String.t()) :: term()
  def getd(%Ctx{} = ctx, name) do
    {scope, key, index} = Vars.parse_name(name)
    read_scope(ctx, scope, key, index)
  end

  @doc """
  Writes a variable whose full name — scope sigil and optional `[N]` array
  element — is only known at runtime (rAthena `setd "name", value`). The name
  dispatches to the same stores as static writes. An indexed name updates the
  element (padding the gap with `0`/`""` by the name's string marker); a list
  value writes consecutive elements from the index (rAthena
  `setarray getd(…), …`); a plain name replaces the whole value. The optional
  rAthena `char_id` argument is dropped. Instance scope (`'`) has no store and
  raises via `Todo`, matching static instance access.
  """
  @spec setd(Ctx.t(), String.t(), term()) :: Ctx.t()
  def setd(%Ctx{status: {:error, _}} = ctx, _name, _value), do: ctx

  def setd(%Ctx{} = ctx, name, value) do
    {scope, key, index} = Vars.parse_name(name)
    write_scope(ctx, scope, key, index, value)
  end

  # -- dynamic-variable helpers ------------------------------------------------

  defp read_scope(_ctx, :server, key, index),
    do: read_dyn(Vars.get_server(key, dyn_default(key, index)), index, key)

  defp read_scope(_ctx, :server_temp, key, index),
    do: read_dyn(Vars.get_server_temp(key, dyn_default(key, index)), index, key)

  defp read_scope(ctx, :account, key, index), do: read_account(ctx, key, index)
  defp read_scope(ctx, :account_global, key, index), do: read_account(ctx, key, index)

  defp read_scope(ctx, :npc, key, index),
    do: read_dyn(Vars.get_npc(ctx.source, key, dyn_default(key, index)), index, key)

  defp read_scope(ctx, :local, key, index),
    do: read_dyn(Map.get(ctx.vars, String.to_atom(key), dyn_default(key, index)), index, key)

  defp read_scope(ctx, :temp, key, index),
    do: read_player_var(ctx, key, index, &get_temp_var/3)

  defp read_scope(ctx, :char, key, index),
    do: read_player_var(ctx, key, index, &get_char_var/3)

  defp read_scope(_ctx, :instance, key, _index), do: Todo.call!(:instance_var, [key])

  defp write_scope(ctx, :server, key, index, value) do
    Vars.put_server(key, array_write(Vars.get_server(key, []), index, value, key))
    ctx
  end

  defp write_scope(ctx, :server_temp, key, index, value) do
    Vars.put_server_temp(key, array_write(Vars.get_server_temp(key, []), index, value, key))
    ctx
  end

  defp write_scope(ctx, :account, key, index, value), do: set_account(ctx, key, index, value)

  defp write_scope(ctx, :account_global, key, index, value),
    do: set_account(ctx, key, index, value)

  defp write_scope(ctx, :npc, key, index, value) do
    Vars.put_npc(
      ctx.source,
      key,
      array_write(Vars.get_npc(ctx.source, key, []), index, value, key)
    )

    ctx
  end

  defp write_scope(ctx, :local, key, index, value) do
    set_local(
      ctx,
      String.to_atom(key),
      array_write(Map.get(ctx.vars, String.to_atom(key), []), index, value, key)
    )
  end

  defp write_scope(ctx, :temp, key, index, value),
    do: write_player_var(ctx, key, index, value, :temp)

  defp write_scope(ctx, :char, key, index, value),
    do: write_player_var(ctx, key, index, value, :char)

  defp write_scope(_ctx, :instance, key, _index, _value) do
    Todo.call!(:instance_var, [key])
  end

  defp read_account(%Ctx{account_id: nil}, key, index), do: dyn_default(key, index)

  defp read_account(%Ctx{account_id: account_id}, key, index),
    do: read_dyn(Vars.get_account(account_id, key, dyn_default(key, index)), index, key)

  # Player-scope reads (`@`/bare) raise without a player, like the static
  # `get_temp_var`/`get_char_var` reads they delegate to.
  defp read_player_var(%Ctx{game_state: nil}, _key, _index, _fun), do: no_player!("getd/2")

  defp read_player_var(%Ctx{} = ctx, key, index, fun),
    do: read_dyn(fun.(ctx, String.to_atom(key), dyn_default(key, index)), index, key)

  # Player-scope writes (`@`/bare) route through the session seam; without a
  # player they halt `:no_player` like the static `set_temp_var`/`set_char_var`.
  defp write_player_var(%Ctx{game_state: nil} = ctx, _key, _index, _value, _scope),
    do: Ctx.halt(ctx, :no_player)

  defp write_player_var(%Ctx{game_state: gs} = ctx, key, index, value, scope) do
    current = Map.get(player_scope(gs, scope), key, [])

    case scope do
      :temp -> set_temp_var(ctx, String.to_atom(key), array_write(current, index, value, key))
      :char -> set_char_var(ctx, String.to_atom(key), array_write(current, index, value, key))
    end
  end

  defp player_scope(%{temp_vars: temp_vars}, :temp), do: temp_vars
  defp player_scope(%{vars: vars}, :char), do: vars

  # Whole-var reads default `0`/`""` by the string marker; indexed reads base
  # the array access on an empty list.
  defp dyn_default(key, nil), do: dyn_pad(key)
  defp dyn_default(_key, _index), do: []

  defp dyn_pad(key) when is_binary(key),
    do: if(String.ends_with?(key, "$"), do: "", else: 0)

  defp read_dyn(current, nil, _key), do: current

  defp read_dyn(current, index, key) do
    if is_list(current), do: Enum.at(current, index, dyn_pad(key)), else: dyn_pad(key)
  end

  # Indexed writes pad the gap (`0`/`""` by the string marker); a list value
  # writes consecutive elements from the index (rAthena setarray-through-getd),
  # a scalar a single element. A non-list base is treated as an empty array.
  defp array_write(_current, nil, value, _key), do: value

  defp array_write(current, index, value, key) do
    current = if is_list(current), do: current, else: []
    pad = dyn_pad(key)

    if is_list(value) do
      Rathena.put_many(current, index, value, pad)
    else
      Rathena.put_at(current, index, value, pad)
    end
  end

  defp set_account(%Ctx{account_id: nil} = ctx, _key, _index, _value), do: ctx

  defp set_account(%Ctx{account_id: account_id} = ctx, key, index, value) do
    Vars.put_account(
      account_id,
      key,
      array_write(Vars.get_account(account_id, key, []), index, value, key)
    )

    ctx
  end

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
  Refunds the player's learned skills into skill points through the session seam
  (rAthena `resetskill`), recomputing stats, refreshing the skill window, and
  persisting. `NV_BASIC` is kept (not refunded) unless the player is a Novice.
  Never fails.
  """
  @spec reset_skills(Ctx.t()) :: Ctx.t()
  def reset_skills(%Ctx{status: {:error, _}} = ctx), do: ctx
  def reset_skills(%Ctx{} = ctx), do: apply_op(ctx, {:reset_skills})

  @doc """
  Grants a skill permanently through the session seam (rAthena `skill
  <id>,<level>{,<flag>}` - the "platinum skill" style permanent grant outside
  the normal skill tree). Aesir implements only the permanent-grant flag
  (rAthena's `SKILL_PERM`); `flag` is accepted for source compatibility with
  transpiled scripts but is otherwise unused. `skill` is a skill id or its
  catalog name atom.

  The session keeps `max(existing, requested)` as the learned level and never
  spends or refunds a skill point, so a repeat or lower-level grant is a
  no-op. Halts `:unknown_skill`, `:invalid_level`, or `:not_grantable` (a
  definition without quest-grant metadata) without mutation; halts
  `:no_player` on a detached ctx.
  """
  @spec skill(Ctx.t(), integer() | atom(), pos_integer(), integer() | atom()) :: Ctx.t()
  def skill(%Ctx{status: {:error, _}} = ctx, _skill, _level, _flag), do: ctx

  def skill(%Ctx{} = ctx, skill_id_or_name, level, _flag),
    do: apply_op(ctx, {:grant_skill, skill_id_or_name, level})

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
  Whether the attached player has a Falcon: `1` when the Falcon option bit is
  set, otherwise `0`. Detached contexts report `0`.
  """
  @spec checkfalcon(Ctx.t()) :: 0 | 1
  def checkfalcon(%Ctx{game_state: nil}), do: 0

  def checkfalcon(%Ctx{game_state: gs}) do
    if (gs.option &&& Option.id(:falcon)) != 0, do: 1, else: 0
  end

  @doc """
  Whether the player has a cart mounted (rAthena `checkcart`): `1` when
  `cart_type` is set, else `0`. Pure read over the ctx snapshot.
  """
  @spec checkcart(Ctx.t()) :: 0 | 1
  def checkcart(%Ctx{game_state: nil}), do: no_player!("checkcart/1")
  def checkcart(%Ctx{game_state: gs}), do: if(gs.cart_type > 0, do: 1, else: 0)

  @doc """
  Whether the server enforces Basic Skill requirements (rAthena
  `basicskillcheck`, the `basic_skill_check` battle flag). Aesir always
  enforces them (the storage gate requires `NV_BASIC`), so this is always
  `1`. Pure read; the ctx is ignored.
  """
  @spec basicskillcheck(Ctx.t()) :: 1
  def basicskillcheck(%Ctx{}), do: 1

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
  a limit of 8 admits 7 players. `opts` accepts `:event_ref` (`"Name::OnLabel"`
  to fire), `:trigger` (defaults to `limit`), `:zeny` (entry fee, checked at
  join and paid on warp), `:min_lvl`, and `:max_lvl`. Valid on a detached ctx; a
  second room on the same NPC no-ops.
  """
  @spec waitingroom(Ctx.t(), String.t(), pos_integer(), keyword()) :: Ctx.t()
  def waitingroom(%Ctx{status: {:error, _}} = ctx, _title, _limit, _opts), do: ctx

  def waitingroom(%Ctx{npc_gid: nil} = ctx, _title, _limit, _opts),
    do: warn_no_npc_gid(ctx, "waitingroom/3")

  def waitingroom(%Ctx{npc_gid: gid} = ctx, title, limit, opts) do
    event_ref = Keyword.get(opts, :event_ref, "")
    trigger = Keyword.get(opts, :trigger, limit)
    zeny = Keyword.get(opts, :zeny, 0)
    min_lvl = Keyword.get(opts, :min_lvl, 1)
    max_lvl = Keyword.get(opts, :max_lvl, Config.max_base_level())

    case WaitingRoom.create(gid, title, limit, trigger, event_ref, zeny, min_lvl, max_lvl) do
      :ok ->
        broadcast_room_info(gid)
        ctx

      {:error, :already_exists} ->
        Logger.warning("npc waitingroom/3: gid #{gid} already has a room, no-op")
        ctx
    end
  end

  @doc "Deletes the calling NPC's waiting room."
  @spec delwaitingroom(Ctx.t()) :: Ctx.t()
  def delwaitingroom(%Ctx{} = ctx), do: delwaitingroom(ctx, nil)

  @doc "Deletes the named NPC's waiting room."
  @spec delwaitingroom(Ctx.t(), String.t()) :: Ctx.t()
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
  @spec enablewaitingroomevent(Ctx.t(), String.t()) :: Ctx.t()
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
  @spec disablewaitingroomevent(Ctx.t(), String.t()) :: Ctx.t()
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
  @spec kickwaitingroomall(Ctx.t(), String.t()) :: Ctx.t()
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

  @spec getwaitingroomusers(Ctx.t(), String.t()) :: Ctx.t()
  def getwaitingroomusers(%Ctx{status: {:error, _}} = ctx, _name), do: ctx

  def getwaitingroomusers(%Ctx{} = ctx, name) do
    case room_gid_for(ctx, name) do
      nil ->
        ctx

      gid ->
        account_ids = Enum.map(WaitingRoom.members(gid), & &1.account_id)

        ctx
        |> set_local(:waitingroom_users, account_ids)
        |> set_local(:waitingroom_usercount, length(account_ids))
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
    case PlayerSession.script_apply(session_pid, op) do
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

  @doc """
  The player's first-job lineage root as an atom (rAthena `BaseClass`): a
  Hunter reads `:archer`, a Knight `:swordman`, Novices and Super Novices
  `:novice`.
  """
  @spec base_class(Ctx.t()) :: atom()
  def base_class(%Ctx{game_state: nil}), do: no_player!("base_class/1")
  def base_class(%Ctx{} = ctx), do: ctx |> class() |> JobLineage.base_class()

  @doc """
  The player's job ignoring transcendence and baby variants as an atom
  (rAthena `BaseJob`): a Hunter or Sniper reads `:hunter`, a plain Novice
  `:novice`.
  """
  @spec base_job(Ctx.t()) :: atom()
  def base_job(%Ctx{game_state: nil}), do: no_player!("base_job/1")
  def base_job(%Ctx{} = ctx), do: ctx |> class() |> JobLineage.base_job()

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
  The player's learned level of a skill (rAthena `getskilllv`), `0` when not
  learned. `skill` is a skill id or its catalog name atom; an unknown skill
  returns `0`, matching rAthena's unknown-skill result. Pure read over the
  ctx snapshot.
  """
  @spec getskilllv(Ctx.t(), integer() | atom()) :: non_neg_integer()
  def getskilllv(%Ctx{game_state: nil}, _skill), do: no_player!("getskilllv/2")

  def getskilllv(%Ctx{game_state: gs}, skill) do
    case resolve_skill_id(skill) do
      {:ok, skill_id} -> Learned.learned_level(gs.stats.progression.learned_skills, skill_id)
      {:error, _reason} -> 0
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

  @doc """
  The "eA job number" (mapid) for the attached player's class, or for an
  explicit job atom/id when one is given (rAthena `eaclass`). Returns `-1` for
  an unknown job or a detached context with no class to read.
  """
  @spec eaclass(Ctx.t()) :: integer()
  def eaclass(%Ctx{game_state: nil}), do: -1
  def eaclass(%Ctx{game_state: gs}), do: JobMapid.from_job(gs.stats.progression.job_id)

  @spec eaclass(Ctx.t(), atom() | integer()) :: integer()
  def eaclass(%Ctx{}, job), do: JobMapid.from_job(job)

  @doc """
  The numeric job id for a mapid, resolved against the attached player's sex
  (or male when detached), or against an explicit `sex` (rAthena `roclass`).
  Returns `-1` for an unknown mapid.
  """
  @spec roclass(Ctx.t(), integer()) :: integer()
  def roclass(%Ctx{game_state: nil}, mapid), do: JobMapid.to_job(mapid, 1)
  def roclass(%Ctx{game_state: %{sex: "M"}}, mapid), do: JobMapid.to_job(mapid, 1)
  def roclass(%Ctx{game_state: %{}}, mapid), do: JobMapid.to_job(mapid, 0)

  @spec roclass(Ctx.t(), integer(), integer()) :: integer()
  def roclass(%Ctx{}, mapid, sex), do: JobMapid.to_job(mapid, sex)

  @doc "The player's sex as rAthena's `Sex`: `1` male, `0` female."
  @spec sex(Ctx.t()) :: 0 | 1
  def sex(%Ctx{game_state: nil}), do: no_player!("sex/1")
  def sex(%Ctx{game_state: %{sex: "M"}}), do: 1
  def sex(%Ctx{game_state: %{}}), do: 0

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

  @doc """
  Whether the player has an item with `item_id` equipped, as rAthena's
  `isequipped`: `1` when equipped, `0` otherwise (so transpiled `== 1`/`> 0`
  comparisons work).
  """
  @spec is_equipped(Ctx.t(), integer()) :: 0 | 1
  # credo:disable-for-next-line Credo.Check.Readability.PredicateFunctionNames
  def is_equipped(%Ctx{game_state: nil}, _item_id), do: no_player!("is_equipped/2")

  # credo:disable-for-next-line Credo.Check.Readability.PredicateFunctionNames
  def is_equipped(%Ctx{game_state: gs}, item_id) do
    equipped? =
      gs.inventory
      |> Inventory.equipped_items()
      |> Enum.any?(fn {_index, %InventoryItem{nameid: nameid}} -> nameid == item_id end)

    if equipped?, do: 1, else: 0
  end

  # rAthena `enum equip_index` ordinal -> Aesir equip location. The transpiler
  # resolves `EQI_*` constants to these indices; variables/ints pass through as
  # the same index at runtime.
  @equip_slot_locations %{
    0 => :left_accessory,
    1 => :right_accessory,
    2 => :shoes,
    3 => :garment,
    4 => :head_low,
    5 => :head_mid,
    6 => :head_top,
    7 => :armor,
    8 => :left_hand,
    9 => :right_hand,
    10 => :costume_head_top,
    11 => :costume_head_mid,
    12 => :costume_head_low,
    13 => :costume_garment,
    14 => :ammo,
    15 => :shadow_armor,
    16 => :shadow_weapon,
    17 => :shadow_shield,
    18 => :shadow_shoes,
    19 => :shadow_right_accessory,
    20 => :shadow_left_accessory
  }

  @doc """
  The item id worn in equip slot `slot` (rAthena `getequipid`), or `-1` when
  the slot is empty or `slot` is not a known `EQI_*` index. `slot` is the
  rAthena `equip_index` ordinal. Pure read over the inventory snapshot.
  """
  @spec getequipid(Ctx.t(), integer()) :: integer()
  def getequipid(%Ctx{game_state: nil}, _slot), do: no_player!("getequipid/2")

  def getequipid(%Ctx{game_state: gs}, slot) do
    with location when not is_nil(location) <- Map.get(@equip_slot_locations, slot),
         %InventoryItem{nameid: nameid} <- equipped_in_slot(gs.inventory, location) do
      nameid
    else
      _ -> -1
    end
  end

  @doc """
  The value stored in card slot `card_slot` (`0..3`) of the item worn in equip
  slot `equip_slot` (rAthena `getequipcardid`). Returns `0` when the equipment
  slot is empty or unknown, or when the card slot is outside `0..3`.
  """
  @spec getequipcardid(Ctx.t(), integer(), integer()) :: integer()
  def getequipcardid(%Ctx{game_state: nil}, _equip_slot, _card_slot),
    do: no_player!("getequipcardid/3")

  def getequipcardid(%Ctx{}, _equip_slot, card_slot) when card_slot not in 0..3, do: 0

  def getequipcardid(%Ctx{game_state: gs}, equip_slot, card_slot) do
    with location when not is_nil(location) <- Map.get(@equip_slot_locations, equip_slot),
         %InventoryItem{} = item <- equipped_in_slot(gs.inventory, location) do
      item |> InventoryItem.cards() |> Enum.at(card_slot)
    else
      _ -> 0
    end
  end

  @spec equipped_in_slot(Inventory.t(), atom()) :: InventoryItem.t() | nil
  defp equipped_in_slot(inventory, location) do
    inventory
    |> Inventory.equipped_items()
    |> Enum.find_value(fn {_index, %InventoryItem{equip: equip} = item} ->
      if location in EquipLocation.bitmask_to_location_atoms(equip), do: item
    end)
  end

  # The item worn in `slot` together with its definition, or `nil` when the
  # slot is unknown/empty. Shared by every equip-read buildin below.
  @spec fetch_equipped(Ctx.t(), integer()) :: {InventoryItem.t(), ItemDefinition.t()} | nil
  defp fetch_equipped(%Ctx{game_state: gs}, slot) do
    with location when not is_nil(location) <- Map.get(@equip_slot_locations, slot),
         %InventoryItem{nameid: nameid} = item <- equipped_in_slot(gs.inventory, location),
         {:ok, item_def} <- ItemManagement.get_item_by_id(nameid) do
      {item, item_def}
    else
      _ -> nil
    end
  end

  # The `{inventory_index, item}` worn in `slot`, or `nil` when the slot is
  # unknown or empty. Used by `delequip` to address the session's row.
  @spec equipped_index(Ctx.t(), integer()) :: {non_neg_integer(), InventoryItem.t()} | nil
  defp equipped_index(%Ctx{game_state: gs}, slot) do
    case Map.get(@equip_slot_locations, slot) do
      nil -> nil
      location -> find_equipped_entry(gs.inventory, location)
    end
  end

  @spec find_equipped_entry(Inventory.t(), atom()) ::
          {non_neg_integer(), InventoryItem.t()} | nil
  defp find_equipped_entry(inventory, location) do
    Enum.find_value(Inventory.equipped_items(inventory), fn {index,
                                                             %InventoryItem{equip: equip} = item} ->
      if location in EquipLocation.bitmask_to_location_atoms(equip), do: {index, item}
    end)
  end

  @doc """
  Whether the equip `slot` is occupied (rAthena `getequipisequiped`): `1` when
  an item is worn there, else `0`. `slot` is the rAthena `equip_index` ordinal.
  Pure read over the inventory snapshot.
  """
  @spec getequipisequiped(Ctx.t(), integer()) :: 0 | 1
  def getequipisequiped(%Ctx{game_state: nil}, _slot), do: no_player!("getequipisequiped/2")

  def getequipisequiped(%Ctx{} = ctx, slot) do
    if fetch_equipped(ctx, slot), do: 1, else: 0
  end

  @doc """
  The refine level of the item worn in equip `slot` (rAthena
  `getequiprefinerycnt`), or `0` when the slot is empty or unknown. Pure read
  over the inventory snapshot.
  """
  @spec getequiprefinerycnt(Ctx.t(), integer()) :: non_neg_integer()
  def getequiprefinerycnt(%Ctx{game_state: nil}, _slot), do: no_player!("getequiprefinerycnt/2")

  def getequiprefinerycnt(%Ctx{} = ctx, slot) do
    case fetch_equipped(ctx, slot) do
      {item, _item_def} -> item.refine
      nil -> 0
    end
  end

  @doc """
  The display name of the item worn in equip `slot` (rAthena `getequipname`),
  or `""` when the slot is empty or unknown. Uses the same `name` field as
  `getitemname` for consistency with dialog display. Pure read over the
  inventory snapshot.
  """
  @spec getequipname(Ctx.t(), integer()) :: String.t()
  def getequipname(%Ctx{game_state: nil}, _slot), do: no_player!("getequipname/2")

  def getequipname(%Ctx{} = ctx, slot) do
    case fetch_equipped(ctx, slot) do
      {_item, %ItemDefinition{name: name}} -> name
      nil -> ""
    end
  end

  @doc """
  The display name of an equip slot, given its rAthena `equip_index` ordinal
  (`F_getpositionname`): `0` → "Accessory 1", … Unknown indices read "Unknown".
  Pure, needs no player state.
  """
  @equip_position_names %{
    0 => "Accessory 1",
    1 => "Accessory 2",
    2 => "Shoes",
    3 => "Robe",
    4 => "Head 3",
    5 => "Head 2",
    6 => "Head",
    7 => "Body",
    8 => "Left hand",
    9 => "Right hand",
    10 => "Upper Costume Headgear",
    11 => "Middle Costume Headgear",
    12 => "Lower Costume Headgear",
    13 => "Costume Garment",
    14 => "Arrow/Ammunition",
    15 => "Shadow Armor",
    16 => "Shadow Weapon",
    17 => "Shadow Shield",
    18 => "Shadow Shoes",
    19 => "Shadow Accessory 2",
    20 => "Shadow Accessory 1"
  }

  @spec equip_position_name(Ctx.t(), integer()) :: String.t()
  def equip_position_name(%Ctx{}, index), do: Map.get(@equip_position_names, index, "Unknown")

  @doc """
  The weapon level of the item worn in equip `slot` (rAthena
  `getequipweaponlv`), or `0` when the slot is empty, unknown, or the worn
  item is not a weapon. Pure read over the inventory snapshot.
  """
  @spec getequipweaponlv(Ctx.t(), integer()) :: non_neg_integer()
  def getequipweaponlv(%Ctx{game_state: nil}, _slot), do: no_player!("getequipweaponlv/2")

  def getequipweaponlv(%Ctx{} = ctx, slot) do
    case fetch_equipped(ctx, slot) do
      {_item, %ItemDefinition{type: :weapon, weapon_level: level}} when is_integer(level) -> level
      _ -> 0
    end
  end

  @doc """
  The armor level of the item worn in equip `slot` (rAthena
  `getequiparmorlv`), or `0` when the slot is empty, unknown, or the worn
  item is not an armor. Pure read over the inventory snapshot.
  """
  @spec getequiparmorlv(Ctx.t(), integer()) :: non_neg_integer()
  def getequiparmorlv(%Ctx{game_state: nil}, _slot), do: no_player!("getequiparmorlv/2")

  def getequiparmorlv(%Ctx{} = ctx, slot) do
    case fetch_equipped(ctx, slot) do
      {_item, %ItemDefinition{type: :armor, armor_level: level}} when is_integer(level) -> level
      _ -> 0
    end
  end

  @doc """
  Whether the item worn in equip `slot` can be refined (rAthena
  `getequipisenableref`): `1` when it is a refinable item and not rented,
  else `0`. Pure read over the inventory snapshot.
  """
  @spec getequipisenableref(Ctx.t(), integer()) :: 0 | 1
  def getequipisenableref(%Ctx{game_state: nil}, _slot), do: no_player!("getequipisenableref/2")

  def getequipisenableref(%Ctx{} = ctx, slot) do
    case fetch_equipped(ctx, slot) do
      {%InventoryItem{expire_time: nil}, %ItemDefinition{refineable: true}} -> 1
      _ -> 0
    end
  end

  @doc """
  The success rate, as a `0..100` percent, of the next refine attempt on the
  item worn in equip `slot` (rAthena `getequippercentrefinery`): normal by
  default, or enriched when `enriched != 0`. `0` when the slot is empty,
  unknown, or the item is not currently refinable at its level. Pure read over
  the inventory snapshot + refine tables.
  """
  @spec getequippercentrefinery(Ctx.t(), integer(), 0 | 1) :: 0..100
  def getequippercentrefinery(ctx, slot, enriched \\ 0)

  def getequippercentrefinery(%Ctx{game_state: nil}, _slot, _enriched),
    do: no_player!("getequippercentrefinery/3")

  def getequippercentrefinery(%Ctx{} = ctx, slot, enriched) do
    cost_type = if enriched != 0, do: :enriched, else: :normal

    with {item, item_def} <- fetch_equipped(ctx, slot),
         {:ok, group, item_level} <- RefineDatabase.group_and_level(item_def),
         %{chances: chances} <- RefineDatabase.level_info(group, item_level, item.refine + 1),
         %{rate: rate} <- Map.get(chances, cost_type) do
      div(rate, 100)
    else
      _ -> 0
    end
  end

  @doc """
  A refine cost field of the item worn in equip `slot` (rAthena
  `getequiprefinecost`): `type` selects the cost variant (`:normal`, `:hd`,
  `:enriched`) and `info` the field (`:material_id` the ore nameid,
  `:zeny_cost` the zeny). Returns `-1` for an empty/unknown slot, a variant
  that has no entry at the item's level, an unknown `type`/`info`, or an item
  with no refine entry. Pure read over the inventory snapshot + refine tables.
  """
  @spec getequiprefinecost(Ctx.t(), integer(), atom(), :material_id | :zeny_cost) :: integer()
  def getequiprefinecost(%Ctx{game_state: nil}, _slot, _type, _info),
    do: no_player!("getequiprefinecost/4")

  def getequiprefinecost(%Ctx{} = ctx, slot, type, info) do
    with {item, item_def} <- fetch_equipped(ctx, slot),
         {:ok, group, item_level} <- RefineDatabase.group_and_level(item_def),
         %{chances: chances} <- RefineDatabase.level_info(group, item_level, item.refine + 1),
         chance when not is_nil(chance) <- Map.get(chances, type) do
      case info do
        :material_id -> chance.material_nameid || -1
        :zeny_cost -> chance.price
        _ -> -1
      end
    else
      _ -> -1
    end
  end

  @doc """
  Counts how many of the given item/card ids are currently equipped (rAthena
  `isequippedcnt`): a non-card id counts the worn stack once per equipped
  copy, a card id counts each equipped card slot holding that card (duplicate
  ids are counted once, non-positive ids ignored). Pure read over the
  inventory snapshot; player needed.
  """
  @spec isequippedcnt(Ctx.t(), [integer()]) :: non_neg_integer()
  def isequippedcnt(%Ctx{game_state: nil}, _ids), do: no_player!("isequippedcnt/2")

  def isequippedcnt(%Ctx{game_state: gs}, ids) when is_list(ids) do
    equipped = gs.inventory |> Inventory.equipped_items() |> Map.values()

    ids
    |> Enum.uniq()
    |> Enum.reject(&(&1 <= 0))
    |> Enum.reduce(0, fn id, acc -> acc + equip_count(equipped, id) end)
  end

  defp equip_count(equipped, id) do
    if card_item?(id) do
      equipped
      |> Enum.flat_map(&InventoryItem.cards/1)
      |> Enum.count(&(&1 == id))
    else
      equipped
      |> Enum.filter(&(&1.nameid == id))
      |> Enum.sum_by(& &1.amount)
    end
  end

  @spec card_item?(integer()) :: boolean()
  defp card_item?(id) do
    case ItemManagement.get_item_by_id(id) do
      {:ok, %ItemDefinition{type: :card}} -> true
      _ -> false
    end
  end

  @doc """
  A static field of an item by `type` code (rAthena `getiteminfo`): the
  `ITEMINFO_*` integer field selector. `item` is a nameid or an Aegis/display
  name. Fields Aesir does not model (item max-chance, gender, alias name)
  return `-1`; `ITEMINFO_AEGISNAME` (`18`) returns the Aegis name string.
  Unknown items return `""` for `ITEMINFO_AEGISNAME` and `-1` otherwise; an
  unknown `type` code returns `-1` (both matching rAthena's defaults). A pure
  read over the item database that never raises — no player is required.
  """
  @spec getiteminfo(Ctx.t(), integer() | String.t(), integer()) :: integer() | String.t()
  def getiteminfo(%Ctx{}, item, type) do
    case resolve_item(item) do
      {:ok, %ItemDefinition{} = definition} -> iteminfo_value(definition, type)
      {:error, _} -> iteminfo_missing(type)
    end
  end

  # `getiteminfo` accepts a nameid or an Aegis name string.
  @spec resolve_item(integer() | String.t()) :: {:ok, ItemDefinition.t()} | :error
  defp resolve_item(item) when is_integer(item), do: ItemManagement.get_item_by_id(item)
  defp resolve_item(item) when is_binary(item), do: ItemManagement.get_item_by_aegis(item)

  # rAthena `enum weapon_type` ordinals, mapped from the importer's subtype
  # atoms. `W_2HMACE` (9) is unused and has no atom; ammo/non-weapon subtypes
  # have no `W_*` equivalent and return `-1`.
  @weapon_subtypes %{
    dagger: 1,
    one_handed_sword: 2,
    two_handed_sword: 3,
    one_handed_spear: 4,
    two_handed_spear: 5,
    one_handed_axe: 6,
    two_handed_axe: 7,
    mace: 8,
    staff: 10,
    bow: 11,
    knuckle: 12,
    musical: 13,
    whip: 14,
    book: 15,
    katar: 16,
    revolver: 17,
    rifle: 18,
    gatling: 19,
    shotgun: 20,
    grenade: 21,
    huuma: 22,
    two_handed_staff: 23
  }

  defp weapon_subtype(%ItemDefinition{subtype: subtype}) when is_atom(subtype),
    do: Map.get(@weapon_subtypes, subtype, -1)

  defp weapon_subtype(%ItemDefinition{}), do: -1

  defp iteminfo_fields do
    %{
      0 => & &1.buy,
      1 => & &1.sell,
      2 => &ClientItemType.to_client_type(&1.type),
      3 => fn _ -> -1 end,
      4 => fn _ -> -1 end,
      5 => &EquipLocation.location_atoms_to_bitmask(&1.locations),
      6 => & &1.weight,
      7 => & &1.attack,
      8 => & &1.defense,
      9 => & &1.range,
      10 => & &1.slots,
      11 => & &1.view,
      12 => & &1.equip_level_min,
      # Weapon/armor level read as 0 unless the item is the matching type.
      13 => fn definition ->
        if definition.type == :weapon, do: definition.weapon_level || 0, else: 0
      end,
      14 => fn _ -> -1 end,
      15 => & &1.equip_level_max,
      16 => & &1.magic_attack,
      17 => & &1.id,
      18 => & &1.aegis_name,
      19 => fn definition ->
        if definition.type == :armor, do: definition.armor_level || 0, else: 0
      end,
      20 => &weapon_subtype/1
    }
  end

  defp iteminfo_value(%ItemDefinition{} = definition, type) do
    case Map.get(iteminfo_fields(), type) do
      fun when is_function(fun, 1) -> fun.(definition)
      nil -> -1
    end
  end

  defp iteminfo_missing(18), do: ""
  defp iteminfo_missing(_type), do: -1

  @doc """
  The number `n` with its English ordinal suffix (rAthena `F_GetNumSuffix`):
  `1` -> `"1st"`, `2` -> `"2nd"`, `3` -> `"3rd"`, `4`/`11`/`12`/`13` -> `"th"`.
  A pure helper; the ctx is ignored.
  """
  @spec num_suffix(Ctx.t(), integer()) :: String.t()
  def num_suffix(%Ctx{}, n) when is_integer(n), do: "#{n}#{ordinal_suffix(n)}"

  defp ordinal_suffix(n) when rem(n, 10) == 1 and n != 11, do: "st"
  defp ordinal_suffix(n) when rem(n, 10) == 2 and n != 12, do: "nd"
  defp ordinal_suffix(n) when rem(n, 10) == 3 and n != 13, do: "rd"
  defp ordinal_suffix(_n), do: "th"

  @doc """
  Formats a number with comma thousands separators (rAthena `F_InsertComma`):
  `1000000` -> `"1,000,000"`. Mirrors rAthena's algorithm — commas inserted
  every three characters from the right of the string form, so a leading sign
  counts as a character (`-1000` -> `"-1,000"`). A pure helper; ctx is ignored.
  """
  @spec insert_comma(Ctx.t(), integer() | String.t()) :: String.t()
  def insert_comma(%Ctx{}, value), do: value |> to_string() |> group_thousands()

  defp group_thousands(str) when byte_size(str) <= 3, do: str

  defp group_thousands(str) do
    (String.length(str) - 3)..1//-3
    |> Enum.reduce(str, fn index, acc ->
      {head, tail} = String.split_at(acc, index)
      head <> "," <> tail
    end)
  end

  @doc """
  The char id of the player's marriage partner (rAthena `getpartnerid`), or `0`
  when unmarried. Aesir has no marriage system yet, so `partner_id` is sourced
  once from the Character at spawn and is currently always `0`. Pure read over
  the ctx snapshot.
  """
  @spec getpartnerid(Ctx.t()) :: non_neg_integer()
  def getpartnerid(%Ctx{game_state: nil}), do: no_player!("getpartnerid/1")
  def getpartnerid(%Ctx{game_state: gs}), do: gs.partner_id

  @doc """
  A renewal build-flag check (rAthena `checkre`): `1` when the feature is
  compiled in, else `0`. Aesir is renewal-only, so every renewal feature
  (`0` RENEWAL / `1` cast / `2` drop / `3` exp / `4` level-damage / `5` ASPD)
  is on and returns `1`; any unknown type returns `0`, matching rAthena. Pure
  read; the ctx is ignored.
  """
  @spec checkre(Ctx.t(), integer()) :: 0 | 1
  def checkre(%Ctx{}, type) when type in 0..5, do: 1
  def checkre(%Ctx{}, _type), do: 0

  @doc """
  A VIP status query (rAthena `vip_status`): active flag / expiry timestamp /
  remaining seconds by `type`. Aesir has no VIP tier, so this mirrors
  rAthena's non-VIP build and always returns `0` for every type. Pure read;
  the ctx is ignored.
  """
  @spec vip_status(Ctx.t(), integer()) :: 0
  def vip_status(%Ctx{}, _type), do: 0

  @doc """
  The current time as an integer tick (rAthena `gettimetick`), by `type`:
  `2` the Unix epoch timestamp in seconds, `1` the seconds elapsed since
  local midnight (`0..86_399`, server local time as everywhere else),
  `0` (and any other type, matching rAthena's default case) the system
  tick — milliseconds since the VM started, monotonic, meant only for
  elapsed-time math. Pure read; the ctx is ignored.
  """
  @spec gettimetick(Ctx.t(), integer()) :: integer()
  def gettimetick(%Ctx{}, 2), do: System.os_time(:second)

  def gettimetick(%Ctx{}, 1) do
    %NaiveDateTime{hour: hour, minute: minute, second: second} = NaiveDateTime.local_now()
    hour * 3600 + minute * 60 + second
  end

  def gettimetick(%Ctx{}, _type) do
    vm_start = System.convert_time_unit(:erlang.system_info(:start_time), :native, :millisecond)
    System.monotonic_time(:millisecond) - vm_start
  end

  @doc """
  The unit id (gid) of the NPC running the script (rAthena `getnpcid`, type-0
  form). A pure read that does not raise on a detached ctx — the NPC identity
  is not player state — and returns `0` when there is no `npc_gid` (e.g. an
  item script), matching rAthena's "no NPC attached" result.
  """
  @spec getnpcid(Ctx.t()) :: non_neg_integer()
  def getnpcid(%Ctx{npc_gid: nil}), do: 0
  def getnpcid(%Ctx{npc_gid: gid}), do: gid

  @doc """
  The unit id (gid) of the first NPC registered under `name`
  (rAthena `getnpcid(0,"name")`), or `0` when the name resolves to no
  placement.
  """
  @spec getnpcid(Ctx.t(), String.t()) :: non_neg_integer()
  def getnpcid(%Ctx{}, name) do
    case NpcRegistry.by_name(name) do
      [{_module, placement} | _rest] -> NpcRegistry.entity_id(placement)
      [] -> 0
    end
  end

  @doc """
  The account id of the player attached to the script, or `0` when none is
  (rAthena `playerattached`). A pure read that does not raise on a detached
  ctx — its whole purpose is to test for attachment, so an event/timer ctx
  returns `0` rather than crashing.
  """
  @spec playerattached(Ctx.t()) :: non_neg_integer()
  def playerattached(%Ctx{account_id: nil}), do: 0
  def playerattached(%Ctx{account_id: account_id}), do: account_id

  @doc """
  An id of the attached player by `type` (rAthena `getcharid`): `0` the char
  id, `1` the party id (`0` when partyless), `2` the guild id (no guild
  system yet, always `0`), `3` the account id. Any other type returns `0`,
  matching rAthena. Pure read over the ctx snapshot.
  """
  @spec getcharid(Ctx.t(), integer()) :: non_neg_integer()
  def getcharid(%Ctx{game_state: nil}, _type), do: no_player!("getcharid/2")
  def getcharid(%Ctx{char_id: char_id}, 0), do: char_id
  def getcharid(%Ctx{game_state: gs}, 1), do: gs.party_id
  def getcharid(%Ctx{account_id: account_id}, 3), do: account_id
  def getcharid(%Ctx{}, _type), do: 0

  @doc """
  Whether the attached player is the leader of their party (rAthena
  `is_party_leader`); with a `party_id`, whether they lead that party. Returns
  `1` (leader) or `0` (not leader / no party / unknown party). Pure read that
  consults the live party entry; a detached ctx raises.
  """
  @spec party_leader?(Ctx.t()) :: 0 | 1
  def party_leader?(%Ctx{game_state: nil}), do: no_player!("party_leader?/1")

  def party_leader?(%Ctx{game_state: gs} = ctx), do: party_leader?(ctx, gs.party_id)

  @spec party_leader?(Ctx.t(), non_neg_integer()) :: 0 | 1
  def party_leader?(%Ctx{game_state: nil}, _party_id), do: no_player!("party_leader?/2")

  def party_leader?(%Ctx{game_state: gs}, party_id) do
    case PartyManager.get(party_id) do
      {:ok, %PartyState{leader_char_id: leader}} -> if leader == gs.character_id, do: 1, else: 0
      {:error, _reason} -> 0
    end
  end

  @doc """
  A field of the running NPC's info as a string (rAthena `strnpcinfo`):
  `0` the full name including the hidden `#`-fragment, `1` the visible name,
  `2` the hidden fragment, `3` the unique name, `4` the map name; the file
  path (`5`) is not modelled and returns an empty string. The hidden fragment
  exists only when the placement's `unique_name` is the rAthena full-name form
  `<visible>#<hidden>` (what the transpiler emits for duplicates); otherwise
  `0` falls back to the visible name and `2` is empty. A pure read that does
  not raise on a detached ctx; an absent or unresolvable `npc_gid` returns an
  empty string, matching rAthena's "no NPC" result.
  """
  @spec strnpcinfo(Ctx.t(), integer()) :: String.t()
  def strnpcinfo(%Ctx{npc_gid: nil}, _type), do: ""

  def strnpcinfo(%Ctx{npc_gid: gid}, type) do
    case NpcRegistry.module_for_unit(gid) do
      {:ok, {_module, placement}} -> npc_info(placement, type)
      :error -> ""
    end
  end

  defp npc_info(%{name: name} = placement, 0) do
    case npc_hidden_fragment(placement) do
      "" -> name
      hidden -> name <> "#" <> hidden
    end
  end

  defp npc_info(%{name: name}, 1), do: name
  defp npc_info(%{} = placement, 2), do: npc_hidden_fragment(placement)
  defp npc_info(%{unique_name: unique_name}, 3), do: unique_name
  defp npc_info(%{map: map}, 4), do: map
  defp npc_info(_placement, _type), do: ""

  defp npc_hidden_fragment(%{name: name, unique_name: unique_name}) do
    case String.split(unique_name, "#", parts: 2) do
      [^name, hidden] -> hidden
      _other -> ""
    end
  end

  @doc """
  Whether the player can carry every `{item_id, amount}` in `items` at once
  (rAthena `checkweight`): `1` when the combined weight fits under the carry
  limit and there are enough free inventory slots for the new item types,
  else `0`.

  The slot check is an approximation — it reserves one slot per distinct item
  type not already held — rather than rAthena's exact per-stack accounting;
  the weight check is exact. Pure read over the ctx snapshot.
  """
  @spec checkweight(Ctx.t(), [{integer(), non_neg_integer()}]) :: 0 | 1
  def checkweight(%Ctx{game_state: nil}, _items), do: no_player!("checkweight/2")

  def checkweight(%Ctx{game_state: gs}, items) do
    added_weight =
      Enum.reduce(items, 0, fn {item_id, amount}, acc -> acc + item_weight(item_id) * amount end)

    weight_ok? = not Weight.would_exceed?(gs.inventory, gs.stats, added_weight)

    new_types =
      items
      |> Enum.map(&elem(&1, 0))
      |> Enum.uniq()
      |> Enum.count(fn item_id -> Inventory.held_amount(gs.inventory, item_id) == 0 end)

    slots_ok? = Inventory.capacity() - map_size(gs.inventory) >= new_types

    if weight_ok? and slots_ok?, do: 1, else: 0
  end

  @spec item_weight(integer()) :: non_neg_integer()
  defp item_weight(item_id) do
    case ItemManagement.get_item_by_id(item_id) do
      {:ok, %ItemDefinition{weight: weight}} -> weight
      {:error, _reason} -> 0
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
    potion_research_rate = 5 * getskilllv(ctx, :am_learningpotion)

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
    new_hp = clamp(current.hp + hp_delta, max_hp)
    new_sp = clamp(sp_fun.(current.sp, max_sp), max_sp)

    new_state = %{current | hp: new_hp, sp: new_sp}
    game_state = %{ctx.game_state | stats: %{stats | current_state: new_state}}

    sync_hp(ctx, current.hp, new_hp)
    sync_sp(ctx, current.sp, new_sp)

    %{ctx | game_state: game_state}
  end

  # Scales the healed HP delta (never SP) by the target's `received_heal_rate`
  # (SC_INCHEALRATE) before it is applied (rAthena `pc.cpp:10719-10720`). Only
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
