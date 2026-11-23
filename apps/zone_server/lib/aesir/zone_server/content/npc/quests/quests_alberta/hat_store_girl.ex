defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.HatStoreGirl do
  @moduledoc """
  Tempestra is a hat merchant on vacation.

  ## Behavior

  - Accepts a Yellow Potion and offers to craft hats from the required materials.

  ## Credits

  - Original from rAthena, authors and contributors:
    - kobra_k88
    - Lupus
    - Evera
    - DZeroX
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta",
        x: 136,
        y: 79,
        dir: 1,
        sprite: 71,
        name: "Hat store girl",
        scope: :shared,
        unique_name: "Hat store girl#new30"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Tempestra]")
      |> mes(
        "Ah, such a cool breeze. It's good to visit the seashore. I think it was the right choice to come here to take a break from my business."
      )
      |> next()
      |> mes("[Tempestra]")
      |> mes(
        "Ooh, the sun is too strong today. I'm glad that I brought my hat. I'm going to get a sunburn if my skin is exposed to the sun like this everyday."
      )
      |> next()
      |> mes("[Tempestra]")
      |> mes(
        "Oh, I'm sooo thirsty! A nice, chilled Yellow Potion would be perfect right about now~"
      )
      |> next()
      |> select(["Let me treat you to a Yellow Potion.", "What, you expect me to give you one?!"])

    case choice do
      1 ->
        if count_item(ctx, 503) > 0 do
          {ctx, topic} =
            ctx
            |> mes("[Tempestra]")
            |> mes(
              "Ah, thank you so much. I'm so glad to have met a friendly person like yourself."
            )
            |> next()
            |> mes("^3355FF*Gulp, gulp*^000000")
            |> delitem(503, 1)
            |> next()
            |> mes("[Tempestra]")
            |> mes("Hyaaaaaa~~!!!")
            |> mes("It's so cold!! Thank you~~~")
            |> next()
            |> select(["It's really hot, isn't it~?", "You should wear your hat..."])

          case topic do
            1 ->
              {ctx, hat} =
                ctx
                |> mes("[Tempestra]")
                |> mes("Yeah~ it's really hot....")
                |> next()
                |> mes("[Tempestra]")
                |> mes("I have")
                |> mes("^0000FFSunday Hat^000000,")
                |> mes("^0000FFMage Hat^000000 and...")
                |> mes("^0000FFMagician Hat^000000 and more in my room.")
                |> next()
                |> mes("[Tempestra]")
                |> mes(
                  "I brought these hats so I can sell them and use the money for my vacation here, but now it looks like I have to wear one~"
                )
                |> next()
                |> select(["Sunday Hat!!?", "Mage Hat?!?", "Magician Hat??!??"])

              hat_recipe(ctx, hat)

            2 ->
              ctx =
                ctx
                |> mes("[Tempestra]")
                |> mes(
                  "Well, the hats I have with me are for my customers. If I use them for myself, I'll have nothing to sell..."
                )
                |> next()
                |> mes("[Tempestra]")
                |> mes(
                  "I want to make something special for you because you showed me such kindness, but I don't have anything like that right now."
                )
                |> next()

              if count_item(ctx, 7086) > 0 and count_item(ctx, 969) > 9 and
                   count_item(ctx, 999) > 39 and count_item(ctx, 1003) > 49 and
                   count_item(ctx, 984) > 1 do
                ctx
                |> mes("[Tempestra]")
                |> mes("Hmm...")
                |> mes("I think I can make a special item from the items you already have.")
                |> next()
                |> mes("[Tempestra]")
                |> mes(
                  "If there are any forged items or slotted items with monster cards, then put them into your Kafra storage."
                )
                |> next()
                |> mes("[Tempestra]")
                |> mes("Heh heh...")
                |> mes("I think I'll make you a Hat of the Sun God~")
                |> next()
                |> delitem(7086, 1)
                |> delitem(969, 10)
                |> delitem(999, 40)
                |> delitem(1003, 50)
                |> delitem(984, 2)
                |> mes("[Tempestra]")
                |> mes("See! Here it is!!")
                |> mes("Haha, I made this quicker than the speed of light!")
                |> next()
                |> mes("[Tempestra]")
                |> mes(
                  "...Or maybe I just gave you the one I already had, and took your items. Hee hee!"
                )
                |> give_item(5022, 1)
                |> next()
                |> mes("[Tempestra]")
                |> mes("Anyway, I justed want to give something really nice to you...")
                |> close()
              else
                ctx
                |> mes("[Tempestra]")
                |> mes("Hmm...")
                |> mes("^0000FF1 Emblem of the Sun God^000000")
                |> mes("^0000FF10 Gold^000000")
                |> mes("^0000FF40 Steel^000000")
                |> mes("^0000FF50 Coal^000000")
                |> mes("^0000FF2 Oridecon^000000")
                |> next()
                |> mes("[Tempestra]")
                |> mes("If you have these, I can make you my fantastic 'Hat of the Sun God!'")
                |> next()
                |> mes("[Tempestra]")
                |> mes(
                  "I just want to make something really special for you, so I won't charge you any zeny to make this hat."
                )
                |> close()
              end

            _ ->
              ctx
          end
        else
          ctx
          |> mes("[Tempestra]")
          |> mes("Umm, I appreciate it but, I guess you just ran out of Yellow Potions?")
          |> close()
        end

      2 ->
        ctx |> mes("[Tempestra]") |> mes("....How rude!") |> close()

      _ ->
        ctx
    end
  end

  defp hat_recipe(ctx, 1) do
    ctx =
      ctx
      |> mes("[Tempestra]")
      |> mes("Oh? Didn't you know? I'm a hat merchant. Didn't I tell you that before?")
      |> next()
      |> mes("[Tempestra]")
      |> mes(
        "Hmm, I guess I didn't. I apologize. Ooh! You know what, I could make you a Sunday Hat~!"
      )
      |> next()
      |> mes("[Tempestra]")
      |> mes("I'd need...")
      |> mes("^0000FF250 Fabric^000000")
      |> mes("^0000FF1 Slotted Hat^000000")
      |> mes("^0000FF1 Slotted Cap^000000")
      |> mes("^0000FF600 Soft feather^000000")
      |> next()

    if count_item(ctx, 1059) > 249 and count_item(ctx, 2221) > 0 and
         count_item(ctx, 2227) > 0 and count_item(ctx, 7063) > 599 do
      {ctx, confirmation} =
        ctx
        |> mes("[Tempestra]")
        |> mes("What?!? ")
        |> mes(
          "You have all the items already? If there are forged items or slotted items with monster cards, then put them into your storage."
        )
        |> next()
        |> mes("[Tempestra]")
        |> mes(
          "I just want to make something for the Yellow Potion, so I won't charge you any zeny for my hat making service."
        )
        |> select(["Oh, please do.", "No thanks."])

      case confirmation do
        1 ->
          ctx
          |> next()
          |> mes("[Tempestra]")
          |> mes("Alrighty. Just give me a moment...")
          |> next()
          |> mes("^3355FF*Thud! Boot!*")
          |> mes("*Thic-Tac!*^000000")
          |> next()
          |> mes("^3355FF*Beeeeeeeh~~~*^000000")
          |> next()
          |> delitem(1059, 250)
          |> delitem(2221, 1)
          |> delitem(2227, 1)
          |> delitem(7063, 600)
          |> mes("[Tempestra]")
          |> mes("Here it is, tee hee~")
          |> mes("How about that? Do you like it?")
          |> give_item(5032, 1)
          |> next()
          |> mes("[Tempestra]")
          |> mes("Once again, thank you for your favour. I'll see you later~")
          |> close()

        2 ->
          ctx
          |> next()
          |> mes("[Tempestra]")
          |> mes("Oh alright~")
          |> next()
          |> mes("[Tempestra]")
          |> mes(
            "If by any chance you visit me later, I'd be more than happy to make a hat for you~"
          )
          |> next()
          |> mes("[Tempestra]")
          |> mes("Well then, see you later~")
          |> close()

        _ ->
          ctx
      end
    else
      ctx
      |> mes("[Tempestra]")
      |> mes("I will tell you a secret, because you gave me the Yellow Potion~")
      |> next()
      |> mes("[Tempestra]")
      |> mes("I'm looking forward seeing you again~~")
      |> close()
    end
  end

  defp hat_recipe(ctx, 2) do
    ctx =
      ctx
      |> mes("[Tempestra]")
      |> mes("Oh? Didn't you know? I'm a hat merchant. Didn't I tell you that before?")
      |> next()
      |> mes("[Tempestra]")
      |> mes(
        "Hmm, I guess I didn't. I apologize. Ooh! You know what, I could make you a Mage Hat!"
      )
      |> next()
      |> mes("[Tempestra]")
      |> mes("^0000FF1 Wizard Hat^000000")
      |> mes("^0000FF400 Dragon Scale^000000")
      |> mes("^0000FF50 Mould Powder^000000")
      |> mes("^0000FF1 Elder Willow Card^000000")
      |> next()

    if count_item(ctx, 2252) > 0 and count_item(ctx, 1036) > 399 and
         count_item(ctx, 4052) > 0 and count_item(ctx, 7001) > 49 do
      {ctx, confirmation} =
        ctx
        |> mes("[Tempestra]")
        |> mes("What?!? ")
        |> mes(
          "You have all the items already? If there are forged items or slotted items with monster cards, then put them into your storage."
        )
        |> next()
        |> mes("[Tempestra]")
        |> mes(
          "I just want to make something nice for you, so I won't charge you any zeny for my hat making service."
        )
        |> select(["Oh, please do.", "No thanks."])

      case confirmation do
        1 ->
          ctx
          |> next()
          |> mes("[Tempestra]")
          |> mes("Alrighty. Just give me a moment...")
          |> next()
          |> mes("^3355FF*Thud! Boot!*")
          |> mes("*Thic-Tac!*^000000")
          |> next()
          |> mes("^3355FF*Beeeeeeeh~~~*^000000")
          |> next()
          |> delitem(2252, 1)
          |> delitem(1036, 400)
          |> delitem(4052, 1)
          |> delitem(7001, 50)
          |> mes("[Tempestra]")
          |> mes("Here it is, tee hee~")
          |> mes("How about that?")
          |> mes("Do you like it?")
          |> give_item(5027, 1)
          |> next()
          |> mes("[Tempestra]")
          |> mes("Once again, thank you for your favour. I'll see you later~")
          |> close()

        2 ->
          ctx
          |> next()
          |> mes("[Tempestra]")
          |> mes("Oh alright~")
          |> next()
          |> mes("[Tempestra]")
          |> mes(
            "If by any chance you visit me later, I'd be more than happy to make a hat for you~"
          )
          |> next()
          |> mes("[Tempestra]")
          |> mes("Well then, see you later~")
          |> close()

        _ ->
          ctx
      end
    else
      ctx
      |> mes("[Tempestra]")
      |> mes("I will tell you a secret, because you gave me the Yellow Potion~")
      |> next()
      |> mes("[Tempestra]")
      |> mes("I'm looking forward seeing you again~~")
      |> close()
    end
  end

  defp hat_recipe(ctx, 3) do
    ctx =
      ctx
      |> mes("[Tempestra]")
      |> mes("Oh? Didn't you know? I'm a hat merchant. Didn't I tell you that before?")
      |> next()
      |> mes("[Tempestra]")
      |> mes(
        "Hmm, I guess I didn't. I apologize. Ooh! You know what, I could make you a Magician Hat!"
      )
      |> next()
      |> mes("[Tempestra]")
      |> mes("^0000FF1 Wizard Hat^000000")
      |> mes("^0000FF450 Ancient Lips^000000")
      |> mes("^0000FF1200 Solid Shell^000000")
      |> next()

    if count_item(ctx, 2252) > 0 and count_item(ctx, 1054) > 449 and
         count_item(ctx, 943) > 1199 do
      {ctx, confirmation} =
        ctx
        |> mes("[Tempestra]")
        |> mes("What?!? ")
        |> mes("You have all the items already?")
        |> mes(
          "If there are forged items or slotted items with monster cards, then put them into your storage."
        )
        |> next()
        |> mes("[Tempestra]")
        |> mes(
          "I just want to make something nice for you, so I won't charge you any zeny for my hat making service."
        )
        |> select(["Please do", "No thanks"])

      case confirmation do
        1 ->
          ctx
          |> next()
          |> mes("[Tempestra]")
          |> mes("Alrighty. Just give me a moment...")
          |> next()
          |> mes("^3355FF*Thud! Boot!*")
          |> mes("*Thic-Tac!*^000000")
          |> next()
          |> mes("^3355FF*Beeeeeeeh~~~*^000000")
          |> next()
          |> delitem(2252, 1)
          |> delitem(1054, 450)
          |> delitem(943, 1200)
          |> mes("[Tempestra]")
          |> mes("Here it is, tee hee~")
          |> mes("How about that?")
          |> mes("Do you like it?")
          |> give_item(5045, 1)
          |> next()
          |> mes("[Tempestra]")
          |> mes("Once again, thank you for your favour. I'll see you later~")
          |> close()

        2 ->
          ctx
          |> next()
          |> mes("[Tempestra]")
          |> mes("Oh alright~")
          |> next()
          |> mes("[Tempestra]")
          |> mes(
            "If by any chance you visit me later, I'd be more than happy to make a hat for you~"
          )
          |> next()
          |> mes("[Tempestra]")
          |> mes("Well then, see you later~")
          |> close()

        _ ->
          ctx
      end
    else
      ctx
      |> mes("[Tempestra]")
      |> mes("I will tell you a secret, because you gave me the Yellow Potion~")
      |> next()
      |> mes("[Tempestra]")
      |> mes("I'm looking forward seeing you again~~")
      |> close()
    end
  end

  defp hat_recipe(ctx, _) do
    ctx
  end
end
