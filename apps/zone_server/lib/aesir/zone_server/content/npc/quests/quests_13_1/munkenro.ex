defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Munkenro do
  @moduledoc """
  Munkenro, the new head of the three-kingdom alliance, overheard through the camp's wall at
  each stage of the Ash-Vacuum quest.

  ## Behavior

  - At `ep13_ryu` step 20 the player overhears the alliance head's decision to push on anyway.
  - At steps 18 and 19 he says the attempt cannot be controlled anymore, and at 15 to 17 he
    doubts the three kingdoms' peace.
  - At step 14 he explains why he stands in for Sikaiz, and stays silent otherwise.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 136,
        y: 260,
        dir: 5,
        sprite: 967,
        name: "Munkenro",
        scope: :shared,
        unique_name: "Munkenro#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ep13_ryu, 0) do
      20 -> overheard_decision(ctx)
      step when step in [18, 19] -> ready_to_try(ctx)
      step when step in [15, 16, 17] -> peace_doubt(ctx)
      14 -> duty_bound(ctx)
      _step -> silence(ctx)
    end
  end

  defp overheard_decision(ctx) do
    ctx =
      ctx
      |> mes(
        "-At this spot, it's possible to overhear something. Listen carefully through the wall...-"
      )
      |> next()
      |> mes("[Munkenro]")
      |> mes("You're a good buddy!")
      |> mes("But...")
      |> next()
      |> mes("[Munkenro]")
      |> mes("We can't avoid this...")
      |> mes("You know better than I!")
      |> mes("We can't go through this,")
      |> mes("in this current status.")
      |> next()
      |> mes("[Munkenro]")
      |> mes("I did all I could do...")
      |> mes("Please...")
      |> next()
      |> mes("[Munkenro]")
      |> mes("......")
      |> next()
      |> mes("[Munkenro]")
      |> mes("............")
      |> next()
      |> mes("..................")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("There's no avoiding it.")
    |> mes("Ok, I need to try.")
    |> close()
  end

  defp ready_to_try(ctx) do
    ctx
    |> mes("[Munkenro]")
    |> mes("You are ready to try this...")
    |> next()
    |> mes("[Munkenro]")
    |> mes("Oh! My friend...")
    |> next()
    |> mes("[Munkenro]")
    |> mes("Nothing can be controlled anymore... Am I trying this...?")
    |> close()
  end

  defp peace_doubt(ctx) do
    ctx
    |> mes("[Munkenro]")
    |> mes("Peace for the three kingdoms...?")
    |> mes("Isn't it impossible...?")
    |> next()
    |> mes("[Munkenro]")
    |> mes("Are you sure that")
    |> mes("you can do that?")
    |> close()
  end

  defp duty_bound(ctx) do
    ctx
    |> mes("[Munkenro]")
    |> mes("Nothing shall prevent me from doing my duty. Nothing!")
    |> next()
    |> mes("[Munkenro]")
    |> mes(
      "Sikaiz is a kind and upright person. But he can't be cautious about everything. It could cause serious problems."
    )
    |> next()
    |> mes("[Munkenro]")
    |> mes("So that's why I am here for him. I always worry about him...")
    |> next()
    |> mes("[Munkenro]")
    |> mes("I don't know what I would do if something were to happen...")
    |> close()
  end

  defp silence(ctx) do
    ctx
    |> mes("[Munkenro]")
    |> mes("......")
    |> close()
  end
end
