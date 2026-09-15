defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.UncleMorocc do
  @moduledoc """
  Explains Morocc’s desert and reflects on the city’s destruction.

  ## Behavior

  - Offers information about desert vegetation and mutated plants.

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
        map: "moc_ruins",
        x: 173,
        y: 70,
        dir: 4,
        sprite: 48,
        name: "Uncle Morocc",
        scope: :shared,
        unique_name: "Uncle Morocc#moc"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Phlanette]")
      |> mes("Morocc is located in an extremely dry region, surrounded by desert.")
      |> mes("No place in the world is as hot as Morocc.")
      |> next()
      |> mes("[Phlanette]")
      |> mes(
        "I have a hunch that this hot and dry climate in Morocc is because of that Satan sealed deeper underground for so long."
      )
      |> next()
      |> select(["Tell me about the desert.", "Quit Conversation"])

    case choice do
      1 ->
        ctx
        |> mes("[Phlanette]")
        |> mes("Um.. I'll briefly tell ya about the desert if you want to know.")
        |> mes(
          "Due to low annual rainfall, low humidity and high evaporation rate, little vegetation can be found in the desert."
        )
        |> next()
        |> mes("[Phlanette]")
        |> mes(
          "Nonetheless, there are a few hardy plants that can survive and grow in the desert."
        )
        |> next()
        |> mes("[Phlanette]")
        |> mes(
          "Unfortunately some of those plants growing around Morocc have been mutated into monsters."
        )
        |> mes("One of those is Muka, the mutated cactus..")
        |> next()
        |> mes("[Phlanette]")
        |> mes(
          "However, now that the Satan has revived, no one's sure of what changes would be made in the life cycles of Morocc."
        )
        |> close()

      2 ->
        ctx
        |> mes("[Phlanette]")
        |> mes("Here and there!")
        |> mes("Sand everywhere...")
        |> mes("Oh, I curse you, the desert of Morocc!!")
        |> mes("Damn you!")
        |> next()
        |> mes("[Phlanette]")
        |> mes("But our of all this hatred, I didn't want it to be completely destroyed...")
        |> next()
        |> mes("[Phlanette]")
        |> mes("How come it's never possible to know its value while it's still around?")
        |> close()

      _ ->
        ctx
    end
  end
end
