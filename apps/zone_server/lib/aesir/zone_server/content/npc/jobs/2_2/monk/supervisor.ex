defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Monk.Supervisor do
  @moduledoc """
  Counts laps of the Monk marathon trial at the finish line.

  ## Behavior

  - Advances the lap count and sends the runner back to the start for another lap.
  - Announces the final lap, then congratulates the finisher and sends them to Tomoon.

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
        x: 387,
        y: 350,
        dir: 0,
        sprite: 45,
        name: "Supervisor",
        scope: :shared,
        unique_name: "Supervisor#race_monk",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx), do: count_lap(ctx, get_char_var(ctx, :MONK_Q, 0))

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp count_lap(ctx, lap) when lap >= 15 and lap <= 23 do
    ctx
    |> set_char_var(:MONK_Q, lap + 1)
    |> warp("monk_test", 385, 388)
  end

  defp count_lap(ctx, lap) when lap == 24 do
    ctx
    |> set_char_var(:MONK_Q, 25)
    |> changequest(3028, 3029)
    |> mapannounce(
      "monk_test",
      "Now! This is the last lap!! If you make it you need to go visit Tomoon for the next test!",
      1
    )
    |> warp("monk_test", 385, 388)
  end

  defp count_lap(ctx, lap) when lap == 25 do
    ctx
    |> mes("[Supervisor]")
    |> mes("Now...you may go visit Tomoon.")
    |> mes("Tomoon is in the deepest room inside a building near this abbey.")
    |> mapannounce(
      "monk_test",
      Rathena.concat(
        Rathena.concat("Congratulations!", char_name(ctx, 0)),
        "!! You completed the marathon!"
      ),
      1
    )
    |> close()
    |> warp("prt_monk", 194, 168)
  end

  defp count_lap(ctx, _lap), do: ctx
end
