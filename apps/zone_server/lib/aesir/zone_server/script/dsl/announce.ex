defmodule Aesir.ZoneServer.Script.Dsl.Announce do
  @moduledoc """
  Broadcast/announcement buildins for the script DSL: global, map, area, and
  self-scoped announces, raw broadcasts, the green `dispbottom` chat line, and
  server-log messages. Delivery is a pure side effect — no player-state
  mutation and no session round-trip.

  Imported into scripts via the `Aesir.ZoneServer.Script.Dsl` facade.
  """

  require Logger

  alias Aesir.ZoneServer.Announcement
  alias Aesir.ZoneServer.Announcement.Flags
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Script.Ctx

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

  @doc """
  Broadcasts `text` globally with an explicit `color`, skipping flag decoding.
  Not a script buildin — a seam for other DSL domains (item-group grant
  announces) that previously reached the announce plumbing directly.
  """
  @spec announce_all(String.t(), non_neg_integer()) :: :ok
  def announce_all(text, color) do
    Announcement.to_all(build_opts(text, color, :all))
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
end
