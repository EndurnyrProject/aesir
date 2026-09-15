defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.Npc do
  @moduledoc """
  Controls the domestic airship's active exits.

  ## Behavior

  - Warps passengers to Juno, Einbroch, Lighthalzen, or Hugel according to the current stop.
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
        map: "airplane",
        x: 243,
        y: 73,
        dir: 0,
        sprite: 45,
        name: "",
        scope: :shared,
        unique_name: "#AirshipWarp-1",
        trigger: {1, 1}
      },
      %{
        map: "airplane",
        x: 243,
        y: 29,
        dir: 0,
        sprite: 45,
        name: "",
        scope: :shared,
        unique_name: "#AirshipWarp-2",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: ctx
  def on_event("OnHide", ctx), do: ctx |> specialeffect(:bash) |> disablenpc()
  def on_event("OnUnhide", ctx), do: ctx |> enablenpc() |> specialeffect(:summonslave)

  def on_event("OnTouch", ctx) do
    case get_server_temp_var(ctx, "airplanelocation", 0) do
      0 -> warp(ctx, "yuno", 92, 260)
      1 -> warp(ctx, "einbroch", 92, 278)
      2 -> warp(ctx, "lighthalzen", 302, 75)
      3 -> warp(ctx, "hugel", 181, 146)
      _ -> ctx
    end
  end
end
