defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.WindmillOwnerSHelper do
  @moduledoc """
  Cutz comments on his work and Cezu’s delivery.

  ## Behavior

  - Changes his greeting before, during, and after the delivery pickup.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lighthalzen",
        x: 366,
        y: 289,
        dir: 2,
        sprite: 97,
        name: "Windmill Owner's Helper",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    delivery_stage = get_char_var(ctx, :KHToastGirlEnd, 0)

    cond do
      delivery_stage < 1 ->
        ctx
        |> mes("[Cutz]")
        |> mes("Man, why are we")
        |> mes("always so busy?")
        |> mes("Why does Mills have")
        |> mes("to work me to the bone?")
        |> mes("Eh, it's a living, I suppose...")
        |> close()

      delivery_stage >= 2 ->
        ctx
        |> mes("[Cutz]")
        |> mes("Wh-what makes you")
        |> mes("think I'm goofing off,")
        |> mes("Mills? L-look, look,")
        |> mes("my hands are moving,")
        |> mes("I'm busy, I'm working!")
        |> close()

      true ->
        ctx
        |> mes("[Cutz]")
        |> mes("Hey, you're from")
        |> mes("Cezu's toast stand,")
        |> mes("right? How is cute")
        |> mes("little Cezu doing?")
        |> close()
    end
  end
end
