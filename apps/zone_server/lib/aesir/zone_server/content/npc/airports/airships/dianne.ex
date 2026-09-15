defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.Dianne do
  @moduledoc """
  Wonders why the international airship's captain is a reindeer.

  ## Behavior

  - Cries when a passenger enters her nearby trigger area.

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
        x: 83,
        y: 61,
        dir: 2,
        sprite: 72,
        name: "Dianne",
        scope: :shared,
        unique_name: "Dianne#01airplane_01",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx), do: emotion(ctx, :cry)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Dianne]")
    |> mes("It's so weird!")
    |> mes("I went to visit the")
    |> mes("Airship Captain and")
    |> mes("all I saw was this")
    |> mes("weird reindeer. Oh!")
    |> mes("Do you think that...")
    |> close()
  end
end
