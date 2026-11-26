defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.GodWeaponCreation.GodWepWarpmaster do
  @moduledoc """
  Hidden controller that opens and closes the god item laboratory's exit warps.

  ## Behavior

  - `OnEnable` enables the six exit warps and `OnDisable` disables them; clicking it runs the
    enable.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_god01",
        x: 169,
        y: 82,
        dir: 0,
        sprite: -1,
        name: "god_wep_warpmaster",
        scope: :shared
      }
    ]

  @warps 1..6

  @impl true
  def on_event("OnEnable", ctx), do: enable_warps(ctx)
  def on_event("OnDisable", ctx), do: Enum.reduce(@warps, ctx, &disablenpc(&2, warp_name(&1)))

  @impl true
  def on_talk(ctx), do: enable_warps(ctx)

  defp enable_warps(ctx), do: Enum.reduce(@warps, ctx, &enablenpc(&2, warp_name(&1)))

  defp warp_name(index), do: "god_failwarp##{index}"
end
