defmodule Aesir.ZoneServer.Content.Npc.Cities.Gonryun.KunlunEnvoy do
  @moduledoc """
  Offers travelers passage from Kunlun back to Alberta.

  ## Behavior

  - Returns consenting travelers to Alberta after closing the conversation.
  - Uses the destination coordinates for the active game mode.

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
        map: "gon_fild01",
        x: 255,
        y: 79,
        dir: 7,
        sprite: 776,
        name: "Kunlun Envoy",
        scope: :shared,
        unique_name: "Kunlun Envoy#gon2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Wa Bai Hu]")
      |> mes("So, did you enjoy your trip?")
      |> mes("I guess it's the time for you to")
      |> mes("go home. The ship to Rune-Midgarts is ready to depart at any time.")
      |> next()
      |> select(["Go back to Alberta", "Cancel"])

    if choice == 1 do
      return_to_alberta(ctx)
    else
      ctx
      |> mes("[Wa Bai Hu]")
      |> mes("Take your time, my guest.")
      |> mes("There should be many places")
      |> mes("you may have missed.")
      |> close()
    end
  end

  defp return_to_alberta(ctx) do
    ctx =
      ctx
      |> mes("[Wa Bai Hu]")
      |> mes("Please come again.")
      |> mes("I hope you will let your friends")
      |> mes("know about Kunlun when you get")
      |> mes("back. Now, let me guide you")
      |> mes("back to Alberta.")
      |> close()

    if Rathena.truthy?(checkre(ctx, 0)) do
      warp(ctx, "alberta", 245, 87)
    else
      warp(ctx, "alberta", 243, 67)
    end
  end
end
