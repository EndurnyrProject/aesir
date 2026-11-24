defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsComodo.Meteurengut do
  @moduledoc """
  Meteurengut helps adventurers obtain the Slate of Muriniel.

  ## Behavior

  - Requests alchemical ingredients and a cobweb to prepare the slate.

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
        map: "aldebaran",
        x: 44,
        y: 53,
        dir: 4,
        sprite: 64,
        name: "Meteurengut",
        scope: :shared,
        unique_name: "Meteurengut#cmd"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      case get_char_var(ctx, :dmdswrd_Q, 0) do
        14 ->
          ctx
          |> mes("[Meteurengut]")
          |> mes("Ah. Your body is surrounded")
          |> mes("by the glow of one that has")
          |> mes("eaten of the Awakening Stone.")
          |> mes("That alone may prove your value")
          |> mes("as an adventurer, but are you")
          |> mes("free from your selfish desires?")
          |> next()
          |> mes("[Meteurengut]")
          |> mes("Even just the smallest")
          |> mes("taint of greed or jealousy")
          |> mes("can prove to be a corruptive")
          |> mes("influence when power is not")
          |> mes("tempered by wisdom and a")
          |> mes("sense of true compassion.")
          |> next()
          |> mes("[Meteurengut]")
          |> mes("Others like you have come")
          |> mes("before me in hopes of learning")
          |> mes("about the Slate of Muriniel and")
          |> mes("eventually obtaining one of the")
          |> mes("three accursed blades. You are probably no different from them...")
          |> next()
          |> mes("[Meteurengut]")
          |> mes("The Slate of Muriniel is an")
          |> mes("alchemic artifact that can")
          |> mes("help one access unimaginable")
          |> mes("power, originally developed")
          |> mes("by a master of alchemy that was")
          |> mes("known as Rikaseh Sumarecon.")
          |> next()
          |> mes("[Meteurengut]")
          |> mes("Sumarecon had two apprentices,")
          |> mes("and after he had passed down the secrets of the Slate of Muriniel")
          |> mes("to only one of his proteges, his other protege killed him and the")
          |> mes("other student out of jealousy.")
          |> next()
          |> mes("[Meteurengut]")
          |> mes("Sumarecon's secrets were")
          |> mes("thought to be lost forever...")
          |> mes("Fortunately, years later, an")
          |> mes("Alchemist named Kuprite found")
          |> mes("Sumarecon's secret documents")
          |> mes("containing his knowledge.")
          |> next()
          |> mes("[Meteurengut]")
          |> mes("Kuprite then taught these")
          |> mes("secrets to a select group of")
          |> mes("Alchemy students, one of which")
          |> mes("was my ancestor, Burukesaemu.")
          |> mes("And so, because of my lineage,")
          |> mes("I have learned those secrets.")
          |> next()
          |> mes("[Meteurengut]")
          |> mes("If you wish for me to")
          |> mes("reproduce the Slate of")
          |> mes("Muriniel for you, then")
          |> mes("please bring me the items")
          |> mes("I require to complete the")
          |> mes("secret alchemic procedure.")
          |> next()
          |> mes("[Meteurengut]")
          |> mes("I shall need")
          |> mes("^3355FF1 Sapphire^000000,")
          |> mes("^3355FF1 Shining Stone^000000,")
          |> mes("^3355FF1 Rough Elunium^000000,")
          |> mes("^3355FF1 Emerald^000000, and")
          |> mes("^3355FF1 Blue Gemstone^000000.")
          |> set_char_var(:dmdswrd_Q, 15)

        15 ->
          if count_item(ctx, 717) > 0 and count_item(ctx, 726) > 0 and count_item(ctx, 721) > 0 and
               count_item(ctx, 640) > 0 and count_item(ctx, 757) > 0 do
            ctx
            |> mes("[Meteurengut]")
            |> mes("You've already found")
            |> mes("all of the items I require to")
            |> mes("create the Slate of Muriniel?")
            |> mes("Fantastic. Now I can begin work")
            |> mes("on this. However, there is one")
            |> mes("more thing I must ask of you.")
            |> delitem(717, 1)
            |> delitem(726, 1)
            |> delitem(721, 1)
            |> delitem(640, 1)
            |> delitem(757, 1)
            |> set_char_var(:dmdswrd_Q, 16)
            |> next()
            |> mes("[Meteurengut]")
            |> mes("Would you please bring me")
            |> mes("^3355FF1 Cobweb^000000? You can obtain")
            |> mes("them by slaying spiders in")
            |> mes("Muriniel Pass which is on the")
            |> mes("way to Al De Baran from here.")
            |> next()
            |> mes("[Meteurengut]")
            |> mes("I'd have asked for it")
            |> mes("sooner, but I need to prepare")
            |> mes("all of these stones, and I need")
            |> mes("the freshest Cobwebs I can get.")
            |> mes("I'll make sure that these stones are ready when you return.")
          else
            ctx
            |> mes("[Meteurengut]")
            |> mes("If you wish for me to")
            |> mes("reproduce the Slate of")
            |> mes("Muriniel for you, then")
            |> mes("please bring me the items")
            |> mes("I require to complete the")
            |> mes("secret alchemic procedure.")
            |> next()
            |> mes("[Meteurengut]")
            |> mes("I shall need")
            |> mes("^3355FF1 Sapphire^000000,")
            |> mes("^3355FF1 Shining Stone^000000,")
            |> mes("^3355FF1 Rough Elunium^000000,")
            |> mes("^3355FF1 Emerald^000000, and")
            |> mes("^3355FF1 Blue Gemstone^000000.")
          end

        16 ->
          if count_item(ctx, 1025) > 0 do
            ctx
            |> mes("[Meteurengut]")
            |> mes("I see that you've brought")
            |> mes("me a Cobweb. It's hard to")
            |> mes("believe, but it's integreal to")
            |> mes("creating the Slate of Muriniel.")
            |> mes("Now, if you'll wait a moment,")
            |> mes("I shall complete the slate...")
            |> next()
            |> delitem(1025, 1)
            |> mes("*^3355FFClang Clang Clang!*")
            |> mes("*Zaaaaaaaaaaaaaap*")
            |> mes("*Ching tink t-t-t-tap*^000000")
            |> set_char_var(:dmdswrd_Q, 17)
            |> next()
            |> mes("[Meteurengut]")
            |> mes("*Whew* It's finished.")
            |> mes("Please take care of this")
            |> mes("slate, and know that I am")
            |> mes("entrusting you with an artifact")
            |> mes("that can help you access power")
            |> mes("beyond your imagination...")
            |> next()
            |> mes("^3355FFYou have received")
            |> mes("the Slate of Muriniel.^000000")
            |> next()
            |> mes("[Meteurengut]")
            |> mes("There. You have eaten of")
            |> mes("the Awakening Stone and you")
            |> mes("possess the Slate of Muriniel.")
            |> mes("Now, you must try to obtain the")
            |> mes("^3355FFBook of the Lamb^000000 if you are")
            |> mes("questing for a doomed sword...")
            |> next()
            |> mes("[Meteurengut]")
            |> mes("I know very little about")
            |> mes("that artifact, and its secrets")
            |> mes("are as well guarded as that of")
            |> mes("the Slate of Muriniel. However,")
            |> mes("I do know that a man in Morocc can create the Book of the Lamb...")
            |> next()
            |> mes("[Meteurengut]")
            |> mes("If that man is still in")
            |> mes("Morocc, then he will probably")
            |> mes("recognize the subtle emanation")
            |> mes("of the Awakening Stone and the")
            |> mes("Slate of Muriniel from you. Best of luck to you, adventurer...")
          else
            ctx
            |> mes("[Meteurengut]")
            |> mes("Ah, have you brought a")
            |> mes("Cobweb? I know it sounds")
            |> mes("strange, but I really need the")
            |> mes("unique energy found only in")
            |> mes("fresh Cobwebs to finish the")
            |> mes("Slate of Muriniel for you...")
          end

        17 ->
          ctx
          |> mes("[Meteurengut]")
          |> mes("You've eaten of the")
          |> mes("Awakening Stone and")
          |> mes("now possess the Slate of")
          |> mes("Muriniel. Now, all you must")
          |> mes("do is obtain the Book of the")
          |> mes("Lamb. I know little about it...")
          |> next()
          |> mes("[Meteurengut]")
          |> mes("All I can tell you is that")
          |> mes("there should be a man in")
          |> mes("Morocc that can create it")
          |> mes("for you. A man like that can")
          |> mes("sense the Slate of Muriniel,")
          |> mes("so he may call out to you...")

        _ ->
          ctx
          |> mes("[Meteurengut]")
          |> mes("The ^3355FFSlate of Muriniel^000000")
          |> mes("is an ancient artifact")
          |> mes("that can only be created")
          |> mes("by the power of Alchemy.")
          |> mes("It is one of the best kept")
          |> mes("secrets of my family...")
          |> next()
          |> mes("[Meteurengut]")
          |> mes("I'm responsible for guarding")
          |> mes("the secrets of its creation, but I must also share the power")
          |> mes("of the slate with those that")
          |> mes("prove themselves worthy of it.")
          |> next()
          |> mes("[Meteurengut]")
          |> mes("After all, power is useless")
          |> mes("if it is never used. However,")
          |> mes("if power is never balanced with")
          |> mes("wisdom and compassion, then")
          |> mes("it will inevitably do more harm")
          |> mes("than good in the very end...")
      end

    close(ctx)
  end
end
