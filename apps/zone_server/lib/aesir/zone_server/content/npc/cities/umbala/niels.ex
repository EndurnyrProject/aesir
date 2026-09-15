defmodule Aesir.ZoneServer.Content.Npc.Cities.Umbala.Niels do
  @moduledoc """
  Challenges adventurers to discover a hidden place near Comodo for themselves.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - Fusion Dev Team
    - Muad Dib
    - Darkchild

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "cmd_in01",
        x: 164,
        y: 115,
        dir: 1,
        sprite: 731,
        name: "Niels",
        scope: :shared,
        unique_name: "Niels#um"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Niels]")
    |> mes("Hmm? What's that look for?")
    |> mes("Ah~ You must of heard the rumors")
    |> mes("of me finding some kind of")
    |> mes("treasure. Yeah, that's understandable...")
    |> next()
    |> mes("[Niels]")
    |> mes("Well, those rumors of me stumbling")
    |> mes("on some wonderful treasure is")
    |> mes("just the result of overactive")
    |> mes("imaginations. All I've found")
    |> mes("was a little something to add")
    |> mes("to my collection.")
    |> next()
    |> mes("[Niels]")
    |> mes("But...since I've proven to myself")
    |> mes("that 'it' actually exists by")
    |> mes("seeing it with my own eyes,")
    |> mes("to me, what I've obtained is a")
    |> mes("valuable treasure.")
    |> next()
    |> mes("[Niels]")
    |> mes("This village of Comodo!")
    |> mes("Don't you think the caves are too")
    |> mes("small and narrow for some reason?")
    |> next()
    |> mes("[Niels]")
    |> mes("So I was thinking about it...")
    |> mes("And I came to the conclusion that")
    |> mes("there should be something hidden")
    |> mes("inside the cave...")
    |> next()
    |> mes("[Niels]")
    |> mes("And then!")
    |> mes("I finally found it.")
    |> mes("The patch to 'the place'")
    |> mes("that no one has ever found!")
    |> next()
    |> mes("[Niels]")
    |> mes("................")
    |> next()
    |> mes("[Niels]")
    |> mes(".......Hm?")
    |> next()
    |> mes("[Niels]")
    |> mes("I was expecting a spectacular and")
    |> mes("rather dramatic sound effect")
    |> mes("for my declaration!")
    |> mes("Eh, oh well...")
    |> emotion(:scratch)
    |> next()
    |> mes("[Niels]")
    |> mes("Well, in the spirit of discovery,")
    |> mes("don't ever think of asking me")
    |> mes("about directions to 'the place'")
    |> mes("or about what is in 'the place.'")
    |> mes("I wouldn't want to spoil the")
    |> mes("surprise.")
    |> next()
    |> mes("[Niels]")
    |> mes("If you're a real adventurer,")
    |> mes("I expect you to scream at the")
    |> mes("top of your lungs...")
    |> next()
    |> mes("[Niels]")
    |> mes("'Ahhhh! I need to know what it")
    |> mes("is!!' Kick the door open and run")
    |> mes("like hell to find this place on")
    |> mes("your own!!")
    |> next()
    |> mes("[Niels]")
    |> mes("Now! Hurry and seek this place")
    |> mes("out! Will this place be a totally")
    |> mes("new world, or will it be a trap")
    |> mes("to hell?! Go forth, meet your")
    |> mes("destiny, adventurer!")
    |> close()
  end
end
