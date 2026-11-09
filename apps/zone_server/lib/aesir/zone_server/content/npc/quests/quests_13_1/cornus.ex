defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Cornus do
  @moduledoc """
  Cornus, the sensitive pet in the expedition camp that Taab watches over.

  ## Behavior

  - Reveals itself when enabled, and hides itself when disabled.
  - Describes its mood to a player who touches it, which is also what a click does.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mid_camp",
        x: 162,
        y: 306,
        dir: 3,
        sprite: 1992,
        name: "Cornus",
        scope: :shared,
        unique_name: "Cornus#alba03",
        trigger: {5, 5}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @npc "Cornus#alba03"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: enablenpc(ctx, @npc)

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx), do: enablenpc(ctx, @npc)
  def on_event("OnDisable", ctx), do: disablenpc(ctx, @npc)
  def on_event("OnTouch", ctx), do: pet_mood(ctx)

  defp pet_mood(ctx) do
    ctx
    |> mes("[Taab]")
    |> mes("Oh, please don't get")
    |> mes("too close to it or try to")
    |> mes("feed something strange.")
    |> mes("It's pretty sensitive...")
    |> close()
  end
end
