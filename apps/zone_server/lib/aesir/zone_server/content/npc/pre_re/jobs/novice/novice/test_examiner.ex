defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.Novice.Novice.TestExaminer do
  @moduledoc """
  Offers passage from pre-renewal combat training to the final course.

  ## Behavior

  - Asks whether the trainee wants to proceed to the next course.
  - Transfers willing trainees to the final course or lets them continue practicing.

  ## Credits

  - Original from rAthena, authors: Dr.Evil and MasterOfMuppets.
  - Elixir adaptation: transpiled and refactored by an LLM.
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "new_1-3",
        x: 96,
        y: 174,
        dir: 3,
        sprite: 85,
        name: "Test Examiner",
        unique_name: "NovKeyman"
      },
      %{
        map: "new_2-3",
        x: 96,
        y: 174,
        dir: 3,
        sprite: 85,
        name: "Test Examiner",
        unique_name: "Test Examiner#nv2"
      },
      %{
        map: "new_3-3",
        x: 96,
        y: 174,
        dir: 3,
        sprite: 85,
        name: "Test Examiner",
        unique_name: "Test Examiner#nv3"
      },
      %{
        map: "new_4-3",
        x: 96,
        y: 174,
        dir: 3,
        sprite: 85,
        name: "Test Examiner",
        unique_name: "Test Examiner#nv4"
      },
      %{
        map: "new_5-3",
        x: 96,
        y: 174,
        dir: 3,
        sprite: 85,
        name: "Test Examiner",
        unique_name: "Test Examiner#nv5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Keyman]")
      |> mes("Good!!")
      |> mes("Now you know how to fight")
      |> mes("against monsters, don't you?")
      |> mes("Would you like to move")
      |> mes("to the next course?")
      |> next()
      |> select(["Yes", "No"])

    case choice do
      1 ->
        ctx
        |> mes("[Keyman]")
        |> mes("I hope you will be")
        |> mes("a good fighter in the")
        |> mes("future. Bon voyage.")
        |> close()
        |> warp("new_1-4", 99, 10)

      2 ->
        ctx
        |> mes("[Keyman]")
        |> mes("I see...")
        |> mes(
          "It can't hurt to practice until you're more comfortable with the basics of battle."
        )
        |> close()

      _ ->
        ctx
    end
  end
end
