defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Alex5290 do
  @moduledoc """
  A doorway leads to a room according to the excavation quest stage.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
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
        map: "hugel",
        x: 52,
        y: 90,
        dir: 0,
        sprite: 45,
        name: "alex",
        scope: :shared,
        unique_name: "alex#warp2",
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: on_talk(ctx)

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :hg_odin, 0)

    cond do
      stage > 59 -> warp(ctx, "hu_in01", 102, 90)
      stage > 21 and stage < 60 -> warp(ctx, "hu_in01", 173, 90)
      true -> warp(ctx, "hu_in01", 33, 90)
    end
  end
end
