defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Room22Warp do
  @moduledoc """
  Security-magic gate of Master Zone Area 2-2 of the Morocc job quest, hidden until the
  area timer enables it and warping anyone who steps in back to the zone entrance.

  ## Behavior

  - Starts hidden on boot and hides itself again whenever the area timer disables it.
  - Reveals itself when the area timer enables it.
  - Warps anyone who steps into its trigger rect back out to the zone entrance.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_job01",
        x: 144,
        y: 51,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#room2_2_warp",
        trigger: {15, 15}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @npc "#room2_2_warp"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: hide(ctx)

  # The reference's `OnInit` label is empty, so booting falls through into `OnDisable`.
  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: hide(ctx)
  def on_event("OnDisable", ctx), do: hide(ctx)
  def on_event("OnEnable", ctx), do: enablenpc(ctx, @npc)
  def on_event("OnTouch_", ctx), do: warp(ctx, "que_job01", 52, 50)

  defp hide(ctx), do: disablenpc(ctx, @npc)
end
