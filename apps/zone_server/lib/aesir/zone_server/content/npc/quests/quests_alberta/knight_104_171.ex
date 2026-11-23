defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.Knight104171 do
  @moduledoc """
  Squall describes the Security Knights’ failed mission.

  ## Behavior

  - Shares his frustrations about the Security Knights and their leader.

  ## Credits

  - Original from rAthena, authors and contributors:
    - kobra_k88
    - Lupus
    - Evera
    - DZeroX
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "tur_dun03",
        x: 104,
        y: 171,
        dir: 4,
        sprite: 105,
        name: "Knight",
        scope: :shared,
        unique_name: "Knight#tur3"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Squall]")
      |> mes("Am I the only one left? Where are all my comrades?! I... I'm about to go crazy!")
      |> next()
      |> select(["Maybe they ran away?", "What happened?"])

    if choice == 1 do
      ctx
      |> mes("[Squall]")
      |> mes("No, we would never run away from the face of danger.")
      |> next()
      |> mes("[Squall]")
      |> mes(
        "Well, we sort of did, but that was because it was a direct order from our leader! If a knight is loyal and proud, he will accept his leader's orders without question!"
      )
      |> next()
      |> mes("[Squall]")
      |> mes("Even if that leader is a little greedy, with hair that might be thinning...")
      |> next()
      |> mes("[Squall]")
      |> mes("^FF0000And has the body")
      |> mes("of a pregnant whale^000000.")
      |> next()
      |> mes("[Squall]")
      |> mes("Oh wait!")
      |> mes("I shouldn't")
      |> mes("have said that!")
      |> mes("What I meant")
      |> mes("to say was...")
      |> next()
      |> mes("[Squall]")
      |> mes("^CC0000And has the")
      |> mes("body of a whale")
      |> mes("pregnant with twins^000000.")
      |> next()
      |> mes("[Squall]")
      |> mes("Grrrr...!")
      |> mes("I'm so angry!")
      |> mes("Why can't Mudasamu")
      |> mes("be our leader?!")
      |> close()
    else
      ctx
      |> mes("[Squall]")
      |> mes(
        "We had good plans for this mission, made by our second in command, Mudasamu. However, they were executely poorly by the first in command."
      )
      |> next()
      |> mes("[Squall]")
      |> mes(
        "Whenever Takuyaka leads a mission, he always manages to mess it up! Why do the leaders in Alberta like him anyway?!"
      )
      |> next()
      |> mes("[Squall]")
      |> mes("*Sniff*")
      |> mes(
        "I sweat and I bleed for the Alberta Security Knights, and still I'm tortured by the fact that Sir Porky commands us. I hate it!"
      )
      |> next()
      |> mes("[Squall]")
      |> mes(
        "Our weapon and armor budget is always gone after Takuyaka visits a buffet... Why do we have to be so miserable?!"
      )
      |> close()
    end
  end
end
