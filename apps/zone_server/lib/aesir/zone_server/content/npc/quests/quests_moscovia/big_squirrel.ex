defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.BigSquirrel do
  @moduledoc """
  A large squirrel exchanges acorns for randomly selected jewels.

  ## Behavior

  - Consumes 20 acorns for a random jewel.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_fild01",
        x: 113,
        y: 108,
        dir: 3,
        sprite: 111,
        name: "Big Squirrel",
        scope: :shared,
        unique_name: "Big Squirrel#mos",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch", ctx), do: on_talk(ctx)

  @impl true
  def on_talk(ctx) do
    cond do
      max_weight(ctx) - weight(ctx) < 2000 ->
        ctx
        |> mes("- Please stop here!! -")
        |> mes("- You're carrying too many items -")
        |> mes("- Please try again -")
        |> mes("- after using the kafra service -")
        |> close()

      true ->
        ctx =
          ctx
          |> mes("- It's an extraordinary big squirrel. -")
          |> next()
          |> mes(
            "- When the animal comes across you, it starts to sniffle and purse up its lips. -"
          )
          |> next()

        if count_item(ctx, 1026) > 19 do
          {ctx, choice} =
            select(ctx, ["Give acorns to it.", "Ignore it.", "Ask about the squirrel."])

          interact(ctx, choice)
        else
          ctx
          |> mes(
            "- The squirrel looks at the acorn which you held for a while but it turned its head with indifference. -"
          )
          |> close()
        end
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp interact(ctx, 1) do
    ctx =
      ctx
      |> mes("- You take one of acorns out and hold it out to the squirrel. -")
      |> next()
      |> mes("- It cocked it's ears up and begins to nibble the acorn quickly. -")
      |> next()
      |> mes("- It makes a crunching sound -")
      |> mes("- It makes a crunching sound -")
      |> mes("- It makes a crunching sound -")
      |> next()
      |> mes(
        "- After eating the acorn up, the squirrel dances around wildly. Suddenly it curls its body and throws something up with a spit-spit sound -"
      )
      |> delitem(1026, 20)
      |> set_local(:cyworld, Enum.random(1..1000))
      |> set_local(:stworld, Enum.random(1..150))

    ctx |> reward(get_local(ctx, :cyworld, 0), get_local(ctx, :stworld, 0)) |> close()
  end

  defp interact(ctx, 2) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("It's so cute.")
    |> close()
  end

  defp interact(ctx, 3) do
    ctx
    |> mes("[Aged Man]")
    |> mes("Is it bigger than an ordinary one?")
    |> mes("I found it one day and was barely able to save it...")
    |> next()
    |> mes("[Aged Man]")
    |> mes("I felt that heaven had sent me a friend so that my life wouldn't be so lonely.")
    |> next()
    |> mes("[Aged Man]")
    |> mes(
      "But I didn't know that it eats so much, it won't give me any attention if I give anything ^3131FFbelow 20 acorns^000000."
    )
    |> mes("That's why it's bigger than ordinary ones hahaha.")
    |> close()
  end

  defp interact(ctx, _), do: ctx

  defp reward(ctx, roll, stone) do
    cond do
      rem(roll, 100) == 0 and roll < 1000 and stone < 90 ->
        item =
          cond do
            stone < 10 -> 718
            stone < 20 -> 719
            stone < 30 -> 720
            stone < 40 -> 721
            stone < 50 -> 722
            stone < 60 -> 723
            stone < 70 -> 725
            stone < 80 -> 728
            true -> 729
          end

        give_item(ctx, item, 1)

      rem(roll, 100) == 0 and roll < 1000 and stone < 100 ->
        item =
          cond do
            roll in [100, 400, 700] -> 730
            roll in [200, 500, 800] -> 731
            true -> 732
          end

        give_item(ctx, item, 1)

      rem(roll, 100) == 0 and roll < 1000 ->
        rare_reward(ctx, roll)

      roll == 1000 ->
        give_item(ctx, 727, 1)

      roll < 500 ->
        give_item(ctx, 733, 1)

      true ->
        give_item(ctx, 724, 1)
    end
  end

  defp rare_reward(ctx, 200) do
    ctx = set_local(ctx, :stonez1, Enum.random(1..10))
    stone = get_local(ctx, :stonez1, 0)

    item =
      cond do
        stone < 6 -> 7290
        stone < 8 -> 7297
        true -> 7292
      end

    give_item(ctx, item, 1)
  end

  defp rare_reward(ctx, 300) do
    give_item(ctx, if(Enum.random(1..10) < 6, do: 7291, else: 7294), 1)
  end

  defp rare_reward(ctx, roll) do
    item =
      %{100 => 7289, 400 => 7295, 500 => 7293, 600 => 7292, 700 => 7290, 800 => 7296, 900 => 7297}[
        roll
      ]

    if item, do: give_item(ctx, item, 1), else: ctx
  end
end
