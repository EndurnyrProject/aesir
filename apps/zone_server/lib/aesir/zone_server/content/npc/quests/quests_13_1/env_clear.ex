defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.EnvClear do
  @moduledoc """
  The invisible Botanist trigger on the camp field, which reveals the Botanist as the
  Nepenthes is studied.

  ## Behavior

  - Fires on touch and on talk.
  - On `ep13_animal` step 7 reveals the Botanist, explains the glowing pileus and asks for the
    rotting stem to be planted, setting the step to 8.
  - On step 8 repeats the request, and on step 9 only reveals the Botanist.

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
        map: "mid_camp",
        x: 49,
        y: 154,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#env_clear",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @botanist "Botanist#ep13_1"

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx), do: study(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: study(ctx)

  defp study(ctx) do
    case get_char_var(ctx, :ep13_animal, 0) do
      7 -> specimen_briefing(ctx)
      8 -> plant_reminder(ctx)
      9 -> enablenpc(ctx, @botanist)
      _step -> ctx
    end
  end

  defp specimen_briefing(ctx) do
    ctx
    |> enablenpc(@botanist)
    |> mes("[Botanist]")
    |> mes("This is it.")
    |> next()
    |> mes("[Botanist]")
    |> mes("Look.")
    |> mes("You can tell the pileus is creating drops of light which drip to the ground.")
    |> next()
    |> mes("[Botanist]")
    |> mes("Please try to plant the rotting stem in the ground.")
    |> set_char_var(:ep13_animal, 8)
    |> close()
  end

  defp plant_reminder(ctx) do
    ctx
    |> enablenpc(@botanist)
    |> mes("[Botanist]")
    |> mes("Please try to plant the rotting stem in the ground.")
    |> close()
  end
end
