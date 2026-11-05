defmodule Aesir.ZoneServer.Content.Npc.Quests.EyeOfHellion.Vat do
  @moduledoc """
  The Payon wine vat that closes the Eye of Hellion clue chain.

  ## Behavior

  - While `HELLIONQ` is 51, quotes the `What will it be? Wine or Grape Juice?`
    message and advances `HELLIONQ` to 52.
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
        x: 240,
        y: 160,
        dir: 3,
        sprite: 111,
        name: "Vat",
        scope: :shared,
        unique_name: "Vat#paypuzz4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :HELLIONQ, 0) == 51 do
      read_message(ctx)
    else
      ctx
    end
  end

  defp read_message(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Alright, the last")
    |> mes("place I have to check.")
    |> mes("It's a big old vat with a")
    |> mes("message here too. Now")
    |> mes("let me see, there should")
    |> mes("be a message here too. Ah--!")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("This says, ''What will it be?")
    |> mes("Wine or Grape Juice? Oh,")
    |> mes("but I much prefer wine.'' Okay,")
    |> mes("what does this have to do with")
    |> mes("that Hellion's gem? Weird...")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Am I missing something?")
    |> mes("I think I really need help in")
    |> mes("figuring this out. Hmm...")
    |> set_char_var(:HELLIONQ, 52)
    |> close()
  end
end
