defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Hillsrion do
  @moduledoc """
  Hillsrion, the horned pet grazing in the expedition camp.

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
        x: 152,
        y: 316,
        dir: 3,
        sprite: 1989,
        name: "Hillsrion",
        scope: :shared,
        unique_name: "Hillsrion#alba01",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @npc "Hillsrion#alba01"

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
    |> mes("It is hissing in a low voice.")
    |> mes("Sometimes it purrs, too.")
    |> mes("It must be in a happy mood.")
    |> close()
  end
end
