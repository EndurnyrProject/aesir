defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.JupeGoto2f do
  @moduledoc """
  Transfers visitors to a random first-floor location.

  ## Behavior

  - Warps visitors to one of four destinations.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - L0ne_W0lf
    - Zephyrus
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "juperos_02",
        x: 33,
        y: 59,
        dir: 0,
        sprite: 45,
        name: "jupe_goto2F",
        scope: :shared,
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: warp_to_first_floor(ctx)

  @impl true
  def on_talk(ctx), do: warp_to_first_floor(ctx)

  defp warp_to_first_floor(ctx) do
    case Enum.random(1..4) do
      1 -> warp(ctx, "juperos_01", 120, 72)
      2 -> warp(ctx, "juperos_01", 120, 112)
      3 -> warp(ctx, "juperos_01", 79, 112)
      4 -> warp(ctx, "juperos_01", 79, 72)
      _ -> ctx
    end
  end
end
