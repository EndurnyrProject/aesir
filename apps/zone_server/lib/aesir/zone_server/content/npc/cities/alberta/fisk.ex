defmodule Aesir.ZoneServer.Content.Npc.Cities.Alberta.Fisk do
  @moduledoc """
  Ferries travelers from Alberta to the Sunken Ship or Izlude Marina.

  ## Behavior

  - Charges 250 zeny for passage to the Sunken Ship.
  - Charges 500 zeny for passage to the mode-appropriate Izlude Marina coordinates.

  ## Credits

  - Original from rAthena, authors and Contributors
    - DZeroX

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "alberta", x: 189, y: 151, dir: 5, sprite: 100, name: "Fisk", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Fisk]")
      |> mes("Ahoy mate,")
      |> mes("where'd ya")
      |> mes("wanna go?")
      |> next()
      |> select(["Sunken Ship -> 250 zeny.", "Izlude Marina -> 500 zeny.", "Never mind."])

    case choice do
      1 -> sail_to_sunken_ship(ctx)
      2 -> sail_to_izlude(ctx)
      3 -> decline_passage(ctx)
      _ -> ctx
    end
  end

  defp sail_to_sunken_ship(ctx) do
    if zeny(ctx) < 250 do
      ctx
      |> mes("[Fisk]")
      |> mes("Hey now, don't try to cheat me! I said 250 zeny!")
      |> close()
    else
      ctx
      |> pay_zeny(250)
      |> warp("alb2trea", 43, 53)
    end
  end

  defp sail_to_izlude(ctx) do
    if zeny(ctx) < 500 do
      ctx
      |> mes("[Fisk]")
      |> mes("Ain't no way yer getting there without the 500 zeny first!")
      |> close()
    else
      ctx
      |> pay_zeny(500)
      |> warp_to_izlude()
    end
  end

  defp warp_to_izlude(ctx) do
    if Rathena.truthy?(checkre(ctx, 0)) do
      warp(ctx, "izlude", 195, 212)
    else
      warp(ctx, "izlude", 176, 182)
    end
  end

  defp decline_passage(ctx) do
    ctx
    |> mes("[Fisk]")
    |> mes("Alright...")
    |> mes("Landlubber.")
    |> close()
  end
end
