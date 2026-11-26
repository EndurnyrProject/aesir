defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Wola do
  @moduledoc """
  Doctor Wola asks for help repairing her medicine pot.

  ## Behavior

  - Quest progress leads the player to collect materials and discuss Leblo’s medicine.
  - Approaching Wola advances the quest when she is distressed.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
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
        map: "payon_in03",
        x: 167,
        y: 149,
        dir: 3,
        sprite: 75,
        name: "Wola",
        scope: :shared,
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{907, 1}]) == 0 -> too_heavy(ctx)
      get_char_var(ctx, :diamond_edq, 0) == 18 -> meet_doctor(ctx)
      get_char_var(ctx, :diamond_edq, 0) == 19 -> bring_materials(ctx)
      get_char_var(ctx, :diamond_edq, 0) == 20 -> ask_medicine(ctx)
      true -> greeting(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :diamond_edq, 0) == 17 do
      ctx
      |> mes("[Wola]")
      |> mes("Oh, how can this be")
      |> mes("happening? What ")
      |> mes("should I do?")
      |> set_char_var(:diamond_edq, 18)
      |> close()
    else
      ctx
    end
  end

  defp too_heavy(ctx) do
    ctx
    |> mes("^3355FFWait a second!")
    |> mes("Right now, you're carrying")
    |> mes("too many things with you.")
    |> mes("Please come back after")
    |> mes("using the Kafra Service")
    |> mes("to store some of your items.^000000")
    |> close()
  end

  defp meet_doctor(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Hello? I'm here to")
    |> mes("see Doctor Wola.")
    |> next()
    |> mes("[Wola]")
    |> mes("Oh... Ah... Um...")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Excuse me, but do you")
    |> mes("know where I can find her?")
    |> next()
    |> mes("[Wola]")
    |> mes("I, um...")
    |> mes("Oh no! Wah!")
    |> mes("See what you did?!")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("I... I don't know")
    |> mes("what you're talking")
    |> mes("about. I'm just wanted")
    |> mes("to talk to Doctor Wola.")
    |> next()
    |> mes("[Wola]")
    |> mes("I'm Doctor Wola!")
    |> mes("And look! You made me")
    |> mes("drop the herbal medicine")
    |> mes("I was brewing! The pot")
    |> mes("is all broken now...")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Huh? Oh, I'm...")
    |> mes("I'm really sorry.")
    |> next()
    |> mes("[Wola]")
    |> mes("That's... That's")
    |> mes("quite alright. It's")
    |> mes("my fault, really.")
    |> mes("Waaah~! My pot!")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("I'm sorry, I don't know")
    |> mes("what's going on exactly.")
    |> mes("Was that pot expensive?")
    |> next()
    |> mes("[Wola]")
    |> mes("Oh, I'm acting stupid")
    |> mes("again! I don't have time")
    |> mes("to cry over a broken pot!")
    |> mes("I need to check my hands")
    |> mes("for any cuts! If they're")
    |> mes("hurt, I can't help anyone!")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("That's, uh, that")
    |> mes("sounds pretty serious.")
    |> mes("So how are your hands?")
    |> mes("They don't hurt, do they?")
    |> next()
    |> mes("[Wola]")
    |> mes("Oooh, never mind that!")
    |> mes("They're fine, thank goodness.")
    |> mes("What's important now is that")
    |> mes("you help me fix my herbal")
    |> mes("medicine pot. You're partly")
    |> mes("responsible, you know.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Okay. Just tell")
    |> mes("me what I should do.")
    |> mes("Hold on, I came here to")
    |> mes("ask you if you'd give me")
    |> mes("some medicine. You see--")
    |> next()
    |> mes("[Wola]")
    |> mes("Perfect! All the more")
    |> mes("reason you should help")
    |> mes("me fix this pot! I can't")
    |> mes("make any medicine without")
    |> mes("this pot now, can I? Let's")
    |> mes("see... I'll need glue, glue...")
    |> next()
    |> mes("[Wola]")
    |> mes("Hurry and get")
    |> mes("^0000FF20 Fine Sands^000000,")
    |> mes("^0000FF5 Empty Bottles^000000,")
    |> mes("^0000FF10 Brigans^000000, and")
    |> mes("^0000FF10 Soft Blades of Grass^000000.")
    |> mes("There's no time to waste!")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("You... You got it.")
    |> changequest(3111, 3112)
    |> set_char_var(:diamond_edq, 19)
    |> close()
  end

  defp bring_materials(ctx) do
    ctx =
      ctx
      |> mes("[Wola]")
      |> mes("Good, you're back.")
      |> mes("So you brought everything")
      |> mes("I need to glue my pot")
      |> mes("back together again?")
      |> next()

    if count_item(ctx, 7043) > 19 and count_item(ctx, 7054) > 9 and
         count_item(ctx, 7194) > 9 and count_item(ctx, 713) > 4 do
      {ctx, choice} =
        ctx
        |> mes("[Wola]")
        |> mes("Great. Give them here.")
        |> mes("I should grind this, mix")
        |> mes("that... Wait, was that right?")
        |> mes("What were these for again?")
        |> mes("Argh, I'm acting stupid again!")
        |> mes("You mind not watching me?")
        |> delitem(7043, 20)
        |> delitem(7054, 10)
        |> delitem(7194, 10)
        |> delitem(713, 5)
        |> next()
        |> mes("[Wola]")
        |> mes("Just... Just sit in")
        |> mes("that corner, don't say")
        |> mes("anything, and wait till")
        |> mes("I say I'm done, okay?!")
        |> next()
        |> mes("[Wola]")
        |> mes("...............................")
        |> mes("...............................")
        |> mes("...............................")
        |> next()
        |> mes("[Wola]")
        |> mes("...............................")
        |> mes("...............................")
        |> mes("...............................")
        |> mes("...............................")
        |> next()
        |> mes("[Wola]")
        |> mes("...............................")
        |> mes("...............................")
        |> mes("...............................")
        |> mes("...............................")
        |> mes("...............................")
        |> next()
        |> mes("[Wola]")
        |> mes("There. It's finally")
        |> mes("fixed. Oh wait, did you")
        |> mes("say something about needing")
        |> mes("some medicine? I completely")
        |> mes("forgot about that for a while.")
        |> mes("What did you say exactly?")
        |> changequest(3112, 3113)
        |> set_char_var(:diamond_edq, 20)
        |> next()
        |> select(["Will you go out with me?", "Leblo's back medicine?"])

      answer(ctx, choice, true)
    else
      ctx
      |> mes("[Wola]")
      |> mes("Hurry and get")
      |> mes("^0000FF20 Fine Sands^000000,")
      |> mes("^0000FF5 Empty Bottles^000000,")
      |> mes("^0000FF10 Brigans^000000, and")
      |> mes("^0000FF10 Soft Blades of Grass^000000.")
      |> mes("There's no time to waste!")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("You... You got it.")
      |> close()
    end
  end

  defp ask_medicine(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Wola]")
      |> mes("Sorry, I completely")
      |> mes("missed what you said")
      |> mes("earlier. Something about")
      |> mes("needing medicine from me?")
      |> next()
      |> select(["Will you go out with me?", "Leblo's back medicine?"])

    answer(ctx, choice, false)
  end

  defp answer(ctx, 1, first_time) do
    if sex(ctx) == 1 do
      ctx = if first_time, do: mes(ctx, "[Wola]"), else: ctx

      ctx
      |> mes("^666666*Blush*^000000 But it's too")
      |> mes("early for us to just go")
      |> mes("on a date. I'm sorry, it's...")
      |> mes("I have someone in mind.")
      |> mes("Still, I'm flattered that")
      |> mes("you think of me that way.")
      |> close()
    else
      ctx
      |> mes("[Wola]")
      |> mes("Wow, I can't believe")
      |> mes("I'm turning you down--")
      |> mes("a little surprised,")
      |> mes("actually. But yes.")
      |> mes("I have someone I like.")
      |> mes("And it's not really you. Sorry.")
      |> close()
    end
  end

  defp answer(ctx, 2, _first_time), do: explain_medicine(ctx)
  defp answer(ctx, _choice, _first_time), do: ctx

  defp explain_medicine(ctx) do
    ctx
    |> mes("[Wola]")
    |> mes("Leblo... Oh, that")
    |> mes("man in Geffen? Finally...")
    |> mes("He has the sense to send")
    |> mes("someone to get his meds.")
    |> mes("I already prepared it.")
    |> mes("Where did I put it now?")
    |> next()
    |> mes("[Wola]")
    |> mes("I want to double check")
    |> mes("his medicine first so")
    |> mes("please tell him that I'll")
    |> mes("have it delivered to him")
    |> mes("shortly. In a while, maybe?")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Um, you're not mad or")
    |> mes("anything? I gathered that")
    |> mes("you didn't like him much...")
    |> next()
    |> mes("[Wola]")
    |> mes("What are saying?")
    |> mes("I'm a doctor: we're duty")
    |> mes("bound to heal everyone we can!")
    |> mes("That's not to say that some")
    |> mes("patients suffer longer and")
    |> mes("more painful treatment...")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("(^666666She hates him!")
    |> mes("But I guess Leblo's life")
    |> mes("should be okay in her hands.^000000)")
    |> next()
    |> mes("[Wola]")
    |> mes("Alright, just let Leblo")
    |> mes("know that I'm taking care")
    |> mes("of him, that his life should")
    |> mes("be okay in my hands. I need")
    |> mes("to get back to work: please")
    |> mes("take care of yourself!")
    |> changequest(3113, 3114)
    |> set_char_var(:diamond_edq, 21)
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Wola]")
    |> mes("Food has a dramatic")
    |> mes("effect on your body:")
    |> mes("treat it like a drug, and")
    |> mes("watch what you eat. Oh,")
    |> mes("and do your research!")
    |> next()
    |> mes("[Wola]")
    |> mes("You know, your lifestyle")
    |> mes("and habits determine")
    |> mes("your health in the future.")
    |> mes("Take care of yourself!")
    |> close()
  end
end
