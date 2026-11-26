defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Witch do
  @moduledoc """
  Kirkena the witch, who leads the Sign quest's Niflheim chapter from her stolen spell books
  to stopping Serin.

  ## Behavior

  - Refuses to talk while the player is overweight.
  - Sends allies carrying exactly one Witch's Medal straight to Serin or to the path towards her.
  - Takes back her spell book and asks for the Symbol of Nine Realms, hinting at Angrboda while
    the player searches for it.
  - Takes the symbol and Serin's gold ring (or notes that it is missing), then explains her plan
    over three topics; hearing all three completes the potion.
  - Hands out the Witch's Potion and five Witch's Medals (plus a gold ring replica when the real
    ring was brought) and sends the player to Serin, one party at a time.
  - Rewards base EXP once the medals come back or Serin was stopped, and closes the chapter
    with a smaller reward when the player failed.

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
  - The medal ally check `(sign_q != 124) || (sign_q != 125) || (sign_q != 126)` was always
    true, so a quester at stage 124 to 126 holding one medal got the ally prompt; it now
    excludes those stages (`&&`).
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_sign01",
        x: 122,
        y: 141,
        dir: 4,
        sprite: 792,
        name: "Witch",
        scope: :shared,
        unique_name: "Witch#s"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])

    if checkweight(ctx, [{1201, 1}]) == 0 do
      ctx
      |> mes("- Wait a minute !! -")
      |> mes("- Currently you're carrying -")
      |> mes("- too many items with you. -")
      |> mes("- Please try again -")
      |> mes("- after you lose some weight. -")
      |> close()
    else
      ctx |> mes("[Kirkena]") |> talk()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp talk(ctx) do
    stage = get_char_var(ctx, :sign_q, 0)

    if count_item(ctx, 7313) == 1 and stage not in [124, 125, 126] do
      send_ally(ctx)
    else
      by_stage(ctx, stage)
    end
  end

  defp by_stage(ctx, 90), do: missing_spell_books(ctx)
  defp by_stage(ctx, 91), do: return_spell_book(ctx)
  defp by_stage(ctx, 92), do: angrboda_hint(ctx)

  defp by_stage(ctx, stage) when stage < 118 do
    ctx
    |> mes("It may be almost")
    |> mes("impossible to obtain")
    |> mes("the Symbol of Nine Realms.")
    |> mes("Still, you and I both need it.")
    |> next()
    |> mes("[Kirkena]")
    |> mes("I hope you understand")
    |> mes("that the symbol is more")
    |> mes("than just a mere voucher.")
    |> mes("It actually contains")
    |> mes("enormous power...")
    |> close()
  end

  defp by_stage(ctx, 118), do: offer_symbol(ctx)
  defp by_stage(ctx, 119), do: check_gold_ring(ctx)
  defp by_stage(ctx, stage) when stage in [120, 121], do: explain_plan(ctx)
  defp by_stage(ctx, stage) when stage in [122, 123], do: hand_out_potion(ctx, stage)
  defp by_stage(ctx, stage) when stage in [124, 125, 198], do: send_to_serin(ctx)
  defp by_stage(ctx, stage) when stage in [127, 128], do: collect_medals(ctx)
  defp by_stage(ctx, stage) when stage in [135, 136], do: thank_for_stopping_serin(ctx)
  defp by_stage(ctx, 200), do: scold_failure(ctx)

  defp by_stage(ctx, stage) when stage > 200 do
    ctx
    |> mes("Hmpf.")
    |> mes("I don't really")
    |> mes("want to talk to")
    |> mes("you anymore.")
    |> close()
  end

  defp by_stage(ctx, stage) when stage > 130 and stage < 136 do
    ctx |> mes("You've got to hurry") |> mes("and stop Serin!") |> close()
  end

  defp by_stage(ctx, _stage) do
    ctx
    |> mes("Hm? Still exploring")
    |> mes("Niflheim? Although you're")
    |> mes("strong enough to survive,")
    |> mes("I still think you're risking")
    |> mes("your life by remaining here")
    |> mes("when you don't have to.")
    |> close()
  end

  defp send_ally(ctx) do
    {ctx, choice} =
      ctx
      |> mes("That Witch's Medal...")
      |> mes("You must be here to")
      |> mes("help your friend take")
      |> mes("care of Serin. Are you")
      |> mes("ready to go, #{char_name(ctx, 0)}?")
      |> next()
      |> select(["Yes.", "Not yet..."])

    case choice do
      1 ->
        choose_ally_path(ctx)

      2 ->
        ctx
        |> mes("[Kirkena]")
        |> mes("Please hurry...")
        |> mes("Time is of the essence...")
        |> close()

      _ ->
        ctx
    end
  end

  defp choose_ally_path(ctx) do
    {ctx, path} = select(ctx, ["Go directly to Serin", "Path Towards Serin"])

    case path do
      1 -> ctx |> thank_ally() |> close2() |> warp("que_sign01", 195, 189)
      2 -> ctx |> thank_ally() |> close2() |> warp("que_sign02", 35, 313)
      _ -> ctx
    end
  end

  defp thank_ally(ctx) do
    ctx
    |> mes("[Kirkena]")
    |> mes("Thank you")
    |> mes("for your help.")
    |> mes("Serin's threat may")
    |> mes("be too much for just")
    |> mes("one adventurer alone...")
  end

  defp missing_spell_books(ctx) do
    if count_item(ctx, 2642) == 1 do
      ctx
      |> mes("That bastard stole")
      |> mes("two spell books from me.")
      |> mes("You've brought one of them")
      |> mes("back, but the other book")
      |> mes("is still missing.")
      |> next()
      |> mes("[Kirkena]")
      |> mes("Would you please")
      |> mes("retrieve my other")
      |> mes("spell book for me,")
      |> mes("adventurer?")
      |> set_char_var(:sign_sq, 0)
      |> close()
    else
      ctx
      |> mes("Some bastard stole")
      |> mes("two of my spell books.")
      |> mes("I'd be grateful if you can")
      |> mes("find him in Niflheim and")
      |> mes("bring my books back to me.")
      |> close()
    end
  end

  defp return_spell_book(ctx) do
    if count_item(ctx, 7304) > 0 do
      ask_for_symbol(ctx)
    else
      ctx
      |> mes("Hmm...?")
      |> mes("Why haven't you")
      |> mes("brought my books")
      |> mes("back to me yet?")
      |> emotion(:hng)
      |> close()
    end
  end

  defp ask_for_symbol(ctx) do
    {ctx, _} =
      ctx
      |> mes("Once that fool stole my spell")
      |> mes("books, he was cursed after he")
      |> mes("cast those spells without my")
      |> mes("permission. I'm so relieved to")
      |> mes("finally hold these in my")
      |> mes("hands again.")
      |> next()
      |> mes("[Kirkena]")
      |> mes("Now mortal...")
      |> mes("Why is it that")
      |> mes("you've come to see me?")
      |> mes("I'm sure that there must")
      |> mes("be something you want.")
      |> next()
      |> select(["He asked me to see you for...."])

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

    {ctx, _} =
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
      |> select(["How am I supposed to get the symbol?"])

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
    |> delitem(7304, 1)
    |> set_char_var(:sign_q, 92)
    |> close()
  end

  defp angrboda_hint(ctx) do
    if Enum.random(1..10) < 9 do
      ctx
      |> mes("If you need to learn more")
      |> mes("about Angrboda, why don't you")
      |> mes("just ask around? I'm sure that")
      |> mes("everyone is aware that the queen")
      |> mes("is searching for her mother.")
      |> next()
      |> mes("[Kirkena]")
      |> mes("Once again, don't let")
      |> mes("anyone know that I've asked")
      |> mes("you to bring me the Symbol of")
      |> mes("the Nine Realms. I especially")
      |> mes("don't want Serin to find out.")
      |> next()
      |> mes("[Kirkena]")
      |> mes("If I can help it,")
      |> mes("I won't tolerate")
      |> mes("Serin's presense here")
      |> mes("in Niflheim. If I could")
      |> mes("banish her, I'd do it!")
      |> close()
    else
      ctx
      |> mes("I almost hate")
      |> mes("suggesting it, but")
      |> mes("I think Serin might")
      |> mes("have some information")
      |> mes("on Angrboda's whereabouts.")
      |> next()
      |> mes("[Kirkena]")
      |> mes("But remember to be")
      |> mes("careful around her.")
      |> mes("Something about that")
      |> mes("Serin isn't quite right...")
      |> close()
    end
  end

  defp offer_symbol(ctx) do
    {ctx, choice} =
      ctx
      |> mes("The Symbol of Nine Realms?")
      |> mes("How were you able to get that?!")
      |> mes(
        "Ah, you must have found the Queen of the Dead's mother, Angrboda, right? Great work~"
      )
      |> next()
      |> mes("[Kirkena]")
      |> mes("Now, if you'll just")
      |> mes("hand me the symbol, I'll tell")
      |> mes("you what we need to do next.")
      |> next()
      |> select(["Give the symbol.", "Don't give the symbol."])

    case choice do
      1 ->
        ctx
        |> mes("[Kirkena]")
        |> mes("Listen carefully.")
        |> mes("Since you were actually")
        |> mes(
          "able to get the symbol, I believe that you're the only person capable of performing this next task."
        )
        |> next()
        |> mes("[Kirkena]")
        |> mes("We're going to use this")
        |> mes("symbol to create something,")
        |> mes("but we need one last item.")
        |> mes("I need you to find something")
        |> mes("imbued with Serin's vibes.")
        |> next()
        |> mes("[Kirkena]")
        |> mes("Serin's already hid herself")
        |> mes("deep within Niflheim, but I'm")
        |> mes("sure you can find something")
        |> mes("if you can find any remaining")
        |> mes("trace of her.")
        |> delitem(7305, 1)
        |> set_char_var(:sign_q, 119)
        |> close()

      2 ->
        ctx
        |> mes("[Kirkena]")
        |> mes("Huh...?")
        |> mes("Don't tell me that")
        |> mes("you've taken that wench's")
        |> mes("side! Well, I won't take the")
        |> mes("symbol against your will, but")
        |> mes("you better think this over...")
        |> emotion(:think)
        |> close()

      _ ->
        ctx
    end
  end

  defp check_gold_ring(ctx) do
    if count_item(ctx, 2642) > 0 do
      ctx
      |> mes("This is Serin's gold ring?")
      |> mes("Excellent, this has been")
      |> mes("strongly infused with her")
      |> mes(
        "vibes. It's really tough to find something like this that resonates so strongly with its owner."
      )
      |> delitem(2642, 1)
      |> set_char_var(:sign_q, 120)
      |> close()
    else
      ctx
      |> mes("Hmm, you don't have")
      |> mes("anything related to Serin.")
      |> mes("This isn't good. She's hid")
      |> mes("herself already and it might")
      |> mes("be too late to find any trace of her. I'll have to do something...")
      |> set_char_var(:sign_q, 121)
      |> close()
    end
  end

  defp explain_plan(ctx) do
    ctx
    |> mes("Now that the potion I'm")
    |> mes("making is being processed,")
    |> mes("I can finally tell you what")
    |> mes("I've been trying to do with")
    |> mes("the objects I've asked you")
    |> mes("to get for me.")
    |> next()
    |> mes("[Kirkena]")
    |> mes("I didn't explain the")
    |> mes("reason I wanted the Symbol")
    |> mes("of Nine Realms to prevent Serin")
    |> mes(
      "from getting suspicious and forcing you to reveal my plans. You see, Serin isn't fit for Niflheim."
    )
    |> next()
    |> mes("[Kirkena]")
    |> mes("Although she's in the")
    |> mes("world of the dead, Serin")
    |> mes("has never accepted death and")
    |> mes(
      "has desired to return to life. Of course, that's the natural response for everyone that comes here..."
    )
    |> next()
    |> mes("[Kirkena]")
    |> mes("However, unlike the others")
    |> mes("who have despaired, lost")
    |> mes("hope and accepted their fate,")
    |> mes(
      "Serin has never given up her hope to return to life. With her hope, she retains her beauty and light."
    )
    |> next()
    |> mes("[Kirkena]")
    |> mes("But she's only denying")
    |> mes("the fate she deserves.")
    |> mes("What she's trying to do")
    |> mes("is wrong and we need to")
    |> mes("stop her before it's too late.")
    |> next()
    |> plan_topics()
  end

  defp plan_topics(ctx) do
    {ctx, topic} =
      select(ctx, ["What does she want?", "What is she going to do?", "What should I do?"])

    case topic do
      1 -> ctx |> explain_serin_wants() |> hear_topic(:kir_talk1) |> after_topic()
      2 -> ctx |> explain_serin_plans() |> hear_topic(:kir_talk2) |> after_topic()
      3 -> ctx |> explain_potion() |> hear_topic(:kir_talk3) |> after_topic()
      _ -> ctx
    end
  end

  defp after_topic(ctx) do
    if get_char_var(ctx, :sign_q, 0) in [122, 123] do
      close(ctx)
    else
      plan_topics(ctx)
    end
  end

  defp hear_topic(ctx, topic) do
    ctx = set_local(ctx, topic, 1)

    if get_local(ctx, :kir_talk1, 0) == 1 and get_local(ctx, :kir_talk2, 0) == 1 and
         get_local(ctx, :kir_talk3, 0) == 1 do
      complete_potion(ctx, get_char_var(ctx, :sign_q, 0))
    else
      ctx
    end
  end

  defp complete_potion(ctx, 120), do: set_char_var(ctx, :sign_q, 122)
  defp complete_potion(ctx, 121), do: set_char_var(ctx, :sign_q, 123)
  defp complete_potion(ctx, _stage), do: ctx

  defp explain_serin_wants(ctx) do
    ctx
    |> mes("[Kirkena]")
    |> mes("Make no mistake:")
    |> mes("Serin wants the Symbol")
    |> mes("of the Nine Realms. ")
    |> next()
    |> mes("[Kirkena]")
    |> mes("Now, if she could use it")
    |> mes("multiple times, she could just")
    |> mes("command the guards of Niflheim")
    |> mes(
      "to just let her pass and re-enter the world of the living. But your symbol can be used just once..."
    )
    |> next()
  end

  defp explain_serin_plans(ctx) do
    ctx
    |> mes("[Kirkena]")
    |> mes("I believe Serin is going to")
    |> mes("summon the Dark Lord. Since")
    |> mes("she used to be a great wizard,")
    |> mes(
      "it's entirely possible. However, she might need the Symbol of the Nine Realms in order to do it."
    )
    |> next()
    |> mes("[Kirkena]")
    |> mes("Now, you may believe that")
    |> mes("Dark Lord can be defeated by")
    |> mes("humans, but what you might not")
    |> mes(
      "know is that the manifestation of Dark Lord in your world is limited to a fraction of his true power."
    )
    |> next()
    |> mes("[Kirkena]")
    |> mes("Sometimes Dark Lord can")
    |> mes("cross over into Midgard,")
    |> mes("but traveling from his world into")
    |> mes(
      "ours takes vast amounts of energy. Also the life force in your world conflicts with his dark powers."
    )
    |> next()
    |> mes("[Kirkena]")
    |> mes("Now, if Dark Lord were")
    |> mes("summoned into Niflheim,")
    |> mes("he would have easy access")
    |> mes("to Midgard and the use")
    |> mes("of all of his destructive power.")
    |> next()
    |> mes("[Kirkena]")
    |> mes("Serin plans to strike")
    |> mes("a deal with Dark Lord:")
    |> mes("In exchange for summoning")
    |> mes("him to Niflheim, Serin will")
    |> mes("be brought back to life.")
    |> next()
    |> mes("[Kirkena]")
    |> mes("Although you've found")
    |> mes("favor with Lady Hell, she")
    |> mes("will probably not stop Dark")
    |> mes("Lord's approach. Dark Lord")
    |> mes("only wants Midgard.")
    |> next()
    |> mes("[Kirkena]")
    |> mes("Now that I think about")
    |> mes("it, massive death would")
    |> mes("actually increase Lady Hell's")
    |> mes("sphere of influence. I don't think she'll help Dark Lord, but she")
    |> mes("also won't get in his way.")
    |> next()
  end

  defp explain_potion(ctx) do
    ctx
    |> mes("[Kirkena]")
    |> mes("I need you to take")
    |> mes("this tonic and have")
    |> mes("Serin drink it. This")
    |> mes("special potion will erase")
    |> mes("most of her memories.")
    |> next()
    |> mes("[Kirkena]")
    |> mes("Without her memories,")
    |> mes("Serin should also lose")
    |> mes("her twisted ambitions.")
    |> mes("Now, with the Symbol of Nine Realms, Serin cannot refuse drinking this potion.")
    |> next()
    |> mes("[Kirkena]")
    |> mes("That's why having the")
    |> mes("symbol is so crucial.")
    |> mes("Serin is clever enough")
    |> mes("to avoid drinking this")
    |> mes("for quite a while now...")
    |> next()
  end

  defp hand_out_potion(ctx, stage) do
    ctx
    |> mes("The potion is finally")
    |> mes("completed. Now, take this")
    |> mes("and command Serin to drink it.")
    |> next()
    |> mes("[Kirkena]")
    |> send_with_potion(stage)
  end

  defp send_with_potion(ctx, 122) do
    ctx
    |> mes("Luckily, I was able to")
    |> mes("use Serin's gold ring to")
    |> mes("trace her location. I'm going")
    |> mes("to send you there, so please")
    |> mes("do whatever it takes to stop her.")
    |> next()
    |> mes("[Kirkena]")
    |> mes("Please take these with you")
    |> mes("as they'll probably be useful")
    |> mes("when you deal with her. As for")
    |> mes(
      "these vouchers, give them to your allies. They'll send them straight to where Serin is located."
    )
    |> next()
    |> mes("[Kirkena]")
    |> mes("When you're finished")
    |> mes("dealing with Serin, don't")
    |> mes("forget to bring back all")
    |> mes("of the vouchers I've")
    |> mes("given you, alright?")
    |> set_char_var(:sign_q, 124)
    |> give_item(7308, 1)
    |> give_item(2643, 1)
    |> give_item(7313, 5)
    |> close()
  end

  defp send_with_potion(ctx, 123) do
    ctx
    |> mes("I'm not exactly sure")
    |> mes("where Serin is hiding,")
    |> mes("but I'll send you to her")
    |> mes("general location. Do")
    |> mes("everything in your")
    |> mes("power to stop her.")
    |> next()
    |> mes("[Kirkena]")
    |> mes("Now, I'm lending you")
    |> mes("these Witch's Medals. You")
    |> mes("may lend these to your allies")
    |> mes("to help you deal with Serin.")
    |> mes("Remember, if they carry more")
    |> mes("than one, they won't work.")
    |> next()
    |> mes("[Kirkena]")
    |> mes("Let your allies know")
    |> mes("that they have to take")
    |> mes("the secret passge through")
    |> mes("the right side of the portrait")
    |> mes("on the castle's second floor.")
    |> mes("Then, I can send them to Serin. ")
    |> next()
    |> mes("[Kirkena]")
    |> mes("When you're finished")
    |> mes("dealing with Serin, don't")
    |> mes("forget to bring back all of")
    |> mes("the Witch's Medals that")
    |> mes("I've lent to you, alright?")
    |> set_char_var(:sign_q, 124)
    |> give_item(7308, 1)
    |> give_item(7313, 5)
    |> close()
  end

  defp send_to_serin(ctx) do
    cond do
      get_server_temp_var(ctx, "sign_w1", 0) == 1 ->
        ctx
        |> mes("Please wait")
        |> mes("a bit. I'm still")
        |> mes("trying to finish")
        |> mes("these preparations...")
        |> close()

      count_item(ctx, 2643) == 1 ->
        send_to_serin_directly(ctx)

      true ->
        send_towards_serin(ctx)
    end
  end

  defp send_to_serin_directly(ctx) do
    {ctx, choice} =
      ctx
      |> mes("You're finally")
      |> mes("back. We might not")
      |> mes("have enough time to")
      |> mes("stop her, but we have")
      |> mes("to try. Are you ready?")
      |> next()
      |> select(["Yes", "No"])

    case choice do
      1 -> ctx |> close2() |> set_server_temp_var("sign_w1", 1) |> warp("que_sign01", 195, 189)
      2 -> urge_hurry(ctx)
      _ -> ctx
    end
  end

  defp send_towards_serin(ctx) do
    {ctx, choice} =
      ctx
      |> mes("We've got to")
      |> mes("stop Serin before")
      |> mes("she does something")
      |> mes("truly horrible. Are")
      |> mes("you ready to go?")
      |> next()
      |> select(["Yes", "No"])

    case choice do
      1 ->
        ctx
        |> mes("[Kirkena]")
        |> mes("Okay then.")
        |> mes("Good luck,")
        |> mes("#{char_name(ctx, 0)}...")
        |> close2()
        |> warp("que_sign02", 35, 313)

      2 ->
        urge_hurry(ctx)

      _ ->
        ctx
    end
  end

  defp urge_hurry(ctx) do
    ctx
    |> mes("[Kirkena]")
    |> mes("Hurry up, then!")
    |> mes("There's no time")
    |> mes("to waste!")
    |> close()
  end

  defp collect_medals(ctx) do
    cond do
      count_item(ctx, 7313) < 5 ->
        ctx
        |> mes("Hmmm...?")
        |> mes("Where are all the")
        |> mes("vouchers I've lent to you?")
        |> mes("Please retrieve them all")
        |> mes("before coming back to me.")
        |> close()

      count_item(ctx, 2643) == 1 ->
        ctx
        |> serin_at_peace(
          "please visit our queen, Lady Hell. I believe she wants to see you for some reason, #{char_name(ctx, 0)}..."
        )
        |> delitem(7313, 5)
        |> set_char_var(:sign_q, 129)
        |> getexp(exp_reward(ctx, 50_000, 500_000), 0)
        |> close()

      true ->
        ctx
        |> serin_at_peace(
          "please visit our queen, Lady Hell. I believe she wants to see you for some reason..."
        )
        |> delitem(7313, 5)
        |> set_char_var(:sign_q, 130)
        |> getexp(exp_reward(ctx, 30_000, 300_000), 0)
        |> close()
    end
  end

  defp thank_for_stopping_serin(ctx) do
    ctx =
      ctx
      |> mes("I'm so relieved that")
      |> mes("my expectations about")
      |> mes("you weren't wrong.")
      |> next()
      |> mes("[Kirkena]")
      |> serin_at_peace(
        "please visit our queen, Lady Hell. I believe she wants to see you for some reason..."
      )

    stage = if count_item(ctx, 2643) == 1, do: 129, else: 130

    ctx
    |> set_char_var(:sign_q, stage)
    |> getexp(exp_reward(ctx, 30_000, 300_000), 0)
    |> close()
  end

  defp serin_at_peace(ctx, farewell) do
    ctx
    |> mes("You've done well.")
    |> mes("Without her memories of her")
    |> mes("previous life, Serin can remain")
    |> mes("here in Niflheim peacefully.")
    |> next()
    |> mes("[Kirkena]")
    |> mes(
      "Although she failed to return to life, I'm sure she is glad to have met you. I think she's also started to learn that life's meaning is not in living alone..."
    )
    |> next()
    |> mes("[Kirkena]")
    |> mes("Once again, thank")
    |> mes("you so much for your")
    |> mes("help. Once you finish here,")
    |> mes(farewell)
  end

  defp scold_failure(ctx) do
    ctx =
      ctx
      |> mes("How could you fail when")
      |> mes("the stakes are so high?")
      |> mes("Serin almost summoned")
      |> mes("the Dark Lord, but luckily,")
      |> mes("somebody else stopped")
      |> mes("her in the nick of time.")
      |> next()
      |> mes("[Kirkena]")
      |> mes(
        "Fortunately, there are many people who are coming to Niflheim as part of the ordeals set before them by the gods. It looks like you just failed that ordeal, and Valkyrie will choose someone else."
      )
      |> next()
      |> mes("[Kirkena]")
      |> mes("It's over. You failed.")
      |> mes("Still, consider yourself")
      |> mes("lucky. Your soul could have")
      |> mes("been bound to Niflheim if it")
      |> mes("weren't for Serin's wish for")
      |> mes("you to remain free.")
      |> next()
      |> mes("[Kirkena]")
      |> mes("You really should thank")
      |> mes("her for that. Though, it's")
      |> mes("ironic that you failed your")
      |> mes("ordeals for her sake...")

    ctx
    |> delete_if_carried(2642)
    |> delete_if_carried(7308)
    |> set_char_var(:sign_q, 201)
    |> getexp(exp_reward(ctx, 20_000, 200_000), 0)
    |> close()
  end

  defp delete_if_carried(ctx, item_id) do
    if count_item(ctx, item_id) > 0, do: delitem(ctx, item_id, 1), else: ctx
  end

  defp exp_reward(ctx, renewal, pre_renewal) do
    if Rathena.truthy?(checkre(ctx, 3)), do: renewal, else: pre_renewal
  end
end
