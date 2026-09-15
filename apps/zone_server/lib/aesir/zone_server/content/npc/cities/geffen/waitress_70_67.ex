defmodule Aesir.ZoneServer.Content.Npc.Cities.Geffen.Waitress7067 do
  @moduledoc """
  Serves imitation drinks and shares random gossip at Geffen's tavern.

  ## Behavior

  - Explains the kingdom's alcohol ban when asked for a drink.
  - Otherwise shares one of four rumors, including encounters with William's Spirit.
  - Tailors one spirit reaction to the visitor's sex and name.

  ## Credits

  - Original from rAthena, authors and Contributors
    - massdriller
    - Nexon
    - MasterOfMuppets
    - Silent
    - Musashiden
    - Evera
    - L0ne_W0lf
    - Lesbian
    - Lupus
    - Samuray22
    - DeadlySilence

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "geffen_in",
        x: 70,
        y: 67,
        dir: 3,
        sprite: 90,
        name: "Waitress",
        scope: :shared,
        unique_name: "Waitress#elise"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Elisa]")
      |> mes("Hello there~")
      |> mes("Can I help you")
      |> mes("with anything?")
      |> next()
      |> select(["May I ask for a drink?", "Is there any interesting gossip lately?"])

    if choice == 1 do
      discuss_drinks(ctx)
    else
      ctx
      |> share_gossip(Enum.random(1..4))
      |> close()
    end
  end

  defp discuss_drinks(ctx) do
    ctx
    |> mes("[Elisa]")
    |> mes("A...")
    |> mes("Drink?")
    |> next()
    |> mes("[Elisa]")
    |> mes(
      "You know that we don't serve alcohol here anymore. We just have all these fake, flavorless drinks that have no effect. Yeah, they're pretty boring..."
    )
    |> next()
    |> mes("[Elisa]")
    |> mes(
      "We pretty much only serve water around here. That, and really bad alcoholic imitation drinks."
    )
    |> next()
    |> mes("[Elisa]")
    |> mes(
      "It's horrible that King Tristram III outlawed alcohol in the kingdom! It's probably the only bad decision he's made throughout his entire reign!"
    )
    |> close()
  end

  defp share_gossip(ctx, 1) do
    ctx
    |> mes("[Elisa]")
    |> mes("You know")
    |> mes("what's so weird?")
    |> next()
    |> mes("[Elisa]")
    |> mes("I went down to the Prontera Sanctuary, and I could have sworn")
    |> mes("that a Priest got married to a Priestess!")
    |> next()
    |> mes("[Elisa]")
    |> mes(
      "I really had no idea whether or not Priests could marry, but since King Tristram III was there himself,"
    )
    |> mes("I suppose that it's okay!")
  end

  defp share_gossip(ctx, 2) do
    ctx
    |> mes("[Elisa]")
    |> mes(
      "I don't like to stereotype people, but haven't you noticed that Swordsmen and Knights"
    )
    |> mes("tend to be, you know...")
    |> next()
    |> mes("[Elisa]")
    |> mes("...INT challenged?")
    |> mes("All they seem to know")
    |> mes("is smashing things!")
  end

  defp share_gossip(ctx, 3) do
    ctx
    |> mes("[Elisa]")
    |> mes("Rumors...?")
    |> mes("Hmmmm, well...")
    |> next()
    |> mes("[Elisa]")
    |> mes("You know the name")
    |> mes("of our kingdom, right?")
    |> mes("The Rune-Midgarts Kingdom?")
    |> next()
    |> mes("[Elisa]")
    |> mes(
      "I hear that it was originally called the Rune-Midgarts Kingdom, after our continent. However, for some reason, the name was changed to 'Rune-Midgarts.'"
    )
    |> next()
    |> mes("[Elisa]")
    |> mes(
      "It was obviously a wise decision, since too many people kept confusing the our continent with our kingdom. Weird, huh?"
    )
  end

  defp share_gossip(ctx, 4), do: william_gossip(ctx, Enum.random(1..2))
  defp share_gossip(ctx, _choice), do: ctx

  defp william_gossip(ctx, 1) do
    ctx =
      ctx
      |> mes("[Elisa]")
      |> mes("Rumors...?")
      |> mes("Hmmmm, well...")
      |> next()
      |> mes("[Elisa]")
      |> mes("That's funny...")
      |> mes("I, I can't think of anything. E-everything feels so fuzzy...")
      |> next()
      |> mes("...")
      |> next()
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("[William's Spirit]")
      |> mes(
        "^990000Stay away from my daughter, or I'll beat your brains out, punk! Elisa's gonna marry a doctor! Or a lawyer!^000000"
      )
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")

    if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
      ctx
      |> mes("Y-y-y-yes, sir!")
      |> next()
      |> mes("^3355FFThat was scary...!")
      |> mes("It looks like a father's love endures forever, even in the afterlife.^000000")
    else
      ctx
      |> mes("But...")
      |> mes("I'm a girl!")
      |> next()
      |> mes("[William's Spirit]")
      |> mes("^990000WHAT...?!")
      |> mes("That's even worse!!^000000")
      |> next()
      |> mes("^3355FFThat was scary...!")
      |> mes("It looks like a father's love endures forever, even in the afterlife.^000000")
    end
  end

  defp william_gossip(ctx, 2) do
    ctx
    |> mes("[William's Spirit]")
    |> mes(
      "^990000How dare you try to pick up on my precious daughter! Do you wish to taste an angry father's fury?!^000000"
    )
    |> next()
    |> mes("[Elisa]")
    |> mes("W-whoa...!")
    |> mes("I'm so sorry!")
    |> next()
    |> mes("[Elisa]")
    |> mes("It's just...")
    |> mes("The spirit of my father,")
    |> mes("God rest his soul, is")
    |> mes("a little overprotective!")
    |> next()
    |> mes("^3355FFYou step away.")
    |> mes("Very. Carefully.^000000")
  end

  defp william_gossip(ctx, _choice), do: ctx
end
