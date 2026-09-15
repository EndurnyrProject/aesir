defmodule Aesir.ZoneServer.Content.Npc.Cities.Louyang.Girl do
  @moduledoc """
  Offers travelers a return trip from Luoyang to Alberta.

  ## Behavior

  - Warps consenting travelers to mode-appropriate Alberta coordinates after saying goodbye.
  - Encourages those who stay to enjoy Luoyang's food and people.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Vidar
    - Mass Zero
    - Dino9021
    - Celest
    - MasterOfMuppets
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lou_fild01",
        x: 190,
        y: 100,
        dir: 7,
        sprite: 815,
        name: "Girl",
        scope: :shared,
        unique_name: "Girl#1lou"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Girl]")
      |> mes("Would you")
      |> mes("like to go back")
      |> mes("to Alberta?")
      |> next()
      |> select(["Go back to Alberta.", "Cancel."])

    if choice == 1 do
      return_to_alberta(ctx)
    else
      encourage_visit(ctx)
    end
  end

  defp return_to_alberta(ctx) do
    ctx =
      ctx
      |> mes("[Girl]")
      |> mes("I hope to")
      |> mes("see you again!")
      |> mes("Bye bye!")
      |> close()

    if Rathena.truthy?(checkre(ctx, 0)) do
      warp(ctx, "alberta", 245, 87)
    else
      warp(ctx, "alberta", 235, 45)
    end
  end

  defp encourage_visit(ctx) do
    ctx =
      ctx
      |> mes("[Girl]")
      |> mes("If you like this")
      |> mes("area, why don't you")
      |> mes("stay and enjoy the")
      |> mes("the food and the sights!")
      |> next()

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        ctx
        |> mes("[Girl]")
        |> mes("And by sights...")
        |> mes("I mean girls!")
        |> mes("Tee hee~")
      else
        ctx
        |> mes("[Girl]")
        |> mes("And the boys here")
        |> mes("aren't bad looking~")
      end

    close(ctx)
  end
end
