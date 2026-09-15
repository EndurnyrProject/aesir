defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.RekenberGuard46125 do
  @moduledoc """
  Guards a restricted Regenschirm laboratory corridor.

  ## Behavior

  - Offers a terse exchange to disguised visitors.
  - Warps undisguised visitors out of the restricted area.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 46,
        y: 125,
        dir: 3,
        sprite: 867,
        name: "Rekenber Guard",
        scope: :shared,
        unique_name: "Rekenber Guard#li03",
        trigger: {5, 5}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx), do: handle_touch(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp handle_touch(ctx) do
    if Rathena.truthy?(is_equipped(ctx, 2241)) and Rathena.truthy?(is_equipped(ctx, 2243)) do
      {ctx, choice} =
        ctx
        |> mes("[Rekenber Guard]")
        |> mes("......................")
        |> next()
        |> select(["Nice day, huh?", "Cancel"])

      respond_to_guard(ctx, choice)
    else
      ctx
      |> mes("[Rekenber Guard]")
      |> mes("...!")
      |> emotion(:surprise)
      |> close()
      |> warp("lhz_in01", 33, 224)
    end
  end

  defp respond_to_guard(ctx, 1) do
    ctx
    |> mes("[Rekenber Guard]")
    |> mes("...")
    |> emotion(:fret)
    |> close()
  end

  defp respond_to_guard(ctx, _choice) do
    ctx
    |> mes("[Rekenber Guard]")
    |> mes("...")
    |> close()
  end
end
