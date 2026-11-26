defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.GodWeaponCreation.GodFailwarp do
  @moduledoc """
  Exit warps of the god item laboratory that send a failed player back to Prontera.

  ## Behavior

  - Each warp starts disabled and is enabled for the duration of a laboratory attempt.
  - Stepping into an enabled warp sends the player to Prontera.

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
        x: 154,
        y: 67,
        dir: 0,
        sprite: -1,
        name: "god_failwarp",
        scope: :shared,
        unique_name: "god_failwarp#1",
        trigger: {4, 7}
      },
      %{
        map: "que_god01",
        x: 154,
        y: 82,
        dir: 0,
        sprite: -1,
        name: "god_failwarp",
        scope: :shared,
        unique_name: "god_failwarp#2",
        trigger: {4, 7}
      },
      %{
        map: "que_god01",
        x: 145,
        y: 99,
        dir: 0,
        sprite: -1,
        name: "god_failwarp",
        scope: :shared,
        unique_name: "god_failwarp#3",
        trigger: {9, 9}
      },
      %{
        map: "que_god01",
        x: 164,
        y: 99,
        dir: 0,
        sprite: -1,
        name: "god_failwarp",
        scope: :shared,
        unique_name: "god_failwarp#4",
        trigger: {9, 9}
      },
      %{
        map: "que_god01",
        x: 145,
        y: 118,
        dir: 0,
        sprite: -1,
        name: "god_failwarp",
        scope: :shared,
        unique_name: "god_failwarp#5",
        trigger: {9, 9}
      },
      %{
        map: "que_god01",
        x: 164,
        y: 118,
        dir: 0,
        sprite: -1,
        name: "god_failwarp",
        scope: :shared,
        unique_name: "god_failwarp#6",
        trigger: {9, 9}
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx)
  def on_event("OnTouch_", ctx), do: warp(ctx, "prontera", 156, 324)

  @impl true
  def on_talk(ctx), do: disablenpc(ctx)
end
