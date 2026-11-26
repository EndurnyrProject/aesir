defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.Gototomb do
  @moduledoc """
  A church entrance sends eligible adventurers to the tomb.

  ## Behavior

  - Warps players during the relevant stages of the curse investigation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Evera
    - Samuray22
    - SinSloth
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_church",
        x: 177,
        y: 113,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#gototomb"
      }
    ]

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :prt_curse, 0)

    if stage in 18..22 or stage in 32..34 or stage in [41, 42, 44, 51, 52] do
      warp(ctx, "prt_church", 21, 91)
    else
      ctx
    end
  end
end
