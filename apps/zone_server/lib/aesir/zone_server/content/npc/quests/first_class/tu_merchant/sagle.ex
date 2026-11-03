defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuMerchant.Sagle do
  @moduledoc """
  Sagle, a young Prontera vendor who sells Red Potions to Merchant trainees.

  ## Behavior

  - During the Merchant price-research task (quest step 6, 7 or 8) sells 10 Red Potions
    for 390, 410 and 420 Zeny respectively; buying sets the quest step to 9 for the fair
    cheapest offer or to 10 when the player overpaid or was scammed.
  - Refuses the sale when the player lacks the Zeny or the weight room.
  - Outside the task, he half-remembers market gossip about the Kafra company.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - L0ne_W0lf
    - SinSloth
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "prontera", x: 66, y: 111, dir: 3, sprite: 82, name: "Sagle", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Sagle]")

    case get_char_var(ctx, :tu_merchant, 0) do
      6 -> sell_potions(ctx, 390, 9)
      7 -> sell_potions(ctx, 410, 10)
      8 -> sell_potions(ctx, 420, 10)
      _ -> small_talk(ctx)
    end
  end

  defp small_talk(ctx) do
    ctx
    |> mes("It's on the tip")
    |> mes("of my tongue, but")
    |> mes("I can't quite remember...")
    |> next()
    |> mes("[Sagle]")
    |> mes(
      "You know, the name of the company that has all those beautiful ladies working for it. Ka... Ka-something. Anyway, I hear they're concerned about their growing competition. "
    )
    |> next()
    |> mes("[Sagle]")
    |> mes("It's none of my business, but it's good to know what's going on in")
    |> mes("the world, particularly if it'll affect the markets.")
    |> close()
  end

  defp sell_potions(ctx, cost, next_step) do
    {ctx, choice} =
      ctx
      |> mes("Hello, hello~")
      |> mes("Why don't you buy")
      |> mes("some Red Potions?")
      |> mes(
        "They're essential for travel, and these Red Potions are the best for newer adventurers~"
      )
      |> next()
      |> mes("[Sagle]")
      |> mes(
        "I will sell you 10 Red Potions for ^871F78#{cost} zeny^000000. You'd better get them now while they're still here!"
      )
      |> next()
      |> select(["Buy", "Cancel"])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[Sagle]")
          |> mes("Excellent!")
          |> mes(
            "You certainly have an eye for bargains. Here you go, 10 Red Potions fresh from the... Potioner..."
          )

        cond do
          zeny(ctx) < cost ->
            ctx
            |> next()
            |> mes("[Sagle]")
            |> mes("Whoa, hold on!")
            |> mes("You can't afford")
            |> mes("these potions...")
            |> mes("Please come back")
            |> mes("when you have enough")
            |> mes("Zeny, alright?")
            |> close()

          get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 71 ->
            ctx
            |> next()
            |> mes("[Sagle]")
            |> mes("Whoa, hold on!")
            |> mes(
              "There's no way you carry all of this! Why don't you put some of your stuff in Kafra Storage before coming back?"
            )
            |> close()

          true ->
            ctx
            |> pay_zeny(cost)
            |> set_char_var(:tu_merchant, next_step)
            |> give_item(501, 10)
            |> close()
        end

      2 ->
        ctx
        |> mes("[Sagle]")
        |> mes("Alright...")
        |> mes("But don't")
        |> mes("complain if")
        |> mes("these potions")
        |> mes("are sold out!")
        |> close()

      _ ->
        small_talk(ctx)
    end
  end
end
