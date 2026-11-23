defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.BazettTeablack do
  @moduledoc """
  Guides Bazett's investigation of the Otherworld.

  ## Behavior

  - Recruits the player and provides investigation notes.
  - Accepts completed notes and awards coins for recorded observations.

  ## Credits

  - Original from rAthena, authors and contributors:
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mid_camp",
        x: 283,
        y: 198,
        dir: 5,
        sprite: 883,
        name: "Bazett Teablack",
        scope: :shared,
        unique_name: "Bazett Teablack#ep13bs"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{1201, 1}]) == 0 -> overweight(ctx)
      get_char_var(ctx, :ep13_2_rhea, 0) < 100 -> keep_writing(ctx)
      true -> bazett_talk(ctx, get_char_var(ctx, :ep13_2_busut, 0))
    end
  end

  defp overweight(ctx) do
    ctx
    |> mes(" - Hold on!! -")
    |> mes(" - You are carrying too many different items - ")
    |> mes(" - You cannot receive the reward - ")
    |> mes(" - Please use the Kafra service - ")
    |> mes(" - And try again. - ")
    |> close()
  end

  defp keep_writing(ctx) do
    ctx
    |> writing_intro()
    |> mes("[Industrious Man]")
    |> mes("write...write...")
    |> mes("crunch...crunch...")
    |> mes("....")
    |> close()
  end

  defp writing_intro(ctx) do
    ctx
    |> mes("[Industrious Man]")
    |> mes("Hu~~")
    |> mes("That's pretty interesting...")
    |> mes("I will take note of it in my research papers.")
    |> emotion(:aha)
    |> next()
    |> mes("[Industrious Man]")
    |> mes("write...write...")
    |> mes("crunch...crunch...")
    |> next()
    |> mes(
      " - He doesn't seem to recognize that I am standing next to him as he continues writing something. -"
    )
    |> next()
  end

  defp bazett_talk(ctx, busut) when busut < 1 do
    if is_equipped(ctx, 2782) == 1, do: first_meeting(ctx), else: untranslated_talk(ctx)
  end

  defp bazett_talk(ctx, 1) do
    {ctx, choice} =
      ctx
      |> mes("[Industrious Man]")
      |> mes("Ah! You've returned!")
      |> mes("Now are you interested in my research?")
      |> next()
      |> select(["Yes.", "No."])

    case choice do
      1 ->
        accept_research(ctx)

      2 ->
        ctx
        |> mes("[Industrious Man]")
        |> mes(".............")
        |> mes("Well if you decide to change your mind, come back to me.")
        |> emotion(:cry)
        |> close()

      _ ->
        ctx
    end
  end

  defp bazett_talk(ctx, 2) do
    ctx
    |> mes("[Bazett]")
    |> mes("Um... for today can you search for giants in the Manuk Field?")
    |> mes("That place is pretty cold so, you might need a coat.")
    |> next()
    |> mes("[Bazett]")
    |> mes("I used this note so it should still be useful. Take it...")
    |> mes("Ah... and don't worry about the title of the note.")
    |> next()
    |> mes("[Bazett]")
    |> mes("After you've finished searching bring that note back to me.")
    |> next()
    |> mes("[Bazett]")
    |> mes("Got it? Ok take care and see you soon.")
    |> set_char_var(:ep13_2_busut, 3)
    |> set_char_var(:ep13_2_bs1, 1)
    |> set_char_var(:ep13_2_bs2, 1)
    |> set_char_var(:ep13_2_bs3, 1)
    |> set_char_var(:ep13_2_bs4, 1)
    |> give_item(6074, 1)
    |> changequest(11_101, 11_102)
    |> close()
  end

  defp bazett_talk(ctx, 3) do
    ctx = ctx |> mes("[Bazett]") |> mes("How's the search going?") |> next()

    if count_item(ctx, 6074) < 1 do
      ctx
      |> lost_notes()
      |> mes("I'll give you a new one.")
      |> give_item(6074, 1)
      |> close()
    else
      ctx |> mes("[Bazett]") |> mes("Take it easy...") |> close()
    end
  end

  defp bazett_talk(ctx, 4) do
    {ctx, choice} =
      ctx
      |> mes("[Bazett]")
      |> mes("Oh! You're done with the investigation?")
      |> next()
      |> select(["Yes.", "Not yet..."])

    case choice do
      1 -> hand_in_notes(ctx)
      2 -> ctx |> mes("[Bazett]") |> mes("Take it easy...") |> close()
      _ -> ctx
    end
  end

  defp bazett_talk(ctx, _busut) do
    ctx
    |> mes("[Bazett]")
    |> mes("You've done well.")
    |> mes("You must be exhausted. Go take a rest, we'll continue tomorrow.")
    |> close()
  end

  defp first_meeting(ctx) do
    {ctx, choice} =
      ctx
      |> writing_intro()
      |> mes("[Industrious Man]")
      |> mes("write..write...")
      |> mes("crunch..crunch...")
      |> mes("....")
      |> next()
      |> mes("[Industrious Man]")
      |> mes("Auch!!!")
      |> mes("Who...who are you?!")
      |> mes("How long have you been standing there?")
      |> emotion(:huk)
      |> next()
      |> player_header()
      |> mes("Uh, I'm just passing by.")
      |> mes("You look like you're busy with something.")
      |> next()
      |> player_header()
      |> mes("See you~!!")
      |> emotion(:profusely_sweat, playerattached(ctx))
      |> next()
      |> mes("[Industrious Man]")
      |> mes("Uh!! Wait!!")
      |> mes("Your finger... Is that..?!")
      |> next()
      |> mes(" - He grabs your hand with a surprised look -")
      |> next()
      |> mes("[Industrious Man]")
      |> mes("This is the ^0000FFRing of the Ancient Wise King^000000!!!!!")
      |> mes("This has to be fate that I've met you!")
      |> next()
      |> mes("[Industrious Man]")
      |> mes(
        "My research is not going so well. The god of fate must have sent you to me. I'm sure of it!!"
      )
      |> emotion(:best)
      |> next()
      |> player_header()
      |> mes("......")
      |> mes("......What?!")
      |> emotion(:huk, playerattached(ctx))
      |> next()
      |> mes("[Industrious Man]")
      |> mes("Would you like to help me with my search?")
      |> next()
      |> select(["What kind of search?", "Sure.", "Borrrring."])

    case choice do
      1 -> explain_research(ctx)
      2 -> accept_research(ctx)
      3 -> ctx |> silent_treatment() |> refuse_research()
      _ -> ctx
    end
  end

  defp explain_research(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Industrious Man]")
      |> mes("To put it simply, I'm searching for fairies and giants that live around here.")
      |> next()
      |> mes("[Industrious Man]")
      |> mes(
        "Though I believe they all live in the same place, they are sure to have different cultures."
      )
      |> mes("...first and foremost is proof of their existence.")
      |> next()
      |> mes("[Industrious Man]")
      |> mes("What about it?")
      |> mes("Are you interested?")
      |> next()
      |> select(["Sure.", "Not really."])

    case choice do
      1 -> accept_research(ctx)
      2 -> refuse_research(ctx)
      _ -> ctx
    end
  end

  defp silent_treatment(ctx) do
    ctx
    |> mes("[Industrious Man]")
    |> mes(".............")
    |> next()
    |> mes("[Industrious Man]")
    |> mes(".............")
    |> mes(".............")
    |> next()
    |> mes("[Industrious Man]")
    |> mes(".............")
    |> mes(".............")
    |> mes(".............")
    |> next()
    |> mes("[Industrious Man]")
    |> mes(".............")
    |> mes(".............")
    |> mes(".............")
    |> mes(".............")
    |> next()
  end

  defp refuse_research(ctx) do
    ctx
    |> mes("[Industrious Man]")
    |> mes(".............")
    |> mes(".............")
    |> mes(".............")
    |> mes(".............")
    |> mes("...........Why!!!!!")
    |> emotion(:cry)
    |> next()
    |> mes("[Industrious Man]")
    |> mes("Well if you decide to change your mind, come back to me.")
    |> set_char_var(:ep13_2_busut, 1)
    |> close()
  end

  defp untranslated_talk(ctx) do
    ctx =
      if Enum.random(1..2) == 1 do
        ctx
        |> mes("[Industrious Man]")
        |> mes("Gthgh sdsWryi")
        |> mes("Apeu hjsu opuer ")
        |> next()
        |> player_header()
        |> mes("?????")
        |> mes("What'd you say?")
        |> next()
        |> mes("[Industrious Man]")
        |> mes("Oh! Sorry, I think I said it wrong...")
        |> mes("I was just infatuated with my research...")
        |> next()
        |> mes("[Industrious Man]")
        |> mes(
          "You should find a way to understand this strange language that I've discovered here in the Ash Vacuum."
        )
      else
        ctx
        |> mes("[Industrious Man]")
        |> mes("TalDathMush Di nahDeh")
        |> mes("ReAnduDu So sehr")
        |> next()
        |> player_header()
        |> mes("?????")
        |> mes("Huh?")
        |> next()
        |> mes("[Industrious Man]")
        |> mes("Oh! I must've said it wrong...")
        |> mes("My research hasn't been going too well lately.")
        |> next()
        |> mes("[Industrious Man]")
        |> mes("There should be a way for you to understand this strange language here.")
      end

    ctx
    |> next()
    |> mes("[Industrious Man]")
    |> mes(
      "Without the ability to communicate it would be really difficult to get around here, don't you think?"
    )
    |> close()
  end

  defp hand_in_notes(ctx) do
    if count_item(ctx, 6074) < 1 do
      ctx
      |> lost_notes()
      |> mes("You must be tired, go take a rest.")
      |> mes("I'll go prepare new notes.")
      |> mes("You can just go investigate again for me.")
      |> set_char_var(:ep13_2_busut, 7)
      |> erasequest(11_102)
      |> setquest(11_104)
      |> close()
    else
      ctx
      |> mes("[Bazett]")
      |> mes("May I take a look at the notes first?")
      |> mes("Oh!!")
      |> next()
      |> mes(" - Bazett is reading the detailed contents - ")
      |> mes(" - He seems to be captivated. - ")
      |> mes(" - It's better if I leave him alone. - ")
      |> mes(" - So he can finish. - ")
      |> next()
      |> mes("[Bazett]")
      |> mes("Mm...there are actually such things?!")
      |> next()
      |> mes("[Bazett]")
      |> mes("Mm...I see, I see.")
      |> next()
      |> mes("[Bazett]")
      |> mes("Even though the content is simple, it's well organized and interesting.")
      |> mes("As expected of #{char_name(ctx, 0)}!!")
      |> next()
      |> mes("[Bazett]")
      |> mes("You've done well.")
      |> mes("You must be exhausted. Go take a rest. We'll continue tomorrow.")
      |> next()
      |> mes("[Bazett]")
      |> mes("Ah... this isn't much, but it's a coin that the giants use.")
      |> mes("Maybe you can buy something from them with this.")
      |> delitem(6074, 1)
      |> set_char_var(:ep13_2_busut, 7)
      |> reward_findings()
      |> erasequest(11_102)
      |> setquest(11_104)
      |> close()
    end
  end

  defp reward_findings(ctx) do
    Enum.reduce([:ep13_2_bs1, :ep13_2_bs2, :ep13_2_bs3, :ep13_2_bs4], ctx, fn finding, ctx ->
      if get_char_var(ctx, finding, 0) == 3, do: give_item(ctx, 6080, 1), else: ctx
    end)
  end

  defp lost_notes(ctx) do
    ctx
    |> mes("[Bazett]")
    |> mes("!!!!!!!")
    |> mes("You lost the notes!!?")
    |> mes("Sigh...")
    |> next()
    |> mes("[Bazett]")
    |> mes("What's done has been done.")
  end

  defp accept_research(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Industrious Man]")
      |> mes("Haha... I just know that I'm right!")
      |> mes("Hahahaha!!")
      |> next()
      |> mes("[Industrious Man]")
      |> mes("So let's work together from this point on. Let me introduce myself.")
      |> mes("As you can see from my name tag, my name is ^0000FFBazett Teablack^000000.")
      |> next()
      |> player_header()
      |> mes("I am #{char_name(ctx, 0)}.")
      |> next()
      |> select(["OK, so what can I do for you?"])

    ctx
    |> mes("[Bazett]")
    |> mes("#{char_name(ctx, 0)} let's see..!!")
    |> mes("Search Manuk and Splendide fields everyday for signs of the fairies or giants.")
    |> next()
    |> mes("[Bazett]")
    |> mes("It's not difficult.")
    |> mes(
      "So please share any information that you can gather as you travel through those areas."
    )
    |> next()
    |> mes("[Bazett]")
    |> mes("Hopefully I can find what I am looking for with the information you can find.")
    |> set_char_var(:ep13_2_busut, 2)
    |> setquest(11_101)
    |> close()
  end

  defp player_header(ctx), do: mes(ctx, "[#{char_name(ctx, 0)}]")
end
