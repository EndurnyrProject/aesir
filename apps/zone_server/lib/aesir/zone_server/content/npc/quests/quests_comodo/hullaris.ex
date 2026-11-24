defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsComodo.Hullaris do
  @moduledoc """
  Hullaris guides adventurers seeking Comodo Cheese.

  ## Behavior

  - Explains the Awakening Stone and directs worthy adventurers to Nigirboran.
  - Serves Comodo Cheese after his test and suggests the next destination.

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
        map: "comodo",
        x: 187,
        y: 153,
        dir: 4,
        sprite: 701,
        name: "Hullaris",
        scope: :shared,
        unique_name: "Hullaris#cmd"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx =
      case get_char_var(ctx, :dmdswrd_Q, 0) do
        10 ->
          {ctx, choice} =
            ctx
            |> mes("[Hullaris]")
            |> mes("Hula~hula~hula~")
            |> mes("Love togther, love together,")
            |> mes("we've groovin' on some more~")
            |> mes("Love togther, love together,")
            |> mes("we've living on the floor~")
            |> next()
            |> select(["Present Muzi's Coin", "Um... Comodo Cheese?"])

          if choice == 1 do
            ctx =
              ctx
              |> mes("^3355FFYou present Muzi's lucky")
              |> mes("coin to the old woman.^000000")
              |> next()
              |> mes("[Hullaris]")
              |> mes("Love! Love!")
              |> mes("Love together~")
              |> mes("Love! Love!")
              |> mes("Love togeth-hm?")
              |> mes("Oh, that's um, Muzi's")
              |> mes("cheat coin, isn't it?")
              |> next()
              |> mes("[Hullaris]")
              |> mes("He always said that he")
              |> mes("might send someone with")
              |> mes("that coin to me as a sign")
              |> mes("of his trust in that person.")
              |> mes("I suppose, then, that I'm")
              |> mes("at your service. Now...")
              |> next()
              |> mes("[Hullaris]")
              |> mes("What exactly did you need?")
              |> mes("I'm guessing you've come")
              |> mes("here to ask me something")
              |> mes("about Comodo. As one of the")
              |> mes("oldest elders, I know more")
              |> mes("about this village than most...")
              |> next()

            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("Actually, I was hoping")
            |> mes("you can tell me about")
            |> mes("Comodo Cheese. If it really")
            |> mes("exists, I'd like to know")
            |> mes("where I can get some.")
            |> next()
            |> mes("[Hullaris]")
            |> mes("Oh... That. First of all,")
            |> mes("Comodo Cheese does exist,")
            |> mes("and it's as precious as the")
            |> mes("legends say. However, it's")
            |> mes("not a true cheese, although you may think so from its taste.")
            |> next()
            |> mes("[Hullaris]")
            |> mes("Yes, it's a very rare, natural")
            |> mes("substance and isn't made from")
            |> mes("cow or goat milk or anything")
            |> mes("like that. However, Comodo")
            |> mes("Cheese isn't merely food.")
            |> mes("No, it's much more...")
            |> next()
            |> mes("[Hullaris]")
            |> mes("Those that eat Comodo")
            |> mes("Cheese find that their")
            |> mes("true potential is unlocked.")
            |> mes("Comodo Cheese's true name")
            |> mes("is the ^3355FFAwakening Stone^000000. Now,")
            |> mes("doesn't that sound impressive?")
            |> next()
            |> mes("[Hullaris]")
            |> mes("The Awakening Stone is")
            |> mes("one of the keys to obtaining")
            |> mes("some kind of forbidden power.")
            |> mes("That's why only the bravest")
            |> mes("adventurers can expect the")
            |> mes("chance of ever eating it.")
            |> next()
            |> mes("[Hullaris]")
            |> mes("Do you really wish to")
            |> mes("eat the Comodo Cheese and")
            |> mes("see where its power may lead")
            |> mes("you? If so, you'll have to endure great challenges to obtain it...")
            |> next()
            |> mes("[Hullaris]")
            |> mes("When you've decided")
            |> mes("to pursue the Awakening")
            |> mes("Stone, seek out a man named")
            |> mes("^3355FFNigirboran^000000. He will judge")
            |> mes("whether you are worthy")
            |> mes("of the Comodo Cheese...")
            |> set_char_var(:dmdswrd_Q, 11)
            |> next()
            |> mes("[Hullaris]")
            |> mes("Now, you should be")
            |> mes("able to find Nigiroban")
            |> mes("training somewhere in one")
            |> mes("of Comodo's Dungeon Caves.")
            |> mes("I'll send him a message to")
            |> mes("let him know you're coming...")
          else
            ctx =
              ctx
              |> mes("[Hullaris]")
              |> mes("Love! Love!")
              |> mes("Love together~")
              |> mes("Love! Love!")
              |> mes("Love togeth-hm?")

            if sex(ctx) == 1 do
              ctx |> mes("Boy, you're ruining") |> mes("my groove! Now beat it!")
            else
              ctx |> mes("Girl, you're ruining") |> mes("my groove! Get away~")
            end
          end

        11 ->
          ctx
          |> mes("[Hullaris]")
          |> mes("Do you really wish to")
          |> mes("eat the Comodo Cheese and")
          |> mes("see where its power may lead")
          |> mes("you? If so, you'll have to endure great challenges to obtain it...")
          |> next()
          |> mes("[Hullaris]")
          |> mes("When you've decided")
          |> mes("to pursue the Awakening")
          |> mes("Stone, seek out a man named")
          |> mes("^3355FFNigirboran^000000. He will judge")
          |> mes("whether you are worthy")
          |> mes("of the Comodo Cheese...")
          |> next()
          |> mes("[Hullaris]")
          |> mes("Now, you should be")
          |> mes("able to find Nigiroban")
          |> mes("training somewhere in one")
          |> mes("of Comodo's Dungeon Caves.")
          |> mes("I'll send him a message to")
          |> mes("let him know you're coming...")

        12 ->
          ctx
          |> mes("[Hullaris]")
          |> mes("Hmm? So you've failed")
          |> mes("Nigirboran's test, have")
          |> mes("you? Well, you better train")
          |> mes("until you can pass it. Otherwise, eating Comodo Cheese could")
          |> mes("mean your death, you know.")

        13 ->
          ctx
          |> mes("[Hullaris]")
          |> mes("Ah, you've returned.")
          |> mes("So were you able to pass")
          |> mes("Nigirboran's little test? An")
          |> mes("adventurer like you should")
          |> mes("be able to have no problem")
          |> mes("with it. I've got faith in you~")
          |> next()
          |> mes("^3355FFYou present the token that")
          |> mes("signifies that you passed")
          |> mes("Nigirboran's test to Hullaris.^000000")
          |> next()
          |> mes("[Hullaris]")
          |> mes("Ah, I was right after all.")
          |> mes("I'm glad to see that you've")
          |> mes("proven worthy of eating this")
          |> mes("Comodo Cheese, or more")
          |> mes("accurately, the Awakening")
          |> mes("Stone. Here, let me get it...")
          |> next()
          |> mes("[Hullaris]")
          |> mes("There you are...")
          |> mes("Only brave and worthy")
          |> mes("adventurers are allowed to")
          |> mes("eat this. Understand that")
          |> mes("eating Comodo Cheese is")
          |> mes("a rare and coveted honor!")
          |> next()
          |> mes("^3355FFHullaris carefully")
          |> mes("hands you a plate of")
          |> mes("Comodo Cheese. You enjoy")
          |> mes("the rich, smooth flavor of")
          |> mes("each and every morsel...")
          |> mes("It's sublimely delicious!^000000")
          |> next()
          |> mes("^3355FFAfter you finish eating the")
          |> mes("Comodo Cheese, you feel")
          |> mes("a subtle, yet definite energy")
          |> mes("gently pulsing through your")
          |> mes("body. You feel a powerful, yet")
          |> mes("quiet confidence of being able")
          |> mes("to accomplish anything.^000000")
          |> set_char_var(:dmdswrd_Q, 14)
          |> next()
          |> mes("[Hullaris]")
          |> mes("Hahahah! So what")
          |> mes("do you think? It's great,")
          |> mes("isn't it? It's unreal, how")
          |> mes("delicious it is. All other")
          |> mes("foods can never match the")
          |> mes("quality of Comodo Cheese~")
          |> next()
          |> mes("[Hullaris]")
          |> mes("Now, I know that you probably")
          |> mes("have things to do, but might")
          |> mes("I suggest that you visit the")
          |> mes("town of Al De Baran? There's")
          |> mes("a man there that can tell you")
          |> mes("about the Slate of Muriniel.")
          |> next()
          |> mes("[Hullaris]")
          |> mes("You've already eaten the")
          |> mes("Awakening Stone, so you may")
          |> mes("as well obtain the other things")
          |> mes("that you need to earn one of")
          |> mes("the three forbidden swords.")
          |> mes("It's just a thought...")

        _ ->
          ctx
          |> mes("[Hullaris]")
          |> mes("Ah... Dance.")
          |> mes("It's more than just a form")
          |> mes("of entertainment. It's art,")
          |> mes("it's seduction, it's battle,")
          |> mes("and it's love. Only a true")
          |> mes("Dancer can understand this...")
          |> next()
          |> mes("[Hullaris]")
          |> mes("You know, Comodo is famous")
          |> mes("for its Dance Academy and the")
          |> mes("Dancers that have been trained")
          |> mes("there. If you know any female")
          |> mes("Archers, why don't you suggest")
          |> mes("visiting the school to them?")
      end

    close(ctx)
  end
end
