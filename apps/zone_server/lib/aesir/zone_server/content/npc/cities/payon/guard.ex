defmodule Aesir.ZoneServer.Content.Npc.Cities.Payon.Guard do
  @moduledoc """
  Refuses entry to visitors except those at exactly base level 30.

  ## Behavior

  - Turns away visitors below or above base level 30 with different dialogue.
  - Says nothing to visitors at exactly base level 30.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad Dib
    - Darkchild
    - DracoRPG
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon_in03",
        x: 102,
        y: 185,
        dir: 5,
        sprite: 708,
        name: "Guard",
        scope: :shared,
        unique_name: "Guard#payon"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case base_level(ctx) do
      level when level < 30 -> reject_inexperienced_visitor(ctx)
      level when level > 30 -> reject_visitor(ctx)
      _ -> ctx
    end
  end

  defp reject_inexperienced_visitor(ctx) do
    ctx
    |> mes("[Guard]")
    |> mes("Hey...!")
    |> mes("You're not")
    |> mes("allowed here!")
    |> mes("Go back outside!")
    |> close()
  end

  defp reject_visitor(ctx) do
    ctx
    |> mes("[Guard]")
    |> mes("I'm sorry,")
    |> mes("but you're")
    |> mes("not allowed here.")
    |> mes("Please leave.")
    |> close()
  end
end
