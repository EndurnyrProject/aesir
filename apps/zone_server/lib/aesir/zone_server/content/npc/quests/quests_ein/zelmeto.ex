defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.Zelmeto do
  @moduledoc """
  Zelmeto, the Einbroch factory's field overseer, runs the Factory Quest.

  ## Behavior

  - Sends the adventurer to inspect the factory machines one at a time, advancing the quest
    after each report.
  - Accepts 20 Flexible Tubes, 10 Rusty Screws and 10 Used Iron Plates for the repairs, rewarding
    base experience scaled by base level and game mode and raising the server-wide pollution
    counter.
  - Once the pollution counter passes 9, warns of the toxic fog and sends the adventurer out to
    Einbroch.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - MasterOfMuppets
    - Lupus
    - KarLaeda
    - SinSloth
    - L0ne_W0lf
    - Yommy
    - Paradox924X
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "ein_in01", x: 67, y: 242, dir: 3, sprite: 851, name: "Zelmeto", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_server_var(ctx, "EinPolution", 0) > 9 do
      evacuate(ctx)
    else
      factory_stage(ctx, get_char_var(ctx, :EinFactory, 0))
    end
  end

  defp evacuate(ctx) do
    ctx
    |> mes("[Zelmeto]")
    |> mes("We've got a big problem")
    |> mes("here! I appreciate that you've")
    |> mes("been gathering the materials,")
    |> mes("but the machines have been")
    |> mes("broken for too long!")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("Right when I tried to")
    |> mes("fix it, a huge shortout")
    |> mes("occurred. Our town is")
    |> mes("probably filled with")
    |> mes("toxic fog right now!")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("I'll try my best to fix")
    |> mes("this, but we really should")
    |> mes("have allocated some funds")
    |> mes("to fix this machine earlier!")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("The most important")
    |> mes("thing is that you get")
    |> mes("out of here and find")
    |> mes("shelter! Right now!")
    |> close()
    |> warp("einbroch", 131, 83)
  end

  defp factory_stage(ctx, 16) do
    ctx
    |> mes("[Zelmeto]")
    |> mes("We'll be putting good")
    |> mes("use to the materials you")
    |> mes("gave me. With your help,")
    |> mes("our factory will operate")
    |> mes("safely. At least, for just")
    |> mes("a little while longer.")
    |> close()
  end

  defp factory_stage(ctx, 15) do
    if repair_materials?(ctx) do
      offer_materials(ctx)
    else
      ctx
      |> mes("[Zelmeto]")
      |> mes("We need")
      |> mes("at least")
      |> mes("20 ^FF0000Flexible Tubes^000000,")
      |> mes("10 ^FF0000Rusty Screw^000000 and")
      |> mes("10 ^FF0000Used Iron Plate^000000")
      |> mes("to repair this factory.")
      |> next()
      |> mes("[Zelmeto]")
      |> mes("^333333*Sigh...*^000000")
      |> mes("But there's no way")
      |> mes("we can get all of those")
      |> mes("things. Our budget isn't")
      |> mes("big enough to cover it...")
      |> close()
    end
  end

  defp factory_stage(ctx, 14) do
    ctx
    |> mes("[Zelmeto]")
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("^333333*Sigh*^000000")
    |> mes("My proposal was rejected")
    |> mes("by our superintendant. But")
    |> mes("maintainance and repairs")
    |> mes("are crucial for peak operating")
    |> mes("efficiency and worker safety!")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("I'm frustrated and worried.")
    |> mes("Maybe nothing will happen")
    |> mes("for now, but we've got to")
    |> mes("safeguard our future by")
    |> mes("regularly maintaining")
    |> mes("all of these machines.")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("Even possible threats")
    |> mes("to the safety of our workers")
    |> mes("can't be ignored. Isn't there")
    |> mes("something I can do? ^333333*Sigh*^000000")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("If we can")
    |> mes("just get")
    |> mes("20 ^FF0000Flexible Tube^000000,")
    |> mes("10 ^FF0000Rusty Screw^000000 and")
    |> mes("10 ^FF0000Used Iron Plate^000000,")
    |> mes("we could make those repairs.")
    |> next()
    |> changequest(8030, 8031)
    |> set_char_var(:EinFactory, 15)
    |> mes("[Zelmeto]")
    |> mes("But without funds, there's")
    |> mes("no way we can purchase")
    |> mes("those items. If something")
    |> mes("happens, who's going to")
    |> mes("be responsible?")
    |> close()
  end

  defp factory_stage(ctx, 13) do
    ctx
    |> mes("[Zelmeto]")
    |> mes("I've got to report this")
    |> mes("to our superintendant")
    |> mes("as soon as possible.")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("With any luck, he'll approve")
    |> mes("a budget increase so that we")
    |> mes("can get all of the materials")
    |> mes("needed for the repairs.")
    |> close()
  end

  defp factory_stage(ctx, 12) do
    ctx
    |> mes("[Zelmeto]")
    |> mes("Well, I figured that both")
    |> mes("conveyors would have")
    |> mes("similar problems. We")
    |> mes("can fix them at the")
    |> mes("same time, but it'll")
    |> mes("be a hassle.")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("Thank you so much for")
    |> mes("your help. Without you,")
    |> mes("I'm pretty sure we wouldn't")
    |> mes("know about these problems")
    |> mes("until it was too late.")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("Now, I've got to make sure")
    |> mes("we have enough materials")
    |> mes("to make the repairs so that")
    |> mes("the machines will be safely")
    |> mes("functioning again.")
    |> next()
    |> changequest(8028, 8029)
    |> set_char_var(:EinFactory, 13)
    |> mes("[Zelmeto]")
    |> mes("First, I better")
    |> mes("hurry and request")
    |> mes("an increase for the")
    |> mes("Factory Repair budget")
    |> mes("from our superintendant.")
    |> close()
  end

  defp factory_stage(ctx, 11) do
    ctx
    |> mes("[Zelmeto]")
    |> mes("The machine which")
    |> mes("you are supposed to")
    |> mes("inspect right now")
    |> mes("is a large conveyor.")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("Remember that we")
    |> mes("also have a small sized")
    |> mes("conveyor, so make sure")
    |> mes("that you examine the")
    |> mes("larger one, alright?")
    |> close()
  end

  defp factory_stage(ctx, 10) do
    ctx
    |> mes("[Zelmeto]")
    |> mes("This is")
    |> mes("worse than")
    |> mes("I imagined...")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("We've got to start")
    |> mes("repairs as soon as we")
    |> mes("can! Hopefully, we can")
    |> mes("resolve this before any")
    |> mes("serious problems happen...")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("Alright, the last")
    |> mes("thing that you need to")
    |> mes("inspect is a ^FF0000large converyor^000000.")
    |> mes("It's similar to the one you")
    |> mes("inspected before, but it's")
    |> mes("bigger and more powerful.")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("We have only one of these")
    |> mes("machines and it's usually")
    |> mes("moved around a lot since")
    |> mes("a lot of people in the factory")
    |> mes("use it. I really don't know")
    |> mes("where it could be now.")
    |> next()
    |> changequest(8026, 8027)
    |> set_char_var(:EinFactory, 11)
    |> mes("[Zelmeto]")
    |> mes("Still, I'm sure that")
    |> mes("it's inside the building,")
    |> mes("so you should be able to")
    |> mes("find it. I hope you can inspect")
    |> mes("that conveyor for me soon.")
    |> close()
  end

  defp factory_stage(ctx, 9) do
    ctx
    |> mes("[Zelmeto]")
    |> mes("This time, you need")
    |> mes("to inspect an outdoor")
    |> mes("pipe that is located far")
    |> mes("outside of the factory.")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("Since there aren't any")
    |> mes("other machines in that")
    |> mes("area, that pipe shouldn't")
    |> mes("be too hard to find.")
    |> close()
  end

  defp factory_stage(ctx, 8) do
    ctx
    |> mes("[Zelmeto]")
    |> mes("Huh?")
    |> mes("I'm suprised to hear")
    |> mes("that. ^333333*Sigh*^000000 There's just")
    |> mes("too many things that need")
    |> mes("fixing. This is terrible...")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("Well, let me worry")
    |> mes("about that for now. Please")
    |> mes("focus on continuing to inspect")
    |> mes("some of the other machines.")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("Now, there's a pipe inside")
    |> mes("this factory that I want you")
    |> mes("to look at. Many of our pipes")
    |> mes("aren't in the best condition,")
    |> mes("but this particular one might")
    |> mes("be severely damaged.")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("Now, the pipe I want")
    |> mes("you to inspect is located")
    |> mes("near those large caultrons")
    |> mes("of molten metal. You should")
    |> mes("be able to find it pretty easily.")
    |> next()
    |> changequest(8024, 8025)
    |> set_char_var(:EinFactory, 9)
    |> mes("[Zelmeto]")
    |> mes("Thanks again")
    |> mes("for your help,")
    |> mes("adventurer.")
    |> close()
  end

  defp factory_stage(ctx, 7) do
    ctx
    |> mes("[Zelmeto]")
    |> mes("The machine which")
    |> mes("I want you to inspect")
    |> mes("this time is a small")
    |> mes("sized conveyor.")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("Be sure that you")
    |> mes("inspect the small")
    |> mes("one, since we also")
    |> mes("have a large conveyor")
    |> mes("in the factory as well.")
    |> close()
  end

  defp factory_stage(ctx, 6) do
    ctx
    |> mes("[Zelmeto]")
    |> mes("I see...")
    |> mes("It's most likely that")
    |> mes("there was a short")
    |> mes("circuit and most")
    |> mes("of the internal devices")
    |> mes("were burnt out...")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("Thanks for checking")
    |> mes("that out for me. Now,")
    |> mes("the next machine I need")
    |> mes("you to inspect is different")
    |> mes("than the others I've had")
    |> mes("you examine.")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("It's a mechanical")
    |> mes("hand that transports")
    |> mes("small objects. We didn't")
    |> mes("really give it a name, but")
    |> mes("you should be able to find it.")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("Recently, it seems")
    |> mes("that there have been")
    |> mes("problems in operating")
    |> mes("that machine. If something's")
    |> mes("broken, we need to know")
    |> mes("and fix it right away.")
    |> next()
    |> changequest(8022, 8023)
    |> set_char_var(:EinFactory, 7)
    |> mes("[Zelmeto]")
    |> mes("Thanks again")
    |> mes("in advance.")
    |> close()
  end

  defp factory_stage(ctx, 5) do
    ctx
    |> mes("[Zelmeto]")
    |> mes("I'd like you to inspect")
    |> mes("the control panel. It's")
    |> mes("fairly large and can be")
    |> mes("found in the middle of the")
    |> mes("factory. You shouldn't have")
    |> mes("too much trouble finding it.")
    |> close()
  end

  defp factory_stage(ctx, 4) do
    ctx
    |> mes("[Zelmeto]")
    |> mes("What...?")
    |> mes("This is worse")
    |> mes("than I expected. But")
    |> mes("it's good that we know")
    |> mes("about these problems")
    |> mes("as soon as possible.")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("Don't you worry,")
    |> mes("we'll take care of")
    |> mes("this. In the meantime,")
    |> mes("I'd like you to inspect")
    |> mes("the next machine for me.")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("I want you to check")
    |> mes("a ^FF0000control panel^000000. It's the")
    |> mes("same kind as the one")
    |> mes("you just inspected, but")
    |> mes("bigger in size.")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("It's located in the")
    |> mes("middle of the factory,")
    |> mes("so you should be able")
    |> mes("to find it. It may be in bad")
    |> mes("condition, even though it's")
    |> mes("operating fine for now...")
    |> next()
    |> changequest(8020, 8021)
    |> set_char_var(:EinFactory, 5)
    |> mes("[Zelmeto]")
    |> mes("We need to ensure that")
    |> mes("it's stable, reliable and")
    |> mes("doesn't pose a threat to")
    |> mes("our workforce. Thanks")
    |> mes("again, adventurer.")
    |> close()
  end

  defp factory_stage(ctx, 3) do
    ctx
    |> mes("[Zelmeto]")
    |> mes("You need to inspect")
    |> mes("an automatic pressure")
    |> mes("governor. It looks fine,")
    |> mes("but sometimes it makes")
    |> mes("strange noises.")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("It probably will")
    |> mes("be a good idea to")
    |> mes("check that machine")
    |> mes("more carefully this")
    |> mes("time, just in case.")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("Thank you")
    |> mes("for helping us,")
    |> mes("adventurer.")
    |> close()
  end

  defp factory_stage(ctx, 2) do
    ctx
    |> mes("[Zelmeto]")
    |> mes("Huh, I see.")
    |> mes("We must do something")
    |> mes("about that as soon as")
    |> mes("we can. Now, let me tell")
    |> mes("you what to check next.")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("There are 3 automatic")
    |> mes("pressure governors which")
    |> mes("hammer the bent iron plates")
    |> mes("from above to flatten them. It")
    |> mes("seems that one of them may")
    |> mes("have some kind of problem.")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("Please inspect the ^FF0000automatic pressure governors^000000. Even if the")
    |> mes("problem seems small, please")
    |> mes(
      "report it to me. I know it might seem fine now, but I want to prevent an accident if I can."
    )
    |> next()
    |> changequest(8018, 8019)
    |> set_char_var(:EinFactory, 3)
    |> mes("[Zelmeto]")
    |> mes("Thank you")
    |> mes("in advance,")
    |> mes("adventurer.")
    |> close()
  end

  defp factory_stage(ctx, 1) do
    ctx
    |> mes("[Zelmeto]")
    |> mes("If you would,")
    |> mes("please inspect the")
    |> mes("2nd control panel that")
    |> mes("seems to have been")
    |> mes("broken for a while...")
    |> close()
  end

  defp factory_stage(ctx, _stage), do: introduce(ctx)

  defp repair_materials?(ctx) do
    count_item(ctx, 7325) > 19 and count_item(ctx, 7317) > 9 and count_item(ctx, 7319) > 9
  end

  defp offer_materials(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Zelmeto]")
      |> mes("Ah, it's you again.")
      |> mes("It's shameful letting")
      |> mes("other people know about")
      |> mes("our miserable situation...")
      |> next()
      |> mes("[Zelmeto]")
      |> mes("There's nothing")
      |> mes("worth seeing here,")
      |> mes("so there really isn't")
      |> mes("a point in you coming to")
      |> mes("visit this place anymore.")
      |> next()
      |> select(["Give him materials.", "Huh."])

    case choice do
      1 ->
        donate_materials(ctx)

      2 ->
        ctx
        |> mes("[Zelmeto]")
        |> mes("^333333*Sigh...*^000000")
        |> mes("I'm really worried")
        |> mes("about this factory's")
        |> mes("future. What is our")
        |> mes("superintendant thinking...?")
        |> close()

      _ ->
        ctx
    end
  end

  defp donate_materials(ctx) do
    ctx
    |> mes("[Zelmeto]")
    |> mes("...Hm?")
    |> mes("Aren't these the")
    |> mes("materials we need")
    |> mes("to make repairs in")
    |> mes("the factory? How did")
    |> mes("you find all of these?")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("I don't know how")
    |> mes("I can possibly pay you")
    |> mes("back for this great favor.")
    |> mes("I appreciate that you've")
    |> mes("stepped forward to help us.")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("Oh...!")
    |> mes("In my years of managing,")
    |> mes("I've learned the ultimate")
    |> mes("motivation techniques. Let")
    |> mes("me enhance your motivation")
    |> mes("to show you my gratitude.")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("Now...")
    |> mes("Just open your mind")
    |> mes("and listen to my words")
    |> mes("of encouragement")
    |> mes("and inspiration...")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("^236B8EWhen the going")
    |> mes("gets rough, you've")
    |> mes("gotta get rougher!")
    |> mes("You gotta climb that")
    |> mes("mountain 'cause no one's")
    |> mes("gonna climb it for you!^000000")
    |> next()
    |> mes("[Zelmeto]")
    |> mes("^236B8EDon't give it up!")
    |> mes("Go for broke!")
    |> mes("Losers are quitters")
    |> mes("and quitters are losers!")
    |> delitem(7325, 20)
    |> delitem(7317, 10)
    |> delitem(7319, 10)
    |> set_server_var("EinPolution", get_server_var(ctx, "EinPolution", 0) + 1)
    |> completequest(8031)
    |> set_char_var(:EinFactory, 16)
    |> grant_repair_exp()
    |> next()
    |> mes("[Zelmeto]")
    |> mes("^333333*Whew*^000000")
    |> mes("I haven't given that much")
    |> mes("inspriration in a while, but")
    |> mes("your help was well worth it.")
    |> mes("I'm going to start the repairs, but once again, I'd like to thank you.")
    |> close()
  end

  defp grant_repair_exp(ctx) do
    base_exp =
      if Rathena.truthy?(checkre(ctx, 3)) do
        cond do
          base_level(ctx) < 41 -> 61
          base_level(ctx) < 51 -> 307
          base_level(ctx) < 61 -> 660
          base_level(ctx) < 71 -> 1850
          base_level(ctx) < 81 -> 3206
          base_level(ctx) < 91 -> 7602
          true -> 29_067
        end
      else
        cond do
          base_level(ctx) < 41 -> 615
          base_level(ctx) < 51 -> 3075
          base_level(ctx) < 61 -> 6604
          base_level(ctx) < 71 -> 18_508
          base_level(ctx) < 81 -> 32_066
          base_level(ctx) < 91 -> 76_026
          true -> 290_675
        end
      end

    getexp(ctx, base_exp, 0)
  end

  defp introduce(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Zelmeto]")
      |> mes("Ah, you must be a visitor.")
      |> mes("I'm Zelmeto Abellov, the")
      |> mes("field overseer. Have you")
      |> mes("been in this facility before?")
      |> next()
      |> mes("[Zelmeto]")
      |> mes("This factory plays an")
      |> mes("important role in our city")
      |> mes("and generates a lot of income.")
      |> mes("However, our employees suffer")
      |> mes("from a poor work environment.")
      |> next()
      |> mes("[Zelmeto]")
      |> mes("Our superintendant makes a lot")
      |> mes("of money and seems content with")
      |> mes(
        "the current situation. However, the rest of the workforce doesn't enjoy all of the benefits he receives..."
      )
      |> next()
      |> mes("[Zelmeto]")
      |> mes("Many people have already")
      |> mes("quit and there are only a few")
      |> mes("people who continue to work")
      |> mes("here. So now we're understaffed")
      |> mes("and I'm in quite a bind...")
      |> next()
      |> mes("[Zelmeto]")
      |> mes("There are some urgent")
      |> mes("tasks I need done, but")
      |> mes("there's no way for me")
      |> mes("to recruit new workers.")
      |> mes("Ah, I'm sorry, I've spoken too")
      |> mes("freely about my own problems...")
      |> next()
      |> select(["You're understaffed?", "No, it's okay."])

    case choice do
      1 ->
        explain_understaffing(ctx)

      2 ->
        ctx
        |> mes("[Zelmeto]")
        |> mes("Thank you for")
        |> mes("your kindness.")
        |> mes("And please don't")
        |> mes("let anyone know about")
        |> mes("anything I just told you.")
        |> close()

      _ ->
        ctx
    end
  end

  defp explain_understaffing(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Zelmeto]")
      |> mes("Yes, we are!")
      |> mes("I don't have enough")
      |> mes("people to inspect the")
      |> mes("factory machines and")
      |> mes("determine what kinds")
      |> mes("of problems we have.")
      |> next()
      |> mes("[Zelmeto]")
      |> mes("It's a time consuming")
      |> mes("task I'd rather do on my")
      |> mes("own. However, between that")
      |> mes("and managing the workforce,")
      |> mes("I don't have enough time...")
      |> next()
      |> select(["I can help you.", "Keep up the good job."])

    case choice do
      1 ->
        ctx
        |> mes("[Zelmeto]")
        |> mes("You can help me?")
        |> mes("I know something like")
        |> mes("this is too much to ask,")
        |> mes("but I'll accept any help")
        |> mes("anyone offers me. I'm")
        |> mes("that desperate.")
        |> next()
        |> mes("[Zelmeto]")
        |> mes("Alright, I'll have you")
        |> mes("inspect the machines")
        |> mes("in the factory one by one.")
        |> mes("It's imperative that we know")
        |> mes("what needs to be repaired")
        |> mes("and what's working fine.")
        |> next()
        |> mes("[Zelmeto]")
        |> mes("First, find the ^FF00002nd control")
        |> mes("panel^000000 and determine its")
        |> mes("status. I'm fairly certain that")
        |> mes("it broke a long time ago, but")
        |> mes("it wouldn't hurt to make sure.")
        |> mes("You should find it easily.")
        |> next()
        |> setquest(8017)
        |> set_char_var(:EinFactory, 1)
        |> mes("[Zelmeto]")
        |> mes("When you finish your")
        |> mes("inspection, report back")
        |> mes("to me so I can tell you")
        |> mes("which machine to check")
        |> mes("next. Thanks again for")
        |> mes("offering to help.")
        |> close()

      2 ->
        ctx
        |> mes("[Zelmeto]")
        |> mes("Well, it's a living.")
        |> mes("^333333*Sigh*^000000 I can put up with")
        |> mes("this, but I hope the higher")
        |> mes("ups will consider improving")
        |> mes("the work environment here...")
        |> close()

      _ ->
        ctx
    end
  end
end
