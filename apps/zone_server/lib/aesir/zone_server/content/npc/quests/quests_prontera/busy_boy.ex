defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.BusyBoy do
  @moduledoc """
  A delivery boy too afraid of airships to deliver his books.

  ## Behavior

  - Eligible adventurers can help him arrange his books and deliver them to Juno.
  - Reminds the player of the delivery until the books reach their recipient.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Evera
    - Samuray22
    - SinSloth
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 248,
        y: 212,
        dir: 3,
        sprite: 706,
        name: "Busy Boy",
        scope: :shared,
        unique_name: "Busy Boy#prt",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    cond do
      overweight?(ctx) -> overweight(ctx)
      base_level(ctx) <= 59 -> busy(ctx, false)
      get_char_var(ctx, :prt_curse, 0) == 0 -> worried(ctx)
      get_char_var(ctx, :prt_curse, 0) == 1 -> speak_again(ctx)
      get_char_var(ctx, :prt_curse, 0) == 2 -> ask_again(ctx)
      get_char_var(ctx, :prt_curse, 0) == 3 -> reminder(ctx)
      true -> busy(ctx, true)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    cond do
      overweight?(ctx) -> overweight(ctx)
      base_level(ctx) <= 59 -> ctx
      get_char_var(ctx, :prt_curse, 0) == 0 -> collision(ctx)
      get_char_var(ctx, :prt_curse, 0) == 3 -> reminder(ctx)
      true -> ctx
    end
  end

  defp overweight?(ctx) do
    max_weight(ctx) - weight(ctx) < 2000 or checkweight(ctx, [{1201, 1}]) == 0
  end

  defp overweight(ctx) do
    ctx
    |> mes("^3355FFWait a second!")
    |> mes("Right now, you're carrying")
    |> mes("too many things with you.")
    |> mes("Please come back after")
    |> mes("using the Kafra Service")
    |> mes("to store some of your items.^000000")
    |> close()
  end

  defp worried(ctx) do
    ctx
    |> mes("[Busy-Looking Boy]")
    |> mes("Aw nuts...")
    |> mes("What am I gonna do?")
    |> mes("I have to deliver these")
    |> mes("books, but... I... Oh man,")
    |> mes("I can't get scared now!")
    |> close()
  end

  defp speak_again(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Busy-Looking Boy]")
      |> mes("Aw nuts...")
      |> mes("What am I gonna do?")
      |> mes("I have to deliver these")
      |> mes("books, but... I... Oh man,")
      |> mes("I can't get scared now!")
      |> next()
      |> select(["Speak with him", "Ignore him"])

    if choice == 1 do
      speak_after_leaving(ctx)
    else
      ctx
      |> mes("[Busy-Looking Boy]")
      |> mes("Okay, okay...")
      |> mes("Don't even think")
      |> mes("about floating in")
      |> mes("the sky. You're like,")
      |> mes("so stable. Don't think...")
      |> mes("Just... Just board that ship...")
      |> close()
    end
  end

  defp speak_after_leaving(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Say, what seems")
      |> mes("to be the problem?")
      |> next()
      |> mes("[Busy-Looking Boy]")
      |> mes(".........?")
      |> next()
      |> mes("[Busy-Looking Boy]")

    ctx =
      if sex(ctx) == 1 do
        ctx |> mes("Ack! You're that clumsy") |> mes("dude who made me drop")
      else
        ctx |> mes("Ack! You're that ditzy") |> mes("chick who made me drop")
      end

    ctx =
      ctx
      |> mes("all of those books earlier!")
      |> mes("Wait, you ditched me before,")
      |> mes("so why act all concerned now?")
      |> emotion(:surprise)

    {ctx, _} = ctx |> next() |> select(["Well, I, um..."])
    ctx = mes(ctx, "[Busy-Looking Boy]")

    ctx =
      if sex(ctx) == 1 do
        ctx
        |> mes("Yeah... A real")
        |> mes("man wouldn't have")
        |> mes("ditched back then")
        |> mes("without helping me.")
        |> mes("You're a real creepo,")
        |> mes("you know that?")
      else
        ctx
        |> mes("Yeah... If you were")
        |> mes("a graceful and considerate")
        |> mes("lady, you woulda helped me")
        |> mes("out before. I'm right, huh?")
      end

    ctx =
      ctx
      |> next()
      |> mes("^3355FFYou instinctively")
      |> mes("kick over one of the")
      |> mes("piles of books next")
      |> mes("to the young boy.")
      |> mes("You couldn't help it:")
      |> mes("it was a natural reflex!^000000")
      |> next()
      |> specialeffect(:hitdark)
      |> emotion(:huk)
      |> mes("^3355FF*BAM!*^000000")
      |> next()
      |> emotion(:huk)
      |> mes("[Busy-Looking Boy]")
      |> mes("Ack! Those books...!")
      |> mes("It took me so long to")
      |> mes("stack all of those!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Oh no, what a mess!")
      |> mes("Here, let me help you")
      |> mes("arrange these nicely")
      |> mes("out of the bottom of")
      |> mes("my freakin' heart.")

    {ctx, _} =
      ctx
      |> emotion(:throb, playerattached(ctx))
      |> next()
      |> mes("[Busy-Looking Boy]")
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> emotion(:think)
      |> next()
      |> mes("[Busy-Looking Boy]")
      |> mes("Huh...?")
      |> mes("Oh, thanks for")
      |> mes("helping me out here.")
      |> mes("I really appreciate it.")
      |> next()
      |> select(["Are these all yours?"])

    delivery_pitch(ctx)
  end

  defp delivery_pitch(ctx) do
    ctx =
      ctx
      |> mes("[Busy-Looking Boy]")
      |> mes("These? Oh, I'm supposed")
      |> mes("to deliver these for my job.")
      |> mes("I need to take these to Juno")
      |> mes("from the Prontera Library")
      |> mes("for a client. However, um...")
      |> next()
      |> mes("[Busy-Looking Boy]")
      |> mes("Well...")
      |> mes("I get motion sick really")
      |> mes("easily, so it scares me to")
      |> mes("death to ride the Airship")
      |> mes("all the way to Juno.")
      |> emotion(:think)
      |> next()
      |> mes("[Busy-Looking Boy]")
      |> mes("Now I'm in trouble!")
      |> mes("I'm never late, but this")
      |> mes("time I just can't help it.")
      |> mes("There's nothing I can do!")
      |> mes("Oh, I'm gonna lose this job!")
      |> emotion(:cry)
      |> next()
      |> mes("[Busy-Looking Boy]")
      |> mes("Wait... You adventurers")
      |> mes("do a lot of traveling, right?")
      |> mes("If you're traveling to Juno,")
      |> mes("would you please deliver this")
      |> mes("for me? I'll be in real trouble")
      |> mes("if I don't send these books...")
      |> next()

    offer_delivery(ctx, :first)
  end

  defp ask_again(ctx) do
    ctx =
      ctx
      |> mes("[Busy-Looking Boy]")
      |> mes("Oh, hello again.")
      |> mes("Sorry, but I'm trying to")
      |> mes("concentrate here. Gonna...")
      |> mes("Summon all my courage...")
      |> mes("and b-board that Airship!")
      |> mes("Argh! No, I can't do it!")
      |> emotion(:think)
      |> next()

    offer_delivery(ctx, :again)
  end

  defp reminder(ctx) do
    ctx
    |> mes("[Busy-Looking Boy]")
    |> mes("Oh, please deliver")
    |> mes("those books I gave")
    |> mes("you to ^FF0000Mr. Karlomoff^000000, who")
    |> mes("should be waiting around")
    |> mes("the Juno Library. Thanks")
    |> mes("again for your help~")
    |> close()
  end

  defp busy(ctx, eligible?) do
    preparation =
      if eligible?,
        do: "these books,  need to... I need to make some preparations!",
        else: "these books, I need to... I need to make some preparations!"

    ctx
    |> mes("[Busy-Looking Boy]")
    |> mes("Ack! Would you leave")
    |> mes("me alone and let me work?")
    |> mes("I've got something important")
    |> mes("to do! When I finish arranging")
    |> mes(preparation)
    |> close()
  end

  defp collision(ctx) do
    ctx =
      ctx
      |> specialeffect(:hitdark)
      |> mes("^3355FF*BAM!*^000000")
      |> next()
      |> mes("[Busy Looking Boy]")
      |> mes("Hey, look out!")
      |> mes("Can't you be more")
      |> mes("careful?! Geeeeez!")
      |> emotion(:anger)
      |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Oops, I'm so sorry.")
      |> mes("Are you alright?")
      |> next()
      |> mes("[Busy Looking Boy]")
      |> mes("Yeah, no thanks to you!")
      |> mes("Oh... Don't worry, I'm fine.")
      |> next()
      |> mes("^3355FFYou notice that the boy")
      |> mes("dropped many hardcover")
      |> mes("books that are probably about")
      |> mes("ruins and their legends, based")
      |> mes("on their titles. The boy dusted")
      |> mes("himself off and began to")
      |> mes("carefully pile the books.^000000")
      |> next()
      |> select(["Leave", "Help him pile the books"])

    if choice == 1 do
      ctx
      |> mes("[Busy-Looking Boy]")
      |> mes("Next time, look")
      |> mes("where you're going,")
      |> mes("alright? I mean, you")
      |> mes("might really break")
      |> mes("something if you're")
      |> mes("always that careless!")
      |> set_char_var(:prt_curse, 1)
      |> close()
    else
      help_pile_books(ctx)
    end
  end

  defp help_pile_books(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Busy-Looking Boy]")
      |> mes("Huh...?")
      |> mes("Oh, thanks for")
      |> mes("helping me out here.")
      |> mes("I really appreciate it.")
      |> next()
      |> select(["Are these all yours?"])

    delivery_pitch(ctx)
  end

  defp offer_delivery(ctx, refusal) do
    {ctx, choice} = select(ctx, ["Help him", "Don't help him"])

    if choice == 1 do
      accept_delivery(ctx)
    else
      decline_delivery(ctx, refusal)
    end
  end

  defp accept_delivery(ctx) do
    ctx
    |> mes("[Busy-Looking Boy]")
    |> mes("Oh, thank you so much!")
    |> mes("You don't understand how")
    |> mes("much I dread those Airships.")
    |> mes("Now, would you please deliver")
    |> mes("these books to ^FF0000Mr. Karlomoff^000000")
    |> mes("near the Juno Library?")
    |> next()
    |> mes("[Busy-Looking Boy]")
    |> mes("I know these books are")
    |> mes("pretty heavy, but be really")
    |> mes("careful with them! Anyway,")
    |> mes("thanks for doing this for me.")
    |> mes("I was really at my wit's end...")
    |> set_char_var(:prt_curse, 3)
    |> give_item(7431, 1)
    |> close()
  end

  defp decline_delivery(ctx, :first) do
    ctx
    |> mes("[Busy-Looking Boy]")
    |> mes("I-I understand.")
    |> mes("It's none of your ")
    |> mes("business, I know, but")
    |> mes("I'm just so desperate...")
    |> emotion(:cry)
    |> set_char_var(:prt_curse, 2)
    |> close()
  end

  defp decline_delivery(ctx, :again) do
    ctx
    |> mes("[Busy-Looking Boy]")
    |> mes("^333333*Sob...*^000000")
    |> mes("What am I gonna do?")
    |> mes("That guy's been waiting")
    |> mes("for me to deliver his books")
    |> mes("for quite a while now...")
    |> emotion(:cry)
    |> close()
  end
end
