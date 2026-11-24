defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.Ayofootprint6 do
  @moduledoc """
  Reveals a clue along Annon's trail through the dungeon.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Fredzilla
    - MasterOfMuppets
    - Lupus
    - Silent
    - Evera
    - SinSloth
    - L0ne_W0lf
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ayo_dun02",
        x: 135,
        y: 168,
        dir: 0,
        sprite: 139,
        name: "AyoFootprint6",
        scope: :shared,
        trigger: {0, 2}
      }
    ]

  @white_potion 504
  @yellow_potion 503

  @impl true
  def on_event("OnTouch_", ctx), do: follow_trail(ctx)

  @impl true
  def on_talk(ctx), do: follow_trail(ctx)

  defp follow_trail(ctx) do
    if get_char_var(ctx, :thai_find, 0) == 9 and Enum.random(1..3) == 1 do
      {ctx, choice} =
        ctx
        |> emotion(:surprise, playerattached(ctx))
        |> mes("^3355FFThe trail of footprints")
        |> mes("continue here, and seem")
        |> mes("to look more freshly made.^000000.")
        |> next()
        |> mes("^3355FFHmm...?")
        |> mes("There's something here...^000000")
        |> next()
        |> select(["Ignore.", "^5C3317Investigate.^000000"])

      case choice do
        1 ->
          ctx
          |> mes("[#{char_name(ctx, 0)}]")
          |> mes("Well, it's probably nothing. But which way should I go now?")
          |> set_char_var(:thai_find, 10)
          |> close()

        2 ->
          ctx = set_local(ctx, :randayo, Enum.random(1..10))
          roll = get_local(ctx, :randayo, 0)

          cond do
            roll < 2 -> potions(ctx, "White", @white_potion)
            roll > 2 and roll < 5 -> potions(ctx, "Yellow", @yellow_potion)
            true -> rat(ctx)
          end

        _ ->
          ctx
      end
    else
      ctx
    end
  end

  defp potions(ctx, color, item) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes(
        "Why, this is a pack of #{color} Potions. Whoever owned these must have dropped these by accident. Hmm, I could use these for later..."
      )
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Wait...")
    |> mes("There are more")
    |> mes("footprints heading")
    |> mes("toward the ^5C3317East^000000.")
    |> mes("I better look")
    |> mes("into this.")
    |> set_char_var(:thai_find, 10)
    |> give_item(item, 10)
    |> close()
  end

  defp rat(ctx) do
    ctx =
      ctx
      |> mes("[Rat]")
      |> mes("^FF0000Squeak!")
      |> mes("^FF0000Squeak Squeak!^000000")

    ctx = ctx |> emotion(:huk, playerattached(ctx)) |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("^8C1717Wah^000000!")
    |> mes("What was that?!")
    |> next()
    |> mes("^3355FFIt was just a rat.")
    |> mes("It feels awful silly to be scared by just a little rat, does it not?^000000")
    |> next()
    |> mes("^3355FFYou find another trail")
    |> mes("of footprints that heads")
    |> mes("towards the ^5C3317East^3355FF.^000000")
    |> set_char_var(:thai_find, 10)
    |> close()
  end
end
