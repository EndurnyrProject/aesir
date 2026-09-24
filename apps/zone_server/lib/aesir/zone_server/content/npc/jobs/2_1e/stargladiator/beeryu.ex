defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21e.Stargladiator.Beeryu do
  @moduledoc """
  Beeryu tests Star Gladiator candidates in the Moon Room.

  ## Behavior

  - Asks three questions about the Moon; candidates who score well move on to the Star Room,
    others are sent to Payon to learn patience.
  - Once Moohyun has helped a candidate understand patience, sends them to the Star Room.
  - Redirects candidates at other quest stages to the right room or back to Payon.
  - Offers everyone else a return to Payon.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Celestria
    - Samuray22
    - L0ne_W0lf
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_star",
        x: 95,
        y: 33,
        dir: 0,
        sprite: 106,
        name: "Beeryu",
        scope: :shared,
        unique_name: "Beeryu#job_star"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.job_id(class(ctx)) == Rathena.job_id(:taekwon) do
      guide_candidate(ctx, get_char_var(ctx, :STGL_Q, 0))
    else
      offer_return_to_payon(ctx)
    end
  end

  defp guide_candidate(ctx, stage) do
    cond do
      stage == 4 -> moon_test(ctx)
      stage == 5 -> send_to_sun_room(ctx)
      stage == 6 -> hurry_to_star_room(ctx)
      stage == 7 -> ask_for_proof_of_patience(ctx)
      stage == 8 -> accept_proof_of_patience(ctx)
      stage > 8 and stage < 12 -> send_to_cheehee(ctx)
      true -> send_back_to_town(ctx)
    end
  end

  defp moon_test(ctx) do
    {ctx, shade} =
      ctx
      |> mes("[Beeryu]")
      |> mes("Welcome to the Moon Room.")
      |> mes("I am Beeryu, your guide in")
      |> mes("this sanctum. I shall ask you a")
      |> mes("series of questions, so please")
      |> mes("think carefully before giving")
      |> mes("me your honest answer.")
      |> next()
      |> mes("[Beeryu]")
      |> mes("Which Moon do we need")
      |> mes("and want most? Think of")
      |> mes("the different shades of the")
      |> mes("moon, and how it changes")
      |> mes("on certain nights.")
      |> next()
      |> select(["Red Moon", "Blue Moon", "Gold Moon", "...?"])

    {ctx, shade_points} = judge_moon_shade(ctx, shade)

    {ctx, purpose} =
      ctx
      |> next()
      |> mes("[Beeryu]")
      |> mes("Now, if the shadows")
      |> mes("of the Moon were to")
      |> mes("lend you their power,")
      |> mes("to what end would you")
      |> mes("use the power of the")
      |> mes("Lunar cosmos?")
      |> next()
      |> select(["Justice", "Self Practice", "Preservation of Nature", "Revenge"])

    {ctx, purpose_points} = judge_lunar_purpose(ctx, purpose)

    {ctx, verse} =
      ctx
      |> next()
      |> mes("[Beeryu]")
      |> mes("Now, listen carefully")
      |> mes("to the lyrics of this")
      |> mes("song. I'm sure Daru has")
      |> mes("sang this to you already...")
      |> next()
      |> mes("[Beeryu]")
      |> mes("''^4D4DFFThe Sun shines on even days.")
      |> mes("The Moon gleams on odd days.")
      |> mes("The Stars sparkle on every")
      |> mes("fifth day without fail.^000000''")
      |> next()
      |> mes("[Beeryu]")
      |> mes("''^4D4DFFA desert is a Solar place,")
      |> mes("its sands kissed by the Sun.")
      |> mes("A marsh is a Lunar place,")
      |> mes("its wolves driven by the Moon.")
      |> mes("A deep cave is a Stellar place, its knights enchanted by Stars.^000000''")
      |> next()
      |> mes("[Beeryu]")
      |> mes("According to these")
      |> mes("lyrics, which is of")
      |> mes("the following most")
      |> mes("strongly evokes the")
      |> mes("light of the moon?")
      |> next()
      |> select([
        "2nd, Marsh, Dark Knights",
        "4th, the Desert, the Sand",
        "10th, Deep Cave, Dark Knight",
        "5th, Marsh, Wolves"
      ])

    verse_points = if verse == 4, do: 10, else: 0

    ctx =
      ctx
      |> mes("[Beeryu]")
      |> mes("Well, I've asked the")
      |> mes("questions I wanted to set")
      |> mes("before you. You must learn")

    if shade_points + purpose_points + verse_points > 20 do
      pass_moon_test(ctx)
    else
      fail_moon_test(ctx)
    end
  end

  defp judge_moon_shade(ctx, 1) do
    ctx =
      ctx
      |> mes("[Beeryu]")
      |> mes("The Red Moon...?")
      |> mes("It's a fearsome sight,")
      |> mes("usually likened to drenching the sky with the color of blood.")
      |> mes("The Red Moon stirs dark feelings that we shouldn't fully embrace...")

    {ctx, 0}
  end

  defp judge_moon_shade(ctx, 2) do
    ctx =
      ctx
      |> mes("[Beeryu]")
      |> mes("The Blue Moon...?")
      |> mes("Ah, yes. It's a calm and")
      |> mes("gentle moon whose soft")
      |> mes("light helps you think clearly.")
      |> mes("It's a moon of peaceful rest...")

    {ctx, 10}
  end

  defp judge_moon_shade(ctx, 3) do
    ctx =
      ctx
      |> mes("[Beeryu]")
      |> mes("The Gold Moon...?")
      |> mes("Ah, that is a moon of")
      |> mes("affluence and wealth. Now,")
      |> mes("to aspire to attain prosperity")
      |> mes("is natural, and to fulfill your")
      |> mes("aspirations is life's pinnacle.")

    {ctx, 10}
  end

  defp judge_moon_shade(ctx, 4) do
    ctx =
      ctx
      |> mes("[Beeryu]")
      |> mes("Hmm...?")
      |> mes("Do you not have an")
      |> mes("opinion of the Moon?")
      |> mes("You should be confident")
      |> mes("and tell me which shade")
      |> mes("of the moon that you like...")

    {ctx, 0}
  end

  defp judge_moon_shade(ctx, _shade), do: {ctx, 0}

  defp judge_lunar_purpose(ctx, 1) do
    ctx =
      ctx
      |> mes("[Beeryu]")
      |> mes("Yes. Justice is always an")
      |> mes("end that is worth fighting")
      |> mes("for. Just remember that")
      |> mes("both power and compassion")
      |> mes("are required to enact the")
      |> mes("truest form of justice.")

    {ctx, 10}
  end

  defp judge_lunar_purpose(ctx, 2) do
    ctx =
      ctx
      |> mes("[Beeryu]")
      |> mes("Self training?")
      |> mes("That is an acceptable")
      |> mes("answer. However, you must")
      |> mes("never forget your reasons")
      |> mes("for attaining mastery of the")
      |> mes("self, else you lose your way.")

    {ctx, 10}
  end

  defp judge_lunar_purpose(ctx, 3) do
    ctx =
      ctx
      |> mes("[Beeryu]")
      |> mes("The preservation of")
      |> mes("nature is the responsiblity")
      |> mes("of every living human. However,")
      |> mes("I was expecting a different")
      |> mes("answer in terms of Taekwon")
      |> mes("Mastery as a martial art...")

    {ctx, 0}
  end

  defp judge_lunar_purpose(ctx, 4) do
    ctx =
      ctx
      |> mes("[Beeryu]")
      |> mes("Sometimes, revenge may")
      |> mes("seem to be best course of")
      |> mes("action, especially if it is")
      |> mes("carried out in the interest")
      |> mes("of justice. However, revenge")
      |> mes("by itself is usually ignoble.")
      |> next()
      |> mes("[Beeryu]")
      |> mes("Ask yourself this:")
      |> mes("what will you do after")
      |> mes("you achieve your revenge?")
      |> mes("When you let your rage burn")
      |> mes("away at you, you inflict the")
      |> mes("most harm to yourself...")

    {ctx, 0}
  end

  defp judge_lunar_purpose(ctx, _purpose), do: {ctx, 0}

  defp pass_moon_test(ctx) do
    ctx
    |> mes("the bond between the moonlight")
    |> mes("with the shadows of the moon.")
    |> mes("Then, you will become a master.")
    |> next()
    |> mes("[Beeryu]")
    |> mes("The soft moonlight ")
    |> mes("illuminates the darkest night.")
    |> mes("The shadows of the moon balance")
    |> mes("the Sun's glorious brightness.")
    |> mes("Wisdom to power, coolness to")
    |> mes("rage. Contemplate on this...")
    |> next()
    |> mes("[Beeryu]")
    |> mes("I have faith that you will soon")
    |> mes("become a great Taekwon Master.")
    |> mes("Now, the time has come for you")
    |> mes("to enter the Star Room. Come,")
    |> mes("follow me this way...")
    |> set_char_var(:STGL_Q, 6)
    |> close()
    |> warp("job_star", 166, 29)
  end

  defp fail_moon_test(ctx) do
    ctx
    |> mes("to be as patient and gentle")
    |> mes("as the moon's soft glow.")
    |> next()
    |> mes("[Beeryu]")
    |> mes("Please think about")
    |> mes("this seriously. A true")
    |> mes("Taekwon Master can")
    |> mes("display calmness of mind")
    |> mes("in all situations, no matter")
    |> mes("what the stakes may be.")
    |> next()
    |> mes("[Beeryu]")
    |> mes("Now, I want you to")
    |> mes("take this chance to")
    |> mes("practice achieving the")
    |> mes("Lunar mindset. Be calm,")
    |> mes("quiet your thoughts and")
    |> mes("settle your active mind...")
    |> next()
    |> mes("[Beeryu]")
    |> mes("For now, I will send")
    |> mes("you out into Payon. Go out")
    |> mes("and learn the ^4D4DFFtrue meaning")
    |> mes("of patience^000000. Then, when you're")
    |> mes("ready, please talk to Moogang")
    |> mes("so that he can send you to me.")
    |> set_char_var(:STGL_Q, 7)
    |> close()
    |> warp("payon", 164, 58)
  end

  defp send_to_sun_room(ctx) do
    ctx
    |> mes("[Beeryu]")
    |> mes("Hm. You must first pass")
    |> mes("testing the Room of the Sun")
    |> mes("before you can be tested here")
    |> mes("in the Moon Room. Let me send")
    |> mes("you to where you must go...")
    |> close()
    |> warp("job_star", 34, 12)
  end

  defp hurry_to_star_room(ctx) do
    ctx
    |> mes("[Beeryu]")
    |> mes("How are you still here?")
    |> mes("The light of the full moon")
    |> mes("brings comfort, but you must")
    |> mes("move on if you wish to become")
    |> mes("a Taekwon Master. Come, I shall")
    |> mes("guide you to the Star Room.")
    |> close()
    |> warp("job_star", 166, 29)
  end

  defp ask_for_proof_of_patience(ctx) do
    ctx
    |> mes("[Beeryu]")
    |> mes("I want you to bring me")
    |> mes("proof that you understand")
    |> mes("the nature of patience that")
    |> mes("is associated with the moon.")
    |> mes("You cannot become a Taekwon")
    |> mes("Master without this attitude...")
    |> next()
    |> mes("[Beeryu]")
    |> mes("The proof I want you to")
    |> mes("show me is concrete and")
    |> mes("indisputable. Please think")
    |> mes("about what it might be. Now,")
    |> mes("I shall send you back to town... ")
    |> close()
    |> warp("payon", 164, 58)
  end

  defp accept_proof_of_patience(ctx) do
    ctx
    |> mes("[Beeryu]")
    |> mes("Ah, you've finally")
    |> mes("returned. I can see in")
    |> mes("the way that you carry")
    |> mes("yourself that your resolve")
    |> mes("has been strengthened. Good.")
    |> mes("I hope you now know patience...")
    |> next()
    |> mes("[Beeryu]")
    |> mes("Patience and resolve are")
    |> mes("necessary to live life without")
    |> mes("any regrets. You must believe")
    |> mes("in yourself while being both")
    |> mes("considerate and understanding")
    |> mes("of others in cosmic harmony.")
    |> next()
    |> mes("[Beeryu]")
    |> mes("Learn to control your")
    |> mes("power through spiritual")
    |> mes("training. Learn how to have")
    |> mes("pride without hubris. You're")
    |> mes("ready for the Star Room, so")
    |> mes("I'll send you to Cheehee now.")
    |> set_char_var(:STGL_Q, 6)
    |> close()
    |> warp("job_star", 166, 29)
  end

  defp send_to_cheehee(ctx) do
    ctx
    |> mes("[Beeryu]")
    |> mes("You should be")
    |> mes("receiving Cheehee's")
    |> mes("tutelage in the Star Room")
    |> mes("now. Come, let me guide you")
    |> mes("there. I hope to see you as")
    |> mes("a Taekwon Master soon...")
    |> close()
    |> warp("job_star", 166, 29)
  end

  defp send_back_to_town(ctx) do
    ctx
    |> mes("[Beeryu]")
    |> mes("Why are you still here?")
    |> mes("You have something much")
    |> mes("more important to do, so")
    |> mes("let me send you back to town...")
    |> close()
    |> warp("payon", 164, 58)
  end

  defp offer_return_to_payon(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Beeryu]")
      |> mes("Try not to bother the")
      |> mes("Taekwon Boys and Girls")
      |> mes("from completing their job")
      |> mes("change test while you're here.")
      |> mes("Ah, and let me know when")
      |> mes("you want to return to Payon.")
      |> next()
      |> select(["Return to Payon", "Cancel"])

    if choice == 1 do
      ctx |> mes("[Beeryu]") |> mes("Be safe!") |> close() |> warp("payon", 164, 58)
    else
      ctx |> mes("[Beeryu]") |> mes("......") |> mes(".........") |> close()
    end
  end
end
