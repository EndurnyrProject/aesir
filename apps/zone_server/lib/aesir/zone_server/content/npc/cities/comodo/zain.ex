defmodule Aesir.ZoneServer.Content.Npc.Cities.Comodo.Zain do
  @moduledoc """
  Operates Reudelus ship service from two Paros Lighthouse docks.

  ## Behavior

  - Charges 600 zeny to travel to Alberta.
  - Charges 800 zeny to travel to the mode-appropriate Izlude arrival point.
  - Explains the fare shortage or promotes future travel when the passenger cancels.

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
        x: 299,
        y: 83,
        dir: 4,
        sprite: 100,
        name: "Zain",
        scope: :shared,
        unique_name: "Zain#cmd"
      },
      %{
        map: "cmd_fild07",
        x: 94,
        y: 134,
        dir: 4,
        sprite: 100,
        name: "Sarumane",
        scope: :shared,
        unique_name: "Sarumane#cmd"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    speaker = "[#{strnpcinfo(ctx, 1)}]"

    {ctx, choice} =
      ctx
      |> mes(speaker)
      |> mes("Would you like to")
      |> mes("board a ship on the")
      |> mes("Reudelus route? You")
      |> mes("can travel on Reudelus")
      |> mes("to Alberta or Izlude.")
      |> next()
      |> select(["Alberta - 600 Zeny", "Izlude - 800 Zeny", "Cancel"])

    case choice do
      1 -> travel_to_alberta(ctx, speaker)
      2 -> travel_to_izlude(ctx, speaker)
      3 -> decline_travel(ctx, speaker)
      _ -> insufficient_fare(ctx, speaker)
    end
  end

  defp travel_to_alberta(ctx, speaker) do
    if zeny(ctx) < 600 do
      insufficient_fare(ctx, speaker)
    else
      ctx
      |> pay_zeny(600)
      |> warp("alberta", 192, 169)
    end
  end

  defp travel_to_izlude(ctx, speaker) do
    if zeny(ctx) < 800 do
      insufficient_fare(ctx, speaker)
    else
      ctx = pay_zeny(ctx, 800)

      if Rathena.truthy?(checkre(ctx, 0)) do
        warp(ctx, "izlude", 195, 212)
      else
        warp(ctx, "izlude", 176, 182)
      end
    end
  end

  defp decline_travel(ctx, speaker) do
    ctx
    |> mes(speaker)
    |> mes("Travel by ship is")
    |> mes("still one of the safest and")
    |> mes("dependable methods of")
    |> mes("transportation. I invite you")
    |> mes("to try Reudelus travel soon~")
    |> close()
  end

  defp insufficient_fare(ctx, speaker) do
    ctx
    |> mes(speaker)
    |> mes("I'm sorry, but you")
    |> mes("don't have enough")
    |> mes("zeny for the boarding fare.")
    |> close()
  end
end
