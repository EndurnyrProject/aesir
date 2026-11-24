defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsComodo.Won do
  @moduledoc """
  Won judges adventurers seeking a doomed sword.

  ## Behavior

  - Grants the qualification to bear a doomed sword.
  - Directs qualified adventurers to Sage Yklah.

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
        x: 232,
        y: 87,
        dir: 4,
        sprite: 106,
        name: "Won",
        scope: :shared,
        unique_name: "Won#cmd"
      }
    ]

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :dmdswrd_Q, 0)

    ctx =
      case progress do
        22 ->
          ctx
          |> mes("[Won]")
          |> mes("Hmm...? It's been a while")
          |> mes("since someone came here to")
          |> mes("get the qualification to own a")
          |> mes("doomed sword. Yeah, I know")
          |> mes("that's why you're here...")
          |> next()
          |> mes("[Won]")
          |> mes("To a man like me, the")
          |> mes("presenses of the Book of the")
          |> mes("Lamb, the Slate of Muriniel,")
          |> mes("and one that has eaten of the")
          |> mes("Awakening Stone are unmistakable.")
          |> next()
          |> mes("[Won]")
          |> mes("Now, listen. I personally")
          |> mes("don't care why you want a")
          |> mes("doomed sword. If you abuse")
          |> mes("its power, you'll pay the price")
          |> mes("eventually. I'm only here to")
          |> mes("make sure you're up to snuff.")
          |> next()
          |> mes("[Won]")
          |> mes("Of course, I also want to")
          |> mes("make sure that you don't bring")
          |> mes("great suffering to the world")
          |> mes("using a doomed sword. So I'm")
          |> mes("going to check if you're, you")
          |> mes("know, balanced and all that.")
          |> next()
          |> mes("[Won]")
          |> mes("Alright, let me take")
          |> mes("a look into your eyes...")
          |> mes("Yeah, alright. You seem to")
          |> mes("understand the value of the")
          |> mes("Awakening Stone, Book of the Lamb, and the Slate of Muriniel.")
          |> next()
          |> mes("[Won]")
          |> mes("Yeah, I can't sense any")
          |> mes("ill intent from you at all.")
          |> mes("That's very good. Huh, you")
          |> mes("seem pretty experienced in battle, so I'm sure you have the stamina")
          |> mes("to handle to a doomed sword...")
          |> next()
          |> mes("[Won]")
          |> mes("Ah, but most importantly,")
          |> mes("you don't strike me as crazy")
          |> mes("at all. Alright, we're done here. Take this Stamp of Muriniel:")
          |> mes("it's the official qualification")
          |> mes("token to own a doomed sword.")
          |> next()
          |> mes("^3355FFYou receive the")
          |> mes("Stamp of Muriniel.^000000")
          |> set_char_var(:dmdswrd_Q, 23)
          |> next()
          |> mes("[Won]")
          |> mes("Mysteltainn, Executioner,")
          |> mes("and Ogretooth... These are")
          |> mes("the forbidden blades, the")
          |> mes("doomed swords. Remember")
          |> mes("that you cannot choose")
          |> mes("which weapon you'll wield...")
          |> next()
          |> mes("[Won]")
          |> mes("These swords have a will")
          |> mes("of their own. The doomed")
          |> mes("sword that finds you most")
          |> mes("worthy of it will choose you.")
          |> mes("You can understand that, right?")
          |> next()
          |> direct_to_sage()

        23 ->
          direct_to_sage(ctx)

        24 ->
          mes(ctx, "1 2 3 4 5 6 7 8 9 10 1 2 3 4 5")

        _ ->
          ctx
          |> mes("[Won]")
          |> mes("The visitors and even the")
          |> mes("people that live here always")
          |> mes("seem to be having such a good")
          |> mes("time, just lounging in leisure.")
          |> mes("It's hard to believe the War")
          |> mes("of the Witch even happened...")
          |> next()
          |> mes("[Won]")
          |> mes("But not everyone here in")
          |> mes("Comodo can afford to relax")
          |> mes("so easily. I, for one, have")
          |> mes("the responsibility of seeking")
          |> mes("out those that are worthy of, well, I don't know if I can say...")
          |> next()
          |> mes("[Won]")
          |> mes("You just have to")
          |> mes("trust that I've got an")
          |> mes("incredibly important")
          |> mes("job to do. I mean, sure,")
          |> mes("it doesn't look like I'm doing")
          |> mes("anything right now, but...")
      end

    close(ctx)
  end

  defp direct_to_sage(ctx) do
    ctx
    |> mes("[Won]")
    |> mes("Now that you have this")
    |> mes("qualification, I'm supposed")
    |> mes("to direct you to the Sages")
    |> mes("that can help lead you to")
    |> mes("the doomed swords.")
    |> next()
    |> mes("[Won]")
    |> mes("The first Sage that you")
    |> mes("must visit is ^3355FFSage Yklah^000000")
    |> mes("in the city of ^3355FFJuno^000000 in the")
    |> mes("Schwarzwald Republic.")
    |> mes("Your quest to obtain a")
    |> mes("doomed sword isn't over yet...")
  end
end
