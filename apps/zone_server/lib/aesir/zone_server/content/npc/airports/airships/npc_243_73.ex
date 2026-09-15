defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.Npc24373 do
  @moduledoc """
  Controls the international airship's active exits.

  ## Behavior

  - Warps passengers to Rachel, Izlude, or Juno according to the current stop.
  - Shows or hides both exit portals in response to route events.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "airplane_01",
        x: 243,
        y: 73,
        dir: 0,
        sprite: 45,
        name: "",
        scope: :shared,
        unique_name: "#AirshipWarp-3",
        trigger: {1, 1}
      },
      %{
        map: "airplane_01",
        x: 243,
        y: 29,
        dir: 0,
        sprite: 45,
        name: "",
        scope: :shared,
        unique_name: "#AirshipWarp-4",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    case get_server_temp_var(ctx, "airplanelocation2", 0) do
      0 -> warp(ctx, "ra_fild12", 292, 204)
      1 -> warp_to_izlude(ctx)
      2 -> warp(ctx, "yuno", 12, 261)
      _ -> ctx
    end
  end

  def on_event("OnInit", ctx), do: ctx
  def on_event("OnHide", ctx), do: ctx |> specialeffect(:bash) |> disablenpc()
  def on_event("OnUnhide", ctx), do: ctx |> enablenpc() |> specialeffect(:summonslave)

  defp warp_to_izlude(ctx) do
    if Rathena.truthy?(checkre(ctx, 0)) do
      warp(ctx, "izlude", 200, 73)
    else
      warp(ctx, "izlude", 200, 56)
    end
  end
end
