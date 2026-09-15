defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.ApprenticePriestess do
  @moduledoc """
  Introduces travelers to Rachel, Freya worship, and the temple festival.

  ## Behavior

  - Changes her guidance after temple donations reach 10,000 zeny.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Tsuyuki and Harp
    - L0ne_W0lf
    - Lupus
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ra_fild12",
        x: 283,
        y: 208,
        dir: 3,
        sprite: 914,
        name: "Apprentice Priestess",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_server_var(ctx, "rachel_donate", 0) < 10_000 do
      promote_festival(ctx)
    else
      introduce_rachel(ctx)
    end
  end

  defp promote_festival(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Papaii]")
      |> mes("Welcome to Arunafeltz,")
      |> mes("adventurer! Enjoy your stay~")
      |> next()
      |> select(["Are you a guide?", "Thanks, have a good day."])

    case choice do
      1 -> explain_festival(ctx)
      _ -> invite_donation(ctx)
    end
  end

  defp explain_festival(ctx) do
    ctx
    |> mes("[Papaii]")
    |> mes("Oh, actually, if you")
    |> mes("want to speak to a guide,")
    |> mes("head west to Rachel, and")
    |> mes("then go north from the plaza")
    |> mes("in the center of the city.")
    |> mes("You'll find one over there.")
    |> next()
    |> mes("[Papaii]")
    |> mes("My name is Papaii,")
    |> mes("and I've been sent here to")
    |> mes("promote the upcoming festival")
    |> mes("in honor of Freya. I encourage")
    |> mes("you to donate for our festival")
    |> mes("if you can spare the zeny.")
    |> next()
    |> mes("[Papaii]")
    |> mes("If you're interested in")
    |> mes("learning more, then please")
    |> mes("visit our temple, which will")
    |> mes("be accepting donations and")
    |> mes("hosting the festival, and")
    |> mes("speak to Priestess Nemma.")
    |> next()
    |> mes("[Papaii]")
    |> mes("If you donate, you can")
    |> mes("receive Lottery Tickets")
    |> mes("that you can redeem for")
    |> mes("randomly selected items from")
    |> mes("the temple's storage. May")
    |> mes("Freya bless you, traveler~")
    |> close()
  end

  defp invite_donation(ctx) do
    ctx
    |> mes("[Papaii]")
    |> mes("May Freya bless you.")
    |> mes("If you have time, please")
    |> mes("visit our temple and make")
    |> mes("a donation if you can~")
    |> close()
  end

  defp introduce_rachel(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Papaii]")
      |> mes("Welcome to Arunafeltz!")
      |> mes("The city over the rampart")
      |> mes("is Rachel, the capital of")
      |> mes("Arunafeltz. If you'd like to")
      |> mes("rest from your travels, why")
      |> mes("don't you visit Rachel?")
      |> next()
      |> select(["Are you a guide?", "Tell me more about Rachel."])

    case choice do
      1 -> explain_religion(ctx)
      _ -> explain_city(ctx)
    end
  end

  defp explain_religion(ctx) do
    ctx
    |> mes("[Papaii]")
    |> mes("Actually, my name is")
    |> mes("Papaii, and I'm stationed")
    |> mes("here on behalf of the temple")
    |> mes("spread awareness of this our")
    |> mes("religion to visiting tourists.")
    |> next()
    |> mes("[Papaii]")
    |> mes("The entire nation of")
    |> mes("Arunafeltz worships the")
    |> mes("goddess Freya, and most")
    |> mes("aspects of our lives are")
    |> mes("largely influenced by our")
    |> mes("religion. Did you know that?")
    |> next()
    |> mes("[Papaii]")
    |> mes("I invite you to visit")
    |> mes("our temple if you'd like")
    |> mes("to learn more about goddess")
    |> mes("Freya. May Freya guide you")
    |> mes("in all that you do, and may she")
    |> mes("protect you in your journeys!")
    |> next()
    |> mes("[Papaii]")
    |> mes("Welcome to Arunafeltz!")
    |> mes("The city over the rampart")
    |> mes("is Rachel, the capital of")
    |> mes("Arunafeltz. If you'd like to")
    |> mes("rest from your travels, why")
    |> mes("don't you visit Rachel?")
    |> close()
  end

  defp explain_city(ctx) do
    ctx
    |> mes("[Papaii]")
    |> mes("Well, Rachel used to be")
    |> mes("a barren desert until our")
    |> mes("goddess led our ancestors to")
    |> mes("this land. They cultivated the")
    |> mes("desert by Freya's grace, and")
    |> mes("made this area habitable.")
    |> next()
    |> mes("[Papaii]")
    |> mes("Everything that you see here")
    |> mes("has been artificially created")
    |> mes("by humans. See? The blessings")
    |> mes("of Freya truly enable us to")
    |> mes("do miraculous things. You'll")
    |> mes("see once you enter the capital.")
    |> close()
  end
end
