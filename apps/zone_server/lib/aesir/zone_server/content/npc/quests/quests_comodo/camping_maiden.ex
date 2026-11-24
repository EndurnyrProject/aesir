defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsComodo.CampingMaiden do
  @moduledoc """
  Emralhandas recalls the War of the Witch at the campsite.

  ## Behavior

  - Describes the four swords and the battle against Mariposum when asked.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Evera
    - Samuray22
    - Brainstorm

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "comodo",
        x: 209,
        y: 305,
        dir: 4,
        sprite: 71,
        name: "Camping Maiden",
        scope: :shared,
        unique_name: "Camping Maiden#cmd"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Emralhandas]")
      |> mes("Rockha, let me pour")
      |> mes("you another drink. We")
      |> mes("always dreamed of this")
      |> mes("during the War of the Witch...")
      |> mes("Having a good time, all of us")
      |> mes("together in a time of peace~")
      |> next()
      |> select(["War of the Witch?", "Cancel"])

    if choice == 1 do
      ctx
      |> mes("[Emralhandas]")
      |> mes("Before I tell you about the")
      |> mes("War of the Witch, I guess")
      |> mes("I should tell you about the")
      |> mes("quest to retrieve 4 rare swords")
      |> mes("of power, said to be the most")
      |> mes("powerful weapons ever made.")
      |> next()
      |> mes("[Emralhandas]")
      |> mes("Now, all 4 swords were")
      |> mes("successfully found 10 years")
      |> mes("after the search began. Then,")
      |> mes("4 protectors were chosen to")
      |> mes("ensure that the swords did")
      |> mes("not fall into the wrong hands.")
      |> next()
      |> mes("[Emralhandas]")
      |> mes("You might not think so just")
      |> mes("by looking at us, but we were")
      |> mes("the protectors--me, Rockha,")
      |> mes("Rochito, and Tausupa, the chief")
      |> mes("of this village. Now, we guarded these weapons very carefully...")
      |> next()
      |> mes("[Emralhandas]")
      |> mes("However, that didn't deter")
      |> mes("Mariposum, ancient witch of")
      |> mes("Comodo, from attacking us and")
      |> mes("trying to steal the swords. She")
      |> mes("was incredibly powerful, and")
      |> mes("we needed an army to fight her.")
      |> next()
      |> mes("[Emralhandas]")
      |> mes("That was the War of the")
      |> mes("Witch, basically. Mariposum")
      |> mes("with her own strange weapon")
      |> mes("of mass destruction against the")
      |> mes("four of us backed by a large")
      |> mes("force of courageous soldiers.")
      |> next()
      |> mes("[Emralhandas]")
      |> mes("Many of our comrades died...")
      |> mes("But finally we succeeded in")
      |> mes("imprisoning the witch by using")
      |> mes("the power of the swords. Yeah,")
      |> mes("if it weren't for Tausupa, we'd")
      |> mes("never have been able to do it.")
      |> close()
    else
      ctx
      |> mes("[Emralhandas]")
      |> mes("Rockha, we still have")
      |> mes("to finish our mission:")
      |> mes("eat all of the barbeque")
      |> mes("that that we possibly can!")
      |> mes("Let's just stuff ourselves...")
      |> mes("All the way until tommorrow!")
      |> close()
    end
  end
end
