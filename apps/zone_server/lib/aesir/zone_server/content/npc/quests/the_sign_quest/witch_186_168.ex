defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Witch186168 do
  @moduledoc """
  Guides mortals through Kirkena's part of The Sign quest.

  ## Behavior

  - Helps a lost child and returns unprepared visitors to the living world.
  - Requests her missing spell books or the Symbol of Nine Realms as the quest progresses.

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
        map: "nif_in",
        x: 186,
        y: 168,
        dir: 1,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#witch",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])

    cond do
      get_char_var(ctx, :sign_q, 0) == 83 -> lost_child(ctx)
      get_char_var(ctx, :sign_q, 0) < 88 -> warning(ctx)
      get_char_var(ctx, :sign_q, 0) == 88 -> quest_request(ctx)
      get_char_var(ctx, :sign_q, 0) == 89 -> ask_about_symbol(ctx)
      true -> ctx
    end
  end

  defp lost_child(ctx) do
    cond do
      get_char_var(ctx, :sign_sq, 0) == 2 ->
        if count_item(ctx, 7304) > 0, do: recovered_book(ctx), else: send_mortal_home(ctx)

      get_char_var(ctx, :sign_sq, 0) == 3 ->
        if count_item(ctx, 7309) < 1, do: replace_wing(ctx), else: save_child(ctx)

      get_char_var(ctx, :sign_sq, 0) < 6 ->
        advise_return(ctx)

      get_char_var(ctx, :sign_sq, 0) == 6 ->
        wing_failed(ctx)

      get_char_var(ctx, :sign_sq, 0) == 7 ->
        child_is_dead(ctx)

      true ->
        warning(ctx)
    end
  end

  defp recovered_book(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kirkena]")
      |> mes("W-what's this?")
      |> mes("Why is it that")
      |> mes("you have one of")
      |> mes("my lost spell books?")
      |> next()
      |> select(["From a cursed soul..."])

    case choice do
      1 -> ask_mortal(ctx)
      _ -> ctx
    end
  end

  defp ask_mortal(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kirkena]")
      |> mes("Oh. That bastard must have")
      |> mes(
        "stolen my spell books and got cursed when he cast the spells without my permission. Still, it's a relief to have my spells back."
      )
      |> next()
      |> mes("[Kirkena]")
      |> mes("So mortal...")
      |> mes("You must be here for")
      |> mes("some reason. Speak")
      |> mes("your mind.")
      |> next()
      |> select([
        "Send me back to my world.",
        "There's a lost child here that I want to help..."
      ])

    case choice do
      1 -> send_home(ctx)
      2 -> give_wing(ctx)
      _ -> ctx
    end
  end

  defp send_home(ctx) do
    ctx
    |> mes("[Kirkena]")
    |> mes("Understood.")
    |> mes("Let me send")
    |> mes("you back to the")
    |> mes("realm of the living")
    |> mes("where you belong...")
    |> close2()
    |> warp("umbala", 132, 203)
  end

  defp give_wing(ctx) do
    ctx
    |> mes("[Kirkena]")
    |> mes("There's a living child?")
    |> mes("Here in Niflheim? That's")
    |> mes("most peculiar. Well, let me")
    |> mes("give you this. It will send")
    |> mes("a living human back to one")
    |> mes("of the towns in your realm.")
    |> delitem(7304, 1)
    |> set_char_var(:sign_sq, 3)
    |> give_item(7309, 1)
    |> close()
  end

  defp send_mortal_home(ctx) do
    ctx
    |> mes("[Kirkena]")
    |> mes("A mortal? What are you doing")
    |> mes("here? I'm not sure how more")
    |> mes("of you are able to get here,")
    |> mes("or your reasons for coming,")
    |> mes("but this place is dangerous")
    |> mes("for the living.")
    |> next()
    |> mes("[Kirkena]")
    |> mes("I'm sending you back")
    |> mes("to the realm of the living.")
    |> mes("If you can help it, you should")
    |> mes("probably avoid coming back")
    |> mes("to Niflheim...")
    |> close2()
    |> warp("umbala", 132, 203)
  end

  defp replace_wing(ctx) do
    ctx
    |> mes("[Kirkena]")
    |> mes("You lost the wing?")
    |> mes("Here, let me give you")
    |> mes("my last one. Now, hurry")
    |> mes("up and save that lost child!")
    |> set_char_var(:sign_sq, 4)
    |> give_item(7309, 1)
    |> close()
  end

  defp save_child(ctx) do
    ctx
    |> mes("[Kirkena]")
    |> mes("I just gave you")
    |> mes("that wing, right?")
    |> mes("Hurry and save that")
    |> mes("poor child stuck in")
    |> mes("Niflheim!")
    |> close()
  end

  defp advise_return(ctx) do
    ctx
    |> mes("[Kirkena]")
    |> mes("Hmm...")
    |> mes("If you don't have")
    |> mes("anything important to")
    |> mes("accomplish in Niflheim,")
    |> mes("you should probably return")
    |> mes("to the realm of the living...")
    |> close()
  end

  defp wing_failed(ctx) do
    ctx
    |> mes("[Kirkena]")
    |> mes("So did you already")
    |> mes("use the wing to save")
    |> mes("that poor, lost child?")
    |> next()
    |> mes("[Kirkena]")
    |> mes("What...?!")
    |> mes("It didn't work?")
    |> mes("That's impossible!")
    |> mes("Wait, give me a moment to")
    |> mes("think. What could be wrong?")
    |> set_char_var(:sign_sq, 7)
    |> close()
  end

  defp child_is_dead(ctx) do
    ctx
    |> mes("[Kirkena]")
    |> mes("Alright.")
    |> mes("Now I understand")
    |> mes("why the wing didn't")
    |> mes("work for that poor girl...")
    |> next()
    |> mes("[Kirkena]")
    |> mes("She's so young that")
    |> mes("she doesn't even know")
    |> mes("that she's dead. It's tragic,")
    |> mes("but there's no way for her")
    |> mes("to get out of here...")
    |> set_char_var(:sign_sq, 8)
    |> close()
  end

  defp warning(ctx) do
    ctx
    |> mes("[Kirkena]")
    |> mes("When people don't fully")
    |> mes("know the situation that")
    |> mes("they're in, they become more")
    |> mes("willing to take their chances.")
    |> close()
  end

  defp quest_request(ctx) do
    if count_item(ctx, 2642) > 0, do: request_symbol(ctx), else: request_books(ctx)
  end

  defp request_symbol(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Kirkena]")
      |> mes("As I expected,")
      |> mes("there is something behind")
      |> mes("all of this. Now, you may")
      |> mes("know where you are, but")
      |> mes("do you understand why")
      |> mes("the dead are here?")
      |> next()
      |> mes("[Kirkena]")
      |> mes("This realm is a place")
      |> mes("for warriors that have failed")
      |> mes("to prove their courage. Keep in")
      |> mes("mind that it's not too late for")
      |> mes("you to join their ranks.")
      |> next()
      |> mes("[Kirkena]")
      |> mes("The realm of Niflheim")
      |> mes("is ruled by the Queen of the")
      |> mes("Dead. Sometimes she appears")
      |> mes(
        "in her shining armor and makes the rounds. Everyone who sees her is stunned by the image of authority."
      )
      |> next()
      |> mes("[Kirkena]")
      |> mes("Now...")
      |> mes("What I need you to do is")
      |> mes("ask the Queen of the Dead")
      |> mes("for the Symbol of Nine Realms.")
      |> next()
      |> select(["What is that?"])

    {ctx, choice} =
      ctx
      |> mes("[Kirkena]")
      |> mes("The symbol acts as")
      |> mes("a voucher of the queen's")
      |> mes("authority and represents her")
      |> mes("undeniable right to rule over")
      |> mes("the dead. But right now, I can't")
      |> mes("explain why I need it.")
      |> next()
      |> mes("[Kirkena]")
      |> mes("I'll tell you why I need")
      |> mes("it once you bring me the")
      |> mes("queen's symbol. Now, please")
      |> mes("keep this secret and tell no one that I asked you to bring the symbol to me.")
      |> next()
      |> select(["Alright, I understand.", "How am I supposed to get the symbol?"])

    case choice do
      1 -> ctx |> set_char_var(:sign_q, 89) |> close()
      2 -> explain_symbol(ctx)
      _ -> ctx
    end
  end

  defp explain_symbol(ctx) do
    ctx =
      ctx
      |> mes("[Kirkena]")
      |> mes("Taking the symbol")
      |> mes("by force is out of the")
      |> mes("question. Not even the gods")
      |> mes("would consider battling the")
      |> mes("Queen of the Dead.")
      |> next()
      |> mes("[Kirkena]")
      |> mes("You will need to")
      |> mes("earn the queen's favor")
      |> mes("in order to even have")
      |> mes("a chance of obtaining")
      |> mes("the Symbol of Nine Realms.")
      |> next()
      |> mes("[Kirkena]")
      |> mes("Now, there is a rumor")
      |> mes("that the Queen of the Dead")
      |> mes(
        "is searching for her lost mother, Angrboda. Now, if you could find where Angrboda has been"
      )
      |> mes("sealed away...")
      |> next()
      |> mes("[Kirkena]")
      |> mes("When you need to meet")
      |> mes("me from now on, go ahead")
      |> mes("and take the ^FF0000secret passage")
      |> mes("through the right side of the")
      |> mes("portrait on the second floor^000000")

    ctx
    |> mes(
      Rathena.concat(
        Rathena.concat("of this castle, ", char_name(ctx, 0)),
        "."
      )
    )
    |> set_char_var(:sign_q, 92)
    |> next()
    |> mes("[Kirkena]")
    |> mes("If you use that piano")
    |> mes("to find me, I'll probably")
    |> mes("mistake you for one of the")
    |> mes("humans that need guidance")
    |> mes("out of Niflheim. So don't")
    |> mes("forget to use that passage.")
    |> close()
  end

  defp request_books(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kirkena]")
      |> mes("Did you need my help?")
      |> mes(
        "I know that I'm one of the few in Niflheim that are sympathetic with mortals, I've got a problem of my own that I need to deal with..."
      )
      |> next()
      |> select(["Never mind, sorry!", "What happened...?"])

    case choice do
      1 -> refuse_help(ctx)
      2 -> missing_books(ctx)
      _ -> ctx
    end
  end

  defp refuse_help(ctx) do
    ctx
    |> mes("[Kirkena]")
    |> mes("...")
    |> mes("Hrrmmmpf...")
    |> emotion(:hng)
    |> close()
  end

  defp missing_books(ctx) do
    ctx
    |> mes("[Kirkena]")
    |> mes("Recently, I've found that")
    |> mes("two of my spell books are")
    |> mes("missing. They contain some")
    |> mes("pretty potent spells that")
    |> mes("could cause disaster in")
    |> mes("incompetent hands...")
    |> next()
    |> mes("[Kirkena]")
    |> mes("I'm pretty sure they")
    |> mes("were stolen, so if you'd")
    |> mes("retrieve them for me from")
    |> mes("the thief, I'd be truly grateful. Then, I'd have my hands free")
    |> mes("to give the help you came for.")
    |> next()
    |> mes("[Kirkena]")
    |> mes("Oh, and next time you come")
    |> mes("to see me, go ahead and use")
    |> mes("the passage to the right of the portrait on the second floor")
    |> mes("of the castle.")
    |> set_char_var(:sign_q, 90)
    |> close()
  end

  defp ask_about_symbol(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Kirkena]")
      |> mes("...Hm?")
      |> mes("Is there")
      |> mes("something that")
      |> mes("you need to ask me?")
      |> next()
      |> select(["How can I get the symbol?"])

    ctx
    |> mes("[Kirkena]")
    |> mes("Taking the symbol")
    |> mes("by force is out of the")
    |> mes("question. Not even the gods")
    |> mes("would consider battling the")
    |> mes("Queen of the Dead.")
    |> next()
    |> mes("[Kirkena]")
    |> mes("You will need to")
    |> mes("earn the queen's favor")
    |> mes("in order to even have")
    |> mes("a chance of obtaining")
    |> mes("the Symbol of Nine Realms.")
    |> next()
    |> mes("[Kirkena]")
    |> mes("Now, there is a rumor")
    |> mes("that the Queen of the Dead")
    |> mes(
      "is searching for her lost mother, Angrboda. Now, if you could find where Angrboda has been"
    )
    |> mes("sealed away...")
    |> next()
    |> mes("[Kirkena]")
    |> mes("When you need to")
    |> mes("meet me from now on,")
    |> mes("go ahead and take passage")
    |> mes("through the right side of the")
    |> mes("portrait on the second")
    |> mes("floor of this castle.")
    |> set_char_var(:sign_q, 92)
    |> close()
  end
end
