defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Monk.Bashu do
  @moduledoc """
  Sends Monk candidates into the test hall of their choice.

  ## Behavior

  - Lets candidates choose between the mushroom-gathering and marathon tests.
  - Welcomes other visitors to the abbey.

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
        map: "monk_test",
        x: 329,
        y: 61,
        dir: 3,
        sprite: 753,
        name: "Bashu",
        scope: :shared,
        unique_name: "Bashu#mk"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest = get_char_var(ctx, :MONK_Q, 0)

    if quest > 14 and quest < 25 do
      ctx
      |> introduce_tests(quest)
      |> choose_test()
    else
      ctx
      |> mes("[Bashu]")
      |> mes("Welcome... this place is a training place for monks, Saint Capitolina Abbey.")
      |> mes(
        "When you go inside....you will meet Tomoon the oldest monk who succeeds to the predecessors,"
      )
      |> next()
      |> mes("[Bashu]")
      |> mes("Please be advised and do not touch anything.")
      |> mes("And please avoid talking loud in front of Tomoon.")
      |> next()
      |> mes("[Bashu]")
      |> mes("I hope you will have a great time in here.")
      |> close()
    end
  end

  defp introduce_tests(ctx, quest) when quest == 15 do
    ctx
    |> mes("[Bashu]")
    |> mes("So, which test do you want to do...?")
    |> next()
    |> mes("[Bashu]")
    |> mes("From what I've heard, you chose the mushroom test...")
    |> mes("Oh well, it's still your choice.")
  end

  defp introduce_tests(ctx, quest) when quest == 16 do
    ctx
    |> mes("[Bashu]")
    |> mes("Which test hall do you wish to enter?")
    |> next()
    |> mes("[Bashu]")
    |> mes("Well, as far as I've been told, you chose the marathon test...")
    |> mes("Oh well, it's your choice.")
  end

  defp introduce_tests(ctx, _quest) do
    ctx
    |> mes("[Bashu]")
    |> mes("Which test hall do you wish to enter?")
    |> mes("You can choose which one you want.")
    |> next()
  end

  defp choose_test(ctx) do
    {ctx, choice} =
      ctx |> next() |> select(["Tolerance - Gathering Mushrooms", "Self-Control - Marathon"])

    if choice == 1 do
      ctx
      |> mes(
        "You have decided to take the test of tolerance by ^FF0000gathering mushrooms^000000."
      )
      |> close()
      |> warp("job_monk", 226, 175)
    else
      ctx
      |> mes(
        "You have decided to take the test of self control by taking a ^FF0000marathon^000000."
      )
      |> close()
      |> warp("monk_test", 386, 387)
    end
  end
end
