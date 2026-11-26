defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.WealthyLookingMerchant do
  @moduledoc """
  Bakerlan administers the merchant portion of The Sign quest.

  ## Behavior

  - Directs the player through his steward’s assignments.
  - Awards a stone piece and experience after the assignments are complete.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta_in",
        x: 125,
        y: 101,
        dir: 5,
        sprite: 807,
        name: "Wealthy-looking Merchant",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Bakerlan]")
    progress = get_char_var(ctx, :sign_q, 0)

    cond do
      progress < 35 or progress == 98 -> idle(ctx)
      progress == 35 -> introduction(ctx)
      progress == 36 -> inspect_stones(ctx)
      progress < 40 -> delivery_reminder(ctx)
      progress == 40 -> next_assignment(ctx)
      progress < 52 -> unfinished(ctx)
      progress == 52 -> complete_test(ctx)
      progress == 97 -> dismissed(ctx)
      true -> encouragement(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp idle(ctx) do
    ctx
    |> mes("Umm...well then...")
    |> mes("I shall take the action for Prontera...")
    |> mes("And for Juno...")
    |> mes("Awww....")
    |> mes("Gosh, this is such a pain in the ass...")
    |> mes("Mumble mumble...")
    |> close()
  end

  defp delivery_reminder(ctx) do
    ctx
    |> mes("Please speak to my")
    |> mes("steward for all matters")
    |> mes("related to the delivery")
    |> mes("that you must complete")
    |> mes("for my test.")
    |> close()
  end

  defp next_assignment(ctx) do
    ctx
    |> mes("Ah yes, Mahatra tells")
    |> mes("me that you've completed")
    |> mes("the delivery. Well, um, he now")
    |> mes("has another assignment for")
    |> mes("for you to complete. So")
    |> mes("please talk to him again.")
    |> set_char_var(:sign_q, 41)
    |> close()
  end

  defp unfinished(ctx) do
    ctx
    |> mes("You have not finished yet.")
    |> mes("Why don't you go finish them first?")
    |> mes("I am a busy businessman.")
    |> close()
  end

  defp dismissed(ctx) do
    ctx
    |> mes("Umm....")
    |> mes("Did I see you wrong? Or did Metz do?")
    |> mes("...I do not have any more business with you.")
    |> mes("Take care now.")
    |> close()
  end

  defp encouragement(ctx) do
    ctx
    |> mes("How is it going?")
    |> mes("In fact, we want to do it on our own...")
    |> mes("but we are too preoccupied with our works...")
    |> mes("I hope you will keep up the good work.")
    |> mes("I am also curious what that stone is.")
    |> close()
  end

  defp introduction(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Gosh.....")
      |> mes("I do not know what I should do about Juno...")
      |> mes("?")
      |> mes("Who are you?")
      |> next()
      |> select(["Nothing.", "Mr. Metz sent me."])

    case choice do
      1 ->
        ctx
        |> mes("[Bakerlan]")
        |> mes("Hmm...")
        |> mes("I am pretty busy at this moment. So please do not interrupt me any further.")
        |> mes("If you are looking for a job,")
        |> mes("please inquire of my steward.")
        |> close()

      2 ->
        ctx
        |> mes("[Bakerlan]")
        |> mes("Ah....")
        |> mes("He did?....Hmmm..")
        |> mes("Unfortunately I am kind of busy...")
        |> mes("will you please come back later?")
        |> mes("Thank you.")
        |> set_char_var(:sign_q, 36)
        |> close()

      _ ->
        ctx
    end
  end

  defp inspect_stones(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Hmm...? You've")
      |> mes("finished all of the")
      |> mes("tests up until Dearle's")
      |> mes("challenge? Prove it to me")
      |> mes("with your pieces of the")
      |> mes("Sobbing Starlight...")
      |> next()
      |> select(["Give me a minute...", "Here..."])

    case choice do
      1 ->
        ctx
        |> mes("[Bakerlan]")
        |> mes("Well, you better")
        |> mes("come back soon. I'm")
        |> mes("a busy businessman, so")
        |> mes("my time is quite precious.")
        |> close()

      2 ->
        assess_stones(ctx)

      _ ->
        ctx
    end
  end

  defp assess_stones(ctx) do
    cond do
      count_item(ctx, 7177) < 5 ->
        ctx
        |> mes("[Bakerlan]")
        |> mes("Hmm, I suppose you")
        |> mes("still haven't completed")
        |> mes("all the tests. These aren't")
        |> mes("enough pieces of the Sobbing")
        |> mes("Starlight, you know...")
        |> close()

      count_item(ctx, 7177) == 5 ->
        ctx
        |> mes("[Bakerlan]")
        |> mes("Ah, now I see that")
        |> mes("you speak the truth.")
        |> mes("Alright, we can begin my test.")
        |> next()
        |> mes("[Bakerlan]")
        |> mes("First, I wish for you to make")
        |> mes(
          "a delivery. The object I want you to deliver is expensive and must be handled with care. Don't lose it or you will fail. Now, speak to my steward for more information."
        )
        |> set_char_var(:sign_q, 37)
        |> close()

      true ->
        ctx
        |> mes("[Bakerlan]")
        |> mes("Hm? It's not possible for")
        |> mes("you to have this many pieces")
        |> mes("of the Sobbing Starlight!")
        |> mes("These must be fakes. How")
        |> mes("dare you! Leave me!")
        |> close()
    end
  end

  defp complete_test(ctx) do
    ctx =
      ctx
      |> mes("Ah, I was informed about you.")
      |> mes("Well, although you have your goal,")
      |> mes("that does not necessarily mean to help that kid.")
      |> mes("Metz must have an eye for a right person, I assume.")
      |> next()
      |> mes("[Bakerlan]")
      |> mes("Well, I wanted to assign you some various tasks")
      |> mes("on my own plan, but recently I am very busy")
      |> mes("to take care of tradings with Kunlun and Amatsu.")
      |> next()
      |> mes("[Bakerlan]")
      |> mes("I found Seyling while I was trading with Amatsu few years ago.")
      |> mes("I introduced her brother to the royal family of Prontera, too.")
      |> mes("But anyways,")
      |> next()
      |> mes("[Bakerlan]")
      |> mes("I want to test you longer, but")
      |> mes("I am too busy for that. Also I don't think it is good for you.")
      |> mes("Let's finish the test now.")
      |> mes("You are qualified enough already.")
      |> next()
      |> mes("[Bakerlan]")
      |> mes("There you go.")
      |> mes("I am the last one who tested your qualification.")
      |> mes("Now bring all of the stone pieces to Metz.")
      |> mes("He will tell you what you need to do next.")
      |> set_char_var(:sign_q, 53)
      |> give_item(7177, 1)

    renewal = Rathena.truthy?(checkre(ctx, 3))

    experience =
      cond do
        base_level(ctx) < 60 -> 500
        base_level(ctx) < 70 -> 800
        base_level(ctx) < 80 -> 1_100
        base_level(ctx) < 90 -> 1_500
        true -> 2_000
      end

    experience = if renewal, do: experience, else: experience * 10

    ctx
    |> getexp(experience, 0)
    |> close()
  end
end
