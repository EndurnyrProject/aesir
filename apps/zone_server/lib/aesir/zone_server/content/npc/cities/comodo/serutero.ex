defmodule Aesir.ZoneServer.Content.Npc.Cities.Comodo.Serutero do
  @moduledoc """
  Guards the road to Sandaruman Fortress and advises travelers about the region.

  ## Behavior

  - Warps determined travelers to Sandaruman Fortress.
  - Recounts the fortress's decline and recommends nearby destinations.

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
        map: "moc_fild12",
        x: 35,
        y: 303,
        dir: 4,
        sprite: 59,
        name: "Serutero",
        scope: :shared,
        unique_name: "Serutero#cmd"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Serutero]")
      |> mes("Hello, I'm Serutero,")
      |> mes("guardian of the roads that")
      |> mes("lead to Sandaruman Fortress.")
      |> mes("If you really want to go there,")
      |> mes("I'll permit you to continue, but you must beware of its dangers...")
      |> next()
      |> select(["I'm going there!", "Sandaruman Fortress?", "Cancel"])

    case choice do
      1 -> enter_fortress(ctx)
      2 -> explain_fortress(ctx)
      3 -> recommend_comodo(ctx)
      _ -> ctx
    end
  end

  defp enter_fortress(ctx) do
    ctx
    |> mes("[Serutero]")
    |> mes("So you're really going")
    |> mes("to go to Sandaruman")
    |> mes("Fortress. Alright then,")
    |> mes("good luck, and be careful!")
    |> close()
    |> warp("cmd_fild08", 331, 319)
  end

  defp explain_fortress(ctx) do
    ctx
    |> mes("[Serutero]")
    |> mes("Although Sandaruman")
    |> mes("Fortress is infested with")
    |> mes("monsters now, it used to be")
    |> mes("a province where people lived.")
    |> mes("However, they were always")
    |> mes("invaded and pillaged...")
    |> next()
    |> mes("[Serutero]")
    |> mes("Sandaruman's inhabitants")
    |> mes("eventually adapted to the")
    |> mes("invasions, developing smoke")
    |> mes("signals and fortifications to")
    |> mes("withstand the ravages of war.")
    |> mes("Then, Comodo was built...")
    |> next()
    |> mes("[Serutero]")
    |> mes("Comodo grew in power and")
    |> mes("influence and eventually annexed Sandaruman. More and more people")
    |> mes("moved from the fortress to Comodo until Sandaruman fortress was")
    |> mes("essentially abandoned.")
    |> next()
    |> mes("[Serutero]")
    |> mes("There were a few people")
    |> mes("remaining in Sandaruman,")
    |> mes("but they revolted and some")
    |> mes("fledging government came into")
    |> mes("power there. The monsters took")
    |> mes("the chance to take over...")
    |> next()
    |> mes("[Serutero]")
    |> mes("There's nothing around")
    |> mes("Sandaruman now. Well, nothing")
    |> mes("except maybe Paros Lighthouse,")
    |> mes("which is southwest of here. That place might be of interest to")
    |> mes("aspiring Rogues, I hear...")
    |> close()
  end

  defp recommend_comodo(ctx) do
    ctx
    |> mes("[Serutero]")
    |> mes("You know, if you're")
    |> mes("tired of traveling, you")
    |> mes("can rest in ^3355FFComodo^000000. That")
    |> mes("place is a pretty popular")
    |> mes("tourist attraction, especially")
    |> mes("for you adventurer types.")
    |> close()
  end
end
