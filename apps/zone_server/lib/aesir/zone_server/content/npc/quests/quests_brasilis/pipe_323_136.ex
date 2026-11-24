defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Pipe323136 do
  @moduledoc """
  The jungle pipe provides access to the museum sewer.

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
        map: "bra_fild01",
        x: 323,
        y: 136,
        dir: 1,
        sprite: 844,
        name: "Pipe",
        scope: :shared,
        unique_name: "Pipe#brafild"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :brazil_ghost, 0) > 6 do
      {ctx, choice} =
        ctx
        |> mes("You see a rusty pipe. It seems to be linked to somewhere beneath the jungle.")
        |> next()
        |> select(["Examine it", "Ignore."])

      case choice do
        1 ->
          ctx
          |> mes("You swim through a gap in the pipe and are swept by a sudden rush of water.")
          |> close()
          |> warp("bra_in01", 206, 182)

        2 ->
          ctx |> mes("It might be dangerous, I better not act rashly.") |> close()

        _ ->
          ctx
      end
    else
      ctx
      |> mes("You see a rusty pipe. It seems to be linked to somewhere beneath the jungle.")
      |> close()
    end
  end
end
