defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Archeologist do
  @moduledoc """
  Metz the archeologist, who recruits the player for The Sign quest and guides each stage.

  ## Behavior

  - Recruits players of base level 50 or higher and sends them to Arian for the first test.
  - After the tests, takes the six Sobbing Starlight pieces, shows their reaction and hands
    back the reassembled set, then randomly (1 in 5) finds Engel Howard as the artisan.
  - Points the player to the Geffen Tower Wizards and to Frank Franklin for the translation.
  - Examines The Sign over a two-hour time slot and returns it once a later slot comes round.
  - Rewards base EXP when the player brings back the finished item, or takes back the
    Sobbing Starlight for an Old Violet Box and EXP when the quest failed.

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
        map: "prt_in",
        x: 227,
        y: 45,
        dir: 0,
        sprite: 804,
        name: "Archeologist",
        scope: :shared,
        unique_name: "Archeologist#sign"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = ctx |> cutin("mets_alpha", 2) |> mes("[Metz]")
    talk(ctx, get_char_var(ctx, :sign_q, 0))
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp talk(ctx, sign_q) when sign_q < 1 do
    ctx
    |> mes(
      "Although you need everlasting patience in an archaeological excavation, the feeling you get when you find something makes"
    )
    |> mes("all those long hours of study and research worth it.")
    |> farewell()
  end

  defp talk(ctx, 1) do
    {ctx, choice} =
      ctx
      |> mes("Hm...?")
      |> mes("Can I help you?")
      |> next()
      |> select(["I've been following these signs and...", "I was just passing by..."])

    case choice do
      1 -> ctx |> apply_for_the_job() |> farewell()
      2 -> ctx |> passing_by() |> farewell()
      _ -> ctx
    end
  end

  defp talk(ctx, 2) do
    ctx
    |> mes("I'm sorry I made you wait,")
    |> mes(
      "but I had some research to finish and it took longer than I expected. Now, before I tell you more about the job, I want to test your competency."
    )
    |> next()
    |> mes("[Metz]")
    |> mes("The job I'm offering is")
    |> mes("pretty risky and not just")
    |> mes("anybody can handle it.")
    |> mes("You'll actually go through")
    |> mes("a series of tests conducted")
    |> mes("by my trusted friends.")
    |> next()
    |> mes("[Metz]")
    |> mes("Now, the first person")
    |> mes("you must visit is ^FF0000Arian^000000")
    |> mes("in Morocc. Please speak")
    |> mes("to him and he'll give you")
    |> mes("all the details about his")
    |> mes("examination... I hope.")
    |> next()
    |> mes("[Metz]")
    |> mes("Once you're finished with")
    |> mes("the test, Arian will tell you")
    |> mes("what to do next. Afterwards,")
    |> mes("come back to me so that we")
    |> mes("can finally talk business.")
    |> next()
    |> mes("[Metz]")
    |> mes("Ah, almost forgot.")
    |> mes("Arian won't talk to anybody")
    |> mes("unless he knows them or")
    |> mes("receives a message from me.")
    |> mes("So if he's snubbed you in the past, just understand that's his way.")
    |> set_char_var(:sign_q, 3)
    |> farewell()
  end

  defp talk(ctx, 3) do
    ctx
    |> mes("Hm...?")
    |> mes("Shouldn't you leave")
    |> mes("for Morocc to see Arian?")
    |> mes("You better hurry in case")
    |> mes("somebody else applies")
    |> mes("for this little job.")
    |> farewell()
  end

  defp talk(ctx, sign_q) when sign_q < 13 do
    ctx
    |> mes("I don't know if you realize")
    |> mes("it, but I'm offering a golden")
    |> mes("opportunity for the adventurer")
    |> mes("who works for me. So don't")
    |> mes("hesitate to see Arian.")
    |> next()
    |> mes("[Metz]")
    |> mes("And just so you know,")
    |> mes("it's not a good idea to")
    |> mes("judge Arian by his looks.")
    |> mes("He's more than meets")
    |> mes("the eye, you know.")
    |> farewell()
  end

  defp talk(ctx, sign_q) when sign_q < 15 do
    ctx
    |> mes("I'm impressed that")
    |> mes("you managed to get")
    |> mes("Arian's approval! Oh,")
    |> mes("and how's Daewoon?")
    |> mes("He's a character, isn't he?")
    |> farewell()
  end

  defp talk(ctx, sign_q) when sign_q < 20 do
    ctx
    |> mes("I'm not surprised")
    |> mes("that Daewoon likes")
    |> mes("you. Ah, but Jore is")
    |> mes("always busy. Still, if you")
    |> mes("know his schedule, you")
    |> mes("should be alright.")
    |> farewell()
  end

  defp talk(ctx, sign_q) when sign_q < 25 do
    ctx
    |> mes("Jesqurienne is")
    |> mes("a brilliant woman.")
    |> mes("Although I worry a")
    |> mes("little bit about her")
    |> mes("overconfidence, she's")
    |> mes("a good friend of mine.")
    |> farewell()
  end

  defp talk(ctx, sign_q) when sign_q < 35 do
    ctx
    |> mes("Dearles...?")
    |> mes("Ah yes, he's one")
    |> mes("of my shadier friends.")
    |> mes("He's difficult to find")
    |> mes("and he's only truly kind")
    |> mes("to a select few, so...")
    |> next()
    |> mes("[Metz]")
    |> mes("It certainly doesn't")
    |> mes("help that he's hopelessly")
    |> mes("addicted to gambling...")
    |> farewell()
  end

  defp talk(ctx, sign_q) when sign_q < 53 do
    ctx
    |> mes("Ah, Bakerlan~")
    |> mes("I've heard that he's")
    |> mes("been quite busy lately.")
    |> mes("But that's how all big")
    |> mes("businessmen are, I suppose.")
    |> farewell()
  end

  defp talk(ctx, 53) do
    ctx
    |> mes("Congratulations~")
    |> mes("You managed to pass")
    |> mes("all of the tests! You seem")
    |> mes("to be the perfect person")
    |> mes("to carry out this special")
    |> mes("assignment!")
    |> next()
    |> mes("[Metz]")
    |> mes("By now, you must have")
    |> mes("six Sobbing Starlight pieces.")
    |> mes("I'm sure that you want to know")
    |> mes("more about these fragments.")
    |> next()
    |> mes("[Metz]")
    |> mes("I remember last summer,")
    |> mes("I found the wholly formed")
    |> mes("Sobbing Starlight north")
    |> mes("of Mount Mjolnir during")
    |> mes("one of my expeditions...")
    |> next()
    |> mes("[Metz]")
    |> mes("Although it was in perfect")
    |> mes("shape, once it was exposed")
    |> mes("to the air, it began to crack")
    |> mes("and shattered into the pieces")
    |> mes("you now hold in your hand.")
    |> next()
    |> mes("[Metz]")
    |> mes("Now, an ordinary artisan")
    |> mes("can't put the Sobbing Starlight")
    |> mes(
      "back together. This mysterious stone has some strange properties. But it's imperative for me to get this stone reassembled."
    )
    |> next()
    |> mes("[Metz]")
    |> mes("Once restored, a strange")
    |> mes("pattern can be seen within")
    |> mes("the Sobbing Starlight. I guess")
    |> mes("that the pattern is a message")
    |> mes("written in an ancient language.")
    |> next()
    |> mes("[Metz]")
    |> mes("Would you let me borrow")
    |> mes("the pieces for a second?")
    |> mes("I'll show you something")
    |> mes("quite interesting...")
    |> next()
    |> mes("^3355FFOnce you hand the pieces")
    |> mes("of the Sobbing Starlight to")
    |> mes("Metz, he pulls out a seventh")
    |> mes("piece. Once gathered, they")
    |> mes("begin to emit a strange light.^000000")
    |> specialeffect(:teleportation2)
    |> next()
    |> mes("[Metz]")
    |> mes("Since the pieces still")
    |> mes("respond to each other,")
    |> mes("I believe that it's possible")
    |> mes("for the Sobbing Starlight")
    |> mes("to be restored to its")
    |> mes("original form.")
    |> next()
    |> mes("[Metz]")
    |> mes("We're still seeking")
    |> mes("an artisan of great")
    |> mes("skill for this task. Once")
    |> mes("know right away. For now,")
    |> mes("please hold on to these pieces.")
    |> set_char_var(:sign_q, 54)
    |> give_item(7177, 1)
    |> farewell()
  end

  defp talk(ctx, 54) do
    if Enum.random(1..5) == 4 do
      ctx
      |> mes("Ah, you've come")
      |> mes("just in the nick of time!")
      |> mes("I just found someone who")
      |> mes("may be capable of restoring")
      |> mes("the Sobbing Starlight.")
      |> next()
      |> mes("[Metz]")
      |> mes("His name is")
      |> mes("^FF0000Engel Howard^000000,")
      |> mes("a legendary Blacksmith")
      |> mes("in Midgard. I don't")
      |> mes("know where he is, but maybe")
      |> mes("his family in Geffen may know.")
      |> next()
      |> mes("[Metz]")
      |> mes("Unfortunately, that's all")
      |> mes("the information that I have")
      |> mes("to give you for now. You'll")
      |> mes("have to investigate this lead")
      |> mes("on your own, #{char_name(ctx, 0)}.")
      |> farewell()
    else
      ctx
      |> mes("Although I've made")
      |> mes("some progress, I still")
      |> mes("haven't found an artisan")
      |> mes("capable of restoring the")
      |> mes("Sobbing Starlight. Please")
      |> mes("give me a little more time.")
      |> farewell()
    end
  end

  defp talk(ctx, sign_q) when sign_q < 71 do
    ctx
    |> mes("Keep up the good work.")
    |> mes("I'm sorry that I don't have")
    |> mes("have much information for")
    |> mes("you to follow, but someone")
    |> mes("with your abilities should")
    |> mes("be able to find a way.")
    |> next()
    |> mes("[Metz]")
    |> mes("While you work things")
    |> mes("out with Engel Howard")
    |> mes("and his family in Geffen,")
    |> mes("I'll continue my research")
    |> mes("on the Sobbing Starlight.")
    |> farewell()
  end

  defp talk(ctx, 71) do
    ctx
    |> mes("Amazing...! You've")
    |> mes("managed to restore")
    |> mes("the Sobbing Starlight!")
    |> mes("Now, I recently learned that")
    |> mes("this stone can lead you to")
    |> mes("an ancient place...")
    |> next()
    |> mes("[Metz]")
    |> mes("That's why we need to")
    |> mes("know what the message in")
    |> mes("the Sobbing Starlight means.")
    |> mes("First, we need a Wizard that")
    |> mes("is skilled in unlocking the")
    |> mes("messages stored in gems...")
    |> next()
    |> mes("[Metz]")
    |> mes("Hmm. It would probably")
    |> mes("be best to visit the Wizards")
    |> mes("on the top floor of the Geffen")
    |> mes("Tower. There's someone I know")
    |> mes("there who might just be up for")
    |> mes("this task...")
    |> set_char_var(:sign_q, 72)
    |> farewell()
  end

  defp talk(ctx, 72) do
    ctx
    |> mes("Now that the")
    |> mes("Sobbing Starlight")
    |> mes("is restored, we need")
    |> mes("to find someone who can")
    |> mes("break the seal on the")
    |> mes("gem's message...")
    |> next()
    |> mes("[Metz]")
    |> mes("For now, please visit")
    |> mes("the Wizards at the top")
    |> mes("floor of the Geffen Tower.")
    |> mes("I know that one of them is")
    |> mes("capable of getting the gem's")
    |> mes("text on to paper...")
    |> farewell()
  end

  defp talk(ctx, sign_q) when sign_q < 76 do
    ctx
    |> mes("The Wizard we're looking")
    |> mes("for isn't in Geffen? Hm, at least we know he's near Comodo. Now,")
    |> mes("while you investigate that lead, I'll continue to gather more")
    |> mes("information on this gem...")
    |> farewell()
  end

  defp talk(ctx, 76) do
    ctx
    |> mes("Great...!")
    |> mes("You were able to get the")
    |> mes("text in the gem printed on a")
    |> mes("Record of Ancient Language?")
    |> next()
    |> mes("[Metz]")
    |> mes("Just as I thought.")
    |> mes("This language isn't")
    |> mes("one I recognize. It's")
    |> mes("probably ^333333too^000000 ancient.")
    |> next()
    |> mes("[Metz]")
    |> mes("Fortunately, I know")
    |> mes("one person who may")
    |> mes("be able to translate this.")
    |> mes("If he's not able to do it...")
    |> mes("We'll have to give up.")
    |> next()
    |> mes("[Metz]")
    |> mes("Bring this Record")
    |> mes("of Ancient Language")
    |> mes("to a man named Frank.")
    |> mes("I hope he'll be able to")
    |> mes("understand what it says...")
    |> next()
    |> ask_about_frank()
  end

  defp talk(ctx, sign_q) when sign_q < 80 do
    ctx
    |> frank_franklin_story()
    |> farewell()
  end

  defp talk(ctx, sign_q) when sign_q < 82 do
    ctx
    |> mes("So far, I've learned")
    |> mes("from my research that")
    |> mes("the gem's message has")
    |> mes("details about a certain")
    |> mes("location and an item that")
    |> mes("serves as some kind of key...")
    |> next()
    |> mes("[Metz]")
    |> mes("While I investigate,")
    |> mes("please try to have Frank")
    |> mes("Franklin translate the")
    |> mes("message in the Record of")
    |> mes("Ancient Language. Keep up")
    |> mes("the good work, #{char_name(ctx, 0)}.")
    |> farewell()
  end

  defp talk(ctx, 82) do
    ctx
    |> mes("I get it now!")
    |> mes("The 'skyscraper'")
    |> mes("in this text refers to")
    |> mes("the Geffen Tower!")
    |> mes("Alright, let's see...")
    |> next()
    |> mes("[Metz]")
    |> mes("Hmm...")
    |> mes("''The town where the")
    |> mes("rejected are left behind.''")
    |> mes("What does that mean")
    |> mes("and where could it be...?")
    |> farewell()
  end

  defp talk(ctx, sign_q) when sign_q < 98 do
    ctx
    |> mes("I'm sure the town")
    |> mes("where the rejected")
    |> mes("live means something,")
    |> mes("but I'm unable to figure")
    |> mes("out the answer to this")
    |> mes("little riddle...")
    |> farewell()
  end

  defp talk(ctx, sign_q) when sign_q > 100 and sign_q < 105 do
    ctx
    |> mes("Angrboda...?!")
    |> mes("According to legend,")
    |> mes("her soul was split into")
    |> mes("pieces and placed behind")
    |> mes("seals created by the gods!")
    |> next()
    |> mes("[Metz]")
    |> mes("You'll need a stout,")
    |> mes("heavy or really sharp")
    |> mes("weapon. Of course, I'm")
    |> mes("told that such weapons")
    |> mes("are truly rare...")
    |> next()
    |> mes("[Metz]")
    |> mes("Supposedly, normal")
    |> mes("Blacksmiths can't even")
    |> mes("forge those kinds of rare")
    |> mes("weapons. But if you manage")
    |> mes("to get one, you might have a")
    |> mes("chance of breaking the seals.")
    |> next()
    |> mes("[Metz]")
    |> mes("Of course, I'm worried")
    |> mes("that may be violating the")
    |> mes("will of the gods by releasing")
    |> mes("Angrboda, but we've already")
    |> mes("gone this far...")
    |> farewell()
  end

  defp talk(ctx, sign_q) when sign_q < 137 do
    ctx
    |> mes("I think you're")
    |> mes("almost there. All")
    |> mes("of our efforts will")
    |> mes("soon come to fruition!")
    |> farewell()
  end

  defp talk(ctx, 137) do
    ctx
    |> mes("This is it...!")
    |> mes("You've brought me,")
    |> mes("'The Sign!' I've finally")
    |> mes("proven its existence!")
    |> mes("Please let me handle")
    |> mes("this and come back later~")
    |> delitem(7314, 1)
    |> set_char_var(:sign_q, 138)
    |> set_char_var(:sign_sq, hour_slot(gettime(ctx, 3)))
    |> farewell()
  end

  defp talk(ctx, 138) do
    ready_slot = slot_two_before(hour_slot(gettime(ctx, 3)))

    if get_char_var(ctx, :sign_sq, 0) == ready_slot do
      ctx
      |> mes("Fascinating...")
      |> mes("This was made with")
      |> mes("a material outside of")
      |> mes("Midgard! See this")
      |> mes("blue lens? That must be")
      |> mes("its incredible power source!")
      |> next()
      |> mes("[Metz]")
      |> mes("I've found that the runes")
      |> mes("around the lens control some")
      |> mes(
        "kind of seals placed at the Geffen Tower and Geffen Fountain. But with this in your hands, the seals should be broken..."
      )
      |> next()
      |> mes("[Metz]")
      |> mes("I... I think")
      |> mes("you can even use this")
      |> mes("to enter Valhalla. There")
      |> mes("may be even other applications")
      |> mes("using the power of this item...")
      |> next()
      |> mes("[Metz]")
      |> mes("I can only think of")
      |> mes("one person who can")
      |> mes("handle working with")
      |> mes("this: Engel Howard,")
      |> mes("Midgard's best")
      |> mes("Blacksmith.")
      |> set_char_var(:sign_q, 139)
      |> set_char_var(:sign_sq, 0)
      |> give_item(7314, 1)
      |> farewell()
    else
      ctx
      |> mes("I'm sorry, but I'm")
      |> mes("still examining the")
      |> mes("artifact you've lent to")
      |> mes("me. Would you please")
      |> mes("give me some more time?")
      |> farewell()
    end
  end

  defp talk(ctx, sign_q) when sign_q < 141 do
    ctx
    |> engel_howard_reminder("Sign's power for you...")
    |> farewell()
  end

  defp talk(ctx, 141) do
    if count_item(ctx, 2644) == 1 do
      ctx
      |> mes("Ah, you're finally")
      |> mes("here. I've been waiting")
      |> mes("to speak with you. First,")
      |> mes("let me thank you again")
      |> mes("for all of your help.")
      |> next()
      |> mes("[Metz]")
      |> mes("Thanks to you, my wish")
      |> mes("of proving the existence")
      |> mes("of the Sign has finally been")
      |> mes("fulfilled. Its power is now")
      |> mes("yours to do as you wish.")
      |> next()
      |> mes("[Metz]")
      |> mes("You may have had your doubts,")
      |> mes(
        "but I'm happy enough to confirm that the Sign really exists. Thanks again, and I hope you stop by and chat from time to time."
      )
      |> set_char_var(:sign_q, 142)
      |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 200_000, else: 2_000_000), 0)
      |> farewell()
    else
      ctx
      |> engel_howard_reminder("the Sign's power for you...")
      |> farewell()
    end
  end

  defp talk(ctx, 201) do
    ctx =
      ctx
      |> mes("You failed?")
      |> mes("It's disappointing,")
      |> mes("but I know that you")
      |> mes("did your best. Let")
      |> mes("me thank you for")
      |> mes("all your work.")
      |> next()
      |> mes("[Metz]")
      |> mes("Although I need to")
      |> mes("take back the Sobbing")
      |> mes("Starlight, I hope you")
      |> mes("accept this as a token")
      |> mes("of my gratitude. Good luck")
      |> mes("on your travels, adventurer.")

    if checkweight(ctx, [{7178, 1}]) == 0 do
      ctx
      |> next()
      |> mes("^3355FFWait a second! Right now,")
      |> mes(
        "you have too many items in your inventory. Please come back after you've freed up more inventory space.^000000"
      )
      |> close()
    else
      ctx
      |> delitem(7178, 1)
      |> set_char_var(:sign_q, 202)
      |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 10_000, else: 100_000), 0)
      |> give_item(617, 1)
      |> farewell()
    end
  end

  defp talk(ctx, sign_q) when sign_q > 201 do
    if count_item(ctx, 7178) == 1 do
      ctx
      |> mes("I'm sorry...")
      |> mes("But I'm taking")
      |> mes("back the Sobbing")
      |> mes("Starlight from you.")
      |> mes("Apparently, you weren't")
      |> mes("worthy of the task...")
      |> next()
      |> mes("[Metz]")
      |> mes("......")
      |> mes("Farewell.")
      |> delitem(7178, 1)
      |> farewell()
    else
      ctx
      |> mes("I guess I can't")
      |> mes("really blame you")
      |> mes("since I didn't provide")
      |> mes("you with that much help...")
      |> farewell()
    end
  end

  defp talk(ctx, _sign_q) do
    ctx
    |> mes("Thank you so much")
    |> mes("for helping me make")
    |> mes("my dream come true.")
    |> mes("can work on another")
    |> mes("project together.")
    |> next()
    |> mes("[Metz]")
    |> mes("Well then...")
    |> mes("Good luck on")
    |> mes("your journeys,")
    |> mes("brave #{char_name(ctx, 0)}.")
    |> farewell()
  end

  defp apply_for_the_job(ctx) do
    ctx =
      ctx
      |> mes("[Metz]")
      |> mes("Great...!")
      |> mes("Welcome to my")
      |> mes("humble lodgings.")
      |> mes("Hmm, let me see...")
      |> next()

    if base_level(ctx) < 50 do
      ctx
      |> mes("[Metz]")
      |> mes(
        "Uh, it pains me to say this, but I don't think you qualified to help me out. Once you gain enough experience though, I'll be happy to have you on board~"
      )
    else
      ctx
      |> mes("[Metz]")
      |> mes("Hey, I think you might")
      |> mes("be well suited for the job!")
      |> mes(
        "But do you think you could come back later? I've got my hands full with some other business."
      )
      |> next()
      |> mes("[Metz]")
      |> mes("Oh right, would you tell")
      |> mes("me your name? #{char_name(ctx, 0)}?")
      |> mes("Okay then, I'll remember that.")
      |> mes("Talk to you later, alright?")
      |> set_char_var(:sign_q, 2)
    end
  end

  defp passing_by(ctx) do
    ctx
    |> mes("[Metz]")
    |> mes("Oh really?")
    |> mes("I see, I thought you")
    |> mes("were an applicant for")
    |> mes("the position I'm offering")
    |> mes("to brave adventurers.")
  end

  defp ask_about_frank(ctx) do
    {ctx, choice} = select(ctx, ["Who is Frank?", "Where is he?", "I see."])

    case choice do
      1 ->
        ctx
        |> mes("[Metz]")
        |> frank_franklin_story()
        |> next()
        |> ask_about_frank()

      2 ->
        ctx
        |> mes("[Metz]")
        |> mes("It's said that")
        |> mes("Frank Franklin lives")
        |> mes("on the Alberta Sunken Ship")
        |> mes("where he devotes his time")
        |> mes("to his research. He may not")
        |> mes("always be home though...")
        |> set_char_var(:sign_q, 77)
        |> next()
        |> ask_about_frank()

      3 ->
        ctx
        |> mes("[Metz]")
        |> mes("Good luck, then.")
        |> mes("I hope that you can")
        |> mes("find a way to get Frank")
        |> mes("Franklin to help us...")
        |> farewell()

      _ ->
        ctx
    end
  end

  defp frank_franklin_story(ctx) do
    ctx
    |> mes("Frank Franklin has lived")
    |> mes("in seclusion and only a few")
    |> mes("people are aware of his skill.")
    |> mes("But I can assure you that his")
    |> mes("knowledge of ancient languages")
    |> mes("is unrivaled by any mortal.")
    |> next()
    |> mes("[Metz]")
    |> mes("I suppose his interest")
    |> mes("in history is what drives")
    |> mes("him in work. Still, I've")
    |> mes("heard that he doesn't like")
    |> mes("meeting people. I hope you")
    |> mes("can convince him to help us...")
  end

  defp engel_howard_reminder(ctx, last_line) do
    ctx
    |> mes("Have you visited")
    |> mes("Engel Howard yet?")
    |> mes("He's the only one")
    |> mes("who can unlock the")
    |> mes(last_line)
  end

  defp farewell(ctx), do: ctx |> close2() |> cutin("mets_alpha", 255)

  defp hour_slot(hour) do
    cond do
      hour < 1 -> 1
      hour < 3 -> 2
      hour < 5 -> 3
      hour < 7 -> 4
      hour < 9 -> 5
      hour < 11 -> 6
      hour < 13 -> 7
      hour < 15 -> 8
      hour < 17 -> 9
      hour < 19 -> 10
      hour < 21 -> 11
      true -> 12
    end
  end

  defp slot_two_before(slot), do: rem(slot + 9, 12) + 1
end
