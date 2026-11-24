defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.ElSchatt do
  @moduledoc """
  El Schatt plans to replace the tree with shops.

  ## Behavior

  - Advances the Memory Quest and rewards its conclusion.

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
      %{map: "hugel", x: 196, y: 164, dir: 3, sprite: 50, name: "El Schatt", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :hg_memory, 0) do
      2 ->
        ctx
        |> mes("[El Schatt]")
        |> mes("What? What's that look for?")
        |> mes("Oh, you must have spoken to")
        |> mes("Manainne. Look, memories are")
        |> mes("nice and all, but I don't dwell")
        |> mes("on the past. I think about the")
        |> mes("future. That's what's best.")
        |> next()
        |> mes("[El Schatt]")
        |> mes("Hey, I've got some great")
        |> mes("memories of this place too,")
        |> mes("but you know what? I've decided")
        |> mes("to let go of them before they")
        |> mes("get too painful. That's life.")
        |> mes("Besides, it's not all bad.")
        |> next()
        |> mes("[El Schatt]")
        |> mes("My father's been wanting to")
        |> mes("build a shop here for so long,")
        |> mes("and now, I think it's about time. And this business will help the")
        |> mes("entire community. We should've")
        |> mes("done this a long time ago...")
        |> next()
        |> set_char_var(:hg_memory, 3)
        |> mes("[El Schatt]")
        |> mes("C'mon... Take a look")
        |> mes("around. I won't deny that")
        |> mes("this is a quaint and lovely")
        |> mes("town, but how much money do")
        |> mes("you think these people enjoy?")
        |> mes("I need to look to the future...")
        |> changequest(8058, 8059)
        |> close()

      3 ->
        ctx
        |> mes("[El Schatt]")
        |> mes("This is the perfect")
        |> mes("location for shops.")
        |> mes("Yeah, I'll build a whole")
        |> mes("plaza, and rent it out to the")
        |> mes("merchants. Build up some")
        |> mes("commerce, attract businesses...")
        |> next()
        |> mes("[El Schatt]")
        |> mes("Everyone should just")
        |> mes("forget about that tree.")
        |> mes("When you think about it,")
        |> mes("it's just a waste of space...")
        |> close()

      4 ->
        ctx
        |> set_char_var(:hg_memory, 5)
        |> mes("[El Schatt]")
        |> mes("You've spoken with my father?")
        |> mes("Hmpf! Don't tell me you're here")
        |> mes("to change my mind. I'm building")
        |> mes("those shops, and that's final.")
        |> mes("It's useless to try to convince")
        |> mes("me otherwise. Understand?")
        |> next()
        |> mes("[El Schatt]")
        |> mes("It's true that I used")
        |> mes("to think differently...")
        |> mes("I'd protect that old tree")
        |> mes("with my life, I won't deny")
        |> mes("it. But that's an old story that should be buried in the past...")
        |> changequest(8060, 8061)
        |> close()

      5 ->
        ctx
        |> mes("[El Schatt]")
        |> mes("The past is behind me")
        |> mes("as it should be. Now")
        |> mes("I must focus on building")
        |> mes("my family's businesses.")
        |> mes("Father was right all along...")
        |> close()

      7 ->
        ctx
        |> mes("[El Schatt]")
        |> mes("What did you say...?")
        |> mes("You met Kanainne?")
        |> mes("Listen, that's not funny.")
        |> mes("I won't tolerate that kind")
        |> mes("of sick joke, so get out")
        |> mes("of here before I get angry.")
        |> close()

      10 ->
        ctx
        |> mes("[El Schatt]")
        |> mes("No way...!")
        |> mes("Kanainne is dead!")
        |> mes("There's no way")
        |> mes("I can believe this!")
        |> next()
        |> mes("[Manainne]")
        |> mes("......")
        |> mes(".........")
        |> mes("............")
        |> close()

      11 ->
        ctx =
          ctx
          |> mes("[El Schatt]")
          |> mes("K-Kanainne! ^333333*Sob*^000000")
          |> mes("I've missed you so much!")
          |> mes("Why did you leave me?")
          |> next()
          |> mes("[Manainne]")
          |> mes("Oh, my dear,")
          |> mes("sweet El Schatt...")
          |> mes("I'm so sorry. But")
          |> mes("that was my fate...")
          |> mes("It was my time to go...")
          |> mes("You have to let me go...")
          |> next()
          |> mes("[El Schatt]")
          |> mes("I can't take it anymore!")
          |> mes("It hurts too much without you!")
          |> mes("I can't stop thinking about us,")
          |> mes("and all the memories... all of")
          |> mes("the memories hurt so much...")
          |> next()
          |> mes("[Manainne]")
          |> mes("Is that why you want to")
          |> mes("cut down that tree? Because")
          |> mes("it reminds you too much of")
          |> mes("all of our days together?")
          |> next()
          |> mes("[El Schatt]")
          |> mes("Y-yes! Seeing it makes")
          |> mes("me so angry and so sad!")
          |> mes("I wanted to get rid of it!")
          |> mes("If I don't forget you, then")
          |> mes("what will I do? I c-can't")
          |> mes("forget about you, c-can I?")
          |> next()
          |> mes("[Manainne]")
          |> mes("Will destroying that tree")
          |> mes("make you happy? Do you think")
          |> mes("you'll be happy if you forget")
          |> mes("all about me? I know you're")
          |> mes("not like that, El Schatt.")
          |> mes("You're not that cold...")
          |> next()
          |> mes("[El Schatt]")
          |> mes("No... I don't want")
          |> mes("to forget you. All of")
          |> mes("our good times. But I miss")
          |> mes("you so much... I think I'm")
          |> mes("going to go insane! I don't")
          |> mes("know if I can endure this pain!")
          |> next()
          |> mes("[Manainne]")
          |> mes("Please be strong for me,")
          |> mes("El Schatt. Someday, time")
          |> mes("will heal your wounds, and")
          |> mes("your memories of me will only")
          |> mes("bring you fondness, not pain.")
          |> mes("I miss you El Schatt, and I...")
          |> next()
          |> mes("[El Schatt]")
          |> mes("Kanainne...?")
          |> mes("K-Kanaine?")
          |> mes("What's happening?")
          |> next()
          |> mes("[Manainne]")
          |> mes("El Schatt, I'm so sorry...")
          |> mes("But I have to go now. I can't")
          |> mes("stay in the world of the living")
          |> mes("for too long, and my time limit")
          |> mes("is almost up. I still... I...")
          |> next()
          |> mes("[El Schatt]")
          |> mes("N-no! Please, stay with")
          |> mes("me! I'm not ready to lose")
          |> mes("you again! D-don't leave")
          |> mes("me again! Nooo! Kanainne!")
          |> mes("I need you here with me!")
          |> next()
          |> mes("[Manainne]")
          |> mes("I can't do that...")
          |> mes("But please, El Schatt...")
          |> mes("Promise that you'll be")
          |> mes("yourself from now on...")
          |> mes("Be kind... And follow")
          |> mes("your true dreams...")
          |> next()
          |> mes("[Manainne]")
          |> mes("Don't cut down")
          |> mes("that tree... And make...")
          |> mes("make beautiful music.")
          |> mes("Please finish the song")
          |> mes("that you made for me for...")
          |> mes("for both of our sakes...")
          |> next()
          |> mes("[El Schatt]")
          |> mes("Anything for you,")
          |> mes("Kanainne. I vow it...")
          |> next()
          |> mes("[Manainne]")
          |> mes("El Schatt...")
          |> mes("I still... I still...")
          |> next()
          |> mes("[El Schatt]")
          |> mes("Y-yes...")
          |> mes("Kanainne...?")
          |> next()
          |> mes("[Manainne]")
          |> mes("......")
          |> mes(".........")
          |> mes("............")
          |> next()
          |> mes("^3355FF*Thud!*^000000")
          |> next()
          |> mes("[El Schatt]")
          |> mes("Kanainne...?")
          |> mes("Kanainne!")
          |> next()
          |> mes("[Manainne]")
          |> mes("...I...")
          |> mes("...El Schatt...")
          |> mes("She's gone again.")
          |> mes("It's... I'm Manainne...")
          |> mes("^333333*Sniff*^000000 She had to go back...")
          |> next()
          |> specialeffect2(:cone)
          |> set_char_var(:hg_memory, 12)

        ctx
        |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 8000, else: 50000), 0)
        |> completequest(8063)
        |> give_item(603, 1)
        |> mes("[El Schatt]")
        |> mes("Oh... Oh dear")
        |> mes("sweet God... My...")
        |> mes("My dear Kanainne...")
        |> mes("No.... No... Please...")
        |> close()

      12 ->
        ctx
        |> mes("[El Schatt]")
        |> mes("...Would you please")
        |> mes("leave me alone? I have...")
        |> mes("I have an awful lot to")
        |> mes("think about. And there's")
        |> mes("music that I have to write...")
        |> close()

      _ ->
        ctx
        |> mes("[El Schatt]")
        |> mes("Father was right...")
        |> mes("This area is the perfect")
        |> mes("place to build some stores.")
        |> mes("All that's left is to chop down")
        |> mes("that old tree. It's in the way")
        |> mes("of a whole lot of things...")
        |> close()
    end
  end
end
