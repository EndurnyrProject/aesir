defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsComodo.Nigirboran do
  @moduledoc """
  Nigirboran tests adventurers seeking the Awakening Stone.

  ## Behavior

  - Tests qualified adventurers and sends successful candidates back to Hullaris.
  - Directs adventurers toward Meteurengut and the Slate of Muriniel.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Evera
    - Samuray22
    - Brainstorm

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "beach_dun3",
        x: 30,
        y: 220,
        dir: 4,
        sprite: 704,
        name: "Nigirboran",
        scope: :shared,
        unique_name: "Nigirboran#cmd"
      }
    ]

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :dmdswrd_Q, 0)

    ctx =
      case progress do
        11 ->
          ctx
          |> mes("[Nigirboran]")
          |> mes("You're the one that")
          |> mes("Hullaris sent? So you're")
          |> mes("here to earn the right to")
          |> mes("eat the Awakening Stone...")
          |> mes("Or Comodo Cheese, as it's")
          |> mes("more commonly known.")
          |> next()
          |> mes("[Nigirboran]")
          |> mes("Yes, it has many names...")
          |> mes("But it's more than a mere")
          |> mes("tasty treat--the Awakening")
          |> mes("Stone can help you access")
          |> mes("your true potential. But if you're not prepared... then you'll die.")
          |> next()
          |> mes("[Nigirboran]")
          |> mes("If your mind and body")
          |> mes("aren't sufficiently trained,")
          |> mes("your body will reject the")
          |> mes("Comodo Cheese and you")
          |> mes("would die a slow, painful,")
          |> mes("yet incredibly flavorful death.")
          |> next()
          |> mes("[Nigirboran]")
          |> mes("But I'm sure that won't")
          |> mes("happen to you! If Hullaris")
          |> mes("sent you to me, you must")
          |> mes("have a fighting chance, right?")
          |> mes("So come back when you're")
          |> mes("ready for the testing~")
          |> set_char_var(:dmdswrd_Q, 12)

        12 ->
          ctx =
            ctx
            |> mes("[Nigirboran]")
            |> mes("Good, you have returned--")
            |> mes("I'd expect nothing less of")
            |> mes("a brave and daring adventurer.")
            |> mes("Now hold still as I gauge your")
            |> mes("body's internal energies and see if it can handle Comodo Cheese...")
            |> next()
            |> mes("[Nigirboran]")
            |> mes("Alright.")
            |> mes("Are you ready?")
            |> mes("Now... Brace yourself!")
            |> mes("Heeeeeyah! Hoooo-HAH!")
            |> next()

          if job_level(ctx) > 20 and base_level(ctx) > 25 do
            outcome = Enum.random(1..3)

            ctx =
              ctx
              |> mes("^3355FFA powerful current of")
              |> mes("warmth immediately coarses")
              |> mes("through your body from head")
              |> mes("to toe, and you struggle to")
              |> mes("keep yourself from writhing.^000000")
              |> next()

            case outcome do
              1 ->
                ctx
                |> mes("[Nigirboran]")
                |> mes("Hmm... Your body seems")
                |> mes("well trained, but your mind")
                |> mes("is still reeling from the test.")
                |> mes("If you ate the Comodo Cheese")
                |> mes("now, you'd be reduced to an")
                |> mes("incoherent invalid...")
                |> next()
                |> mes("[Nigirboran]")
                |> mes("Go and train yourself")
                |> mes("a little more, and try")
                |> mes("to improve your mind's")
                |> mes("sense of clarity. When")
                |> mes("you feel ready, come")
                |> mes("back to me once more.")

              2 ->
                ctx
                |> mes("[Nigirboran]")
                |> mes("Huh. Your body is")
                |> mes("strong, but your spirit")
                |> mes("is weak. You need more")
                |> mes("training. If you were to eat")
                |> mes("the Comodo Cheese now...")
                |> mes("You would evaporate.")
                |> next()
                |> mes("[Nigirboran]")
                |> mes("But don't lose heart,")
                |> mes("it's too early for you")
                |> mes("to give up. Go out and")
                |> mes("train some more, and then")
                |> mes("come back to me when you")
                |> mes("feel like you're ready.")

              3 ->
                ctx
                |> mes("[Nigirboran]")
                |> mes("Yes... Yes...")
                |> mes("Your mind, soul, and body")
                |> mes("seem well trained. I think you")
                |> mes("can eat the Comodo Cheese")
                |> mes("without any ill effect. Good,")
                |> mes("good, I think you're ready.")
                |> next()
                |> mes("[Nigirboran]")
                |> mes("Here, take this little")
                |> mes("token to Hullaris. That")
                |> mes("will prove to her that")
                |> mes("you've passed my little")
                |> mes("test. Congratulations~")
                |> next()
                |> mes("^3355FFYou've received")
                |> mes("a token button to")
                |> mes("present to Hullaris")
                |> mes("from Nigirboran.^000000")
                |> set_char_var(:dmdswrd_Q, 13)
                |> next()
                |> mes("[Nigirboran]")
                |> mes("Ah, I almost forgot")
                |> mes("to ask you. Why do you")
                |> mes("seek the Comodo Cheese,")
                |> mes("or the Awakening Stone?")
                |> mes("Are you seeking one of")
                |> mes("the 3 forbidden swords?")
                |> next()
                |> mes("[Nigirboran]")
                |> mes("I don't know all the details,")
                |> mes("but I do know that you'll need")
                |> mes("the ^3355FFAwakening Stone^000000, the ^3355FFBook^000000")
                |> mes("^3355FFof the Lamb^000000 and the ^3355FFSlate of^000000")
                |> mes(
                  "^3355FFMurniel^000000 to even have a chance of obtaining one of those swords."
                )
                |> next()
                |> mes("[Nigirboran]")
                |> mes("Let's see... After you")
                |> mes("speak to Hullaris, you")
                |> mes("should go to Al De Baran")
                |> mes("and find someone named")
                |> mes("^3355FFMeteurengut^000000 to learn about")
                |> mes("the Slate of Muriniel.")
                |> next()
                |> mes("[Nigirboran]")
                |> mes("Anyway, I wish you")
                |> mes("the best of luck in")
                |> mes("accomplishing your")
                |> mes("goals. Godspeed...")

              _ ->
                ctx
            end
          else
            ctx
            |> mes("^3355FFA torrent of warmth")
            |> mes("coarses through your")
            |> mes("entire body, and you")
            |> mes("immediately faint from")
            |> mes("the rush of energy.^000000")
            |> next()
            |> mes("[Nigirboran]")
            |> mes("Goodness...!")
            |> mes("Your mind and body")
            |> mes("are far too weak to")
            |> mes("handle the Comodo Cheese")
            |> mes("now. You must seriously")
            |> mes("train yourself much more...")
            |> next()
            |> mes("[Nigirboran]")
            |> mes("After you've developed")
            |> mes("some more strength, come")
            |> mes("back to me. You can retake")
            |> mes("this little test anytime~")
          end

        13 ->
          ctx
          |> mes("[Nigirboran]")
          |> mes("I don't know all the details,")
          |> mes("but I do know that you'll need")
          |> mes("the ^3355FFAwakening Stone^000000, the ^3355FFBook^000000")
          |> mes("^3355FFof the Lamb^000000 and the ^3355FFSlate of^000000")
          |> mes("^3355FFMurniel^000000 to even have a chance")
          |> mes("of obtaining a forbidden sword.")
          |> next()
          |> mes("[Nigirboran]")
          |> mes("Let's see... After you")
          |> mes("speak to Hullaris, you")
          |> mes("should go to Al De Baran")
          |> mes("and find someone named")
          |> mes("^3355FFMeteurengut^000000 to learn about")
          |> mes("the Slate of Muriniel.")
          |> next()
          |> mes("[Nigirboran]")
          |> mes("Anyway, I wish you")
          |> mes("the best of luck in")
          |> mes("accomplishing your")
          |> mes("goals. Godspeed...")

        14 ->
          ctx
          |> mes("[Nigirboran]")
          |> mes("Somewhere in ^3355FFAl De Baran^000000,")
          |> mes("you'll find a man named")
          |> mes("^3355FFMeteurengut^000000. He should be")
          |> mes("able to help you learn more")
          |> mes("about the Slate of Muriniel.")

        _ ->
          ctx
          |> mes("[Nigirboran]")
          |> mes("Oh... Hello there.")
          |> mes("I guess you could say")
          |> mes("that I'm something of")
          |> mes("a trainer here in Comodo.")
          |> mes("My name is Nigirboran.")
          |> mes("I know it's hard to say...")
          |> next()
          |> mes("[Nigirboran]")
          |> mes("If Hullaris hasn't sent")
          |> mes("you, then I don't think")
          |> mes("I can be of any real help")
          |> mes("for you. That seems to be")
          |> mes("the case, so I'd appreciate")
          |> mes("it if you'd let me train...")
      end

    close(ctx)
  end
end
