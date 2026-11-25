defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.SupplyStack207168 do
  @moduledoc """
  A supply stack that may hide medicine for the doctor quest.

  ## Behavior

  - Allows a search for medicine during the appropriate quest stage.
  - Warns players who are carrying too much or disturbing the storage.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lou_in02",
        x: 207,
        y: 168,
        dir: 0,
        sprite: 111,
        name: "Supply Stack",
        scope: :shared,
        unique_name: "Supply Stack#5lou"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      max_weight(ctx) - weight(ctx) < 2000 -> overweight(ctx)
      get_char_var(ctx, :ch_par, 0) == 4 -> search(ctx)
      true -> inspect_stack(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp overweight(ctx) do
    ctx
    |> mes("^3355FF* Wait a minute !! *")
    |> mes(
      "You're carrying too many items with you. Please put some of your items into your Kafra Storage and try again.^000000"
    )
    |> close()
  end

  defp search(ctx) do
    if Enum.random(1..20) == 13 do
      ctx =
        ctx
        |> mes("^3355FF*Rummage rummage*")
        |> mes(
          "It seems there's something inside of this stack. You decide to rummage around to see if you can find anything.^000000"
        )
        |> next()

      if Enum.random(1..100) == 43, do: found_medicine(ctx), else: search_failed(ctx)
    else
      ctx
      |> mes("^3355FF*Rummage rummage*")
      |> mes("You didn't find anything. You decided to give up your search.^000000")
      |> close()
    end
  end

  defp found_medicine(ctx) do
    ctx
    |> rummage()
    |> mes("You found a medicine.^000000")
    |> set_char_var(:ch_par, 9)
    |> changequest(11050, 11056)
    |> give_item(7252, 1)
    |> next()
    |> mes("[Jiang Xiayou]")
    |> mes("Err...")
    |> mes("You found it...?!")
    |> mes("I can't believe it!")
    |> mes("You just lucked out.")
    |> close()
  end

  defp search_failed(ctx) do
    ctx
    |> rummage()
    |> mes("You didn't find anything.^000000")
    |> next()
    |> mes("[Jiang Xiayou]")
    |> mes("Hey, hey...")
    |> mes("I told you!")
    |> mes("It's not too late for you")
    |> mes("to do the favor I asked.")
    |> mes("I'm only asking you once!")
    |> close()
  end

  defp rummage(ctx) do
    ctx
    |> mes("^3355FF*Rummage rummage*")
    |> mes("*Rummage rummage*")
    |> mes("*Rummage rummage*")
  end

  defp inspect_stack(ctx) do
    ctx =
      ctx
      |> mes(
        "^3355FFThere are many things piled up to the ceiling. Since there is too much stuff jumbled together, it doesn't seem possible that you'll find anything in this stack.^000000"
      )
      |> next()
      |> mes("[Jiang Xiayou]")
      |> mes(
        "Hey, don't touch anything! If you mess anything up, you've gotta pile it up again, got it? If you don't want to clean up after yourself, don't make a mess!"
      )

    ctx
    |> emotion(:rock, getnpcid(ctx, "Storage Keeper#lou"))
    |> close()
  end
end
