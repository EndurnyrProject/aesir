defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.PoorLookingMerchant do
  @moduledoc """
  Machen discusses the Alchesh family and their wealth.

  ## Behavior

  - Changes his conversation as the Sign quest progresses.
  - Directs adventurers looking for Bakerlan to the Alchesh Estate.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta",
        x: 43,
        y: 49,
        dir: 5,
        sprite: 89,
        name: "Poor-looking Merchant",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Machen]")

    cond do
      get_char_var(ctx, :sign_q, 0) < 35 ->
        lament_lost_wealth(ctx)

      get_char_var(ctx, :sign_q, 0) < 52 or get_char_var(ctx, :sign_q, 0) == 98 ->
        {ctx, choice} =
          ctx
          |> mes("^333333*Sigh...*^000000")
          |> mes("How did it happen?")
          |> mes("How did the Alcheshs")
          |> mes("become so rich so quickly?")
          |> next()
          |> select(["Alchesh family?", "Do you know where Mr. Bakerlan is?"])

        case choice do
          1 ->
            ctx
            |> mes("[Machen]")
            |> mes("My family, the Tudas,")
            |> mes("used to run the biggest")
            |> mes("trading company in Alberta.")
            |> mes("But when the Alcheshs came")
            |> mes("fifty years ago, they started")
            |> mes("to outdo us in everything...")
            |> next()
            |> mes("[Machen]")
            |> mes("It's like they're financial")
            |> mes("geniuses or something!")
            |> mes("Under Bakerlan's guidance,")
            |> mes("their estate has grown to be")
            |> mes("one of the richest in Alberta,")
            |> mes("if not all of Rune-Midgarts...")
            |> close()

          2 ->
            {ctx, _} =
              ctx
              |> mes("[Machen]")
              |> mes("Bakerlan...?")
              |> mes("Oh, he's probably")
              |> mes("in his ten story money")
              |> mes("vault, swimming in his")
              |> mes("money by now. You")
              |> mes("know rich people.")
              |> next()
              |> select(["........."])

            ctx
            |> mes("[Machen]")
            |> mes("It-was-a-joke!")
            |> mes("You see that big")
            |> mes("mansion to the north?")
            |> mes("That's the Alchesh Estate.")
            |> mes("He should be home now.")
            |> next()
            |> mes("[Machen]")
            |> mes("He usually travels")
            |> mes("a lot on business,")
            |> mes("but if you're lucky you")
            |> mes("should be able to catch him.")
            |> close()

          _ ->
            ctx
        end

      get_char_var(ctx, :sign_q, 0) == 97 ->
        lament_lost_wealth(ctx)

      true ->
        ctx
        |> mes("You know, if the Alcheshs")
        |> mes("were greedy, they actually")
        |> mes("wouldn't be as big as they")
        |> mes("are today. They've contributed")
        |> mes("to a lot of social causes and")
        |> mes("that won them a lot of support.")
        |> next()
        |> mes("[Machen]")
        |> mes("I gotta admit...")
        |> mes("The whole family")
        |> mes("is a bunch of financial")
        |> mes("geniuses, alright.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp lament_lost_wealth(ctx) do
    ctx
    |> mes("Why...?")
    |> mes("How did my")
    |> mes("family's wealth")
    |> mes("and prestige just")
    |> mes("go down the drain?")
    |> next()
    |> mes("[Machen]")
    |> mes("Ever since the")
    |> mes("Alcheshs came to Alberta,")
    |> mes("they quickly took our place")
    |> mes("as the biggest business owners")
    |> mes("here. It's our biggest shame...")
    |> close()
  end
end
