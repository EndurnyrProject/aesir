defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.Teacher do
  @moduledoc """
  A teacher trades a hat for four kinds of flowers.

  ## Behavior

  - Offers her graduation hat in exchange for the flowers, rechecking their quantities before trading.
  - Describes her interest in flowers when the player lacks them.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Evera
    - Samuray22
    - SinSloth
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "prt_in", x: 38, y: 108, dir: 4, sprite: 53, name: "Teacher", scope: :shared}]

  @impl true
  def on_talk(ctx) do
    if has_flowers?(ctx) do
      {ctx, choice} =
        ctx
        |> mes("[Teacher]")
        |> mes("Oh...")
        |> mes("Those Flowers in your hand are...")
        |> next()
        |> select(["Show Flowers", "Present Flowers", "Cancel"])

      case choice do
        1 ->
          ctx
          |> mes("[Teacher]")
          |> mes("Ah...")
          |> mes(
            "Those are definitely the 4 kinds of Flowers I was looking for! Would you give them to me?"
          )
          |> next()
          |> mes("[Teacher]")
          |> mes("If you would...")
          |> mes("I'll give you my precious item.")
          |> close()

        2 ->
          if has_flowers?(ctx) do
            ctx
            |> delitem(710, 1)
            |> delitem(703, 1)
            |> delitem(704, 1)
            |> delitem(708, 1)
            |> give_item(5012, 1)
            |> mes("[Teacher]")
            |> mes(
              "I really really appreciate you what you've done for me. I'm truly grateful. I will give my precious item to you as promised."
            )
            |> next()
            |> mes("[Teacher]")
            |> mes(
              "This is the Hat I've worn on my Graduation from my University. It reminds me of my happy school days. Please take this..."
            )
            |> close()
          else
            ctx
            |> mes("[Teacher]")
            |> mes("... Oh, I'm Sorry.")
            |> mes(
              "But that's not what I'm looking for. Maybe you need to study flowers a little bit?"
            )
            |> close()
          end

        _ ->
          ctx
      end
    else
      {ctx, choice} =
        ctx
        |> mes("[Teacher]")
        |> mes("Don't you think...")
        |> mes("Flowers are pretty?")
        |> next()
        |> select(["Talk", "Quit"])

      case choice do
        1 ->
          ctx
          |> mes("[Teacher]")
          |> mes("When I was young,")
          |> mes("I had no friends and")
          |> mes("studied all the time.")
          |> next()
          |> mes("[Teacher]")
          |> mes(
            "Sometimes I regret what I did when I was younger, but it's not a big deal now. Through hard study, I finished entire educational courses earlier than all the other students."
          )
          |> next()
          |> mes("[Teacher]")
          |> mes("However...")
          |> mes(
            "I was sad and sometimes lonely. Whenever the studying got too hard, I needed someone who would listen to me. Finally, one day, I met my best friend."
          )
          |> next()
          |> mes("[Teacher]")
          |> mes(
            "When I saw a Pretty Flower blooming in the abandoned Garden, I realized It was my friend which shared my fate."
          )
          |> next()
          |> mes("[Teacher]")
          |> mes(
            "Although it is a Common and Normal Flower to others, she gave me the reason to study again. I could achieve my goals because of her."
          )
          |> next()
          |> mes("[Teacher]")
          |> mes("So recently...")
          |> mes(
            "I am trying to pay her back. Now I am studying Flowers, and plan to over the whole world with them."
          )
          |> next()
          |> mes("[Teacher]")
          |> mes("To accomplish my work...")
          |> mes(
            "I need bunches of flowers. But for someone who rarely goes outside, it is really hard to find all the flowers I need."
          )
          |> next()
          |> mes("[Teacher]")
          |> mes(
            "I need 1 ^3355FFIllusion Flower^000000 ,1 ^3355FFHinalle^000000,1 ^3355FFAloe^000000 and 1 ^3355FFMent^000000. If you can bring them to me, I'd give you my treasure..."
          )
          |> close()

        2 ->
          ctx
          |> mes("[Teacher]")
          |> mes("One of these days I will cover this whole world with Flowers.")
          |> close()

        _ ->
          ctx
      end
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp has_flowers?(ctx) do
    count_item(ctx, 710) > 0 and count_item(ctx, 703) > 0 and count_item(ctx, 704) > 0 and
      count_item(ctx, 708) > 0
  end
end
