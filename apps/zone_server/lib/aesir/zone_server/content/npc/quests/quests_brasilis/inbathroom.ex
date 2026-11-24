defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Inbathroom do
  @moduledoc """
  The bathroom entrance admits adventurers who have progressed through the ghost quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "bra_in01",
        x: 12,
        y: 185,
        dir: 0,
        sprite: 45,
        name: "inbathroom",
        scope: :shared,
        unique_name: "inbathroom#bra",
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: enter(ctx)

  @impl true
  def on_talk(ctx), do: enter(ctx)

  defp enter(ctx) do
    if get_char_var(ctx, :brazil_ghost, 0) > 6 do
      warp(ctx, "bra_in01", 138, 176)
    else
      ctx |> mes("The entrance has been blocked.") |> close()
    end
  end
end
