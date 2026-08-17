defmodule Aesir.ZoneServer.Script.Dsl.Visuals do
  @moduledoc """
  Appearance and client-effect buildins for the script DSL: look reads/writes,
  special effects, viewpoint markers, quest-info icons, cutins, sound effects,
  client navigation, NPC emotes, and full unequip.

  Imported into scripts via the `Aesir.ZoneServer.Script.Dsl` facade.
  """

  import Aesir.ZoneServer.Script.Dsl.Internal,
    only: [apply_op: 2, no_player!: 1, clamp: 2]

  require Logger

  alias Aesir.Net.Cutin
  alias Aesir.Net.NavigateTo
  alias Aesir.Net.SoundEffect
  alias Aesir.Net.Viewpoint
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Npc.QuestInfo, as: NpcQuestInfo
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Emote
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.SpecialEffect

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
  packet `ZC_COMPASS`). `type` is the action (`0` display the mark for 15
  seconds / `1` display the mark until dead or teleported / `2` remove the
  mark), `x`/`y` the cell, `id` the marker slot, and `color` a `0xRRGGBB`
  value.

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
  Plays a one-shot sound effect for every player in view range of the origin
  unit (rAthena `soundeffectall`, area-around form — the trailing map-name and
  bounding-box arguments are dropped, so the map-wide and sub-area variants are
  approximated by the local broadcast). `name` is the `.wav` filename; `type`
  selects the playback source (`0` = `data/wav`).

  The origin is the invoking player when one is attached, otherwise the NPC
  running the script, matching rAthena's rid-then-oid fallback. Purely cosmetic,
  so the context is returned unchanged and a detached ctx with no origin (no
  player and no `npc_gid`) is a silent no-op — a missing sound must never abort
  the surrounding script.
  """
  @spec soundeffectall(Ctx.t(), String.t(), non_neg_integer()) :: Ctx.t()
  def soundeffectall(%Ctx{status: {:error, _}} = ctx, _name, _type), do: ctx

  def soundeffectall(%Ctx{} = ctx, name, type) do
    packet = %SoundEffect{name: name, type: type}

    case origin_unit(ctx) do
      {:ok, unit_type, unit_id} -> broadcast_area(unit_type, unit_id, packet)
      :error -> :ok
    end

    ctx
  end

  defp origin_unit(%Ctx{char_id: char_id}) when is_integer(char_id), do: {:ok, :player, char_id}
  defp origin_unit(%Ctx{npc_gid: gid}) when is_integer(gid), do: {:ok, :npc, gid}
  defp origin_unit(%Ctx{}), do: :error

  defp broadcast_area(unit_type, unit_id, packet) do
    case SpatialIndex.get_unit_position(unit_type, unit_id) do
      {:ok, {x, y, map_name}} ->
        Broadcast.to_in_range(map_name, x, y, Config.view_range(), packet, [])

      {:error, :not_found} ->
        :ok
    end
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

  @doc """
  Unequips every item the invoking player has equipped (rAthena `nude`) through
  the session seam, sending each takeoff ack, recomputing stats, and
  broadcasting the appearance changes. Returns the context unchanged when
  nothing is equipped. Halts `:no_player` on a detached ctx.
  """
  @spec nude(Ctx.t()) :: Ctx.t()
  def nude(%Ctx{status: {:error, _}} = ctx), do: ctx
  def nude(%Ctx{} = ctx), do: apply_op(ctx, {:nude})
end
