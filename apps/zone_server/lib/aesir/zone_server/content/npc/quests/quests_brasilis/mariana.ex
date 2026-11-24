defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Mariana do
  @moduledoc """
  Mariana discusses ghost stories and her friends.

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
        x: 187,
        y: 244,
        dir: 1,
        sprite: 72,
        name: "Mariana",
        scope: :shared,
        unique_name: "Mariana#bra"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :brazil_ghost, 0) do
      0 ->
        doevent(ctx, "Pedro#bra::OnTalk")

      1 ->
        ctx
        |> mes("[Mariana]")
        |> mes("Can you guys stop talking about the ghosts?")
        |> mes("I've already got goosebumps all over.")
        |> close()

      _ ->
        ctx
        |> mes("[Mariana]")
        |> mes("Why do Fabio and Daniel always bother us?")
        |> close()
    end
  end
end
