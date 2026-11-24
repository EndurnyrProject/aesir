defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Entrance do
  @moduledoc """
  Laura can be heard arguing inside the excavation headquarters.

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
        map: "hu_in01",
        x: 174,
        y: 90,
        dir: 0,
        sprite: 139,
        name: "Entrance",
        scope: :shared,
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: on_talk(ctx)

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :hg_odin, 0) in [22, 23] do
      ctx
      |> mes("[Laura]")
      |> mes("So it means that everyone fooled me!")
      |> next()
      |> mes("== Laura is violently wielding a thick file in the air. ==")
      |> close()
    else
      ctx
    end
  end
end
