defmodule Aesir.ZoneServer.Content.Npc.Cities.Comodo.Rahasu do
  @moduledoc """
  Offers information about Paros Lighthouse and its view.

  ## Behavior

  - Recounts the lighthouse's history when asked.
  - Recommends the view when the visitor declines.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "cmd_fild07",
        x: 192,
        y: 58,
        dir: 4,
        sprite: 100,
        name: "Rahasu",
        scope: :shared,
        unique_name: "Rahasu#cmd"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Rahasu]")
      |> mes("Hey, I'm Rahasu.")
      |> mes("If you want to learn")
      |> mes("a little more about")
      |> mes("Paros Lighthouse, I'll")
      |> mes("be happy to tell you.")
      |> next()
      |> select(["Paros Lighthouse?", "Cancel"])

    if choice == 1 do
      tell_history(ctx)
    else
      recommend_view(ctx)
    end
  end

  defp tell_history(ctx) do
    ctx
    |> mes("[Rahasu]")
    |> mes("For many years, this")
    |> mes("lighthouse guided many")
    |> mes("ships to shore. That was")
    |> mes("a long time ago: now this")
    |> mes("lighthouse sits quietly,")
    |> mes("unused, but never unloved.")
    |> next()
    |> mes("[Rahasu]")
    |> mes("Although this place")
    |> mes("isn't the center of")
    |> mes("trade and commerce that")
    |> mes("it used to be, plenty of")
    |> mes("people still wander to this")
    |> mes("area. I wonder why, exactly...")
    |> close()
  end

  defp recommend_view(ctx) do
    ctx
    |> mes("[Rahasu]")
    |> mes("Hey, before you leave,")
    |> mes("you really ought to check")
    |> mes("the view from the lighthouse.")
    |> mes("It's... It's breathtaking...")
    |> close()
  end
end
