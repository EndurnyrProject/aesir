defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.SoldierMorocc do
  @moduledoc """
  Blocks access to a restricted area in Morocc.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc",
        x: 150,
        y: 120,
        dir: 5,
        sprite: 707,
        name: "Soldier - Morocc",
        scope: :shared,
        unique_name: "MocSoldier",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx), do: warn_player(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: warn_player(ctx)

  defp warn_player(ctx) do
    ctx
    |> mes("[Morocc Soldier]")
    |> mes("Hey, you! Stop there.")
    |> next()
    |> mes("[Morocc Soldier]")
    |> mes("This is a restricted area. You can't come any further!")
    |> close()
  end
end
