defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.OfficerGuo do
  @moduledoc """
  Shares Officer Guo's remarks with visitors to Lighthalzen.

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
        map: "lhz_in02",
        x: 147,
        y: 222,
        dir: 3,
        sprite: 85,
        name: "Officer Guo",
        scope: :shared,
        unique_name: "off_guo"
      },
      %{
        map: "lhz_in02",
        x: 142,
        y: 222,
        dir: 6,
        sprite: 870,
        name: "Suspect",
        scope: :shared,
        unique_name: "Suspect#6"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Officer Guo]")
    |> mes("Tell me...!")
    |> mes("TELL ME...!!")
    |> mes("Admit you did it!!")
    |> next()
    |> mes("[Suspect]")
    |> mes("Damn it!")
    |> mes("I keep telling")
    |> mes("you I'm not guilty!")
    |> next()
    |> mes("[Officer Guo]")
    |> mes("^333333*Sigh...*^000000")
    |> next()
    |> mes("[Suspect]")
    |> mes("You're wasting your")
    |> mes("time. Just let me go.")
    |> next()
    |> mes("[Officer Guo]")
    |> mes("So...")
    |> mes("How's your mother?")
    |> next()
    |> mes("[Suspect]")
    |> mes("That's none of")
    |> mes("your business!")
    |> mes("She's fine, I guess.")
    |> next()
    |> mes("[Officer Guo]")
    |> mes("When was the last")
    |> mes("time you've seen her?")
    |> next()
    |> mes("[Suspect]")
    |> mes("I just told you,")
    |> mes("that's none of")
    |> mes("your business...!")
    |> next()
    |> mes("[Officer Guo]")
    |> mes("You know, mothers")
    |> mes("throughout the animal")
    |> mes("kingdom instinctively")
    |> mes("care for their young.")
    |> mes("Humans are no exception.")
    |> mes("Yours must be worried to death.")
    |> next()
    |> mes("[Suspect]")
    |> mes("...")
    |> mes("Man...")
    |> mes("You're starting")
    |> mes("to weird me out.")
    |> next()
    |> mes("[Officer Guo]")
    |> mes("Funny thing about humans,")
    |> mes("though. It seems to be their")
    |> mes("nature to lie, even when they")
    |> mes("know they'll be caught. But")
    |> mes("like all animals, they")
    |> mes("instinctively fear pain...")
    |> next()
    |> mes("[Suspect]")
    |> mes("N-no, no...")
    |> mes("You gotta be...")
    |> mes("You're bluffing.")
    |> mes("Right?")
    |> next()
    |> mes("[Officer Guo]")
    |> mes("NO.")
    |> mes("You're bluffing.")
    |> mes("Tell me...!")
    |> mes("TELL ME...!!")
    |> mes("Admit you did it!!")
    |> close()
  end
end
