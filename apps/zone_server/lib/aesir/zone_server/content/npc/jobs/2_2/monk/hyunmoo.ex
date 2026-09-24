defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Monk.Hyunmoo do
  @moduledoc """
  Runs the mushroom-gathering test of the Monk job quest.

  ## Behavior

  - Explains the test to candidates without mushrooms and lets them quit.
  - Treats candidates holding too few mushrooms as quitting after their answer.
  - Passes candidates holding 30 of either mushroom, takes the mushrooms, and sends them to Tomoon.
  - Reminds candidates past this test to go meet Tomoon.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Dino9021
    - Celest
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Lupus
    - Yor
    - Zephiris
    - Vicious
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_monk",
        x: 225,
        y: 180,
        dir: 1,
        sprite: 89,
        name: "Hyunmoo",
        scope: :shared,
        unique_name: "Hyunmoo#mk"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest = get_char_var(ctx, :MONK_Q, 0)
    net_mushrooms = count_item(ctx, 1069)
    gooey_mushrooms = count_item(ctx, 1070)
    in_test? = quest > 14 and quest < 25

    cond do
      (net_mushrooms > 0 or gooey_mushrooms > 0) and net_mushrooms < 30 and
          gooey_mushrooms < 30 ->
        demand_more_mushrooms(ctx)

      in_test? and (net_mushrooms == 0 or gooey_mushrooms == 0) ->
        explain_test(ctx)

      in_test? and (net_mushrooms > 29 or gooey_mushrooms > 29) ->
        pass_test(ctx)

      quest > 24 ->
        ctx
        |> mes("[Hyunmoo]")
        |> mes(
          "Didn't I tell you to go meet ^FF0000Tomoon^000000? Or do you want to pick some more mushrooms?"
        )
        |> mes("Tomoon is staying in the deepest room inside a building near this abbey.")
        |> close()

      true ->
        ctx
    end
  end

  defp demand_more_mushrooms(ctx) do
    {ctx, _answer} =
      ctx
      |> mes("[Hyunmoo]")
      |> mes("You didn't bring enough mushrooms... go get some more.")
      |> next()
      |> mes("[Hyunmoo]")
      |> mes("Or is it you want to quit... do you want to quit?")
      |> next()
      |> select(["No.", "Yes."])

    ctx
    |> mes("[Hyunmoo]")
    |> mes(".....I figured as much....you don't have a spirit.")
    |> announce_quit(", has quit his testing to become a monk.")
    |> close()
    |> set_char_var(:MONK_Q, 16)
    |> changequest(3027, 3028)
    |> warp("prt_monk", 194, 168)
  end

  defp explain_test(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hyunmoo]")
      |> mes("Nice to meet you. My name is Hyunmoo. I am in charge of the mushroom test.")
      |> next()
      |> mes("[Hyunmoo]")
      |> mes("Your task will be to gather mushrooms.")
      |> mes("Understand?")
      |> next()
      |> mes("[Hyunmoo]")
      |> mes("Picking the mushrooms is to train your tolerance.")
      |> mes("We planted a garden in order to survive as well as to discipline our minds.")
      |> next()
      |> mes("[Hyunmoo]")
      |> mes(
        "I believe there is no better way to find true inner peace then to be one with nature."
      )
      |> mes("So we created our garden, however these mushrooms started sprouting up everywhere!")
      |> next()
      |> mes("[Hyunmoo]")
      |> mes("What we ask of you as part of your training is to remove these mushrooms.")
      |> mes("Go help the others remove as many mushrooms as you can and bring me back")
      |> mes(
        "enough ^FF0000Orange Net Mushrooms^000000 and ^FF0000Orange Gooey Mushroom^000000 as proof."
      )
      |> next()
      |> mes("[Hyunmoo]")
      |> mes("Now, go get some mushrooms.")
      |> mes("Check back with me when you have picked some, I will tell you if it is enough.")
      |> mes("And remember, find peace when gardening.")
      |> next()
      |> mes("[Hyunmoo]")
      |> mes("...or do you want to quit?")
      |> next()
      |> select(["No.", "Yes."])

    if choice == 1 do
      ctx |> mes("[Hyunmoo]") |> mes("Alright then, keep going.") |> close()
    else
      ctx
      |> mes("[Hyunmoo]")
      |> mes(".....yeah I thought as much....you don't have the spirit needed to become a monk.")
      |> announce_quit(", has quit his testing to become a monk.")
      |> remove_mushrooms()
      |> close()
      |> announce_quit(", has quit his training to become a monk.")
      |> warp("prt_monk", 194, 168)
      |> set_char_var(:MONK_Q, 16)
      |> changequest(3027, 3028)
    end
  end

  defp pass_test(ctx) do
    ctx
    |> mes("[Hyunmoo]")
    |> mes("...hmm... not bad.")
    |> mes("Ok, you passed.")
    |> next()
    |> mes("[Hyunmoo]")
    |> mes("Go meet Tomoon for your next test.")
    |> mes("Tomoon is staying in the deepest room inside a building near this abbey.")
    |> set_char_var(:MONK_Q, 25)
    |> changequest(3027, 3029)
    |> remove_mushrooms()
    |> close()
    |> warp("prt_monk", 194, 168)
  end

  defp announce_quit(ctx, message) do
    mapannounce(
      ctx,
      "job_monk",
      Rathena.concat(Rathena.concat("", char_name(ctx, 0)), message),
      1
    )
  end

  defp remove_mushrooms(ctx) do
    ctx = delitem(ctx, 1069, count_item(ctx, 1069))
    delitem(ctx, 1070, count_item(ctx, 1070))
  end
end
