defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.EmergencyExit do
  @moduledoc """
  Offers a way out of the dance examination room.

  ## Behavior

  - Transports the player to Comodo on request.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "cmd_in01",
        x: 16,
        y: 24,
        dir: 0,
        sprite: 111,
        name: "Emergency Exit",
        scope: :shared
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Exit]")
      |> mes("Would you like to go out?")
      |> next()
      |> select(["Yes.", "No."])

    case choice do
      1 -> ctx |> mes("[Exit]") |> mes("Farewell.") |> next() |> warp("comodo", 187, 163)
      2 -> ctx |> mes("[Exit]") |> mes("..........") |> close()
      _ -> ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
