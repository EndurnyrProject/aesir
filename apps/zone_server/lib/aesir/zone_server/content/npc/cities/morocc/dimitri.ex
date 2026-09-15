defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.Dimitri do
  @moduledoc """
  Shares observations about Morocc’s desert, recovery, and wildlife.

  ## Behavior

  - Offers observations about desert sand, potions, or Milk from Peco Peco Eggs.

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
        y: 141,
        dir: 4,
        sprite: 49,
        name: "Dimitri",
        scope: :shared,
        unique_name: "Dimitri#moc"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Dimitri]")
      |> mes(
        "The desert of Morocc has the highest average temperature in Midgard. You might as well think twice before you sit on the sand in the middle of the desert, cause your ass will be toasted."
      )
      |> next()
      |> select(["About the desert sands", "About the remedy for Fatigue", "End Conversation"])

    case choice do
      1 ->
        ctx
        |> mes("[Dimitri]")
        |> mes("......What I mean is that...")
        |> mes("It seems like it should be all burnt, but it's not!")
        |> next()
        |> mes("[Dimitri]")
        |> mes(
          "You can sit down and take a rest whenever you need to and your ass won't burn. I guess the Morocc sand doesn't conduct heat as much as it should."
        )
        |> next()
        |> mes("[Dimitri]")
        |> mes("That's why everyone could recover the HP and SP in the middle of desert.")
        |> next()
        |> mes("[Dimitri]")
        |> mes(
          "Now I come to think of it, maybe the reason why Morocc has exceptionally high average temperature is because that Satan is sealed within."
        )
        |> close()

      2 ->
        ctx
        |> mes("[Dimitri]")
        |> mes("Recovery!")
        |> mes("That's what the potions are for!")
        |> mes(
          "Red Potions have become steadily popular since they're so affordable, even though they only recover a little bit of HP."
        )
        |> next()
        |> mes("[Dimitri]")
        |> mes(
          "Try this bottle of ice-cold potion when you go into the Oasis around the Pyramid..."
        )
        |> mes("Yeah.. you want this bad.. but the situation's not good...")
        |> close()

      3 ->
        ctx
        |> mes("[Dimitri]")
        |> mes("Sometimes 'Milk' comes out of 'PecoPeco's Egg.' Now..")
        |> mes("I'm not sure how the cow's milk comes out of some bird's egg...")
        |> next()
        |> mes("[Dimitri]")
        |> mes("I may not be a man of science, but how is that even possible?.")
        |> mes(
          "I mean, did the Milk come prepackaged with the egg, or did it get in there somehow?.."
        )
        |> mes("Oh, whatever.. It's just not the time for this.")
        |> close()

      _ ->
        ctx
    end
  end
end
