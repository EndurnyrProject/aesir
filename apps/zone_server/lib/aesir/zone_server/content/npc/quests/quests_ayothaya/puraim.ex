defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.Puraim do
  @moduledoc """
  Puraim guards the approach to the Ayothaya ruins.

  ## Behavior

  - Warns visitors without a holy thread to stay away.
  - Offers qualified adventurers passage, hurting them before warping them to the ruins.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Fredzilla
    - MasterOfMuppets
    - Lupus
    - Silent
    - Evera
    - SinSloth
    - L0ne_W0lf
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ayo_fild01",
        x: 129,
        y: 197,
        dir: 0,
        sprite: 842,
        name: "Puraim",
        scope: :shared,
        unique_name: "Puraim#thai1"
      }
    ]

  @holy_thread 7285
  @blessed_thread 7287

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :ayodunquest, 0) > 2 and
         (count_item(ctx, @holy_thread) > 0 or count_item(ctx, @blessed_thread) > 0) do
      offer_passage(ctx)
    else
      warn(ctx)
    end
  end

  defp offer_passage(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Puraim]")
      |> mes("Huh...?")
      |> mes("I feel it!")
      |> mes("I can feel the")
      |> mes("power of holiness!")
      |> mes("It's coming from you!")
      |> next()
      |> mes("[Puraim]")
      |> mes("I guess you can go ahead")
      |> mes("into the ruins. So that's")
      |> mes("what you want? To explore")
      |> mes("this area?")
      |> next()
      |> mes("[Puraim]")
      |> mes("I would suggest")
      |> mes("against coming inside.")
      |> mes("Even the local people")
      |> mes("fear this area.")
      |> next()
      |> mes("[Puraim]")
      |> mes(
        "If the Sa-mhing Tiger wasn't around, there would still be all the evil spirits in this place. Even with the holy thread, this place is still dangerous."
      )
      |> next()
      |> mes("[Puraim]")
      |> mes("So what do you want?")
      |> mes("Do you still want to")
      |> mes("explore the area,")
      |> mes("adventurer?")
      |> next()
      |> select(["Yes.", "No! I'm too afraid of the ruins now."])

    if choice == 1, do: enter(ctx), else: stay(ctx)
  end

  defp enter(ctx) do
    ctx
    |> mes("[Puraim]")
    |> mes("Hmmm...")
    |> mes("It seems you adventurers are tempted by the thrill of danger,")
    |> mes("or you've all got some death wish.")
    |> next()
    |> mes("[Puraim]")
    |> mes("Oh well, that's none of my business. After all, you already")
    |> mes(
      "have a holy spirit. Still, be careful. You might not want to go to the 2nd underground level of the ruins."
    )
    |> next()
    |> mes("[Puraim]")
    |> mes("As you Midgardians")
    |> mes("say, 'curiousity killed the cat.'")
    |> mes("Anyway, go for it!")
    |> next()
    |> mes("^3355FFHe shoved you off the hill")
    |> mes("and you plummet like a rock.^000000")
    |> close()
    |> percent_heal(hp: -10, sp: 0)
    |> warp("ayo_fild02", 30, 135)
  end

  defp stay(ctx) do
    ctx
    |> mes("[Puraim]")
    |> mes("Good decision!")
    |> mes("As I expected, you're")
    |> mes("smart enough not to")
    |> mes("stupidly jeopardize your life.")
    |> close()
  end

  defp warn(ctx) do
    ctx
    |> mes("[Puraim]")
    |> mes("If I were you, I wouldn't")
    |> mes("even dare to approach")
    |> mes("the ruins down over there.")
    |> next()
    |> mes("[Puraim]")
    |> mes(
      "Anyone who doesn't have the protection of a holy spirit will be easy game for the evil creatures living there. You'd be killed in"
    )
    |> mes("no time at all!")
    |> next()
    |> mes("[Puraim]")
    |> mes("Go back, adventurer.")
    |> mes("If you wish to explore")
    |> mes("this area, you'd better")
    |> mes("show me some holy spirit.")
    |> close()
  end
end
