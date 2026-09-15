defmodule Aesir.ZoneServer.Content.Npc.Cities.Geffen.Waitress do
  @moduledoc """
  Serves imitation drinks and shares random gossip at Geffen's tavern.

  ## Behavior

  - Explains the kingdom's alcohol ban when asked for a drink.
  - Otherwise shares one of four rumors, including encounters with William's Spirit.
  - Tailors some gossip and spirit reactions to the visitor's sex and name.

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
        x: 27,
        y: 134,
        dir: 5,
        sprite: 91,
        name: "Waitress",
        scope: :shared,
        unique_name: "Waitress#elen"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Elenore]")
      |> mes("This place...")
      |> mes("Certainly has")
      |> mes("atmosphere.")
      |> next()
      |> mes("[Elenore]")
      |> mes(
        "We've got some kind of Fortune Teller that's always hanging around in the corner, and a loud, belligerent drunk who's always picking on Mages."
      )
      |> next()
      |> mes("[Elenore]")
      |> mes("So...")
      |> mes("What can")
      |> mes("I do for you?")
      |> next()
      |> select(["May I have a drink?", "Is there any interesting gossip?"])

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
    |> mes("[Elenore]")
    |> mes("Well...")
    |> mes(
      "If you're looking for alcohol, King Tristram III outlawed it a while ago. Now I hear they only serve it in certain places."
    )
    |> next()
    |> mes("[Elenore]")
    |> mes(
      "Still, people manage to get drunk off the imitation drinks that we serve here. I guess it's all psychological."
    )
    |> next()
    |> mes("[Elenore]")
    |> mes(
      "I reeeeally want to be able to visit that place where they serve real drinks. I hear it's just like paradise!"
    )
    |> close()
  end

  defp share_gossip(ctx, 1) do
    ctx
    |> mes("[Elenore]")
    |> mes("Gossip...?")
    |> mes("Well, I've heard that they're opening a new Airship Service")
    |> mes("in Juno!")
    |> next()
    |> mes("[Elenore]")
    |> mes(
      "Or at least, they're planning to. The airship isn't really ready to take off just yet. In the meantime, there's some weird customer representative over there who's offering a teleport service."
    )
    |> next()
    |> mes("[Elenore]")
    |> mes(
      "It seems like Kafra Corporation may finally have a competitor! Then again, I don't think many girls are as attractive as the Kafra Employees..."
    )
  end

  defp share_gossip(ctx, 2) do
    ctx
    |> mes("[Elenore]")
    |> mes("Have you heard?")
    |> mes("There are some new fashions floating around the Rune-Midgarts Kingdom!")
    |> next()
    |> mes("[Elenore]")
    |> mes(
      "People have been coming in, wearing some cute new hats. There was this cute Teddy Bear Hat I've never seen before, and a girl came in wearing these black Kitty Ears..."
    )
    |> next()
    |> mes("[Elenore]")
    |> mes(
      "Of course, not every popular style suits my taste. I mean, I saw someone walking around with a Mushroom on their head. And I hear someone has been making hats made out of Fish?"
    )
    |> next()
    |> mes("[Elenore]")
    |> mes("I guess those")
    |> mes("kinds of hats are too")
    |> mes("artistic for my taste.")
  end

  defp share_gossip(ctx, 3) do
    ctx =
      ctx
      |> mes("[Elenore]")
      |> mes("Gossip, eh?")
      |> next()
      |> mes("[Elenore]")
      |> mes("Well...")
      |> mes("I hear there's this person somewhere in Rune-Midgarts...")
      |> next()
      |> mes("[Elenore]")

    if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
      mes(
        ctx,
        "Tell me, have you ever heard of #{char_name(ctx, 0)}? He's supposed to be the suavest hero around!"
      )
    else
      mes(
        ctx,
        "Have you ever heard of #{char_name(ctx, 0)}? People say she's one of the prettiest girls in all of Rune-Midgarts!"
      )
    end
  end

  defp share_gossip(ctx, 4), do: william_gossip(ctx, Enum.random(1..2))
  defp share_gossip(ctx, _choice), do: ctx

  defp william_gossip(ctx, 1) do
    ctx
    |> mes("[Elenore]")
    |> mes("Gossip, eh?")
    |> mes("W-wait...")
    |> next()
    |> mes("[Elenore]")
    |> mes("Ugh...")
    |> mes("Ooooh...")
    |> mes("My he-head...")
    |> mes("It huuurts...")
    |> next()
    |> mes("[William's Spirit]")
    |> mes(
      "^990000You get the hell away from my daughter, low-life, before I sell your organs for zeny!"
    )
    |> mes("You hear me?!^000000")
    |> next()
    |> mes("[Elenore]")
    |> mes("*Cough*")
    |> mes("Oh...!")
    |> mes("Sorry about that!")
    |> mes("I must be coming")
    |> mes("down with the flu!")
    |> mes("...Or something.")
    |> next()
    |> mes("^3355FFWeird...")
    |> mes("Her voice was")
    |> mes("really deep for")
    |> mes("a minute there...")
  end

  defp william_gossip(ctx, 2) do
    ctx =
      ctx
      |> mes("[William's Spirit]")
      |> mes(
        "^990000Hey you sex crazed bastard!! Stop looking at my daughter like that before I rip out your eyes, and eat them with pasta!^000000"
      )
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")

    if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
      ctx
      |> mes("Huh...?")
      |> mes("C-come again?")
      |> next()
      |> mes("[Elenore]")
      |> mes("Huh...?")
      |> mes("Oh, Dad must have possessed me again. It happens to me and my sister all the time.")
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("No kidding?")
      |> mes("Huh. Total bummer.")
      |> next()
      |> mes("[Elenore]")
      |> mes("Yeah...")
      |> mes("Tell me about it.")
    else
      ctx
      |> mes("W-waaaaait~")
      |> mes("But, But I'm a girl!")
      |> next()
      |> mes("[William's Spirit]")
      |> mes(
        "^990000What part of ^FF0000I will whup you where you stand^000000 ^990000do you not understand?! Now, quit it you pervert!^000000"
      )
      |> next()
      |> mes("^3355FFWaaah~!")
      |> mes("How did she")
      |> mes("get all scary?!^000000")
    end
  end

  defp william_gossip(ctx, _choice), do: ctx
end
