defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21e.Stargladiator.Daru do
  @moduledoc """
  Daru tests Star Gladiator candidates in the Room of the Sun.

  ## Behavior

  - Asks three questions about the Sun; a near-perfect score sends the candidate to the Moon
    Room, otherwise the candidate must meditate and is later passed at random.
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
        x: 29,
        y: 33,
        dir: 0,
        sprite: 59,
        name: "Daru",
        scope: :shared,
        unique_name: "Daru#job_star"
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
      stage == 3 -> sun_test(ctx)
      stage == 4 -> proceed_to_moon_room(ctx)
      stage == 5 -> meditate_on_sun(ctx)
      stage == 6 -> send_to_star_room(ctx)
      stage == 7 -> send_to_solve_riddle(ctx)
      stage == 8 -> send_to_beeryu(ctx)
      stage > 8 and stage < 12 -> hurry_to_star_room(ctx)
      true -> send_back_to_town(ctx)
    end
  end

  defp sun_test(ctx) do
    {ctx, sight} =
      ctx
      |> mes("[Daru]")
      |> mes("Ah, greetings.")
      |> mes("I am Daru, and I will")
      |> mes("be your guide for this room.")
      |> mes("For this test, you must open")
      |> mes("your eyes and answer my")
      |> mes("questions. Let us begin.")
      |> next()
      |> mes("[Daru]")
      |> mes("Tell me.")
      |> mes("What is it")
      |> mes("that you see?")
      |> next()
      |> select(["The Sun.", "The Moon.", "The Stars.", "I have no idea."])

    {ctx, sight_points} = judge_sight(ctx, sight)

    {ctx, gift} =
      ctx
      |> next()
      |> mes("[Daru]")
      |> mes("Now, there is nothing")
      |> mes("that can live without the")
      |> mes("sun. Do you know what one")
      |> mes("needs most from the sun?")
      |> next()
      |> select(["Warmth", "Comfort", "Light", "Nothing"])

    {ctx, gift_points} = judge_sun_gift(ctx, gift)

    {ctx, verse} =
      ctx
      |> next()
      |> mes("[Daru]")
      |> mes("There is a song that goes,")
      |> mes("''^4D4DFFThe Sun shines on even days.")
      |> mes("The Moon gleams on odd days.")
      |> mes("The Stars sparkle on every")
      |> mes("fifth day without fail.^000000''")
      |> next()
      |> mes("[Daru]")
      |> mes("''^4D4DFFA desert is a Solar place,")
      |> mes("its sands kissed by the Sun.")
      |> mes("A marsh is a Lunar place,")
      |> mes("its wolves driven by the Moon.")
      |> mes("A deep cave is a Stellar place, its knights enchanted by Stars.^000000''")
      |> next()
      |> mes("[Daru]")
      |> mes("Now, which of the")
      |> mes("following combinations")
      |> mes("shines brightest among ")
      |> mes("them all? Think carefully...")
      |> next()
      |> select([
        "2nd, Marsh, Knights",
        "4th, Desert, Sand",
        "10th, Desert, Knights",
        "5th, Deep Cave, Wolves"
      ])

    verse_points = if verse == 2, do: 10, else: 0

    ctx =
      ctx
      |> mes("[Daru]")
      |> mes("Well, that will be all.")
      |> mes("I cannot possibly know all")
      |> mes("there is to know about you")
      |> mes("through just 3 questions...")
      |> mes("But this should suit our")
      |> mes("purposes for now.")
      |> next()

    case sight_points + gift_points + verse_points do
      30 -> pass_perfectly(ctx)
      25 -> pass_narrowly(ctx)
      _ -> fail_sun_test(ctx)
    end
  end

  defp judge_sight(ctx, 1) do
    ctx =
      ctx
      |> mes("[Daru]")
      |> mes("Yes! It is the sun!")
      |> mes("I suppose you can think")
      |> mes("of mankind as the sons of")
      |> mes("the sun. Good, very good...")

    {ctx, 10}
  end

  defp judge_sight(ctx, 2) do
    ctx =
      ctx
      |> mes("[Daru]")
      |> mes("The... The moon?")
      |> mes("Mm. But this is the")
      |> mes("Sun Room. Hmmm...")

    {ctx, 0}
  end

  defp judge_sight(ctx, 3) do
    ctx =
      ctx
      |> mes("[Daru]")
      |> mes("The Stars. Well, hmm.")
      |> mes("I suppose you can think of")
      |> mes("the Sun as one of thousands")
      |> mes("of stars in the universe...")

    {ctx, 5}
  end

  defp judge_sight(ctx, 4) do
    ctx =
      ctx
      |> mes("[Daru]")
      |> mes("No... idea?")
      |> mes("Hmm. You should")
      |> mes("open your mind as")
      |> mes("well as your eyes.")
      |> mes("It wouldn't hurt to")
      |> mes("try to guess an answer...")

    {ctx, 0}
  end

  defp judge_sight(ctx, _sight), do: {ctx, 0}

  defp judge_sun_gift(ctx, 1) do
    ctx =
      ctx
      |> mes("[Daru]")
      |> mes("That is right.")
      |> mes("Without the warmth")
      |> mes("of the sun, our world")
      |> mes("not only be cold, but it")
      |> mes("would be completely lifeless.")

    {ctx, 10}
  end

  defp judge_sun_gift(ctx, 2) do
    ctx =
      ctx
      |> mes("[Daru]")
      |> mes("Comfort...?")
      |> mes("Ah, yes. The warmth")
      |> mes("of the sun brings comfort.")
      |> mes("And without comfort, is life")
      |> mes("truly worth living? Good answer.")

    {ctx, 10}
  end

  defp judge_sun_gift(ctx, 3) do
    ctx =
      ctx
      |> mes("[Daru]")
      |> mes("Yes. Without the")
      |> mes("glorious light of the sun,")
      |> mes("we would see nothing.")
      |> mes("We would know nothing.")
      |> mes("We would be nothing.")

    {ctx, 10}
  end

  defp judge_sun_gift(ctx, 4) do
    ctx =
      ctx
      |> mes("[Daru]")
      |> mes("Mmm...")
      |> mes("The answer should")
      |> mes("come from your heart,")
      |> mes("rather than your mind.")
      |> mes("Everyone needs something")
      |> mes("from the sun. Let's see now...")

    {ctx, 0}
  end

  defp judge_sun_gift(ctx, _gift), do: {ctx, 0}

  defp pass_perfectly(ctx) do
    ctx
    |> mes("[Daru]")
    |> mes("I admit that I am impressed")
    |> mes("with your understanding of")
    |> mes("the Sun. It is the source of")
    |> mes("all life, the origin of warmth")
    |> mes("and comfort. Now, let me lead")
    |> mes("you to the Moon Room.")
    |> set_char_var(:STGL_Q, 4)
    |> close()
    |> warp("job_star", 100, 13)
  end

  defp pass_narrowly(ctx) do
    ctx
    |> mes("[Daru]")
    |> mes("Although your understanding")
    |> mes("of the Sun is not perfect, you")
    |> mes("seem to understand the idea")
    |> mes("that it is the source of warm")
    |> mes("and life in our world.")
    |> next()
    |> mes("[Daru]")
    |> mes("This idea is one of the basics")
    |> mes("that will help you in becoming")
    |> mes("more attuned with the power of")
    |> mes("the cosmos. Now, please come")
    |> mes("this way to the Moon Room...")
    |> set_char_var(:STGL_Q, 4)
    |> close()
    |> warp("job_star", 100, 13)
  end

  defp fail_sun_test(ctx) do
    ctx
    |> mes("[Daru]")
    |> mes("Hmm... If you do not")
    |> mes("understand the role of the")
    |> mes("sun in the universe and")
    |> mes("the human world, you will")
    |> mes("forever be out of touch with")
    |> mes("nature, with the cosmos.")
    |> next()
    |> mes("[Daru]")
    |> mes("I advise you to meditate")
    |> mes("carefully on the fundamental")
    |> mes("truths of nature before coming")
    |> mes("to speak to me once again.")
    |> mes("Contemplate the infinite")
    |> mes("power of the sun...")
    |> set_char_var(:STGL_Q, 5)
    |> close()
  end

  defp proceed_to_moon_room(ctx) do
    ctx
    |> mes("[Daru]")
    |> mes("There is no longer any")
    |> mes("need for us to remain")
    |> mes("here. Let us proceed to")
    |> mes("the Moon Room together.")
    |> close()
    |> warp("job_star", 100, 13)
  end

  defp meditate_on_sun(ctx) do
    if Enum.random(1..5) == 3 do
      ctx
      |> mes("[Daru]")
      |> mes("Hmmm. I believe you've")
      |> mes("spent enough time reflecting")
      |> mes("on the glory of the Sun and")
      |> mes("its importance to the humans")
      |> mes("and the world. Well done. Now,")
      |> mes("let's proceed to the Moon Room.")
      |> set_char_var(:STGL_Q, 4)
      |> close()
      |> warp("job_star", 100, 13)
    else
      ctx
      |> mes("[Daru]")
      |> mes("Relax every muscle in")
      |> mes("your body. Close your eyes.")
      |> mes("Feel the warmth of the Sun")
      |> mes("against your eyelids as you")
      |> mes("meditate on its role in the world and your place in the cosmos.")
      |> close()
    end
  end

  defp send_to_star_room(ctx) do
    ctx
    |> mes("[Daru]")
    |> mes("Hm? The time for you")
    |> mes("to be in the Room of the")
    |> mes("Sun has passed. Let us go")
    |> mes("to the Star Room now...")
    |> close()
    |> warp("job_star", 166, 29)
  end

  defp send_to_solve_riddle(ctx) do
    ctx
    |> mes("[Daru]")
    |> mes("Ah, Beeryu must have")
    |> mes("given you his riddle to")
    |> mes("solve. Well, you'll need")
    |> mes("to go back to town in order")
    |> mes("to figure out the answer, so")
    |> mes("let me send you there now~")
    |> close()
    |> warp("payon", 164, 58)
  end

  defp send_to_beeryu(ctx) do
    ctx
    |> mes("[Daru]")
    |> mes("Hm? Beeryu is expecting")
    |> mes("you in the Moon Room. Let")
    |> mes("me send you there right now...")
    |> close()
    |> warp("job_star", 100, 13)
  end

  defp hurry_to_star_room(ctx) do
    ctx
    |> mes("[Daru]")
    |> mes("Hm. I cannot blame")
    |> mes("you if you enjoy the")
    |> mes("Room of the Sun this")
    |> mes("much, but now is the time")
    |> mes("for you to be in the Star")
    |> mes("Room. I'll send you there...")
    |> close()
    |> warp("job_star", 166, 29)
  end

  defp send_back_to_town(ctx) do
    ctx
    |> mes("[Daru]")
    |> mes("Hm. I cannot blame")
    |> mes("you if you enjoy the")
    |> mes("Room of the Sun this")
    |> mes("much, but you have very")
    |> mes("important task to complete")
    |> mes("now. Let me send you to town.")
    |> close()
    |> warp("payon", 164, 58)
  end

  defp offer_return_to_payon(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Daru]")
      |> mes("While you're here,")
      |> mes("I ask that you don't")
      |> mes("interfere with anyone")
      |> mes("that may be taking the")
      |> mes("job change test. So, would")
      |> mes("you like to return to town?")
      |> next()
      |> select(["Return to Payon", "Cancel"])

    if choice == 1 do
      ctx
      |> mes("[Daru]")
      |> mes("I see. Let me")
      |> mes("guide you back")
      |> mes("to Payon, then.")
      |> close()
      |> warp("payon", 164, 58)
    else
      ctx
      |> mes("[Daru]")
      |> mes("Please take your")
      |> mes("time and enjoy the")
      |> mes("splendor of the Sun")
      |> mes("while you are here.")
      |> close()
    end
  end
end
