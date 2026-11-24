defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.AllenSchuwell do
  @moduledoc """
  Allen asks for help obtaining medicine and rewards the player for caring for him.

  ## Behavior

  - Sends eligible adventurers to find his son and asks for a White Potion.
  - Repeatedly asks for Withstander until Postell returns, then offers a reward.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hu_in01",
        x: 387,
        y: 245,
        dir: 0,
        sprite: 849,
        name: "Allen Schuwell",
        scope: :shared,
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @white_potion 504

  @impl true
  def on_event("OnTouch_", ctx) do
    case get_char_var(ctx, :hg_herb, 0) do
      4 -> request_drawer(ctx)
      7 -> request_more_medicine(ctx)
      _ -> ctx
    end
  end

  @impl true
  def on_talk(ctx) do
    if base_level(ctx) > 49 do
      case get_char_var(ctx, :hg_herb, 0) do
        0 -> request_son(ctx)
        2 -> request_potion(ctx)
        3 -> request_withstander(ctx)
        4 -> near_death(ctx)
        6 -> take_withstander(ctx)
        7 -> request_cpr(ctx)
        9 -> take_another_dose(ctx)
        10 -> postell_arrives(ctx)
        11 -> offer_reward(ctx)
        12 -> remind_reward(ctx)
        13 -> thank_player(ctx)
        _ -> groan(ctx)
      end
    else
      groan(ctx)
    end
  end

  defp request_son(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Allen]")
      |> mes("*Groooooan~*")
      |> mes("Arrrgh, my back hurts...")
      |> mes("And my stomach... Why do")
      |> mes("I have to suffer like this")
      |> mes("while other people get to")
      |> mes("live happy, luxurious lives?")
      |> next()
      |> mes("[Allen]")
      |> mes("My son is the only family")
      |> mes("I've got. He used to be such")
      |> mes("a good obedient kid, but now")
      |> mes("I doubt whether he cares about")
      |> mes("his father! I told that lazy kid to hurry and bring me my meds...")
      |> next()
      |> mes("[Allen]")
      |> mes("But does he worry about")
      |> mes("his father's suffering?! No!")
      |> mes("I bet you he's hanging out with")
      |> mes("his no good hoodlum friends!")
      |> mes("Argh! The pain is getting worse! I... I need my medication!")
      |> next()
      |> mes("[Allen]")
      |> mes("Oh! I can definitely feel")
      |> mes("it getting worse! Please,")
      |> mes("adventurer, would you help")
      |> mes("a sick man? I need you to")
      |> mes("find my son Postell and to")
      |> mes("tell him to bring my medicine!")
      |> next()
      |> select(["Sure.", "No, I'm sorry."])

    case choice do
      1 ->
        ctx
        |> mes("[Allen]")
        |> mes("Th-thank you so much!")
        |> mes("Please head east, go")
        |> mes("outside of town, and")
        |> mes("you should be able to")
        |> mes("find Postell. Tell him that")
        |> mes("I need my ''Kolbun A'' now!")
        |> set_char_var(:hg_herb, 1)
        |> setquest(8053)
        |> next()
        |> mes("[Allen]")
        |> mes("And let him know that")
        |> mes("if he doesn't shape up...")
        |> mes("Well, I just might have")
        |> mes("to disown my own son!")
        |> mes("He's dead to me if he")
        |> mes("doesn't love his father!")
        |> close()

      2 ->
        ctx
        |> mes("[Allen]")
        |> mes("I... I don't understand...!")
        |> mes("How can you leave a sick")
        |> mes("man alone with his suffering?")
        |> mes("I-I desperately need help!")
        |> mes("No! Please, d-don't go away!")
        |> close()

      _ ->
        ctx
    end
  end

  defp request_potion(ctx) do
    ctx =
      ctx
      |> mes("[Allen]")
      |> mes("Postell... My son...")
      |> mes("Why have you forsaken me?")
      |> mes("I'm lying here at the brink")
      |> mes("of death, and the boy won't")
      |> mes("even come to see his father!")
      |> next()
      |> mes("[Allen]")
      |> mes("But you... I can count on you.")
      |> mes("Even in Lighthalzen, I'd never")
      |> mes("find anyone as dependable as")
      |> mes("you. This time, I've decided to")
      |> mes("discipline my degenerate son.")
      |> mes("Will you help me once more?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Wait, wait...")
      |> mes("Lighthalzen?")
      |> mes("Did you used to")
      |> mes("live there or something?")
      |> next()
      |> mes("[Allen]")
      |> mes("Uh? Er, well, that's just")
      |> mes("an expression I use. You")
      |> mes("know, like an example.")
      |> mes("I-I--^333333*Cough!*^000000 Oh, oh no.")
      |> mes("My ^333333*Hack!*^000000 pancreas! Or liver!")
      |> mes("I'm having another attack!")
      |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("......")
      |> mes(".........")
      |> mes("............")
      |> next()
      |> mes("[Allen]")
      |> mes("Oh, everything's getting")
      |> mes("so dark! P-please, if you")
      |> mes("have any mercy at all, any")
      |> mes("shred of human decency,")
      |> mes("would you please let me")
      |> mes("have a White P-Potion?")
      |> next()
      |> select(["Give White Potion", "Ignore"])

    case choice do
      1 ->
        if not Rathena.truthy?(count_item(ctx, @white_potion)) do
          ctx
          |> mes("[Allen]")
          |> mes("Oh... Oh no...! You")
          |> mes("don't have any White")
          |> mes("Potions either?! Wh-what")
          |> mes("what am I gonna--?! Help me,")
          |> mes("please! Bring me a White Potion")
          |> mes("as soon as you can! ^333333*Cough!*^000000")
          |> close()
        else
          ctx =
            ctx
            |> delitem(@white_potion, 1)
            |> mes("[Allen]")
            |> mes("Oh, thank you!")
            |> mes("I-It hurts so much...")
            |> mes("A White Potion just has")
            |> mes("to help. I-It has to work!")
            |> next()

          ctx =
            ctx
            |> mes("[#{char_name(ctx, 0)}]")
            |> mes("......")
            |> mes(".........")
            |> mes("............")
            |> next()
            |> mes("[Allen]")
            |> mes("Ah, that... *Whew*")
            |> mes("Thank you so much. Now,")
            |> mes("all I need to do is wait for")
            |> mes("my son to bring my medicine.")
            |> mes("Wait. What if he takes too long")
            |> mes("to get here. No, no, what if...")
            |> next()
            |> mes("[Allen]")
            |> mes("Wh-what if I have another")
            |> mes("ulcer attack before Postell")
            |> mes("can bring my meds?! I might")
            |> mes("not survive! A-adventurer, would you please stay by my side until")
            |> mes("my son arrives? P-please?")
            |> next()
            |> set_char_var(:hg_herb, 3)
            |> changequest(8054, 8055)

          ctx
          |> mes("[#{char_name(ctx, 0)}]")
          |> mes("......")
          |> mes(".........")
          |> mes("............")
          |> close()
        end

      2 ->
        ctx
        |> mes("[Allen]")
        |> mes("W-wait! A-are you just")
        |> mes("going to let me d-die?")
        |> mes("Noo! ^333333*Cough*^000000 Arrgh! A plague!")
        |> mes("A plague on both your houses!")
        |> close()

      _ ->
        ctx
    end
  end

  defp request_withstander(ctx) do
    ctx
    |> mes("[Allen]")
    |> mes("*Gasp* I... I can")
    |> mes("feel it! I think I'm")
    |> mes("gonna have another")
    |> mes("neutron attack! Argh, it's")
    |> mes("already effecting all of the")
    |> mes("neutrons in my nervous system!")
    |> next()
    |> mes("[Allen]")
    |> mes("C-can't... Lift...")
    |> mes("Legs and fingers...")
    |> mes("But... Must... Get...")
    |> mes("''Withstander'' medicine...")
    |> mes("from... Drawer... H-heeelp me!")
    |> mes("Adventurer! H-Heeeeelp~!")
    |> set_char_var(:hg_herb, 4)
    |> close()
  end

  defp near_death(ctx) do
    ctx
    |> mes("[Allen]")
    |> mes("No...!")
    |> mes("There's a light at the")
    |> mes("the end of the tunnel!")
    |> mes("Please, adventurer! C-come")
    |> mes("a little closer to me! Don't")
    |> mes("let me step into the light!")
    |> close()
  end

  defp take_withstander(ctx) do
    ctx
    |> mes("^3355FFYou have given the")
    |> mes("Withstander medicine")
    |> mes("to Allen who guzzles")
    |> mes("it down very quickly.^000000")
    |> next()
    |> mes("[Allen]")
    |> mes("Blood... circulating...")
    |> mes("through limbs... Clarity...")
    |> mes("of thought... returning...")
    |> next()
    |> mes("[Allen]")
    |> mes("Ah, wh-what a relief. It looks")
    |> mes("like I-I live to see another")
    |> mes("day. Th-thank you so much...")
    |> set_char_var(:hg_herb, 7)
    |> close()
  end

  defp request_cpr(ctx) do
    ctx
    |> mes("[Allen]")
    |> mes("I... I can't...!")
    |> mes("I can barely breathe!")
    |> mes("A-adventurer, I need you")
    |> mes("again! Please, c-come closer")
    |> mes("to me! I-I think I need CPR!")
    |> close()
  end

  defp take_another_dose(ctx) do
    ctx =
      ctx
      |> mes("^3355FFYou give another dose")
      |> mes("of Withstander to Allen.^000000")
      |> next()

    if Enum.random(1..3) == 3 do
      ctx
      |> mes("[Allen]")
      |> mes("Oh... Thank you...")
      |> mes("I feel much b-better now.")
      |> mes("My son Postell, he should")
      |> mes("be coming soon. Thank you")
      |> mes("for being so patient with me...")
      |> set_char_var(:hg_herb, 10)
      |> close()
    else
      ctx =
        ctx
        |> mes("[Allen]")
        |> mes("Oh... Thank you...")
        |> mes("Y-you're an angel, a regular")
        |> mes("Florence Nightingale. Please")
        |> mes("stay with m-me until my son")
        |> mes("arrives. You wouldn't abandon")
        |> mes("this sick man now, would you?")
        |> next()

      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("(^333333Your son Postell")
      |> mes("better get here soon!^000000)")
      |> set_char_var(:hg_herb, 7)
      |> close()
    end
  end

  defp postell_arrives(ctx) do
    ctx =
      ctx
      |> mes("[Allen]")
      |> mes("Arrrgh! My ligaments!")
      |> mes("They're in such pain!")
      |> mes("Oh, oh no! I think my")
      |> mes("bones are infected!")
      |> mes("Help me, oh help me!")
      |> next()
      |> donpcevent("Postell Schuwell#D::OnEnable")
      |> mes("[Allen]")
      |> mes("Oh...")
      |> mes("My son...!")
      |> mes("P-Postell!")
      |> next()
      |> mes("[Postell]")
      |> mes("Uh... Hey, dad.")
      |> mes("I brought that")
      |> mes("medicine you're")
      |> mes("supposed to")
      |> mes("need so badly.")
      |> specialeffect(:changecold, :area, "Postell Schuwell#D")
      |> next()
      |> mes("[Allen]")
      |> mes("Thank goodness...")
      |> mes("G-give it to me!")
      |> mes("^333333*Gulp gulp gulp*^000000")
      |> next()
      |> mes("[Allen]")
      |> mes("W-wait...")
      |> mes("Something's not")
      |> mes("right. Bunkoll A")
      |> mes("doesn't taste like this...")

    ctx =
      ctx
      |> emotion(:sweat, getnpcid(ctx, "Postell Schuwell#D"))
      |> next()
      |> mes("[Postell]")
      |> mes("Bunkoll A...?")
      |> mes("I thougt you said that")
      |> mes("you wanted Kolbun A?")
      |> next()
      |> mes("[Allen]")
      |> mes("My own son, lying to")
      |> mes("me! Are you trying to")
      |> mes("trick me, Postell?!")
      |> mes("I told you get Bunkoll A!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("(^333333Wait, wait...")
      |> mes("Allen did say that")
      |> mes("he wanted Kolbun A...^000000)")
      |> next()
      |> mes("[Postell]")
      |> mes("Right. Okay, I guess")
      |> mes("I made a mistake? Um,")
      |> mes("Dad, I'll be right back with")
      |> mes("the medicine that you want.")
      |> mes("It won't take long, so don't")
      |> mes("stress yourself about it.")
      |> close()
      |> set_char_var(:hg_herb, 11)
      |> disablenpc("Postell Schuwell#D")

    ctx |> emotion(:sweat, playerattached(ctx)) |> emotion(:sweat)
  end

  defp offer_reward(ctx) do
    ctx
    |> mes("[Allen]")
    |> mes("*Sniff* I should have known")
    |> mes("that Postell really does care")
    |> mes("about me deep down inside.")
    |> mes("I wish I had never gotten")
    |> mes("myself sick in Lighthalzen...")
    |> mes("Then we both wouldn't suffer...")
    |> next()
    |> mes("[Allen]")
    |> mes("Don't worry, adventurer.")
    |> mes("I haven't forgotten about")
    |> mes("you. Please take a look inside")
    |> mes("the medicine drawer, and help")
    |> mes("yourself to whatever you like~")
    |> set_char_var(:hg_herb, 12)
    |> changequest(8055, 8056)
    |> close()
  end

  defp remind_reward(ctx) do
    ctx
    |> mes("[Allen]")
    |> mes("Don't worry, adventurer.")
    |> mes("I haven't forgotten about")
    |> mes("you. Please take a look inside")
    |> mes("the medicine drawer, and help")
    |> mes("yourself to whatever you like~")
    |> close()
  end

  defp thank_player(ctx) do
    ctx
    |> mes("[Allen]")
    |> mes("So did you find the")
    |> mes("Old Blue Box I put in")
    |> mes("my medicine drawer? It's")
    |> mes("not much, but I hope you")
    |> mes("like it. Consider my way")
    |> mes("of thanking you for your help~")
    |> close()
  end

  defp groan(ctx) do
    ctx
    |> mes("[Allen]")
    |> mes("*Groooooan~*")
    |> mes("Arrrgh, my back hurts...")
    |> mes("And my stomach... Why do")
    |> mes("I have to suffer like this")
    |> mes("while other people get to")
    |> mes("live happy, luxurious lives?")
    |> close()
  end

  defp request_drawer(ctx) do
    ctx
    |> mes("[Allen]")
    |> mes("^333333*Cough cough!*^000000")
    |> mes("W-Withstander...!")
    |> mes("I need m-my Withstander!")
    |> mes("P-please! ^333333*Cough cough!*^000000")
    |> set_char_var(:hg_herb, 5)
    |> donpcevent("#DrawerOpener::OnEnable")
    |> close()
  end

  defp request_more_medicine(ctx) do
    ctx
    |> mes("[Allen]")
    |> mes("^333333*Whew*^000000")
    |> mes("I... I can breathe again!")
    |> mes("B-but what if I have another")
    |> mes("attack?! Please, g-get me")
    |> mes("another dose of Withstander,")
    |> mes("just to be on the safe side!")
    |> set_char_var(:hg_herb, 8)
    |> donpcevent("#DrawerOpener::OnEnable")
    |> close()
  end
end
