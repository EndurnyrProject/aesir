defmodule Aesir.ZoneServer.Content.Npc.Cities.Payon.MonsterScholar do
  @moduledoc """
  Explains Payon's undead and the kingdom's monster research efforts.

  ## Behavior

  - Discusses local monster news, undead origins, or the Monster Research Organization.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad Dib
    - Darkchild
    - DracoRPG
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon",
        x: 132,
        y: 235,
        dir: 3,
        sprite: 98,
        name: "Monster Scholar",
        scope: :shared,
        unique_name: "Monster Scholar#02"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Monster Scholar Vuicokk]")
      |> mes("Nice to meet you.")
      |> mes("I am called Vuicokk.")
      |> mes(
        "I am a scholar in the Monster Research organization of the Rune-Midgarts Kingdom. Do you have any questions about monsters?"
      )
      |> next()
      |> select(["Any news?", "Undead Monsters?", "Monster Research Organization?"])

    ctx
    |> answer_topic(choice)
    |> close()
  end

  defp answer_topic(ctx, 1) do
    ctx
    |> mes("[Monster Scholar Vuicokk]")
    |> mes(
      "Payon is located deep inside the forest where it can easily be attacked by hordes of monsters. Monsters also come from the dangerous cave located near town."
    )
    |> next()
    |> mes("[Monster Scholar Vuicokk]")
    |> mes(
      "Since Undead monsters roam the Payon Cave, it has attracted the attention of the monster academic world. My job here is to analyze their characteristics."
    )
  end

  defp answer_topic(ctx, 2) do
    ctx
    |> mes("[Monster Scholar Vuicokk]")
    |> mes(
      "What is most remarkable of the Undead monsters in Payon is their origin Most of them used to be citizens of Payon!"
    )
    |> next()
    |> mes("[Monster Scholar Vuicokk]")
    |> mes("However, these souls are")
    |> mes("unable to rest in peace and still wander about as Undead bound")
    |> mes("to this world.")
    |> next()
    |> mes("[Monster Scholar Vuicokk]")
    |> mes(
      "These monsters cannot be classified with other monsters that have mutated from living creatures, so our wise and benevolent ruler, King Tristram III, has taken a great interest in Payon's Undead."
    )
    |> next()
    |> mes("[Monster Scholar Vuicokk]")
    |> mes("After all, some of these")
    |> mes("Undead used to belong to")
    |> mes("the Rune-Midgarts Kingdom.")
    |> next()
    |> mes("[Monster Scholar Vuicokk]")
    |> mes("As his subjects,")
    |> mes("King Tristram III")
    |> mes("feels some responsibility")
    |> mes("to release their souls.")
    |> next()
    |> mes("[Monster Scholar Vuicokk]")
    |> mes("His Majesty has been supporting")
    |> mes(
      "us in our search to discover how to eliminate all of the Undead in this world. We will try to accomplish this goal as soon as we"
    )
    |> mes("possibly can.")
    |> next()
    |> mes("[Monster Scholar Vuicokk]")
    |> mes("For the safety of our people,")
    |> mes(
      "for the sake of their bereaved families, and in accordance with King Tristram III's order, we must succeed!"
    )
  end

  defp answer_topic(ctx, 3) do
    ctx
    |> mes("[Monster Scholar Vuicokk]")
    |> mes("As you may well know,")
    |> mes(
      "monsters have been endlessly spawning in this world, and the threat of their attacks is grows greater every day."
    )
    |> next()
    |> mes("[Monster Scholar Vuicokk]")
    |> mes("In response to this,")
    |> mes(" the Monster Research")
    |> mes("Organization has been formed.")
    |> next()
    |> mes("[Monster Scholar Vuicokk]")
    |> mes(
      "Talented people around the world have joined forces in an effort to deduce the origin of monsters, and a way to eliminate them once and for all."
    )
    |> next()
    |> mes("[Monster Scholar Vuicokk]")
    |> mes("Of course, it's not")
    |> mes(
      "as easy as you would may believe. Many have sacrificed their lives in the pursuit of this knowledge."
    )
    |> next()
    |> mes("[Monster Scholar Vuicokk]")
    |> mes(
      "In our missions, the number of victims of monster attacks have been countless. Still, nothing can stop us. If our suffering can save humanity, so be it!"
    )
    |> next()
    |> mes("[Monster Scholar Vuicokk]")
    |> mes(
      "^666666*Ahem*^000000 My apologies, I get too excited sometimes. But if you happen to meet other scholars such as myself, please treat them well. Our jobs are very difficult!"
    )
  end

  defp answer_topic(ctx, _choice), do: ctx
end
