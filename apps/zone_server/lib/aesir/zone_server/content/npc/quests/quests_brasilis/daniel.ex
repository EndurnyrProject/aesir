defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Daniel do
  @moduledoc """
  Daniel joins Pedro and Fabio in teasing their friends.

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
        map: "brasilis",
        x: 180,
        y: 249,
        dir: 5,
        sprite: 706,
        name: "Daniel",
        scope: :shared,
        unique_name: "Daniel#bra"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :brazil_ghost, 0) do
      0 -> doevent(ctx, "Pedro#bra::OnTalk")
      1 -> ctx |> mes("[Daniel]") |> mes("Nyah nyah nyah~") |> close()
      _ -> ctx |> mes("[Daniel]") |> mes("Keke Here~ I found more bugs~") |> close()
    end
  end
end
