defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Monk.Proctor9585 do
  @moduledoc """
  Admits Monk candidates into a wing of the spirit maze trial.

  ## Behavior

  - Explains the maze on request.
  - Marks the candidate as in the maze trial and warps them to the maze entrance.

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
        x: 95,
        y: 85,
        dir: 1,
        sprite: 79,
        name: "Proctor",
        scope: :shared,
        unique_name: "Proctor#btl#3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Proctor]")
      |> mes("So, are you ready to undergo this spiritual training?")
      |> next()
      |> select(["Yes!", "No.", "Check the caution for the test."])

    case choice do
      1 -> enter_maze(ctx)
      2 -> ctx |> mes("[Proctor]") |> mes("I see. Take your time.") |> close()
      3 -> explain_maze(ctx)
      _ -> ctx
    end
  end

  defp enter_maze(ctx) do
    ctx
    |> mes("[Proctor]")
    |> mes(
      "Alright! I wish you luck. If you get lost and can't find a way out, simply log out and log back in."
    )
    |> mes(
      "Then you will return to your save point. What's that mean? Heck if I know, I'm just told to say that. Oh yes and also, please cooperate with your comrades."
    )
    |> close()
    |> set_char_var(:MONK_Q, 26)
    |> warp("monk_test", 230, 277)
  end

  defp explain_maze(ctx) do
    ctx
    |> mes("[Proctor]")
    |> mes("Inside this test hall is the maze of spirits.")
    |> mes("There are spirits inside which will block you from moving freely.")
    |> next()
    |> mes("[Proctor]")
    |> mes(
      "If you want to exit the test hall, you must make your way to the warp portal located at the opposite side from the start point."
    )
    |> next()
    |> mes("[Proctor]")
    |> mes(
      "....Oh yes and also there are monsters wandering around in the maze, please clear them."
    )
    |> mes("Good luck.")
    |> close()
  end
end
