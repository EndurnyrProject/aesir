defmodule Aesir.ZoneServer.Content.Npc.Cities.Gonryun.KunlunEnvoy15364 do
  @moduledoc """
  Guides departing Kunlun visitors back to the harbor.

  ## Behavior

  - Warps consenting travelers to the harbor after closing the conversation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - x[tsk]
    - KarLaeda

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gonryun",
        x: 153,
        y: 64,
        dir: 7,
        sprite: 776,
        name: "Kunlun Envoy",
        scope: :shared,
        unique_name: "Kunlun Envoy#gon4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Zhang Quing Long]")
      |> mes("Please make yourself comfortable.")
      |> mes("If you want to go back, I will")
      |> mes("be more than happy to guide you")
      |> mes("to the ship to Alberta.")
      |> next()
      |> select(["Go back to the harbor", "Cancel"])

    if choice == 1 do
      ctx
      |> mes("[Zhang Quing Long]")
      |> mes("I hope you enjoyed your trip.")
      |> mes("Now, let me guide you back")
      |> mes("to the harbor.")
      |> close()
      |> warp("gon_fild01", 258, 82)
    else
      ctx
      |> mes("[Zhang Quing Long]")
      |> mes("Take your time, my guest.")
      |> mes("There should be many places")
      |> mes("you may have missed.")
      |> close()
    end
  end
end
