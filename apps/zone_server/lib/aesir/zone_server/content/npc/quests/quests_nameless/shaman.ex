defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Shaman do
  @moduledoc """
  A shaman offers to lift the Unlucky Emerald’s curse.

  ## Behavior

  - Advances the jewel investigation through payments, offerings, and guidance.

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
      %{map: "alberta_in", x: 70, y: 109, dir: 5, sprite: 788, name: "Shaman", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :jewel_nd, 0) == 0 ->
        ctx
        |> mes("[Shaman]")
        |> mes("The spiritual realm is")
        |> mes("the source of my sorcery.")
        |> mes("Do not understimate the")
        |> mes("power of the spirits!")
        |> close()

      get_char_var(ctx, :jewel_nd, 0) > 0 and get_char_var(ctx, :jewel_nd, 0) < 12 ->
        ctx
        |> mes("[Shaman]")
        |> mes("Oh? Heh heh!")
        |> mes("You're carrying")
        |> mes("something very")
        |> mes("valuable, aren't you?")
        |> close()

      get_char_var(ctx, :jewel_nd, 0) == 12 ->
        examine_emerald(ctx)

      get_char_var(ctx, :jewel_nd, 0) == 13 ->
        collect_first_payment(ctx)

      get_char_var(ctx, :jewel_nd, 0) == 14 ->
        ctx
        |> mes("[Shaman]")
        |> mes("Hmm... You know the")
        |> mes("money you gave me?")
        |> mes("Apparently, it wasn't")
        |> mes("enough. One of the spirits")
        |> mes("was about to enter me, but...")
        |> next()
        |> mes("[Shaman]")
        |> mes("It left in disgust after")
        |> mes("it learned that I was trying")
        |> mes("to break the curse for only")
        |> mes("200,000 zeny. I think...")
        |> mes("I think I need 100,000 zeny")
        |> mes("more for this to be effective.")
        |> set_char_var(:jewel_nd, 15)
        |> close()

      get_char_var(ctx, :jewel_nd, 0) == 15 ->
        collect_second_payment(ctx)

      get_char_var(ctx, :jewel_nd, 0) == 16 ->
        begin_ritual(ctx)

      get_char_var(ctx, :jewel_nd, 0) == 17 ->
        receive_offerings(ctx)

      get_char_var(ctx, :jewel_nd, 0) == 18 ->
        ctx
        |> mes("[Shaman]")
        |> mes("That antique appraiser...")
        |> mes("He wouldn't know anything")
        |> mes("more about the jewel, but")
        |> mes("that archaeologist in Juno")
        |> mes("will hopefully have some")
        |> mes("new information we can use.")
        |> close()

      get_char_var(ctx, :jewel_nd, 0) == 19 ->
        hear_archaeologist(ctx)

      get_char_var(ctx, :jewel_nd, 0) == 20 ->
        read_emerald(ctx)

      get_char_var(ctx, :jewel_nd, 0) == 21 ->
        ctx
        |> mes("[Shaman]")
        |> mes("Go yonder to the town")
        |> mes("of Geffen, head west, and")
        |> mes("seek the high ground that")
        |> mes("is over the bridge. You know...")
        |> mes("Leave Geffen through the west")
        |> mes("gate and find a high place.")
        |> next()
        |> mes("[Shaman]")
        |> mes("Trust me. You'll find")
        |> mes("something there that will")
        |> mes("react to the power of that")
        |> mes("emerald you possess.")
        |> mes("Don't forget to bring")
        |> mes("that emerald with you!")
        |> close()

      get_char_var(ctx, :jewel_nd, 0) == 22 or get_char_var(ctx, :jewel_nd, 0) == 23 ->
        ctx
        |> mes("[Shaman]")
        |> mes("What did I tell you?")
        |> mes("That jewel brings very")
        |> mes("bad fortune. Though, I'm")
        |> mes("not sure why the warrior")
        |> mes("spirit inside wouldn't talk")
        |> mes("to me. What's with that?")
        |> close()

      true ->
        ctx
        |> mes("[Shaman]")
        |> mes("It's been a long time")
        |> mes("since I've done these")
        |> mes("rituals. I feel thoroughly")
        |> mes("drained of my spiritual energy.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp examine_emerald(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Shaman]")
      |> mes("You! Yes... I can sense")
      |> mes("them... The angry spirits of")
      |> mes("your ancestors! You haven't")
      |> mes("made any offerings to them,")
      |> mes("have you? You must appease")
      |> mes("them before they torment you!")
      |> next()
      |> mes("[Shaman]")
      |> mes("Quickly, now! It is")
      |> mes("imperative that you give me")
      |> mes("500,000 zeny immediately")
      |> mes("so that I can comfort their")
      |> mes("souls before they wreck")
      |> mes("havoc on your life!")
      |> next()
      |> select(["Actually, I have a Cursed Jewel."])

    ctx =
      ctx
      |> mes("[Shaman]")
      |> mes("Jewel...? Oh, a Cursed")
      |> mes("Jewel! Hahaha! So that's")
      |> mes("what that evil aura was!")
      |> mes("My mistake! Say, do you")
      |> mes("mind if I take a look at it?")
      |> next()

    if count_item(ctx, 7725) > 0 do
      ctx
      |> emotion(:think)
      |> mes("[Shaman]")
      |> mes("So this bauble's the")
      |> mes("Unlucky Emerald? Yes,")
      |> mes("it's definitely cursed.")
      |> mes("If you don't break the")
      |> mes("curse soon, it'll consume")
      |> mes("your soul. Not a good thing.")
      |> next()
      |> mes("[Shaman]")
      |> mes("I need to perform")
      |> mes("a ritual to break the")
      |> mes("curse. I'll charge you")
      |> mes("200,000 zeny for the service.")
      |> mes("It's expensive, but I'm saving")
      |> mes("your life and risking mine.")
      |> set_char_var(:jewel_nd, 13)
      |> close()
    else
      ctx
      |> mes("[Shaman]")
      |> mes("Hm? Did you forget to")
      |> mes("bring the jewel? Hurry,")
      |> mes("and bring it back to me.")
      |> mes("You need to break that")
      |> mes("curse before the jewel")
      |> mes("can devour your soul!")
      |> close()
    end
  end

  defp collect_first_payment(ctx) do
    ctx =
      ctx
      |> mes("[Shaman]")
      |> mes("Did you bring the money?")
      |> mes("We must appease the spirits")
      |> mes("possessing the soul, and to")
      |> mes("do that, I will need to perform")
      |> mes("a ritual that will be taxing")
      |> mes("on my body and spirit.")
      |> next()

    if zeny(ctx) > 199_999 do
      ctx
      |> mes("[Shaman]")
      |> mes("Good, good. I see that")
      |> mes("you've brought the money.")
      |> mes("I can now begin the ritual.")
      |> mes("If all goes well, you'll be")
      |> mes("free of your curse, and I can")
      |> mes("buy some Prontera real estate.")
      |> pay_zeny(200_000)
      |> set_char_var(:jewel_nd, 14)
      |> next()
      |> mes("[Shaman]")
      |> mes("Please come back soon")
      |> mes("after I've completed the")
      |> mes("preparations for the ritual.")
      |> close()
    else
      ctx
      |> mes("[Shaman]")
      |> mes("You... You don't have")
      |> mes("200,000 zeny? I'm sorry,")
      |> mes("but I cannot perform the")
      |> mes("ritual for free, even if")
      |> mes("your soul is at stake.")
      |> close()
    end
  end

  defp collect_second_payment(ctx) do
    ctx =
      ctx
      |> mes("[Shaman]")
      |> mes("Good, you've returned!")
      |> mes("Did you bring the 100,000")
      |> mes("zeny like I asked? It's a small")
      |> mes("price considering that I'm")
      |> mes("saving your very soul.")
      |> next()

    if zeny(ctx) > 99999 do
      ctx
      |> mes("[Shaman]")
      |> mes("Ah, perfect!")
      |> mes("Hopefully, the")
      |> mes("spirits will be more")
      |> mes("cooperative this time.")
      |> pay_zeny(100_000)
      |> set_char_var(:jewel_nd, 16)
      |> next()
      |> mes("[Shaman]")
      |> mes("Yes, the vindictive")
      |> mes("spirit in this jewel")
      |> mes("will be most impressed")
      |> mes("by your sincere efforts.")
      |> close()
    else
      ctx
      |> mes("[Shaman]")
      |> mes("You didn't? Do you know")
      |> mes("what it's like to have")
      |> mes("your soul consumed? Let")
      |> mes("me tell you, it's a lot")
      |> mes("more painful than parting")
      |> mes("with a paltry 100,000 zeny!")
      |> close()
    end
  end

  defp begin_ritual(ctx) do
    ctx =
      ctx
      |> mes("[Shaman]")
      |> mes("At long last, the")
      |> mes("spirits and I are one.")
      |> mes("The ritual may now begin.")
      |> mes("Ohhhhhhhhhhhmmmmm... ")
      |> next()
      |> mes("[Shaman]")
      |> mes("Hhhkkk... Arrrgh...!")
      |> emotion(:huk)
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes(".....?")
    |> next()
    |> mes("[Shaman]")
    |> mes("Th-this emerald!")
    |> mes("So many lives! Money")
    |> mes("alone won't break this")
    |> mes("curse! It's time to get")
    |> mes("serious and suppress")
    |> mes("this jewel's power!")
    |> next()
    |> mes("[Shaman]")
    |> mes("Remember the items")
    |> mes("I tell you to bring, and")
    |> mes("come back with them")
    |> mes("as quickly as you can!")
    |> mes("Both of our lives are in")
    |> mes("danger until you do!")
    |> next()
    |> mes("[Shaman]")
    |> mes("Bring me")
    |> mes("^FF00001 Holy Water^000000,")
    |> mes("^FF00001 Red Blood^000000,")
    |> mes("^FF00001 Witherless Rose^000000,")
    |> mes("^FF00001 Crystal Blue^000000, and")
    |> mes("^FF00001 Wind of Verdure^000000.")
    |> next()
    |> mes("[Shaman]")
    |> mes("Hurry! Although the spirits")
    |> mes("are eternal, they don't like")
    |> mes("to be kept waiting! Don't")
    |> mes("question this great irony,")
    |> mes("and get those items now!")
    |> set_char_var(:jewel_nd, 17)
    |> close()
  end

  defp receive_offerings(ctx) do
    ctx =
      ctx
      |> mes("[Shaman]")
      |> mes("You brought the items?!")
      |> mes("Quickly! Place them in")
      |> mes("my hands! We can't afford")
      |> mes("to waste any more time!")
      |> next()

    if count_item(ctx, 990) > 0 and count_item(ctx, 991) > 0 and
         count_item(ctx, 992) > 0 and count_item(ctx, 748) > 0 and
         count_item(ctx, 523) > 0 do
      ctx
      |> mes("[Shaman]")
      |> mes("Thank goodness.")
      |> mes("Now... Let me begin...")
      |> mes("Uhhkk... Argh! Wait!")
      |> mes("I... I see someone...")
      |> mes("Covered in blood? Yes...")
      |> mes("He's staring at something.")
      |> delitem(990, 1)
      |> delitem(991, 1)
      |> delitem(992, 1)
      |> delitem(748, 1)
      |> delitem(523, 1)
      |> next()
      |> mes("[Shaman]")
      |> mes("There's a sword behind it.")
      |> mes("He's... He's just been in")
      |> mes("a fight? I can smell...")
      |> mes("His bloodlust. I can't tell")
      |> mes("if he cursed the jewel of")
      |> mes("if he's another victim...")
      |> next()
      |> mes("[Shaman]")
      |> mes("Damn it! It's not clear")
      |> mes("to me! We need to figure")
      |> mes("out if what I'm seeing is")
      |> mes("the root of the curse...")
      |> mes("What can we do to--Right!")
      |> next()
      |> mes("[Shaman]")
      |> mes("I'm not sure how helpful")
      |> mes("he'll be, but there is an")
      |> mes("archaeologist in Juno that")
      |> mes("might know more about this")
      |> mes("specific jewel. Hopefully,")
      |> mes("he will have the answer.")
      |> set_char_var(:jewel_nd, 18)
      |> next()
      |> mes("[Shaman]")
      |> mes("For now, the jewel's")
      |> mes("curse is beyond my power.")
      |> mes("However, if you can determine")
      |> mes("the source of the curse, then")
      |> mes("I will be able to help you.")
      |> close()
    else
      ctx
      |> mes("[Shaman]")
      |> mes("You... Forgot?!")
      |> mes("Your body and soul are in")
      |> mes("jeopardy and you forgot?!")
      |> next()
      |> mes("[Shaman]")
      |> mes("Bring me")
      |> mes("^FF00001 Holy Water^000000,")
      |> mes("^FF00001 Red Blood^000000,")
      |> mes("^FF00001 Witherless Rose^000000,")
      |> mes("^FF00001 Crystal Blue^000000, and")
      |> mes("^FF00001 Wind of Verdure^000000!")
      |> close()
    end
  end

  defp hear_archaeologist(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Shaman]")
      |> mes("Ah, you're back.")
      |> mes("So did you learn")
      |> mes("anything new about")
      |> mes("the Unlucky Emerald?")
      |> next()
      |> select(["The archaeologist said..."])

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("The archaeologist said...")
    |> mes("Well, he said that there")
    |> mes("is no curse on the jewel.")
    |> next()
    |> mes("[Shaman]")
    |> mes("What? How dare he refute")
    |> mes("what I just told you?!")
    |> mes("Is he calling me a liar?")
    |> mes("There was a vindictive")
    |> mes("warrior's soul inside")
    |> mes("that very emerald!")
    |> next()
    |> mes("[Shaman]")
    |> mes("Then again, there's no")
    |> mes("point fighting someone")
    |> mes("that doesn't believe in")
    |> mes("the spirit realm. However,")
    |> mes("I wasn't lying. My honor")
    |> mes("as a shaman is at stake!")
    |> set_char_var(:jewel_nd, 20)
    |> next()
    |> mes("[Shaman]")
    |> mes("In fact, I'll prove it to you")
    |> mes("by reading the message")
    |> mes("inside this emerald. Bring")
    |> mes("me the jewel, and I'll summon")
    |> mes("the warrior spirit inside it.")
    |> mes("Just let me rest a bit first.")
    |> close()
  end

  defp read_emerald(ctx) do
    if count_item(ctx, 7725) > 0 do
      ctx
      |> mes("[Shaman]")
      |> mes("Alright. By my pride")
      |> mes("as a shaman, I'll provide")
      |> mes("this service to you free")
      |> mes("of charge! Can't have")
      |> mes("anyone thinking I'm")
      |> mes("some kind of quack...")
      |> next()
      |> mes("[Shaman]")
      |> mes("Hmmmm...")
      |> mes("Hmmmm...")
      |> mes("I... I see.")
      |> next()
      |> mes("[Shaman]")
      |> mes("Huh. Well, what do you")
      |> mes("know? There is no curse.")
      |> mes("However, it's not true that")
      |> mes("only Comodo's prodigal son")
      |> mes("was killed over this jewel.")
      |> mes("There are many more...")
      |> next()
      |> mes("[Shaman]")
      |> mes("Go yonder to the town")
      |> mes("of Geffen, head west, and")
      |> mes("seek the high ground that")
      |> mes("is over the bridge. You know...")
      |> mes("Leave Geffen through the west")
      |> mes("gate and find a high place.")
      |> next()
      |> mes("[Shaman]")
      |> mes("Trust me. You'll find")
      |> mes("something there that will")
      |> mes("react to the power of that")
      |> mes("emerald you possess.")
      |> next()
      |> mes("[Shaman]")
      |> mes("Hmpf! That arrogant")
      |> mes("archaeologist! He doesn't")
      |> mes("know what he's talking about!")
      |> set_char_var(:jewel_nd, 21)
      |> close()
    else
      ctx
      |> mes("[Shaman]")
      |> mes("You don't have the")
      |> mes("emerald with you?")
      |> mes("I hope you didn't")
      |> mes("lose it somewhere.")
      |> close()
    end
  end
end
