defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.AssassinBoy do
  @moduledoc """
  Shares rumors and information about the Assassin clan.

  ## Behavior

  - Offers rumors about Assassin training, the clan’s location, and its combat role.

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
        x: 143,
        y: 43,
        dir: 4,
        sprite: 118,
        name: "Assassin Boy",
        scope: :shared,
        unique_name: "Assassin Boy#moc"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Slayer Kid]")
      |> mes(
        "Unbeatable in man-to-man fights, Assassins always overcome their enemies! Erm, always overcome their enemies without a trace."
      )
      |> next()
      |> mes("[Slayer Kid]")
      |> mes("But what did they do when this destruction happened in Morocc!!!")
      |> next()
      |> select(["?????", "Where I can find the Assassin clan?", "End Conversation"])

    case choice do
      1 ->
        ctx
        |> mes("[Slayer Kid]")
        |> mes("I hear Assassins practice killing people, quietly and stealthfully..")
        |> next()
        |> mes("[Slayer Kid]")
        |> mes(
          "I left home three years ago, and have been searching for their secret base ever since..."
        )
        |> mes("Are they really that invisible?!")
        |> next()
        |> mes("[Slayer Kid]")
        |> mes("Well.. Maybe it'd too late now..")
        |> mes("Now that the whole town's destroyed... I don't even care what happens next...")
        |> close()

      2 ->
        ctx
        |> mes("[Slayer Kid]")
        |> mes("You know what...")
        |> mes("It seemed to be impossible to find.")
        |> next()
        |> mes("[Slayer Kid]")
        |> mes(
          "Well, I hear that if you leave this town and go 2 maps east, and then 2 maps South, you should be able to find it.."
        )
        |> next()
        |> mes("[Slayer Kid]")
        |> mes(
          "The 'Mirage Tower,' the head building of Sograt Desert, is supposed to appear in this awesome sandstorm! But, I still haven't found it."
        )
        |> next()
        |> mes("[Slayer Kid]")
        |> mes(
          "If you find them, and the clan master thinks you're qualified, you can become an Assassin! Or, at least, I think.."
        )
        |> next()
        |> mes("[Slayer Kid]")
        |> mes(
          "And I hear the coolest Assassin of them all is the Assassin Cross! But, that's even a bigger mystery~ You won't be able to see them unless you're a great thief!"
        )
        |> next()
        |> mes("[Slayer Kid]")
        |> mes("But then... What the hell were they doing when Morocc was destroyed?!!!")
        |> close()

      3 ->
        ctx
        |> mes("[Slayer Kid]")
        |> mes(
          "Assassin is one of the advanced jobs for Thief, and specializes in fighting with Neutral and Poison property attacks."
        )
        |> next()
        |> mes("[Slayer Kid]")
        |> mes(
          "They're also very sneaky! I hear that they're able to cloak so that no one can see them!"
        )
        |> next()
        |> mes("[Slayer Kid]")
        |> mes("But then... What the hell were they doing when Morocc was destroyed?!!!")
        |> close()

      _ ->
        ctx
    end
  end
end
