defmodule Aesir.ZoneServer.Content.Npc.Quests.EyeOfHellion.PileOfStone do
  @moduledoc """
  The Payon pile of stone that carries the fourth Eye of Hellion clue.

  ## Behavior

  - While `HELLIONQ` is 49, reads out the `I used to pray for peaceful days
    here` engraving and advances `HELLIONQ` to 50.
  - Says nothing at any other quest step.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon",
        x: 82,
        y: 109,
        dir: 3,
        sprite: 111,
        name: "Pile of Stone",
        scope: :shared,
        unique_name: "Pile of Stone#paypuzz2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :HELLIONQ, 0) == 49 do
      read_engraving(ctx)
    else
      ctx
    end
  end

  defp read_engraving(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Well, this is the place")
    |> mes("that Grout'he told me about.")
    |> mes("Let's see, there's an engraving")
    |> mes("here that says, ''I used to pray for peaceful days here.'' Okay.")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Man...")
    |> mes("This better not be")
    |> mes("one of those puzzles")
    |> mes("that looks easy once")
    |> mes("I get the answer. Well,")
    |> mes("if I ever get it, that is.")
    |> set_char_var(:HELLIONQ, 50)
    |> close()
  end
end
