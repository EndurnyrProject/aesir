defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21e.Stargladiator.Cheehee do
  @moduledoc """
  Cheehee tests Star Gladiator candidates in the Star Room.

  ## Behavior

  - Starts the Star Room test for candidates arriving from the Moon Room, then at random asks
    for a Star Crumb and Star Dust.
  - Takes both items, then asks a question about the stars; any answer completes her testing
    and sends the candidate back to Moogang.
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
        x: 161,
        y: 33,
        dir: 0,
        sprite: 77,
        name: "Cheehee",
        scope: :shared,
        unique_name: "Cheehee#job_star"
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
      stage == 6 -> admire_stars(ctx)
      stage == 9 -> contemplate_stars(ctx)
      stage == 10 -> check_star_items(ctx)
      stage == 11 -> star_question(ctx)
      stage == 12 -> offer_to_leave(ctx)
      true -> offer_return_to_payon(ctx)
    end
  end

  defp admire_stars(ctx) do
    ctx
    |> mes("[Cheehee]")
    |> mes("Don't you think stars")
    |> mes("are so beautiful? They're")
    |> mes("like a pretty girl's teardrops")
    |> mes("shed on a background of ")
    |> mes("pitch black night sky...")
    |> set_char_var(:STGL_Q, 9)
    |> close()
  end

  defp contemplate_stars(ctx) do
    if Enum.random(1..5) == 3 do
      ctx
      |> mes("[Cheehee]")
      |> mes("The test I have for")
      |> mes("you is simple. Just")
      |> mes("bring me the items on")
      |> mes("this earth that come from")
      |> mes("the stars. Bring me a piece of a star and the sand of a star...")
      |> set_char_var(:STGL_Q, 10)
      |> changequest(7009, 7010)
      |> close()
    else
      ctx
      |> mes("[Cheehee]")
      |> mes("......")
      |> mes(".........")
      |> next()
      |> mes("^3355FFCheehee stands mesmerized,")
      |> mes("staring at the sky as if she were counting each and every single")
      |> mes("shining star in the heavens.^000000")
      |> close()
    end
  end

  defp check_star_items(ctx) do
    if count_item(ctx, 1000) > 0 and count_item(ctx, 1001) > 0 do
      ctx
      |> mes("[Cheehee]")
      |> mes("Oh? You've brought exactly")
      |> mes("what I've asked you to bring.")
      |> mes("Did you know that the spirit")
      |> mes("of the stars is used to enhance")
      |> mes("the armors and weapons that")
      |> mes("all adventurers use in battle?")
      |> next()
      |> mes("[Cheehee]")
      |> mes("Stars are linked to the")
      |> mes("ideas of wishes, dreams,")
      |> mes("hopes, magic and romance.")
      |> mes("Occasionally, the stars can")
      |> mes("be saddening, but it's a very")
      |> mes("sweet kind of sadness...")
      |> delitem(1000, 1)
      |> delitem(1001, 1)
      |> set_char_var(:STGL_Q, 11)
      |> close()
    else
      ctx
      |> mes("[Cheehee]")
      |> mes("The pieces of the stars...")
      |> mes("The sand of the stars. If you")
      |> mes("didn't bring them with you, then you won't find them here. You'll")
      |> mes("have to go out and find them out there before bringing them to me.")
      |> close()
      |> warp("payon", 164, 58)
    end
  end

  defp star_question(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Cheehee]")
      |> mes("Have you given any thought")
      |> mes("to the idea of feeling sadness")
      |> mes("from the stars? Perhaps this")
      |> mes("song will help you better")
      |> mes("understand, though I know")
      |> mes("you've already heard it...")
      |> next()
      |> mes("[Cheehee]")
      |> mes("''^4D4DFFThe Sun shines on even days.")
      |> mes("The Moon gleams on odd days.")
      |> mes("The Stars sparkle on every")
      |> mes("fifth day without fail.^000000''")
      |> next()
      |> mes("[Cheehee]")
      |> mes("''^4D4DFFA desert is a Solar place,")
      |> mes("its sands kissed by the Sun.")
      |> mes("A marsh is a Lunar place,")
      |> mes("its wolves driven by the Moon.")
      |> mes("A deep cave is a Stellar place, its knights enchanted by Stars.^000000''")
      |> next()
      |> mes("[Cheehee]")
      |> mes("Now...")
      |> mes("Which of the following")
      |> mes("groups shines brightest")
      |> mes("with starlight?")
      |> next()
      |> select([
        "5th day, Deep Cave, Sand",
        "10th day, Desert, Sand",
        "25th day, Deep Cave, Knights",
        "10th day, Desert, Knights"
      ])

    ctx =
      if answer == 3 do
        ctx
        |> mes("[Cheehee]")
        |> mes("You're right. The combination")
        |> mes("of the 25th day, a multiple of")
        |> mes("the number 5, and the Knights")
        |> mes("stationed in Deep Caves shines")
        |> mes("brightest with starlight.")
      else
        ctx
        |> mes("[Cheehee]")
        |> mes("Hmm...")
        |> mes("You must learn more")
        |> mes("about the nature of the")
        |> mes("Stars. You must understand")
        |> mes("the cosmos if you are to")
        |> mes("become a Taekwon Master.")
      end

    ctx
    |> next()
    |> mes("[Cheehee]")
    |> mes("If you can understand")
    |> mes("the lyrics of this song,")
    |> mes("you should understand the")
    |> mes("essense of being a Taekwon")
    |> mes("Master. Remember that light")
    |> mes("comes in different shades...")
    |> next()
    |> mes("[Cheehee]")
    |> mes("The glory of the sun, the")
    |> mes("gentle moonlight, and the")
    |> mes("melancholic twinkling of the")
    |> mes("stars are unique from each")
    |> mes("other. Please enjoy the starlight in this room as long as you like.")
    |> next()
    |> mes("[Cheehee]")
    |> mes("When you are ready,")
    |> mes("please go speak to")
    |> mes("Moogang again. I will")
    |> mes("let him know that you")
    |> mes("completed our testing.")
    |> set_char_var(:STGL_Q, 12)
    |> changequest(7010, 7011)
    |> close()
  end

  defp offer_to_leave(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Cheehee]")
      |> mes("Do you wish to")
      |> mes("leave the Star Room?")
      |> next()
      |> select(["Yes", "No"])

    if choice == 1 do
      ctx
      |> mes("[Cheehee]")
      |> mes("Then, I shall guide")
      |> mes("you to Payon, the closest")
      |> mes("town. Farewell for now...")
      |> close()
      |> warp("payon", 164, 58)
    else
      invite_to_stay(ctx)
    end
  end

  defp offer_return_to_payon(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Cheehee]")
      |> mes("The stars certainly")
      |> mes("are beautiful, aren't")
      |> mes("they? Would you like")
      |> mes("to return to Payon now?")
      |> next()
      |> select(["Yes", "No"])

    if choice == 1 do
      ctx
      |> mes("[Cheehee]")
      |> mes("I see.")
      |> mes("Let me guide")
      |> mes("you back to Payon.")
      |> close()
      |> warp("payon", 164, 58)
    else
      invite_to_stay(ctx)
    end
  end

  defp invite_to_stay(ctx) do
    ctx
    |> mes("[Cheehee]")
    |> mes("Please, take your")
    |> mes("time and enjoy the")
    |> mes("starlight in this room...")
    |> close()
  end
end
