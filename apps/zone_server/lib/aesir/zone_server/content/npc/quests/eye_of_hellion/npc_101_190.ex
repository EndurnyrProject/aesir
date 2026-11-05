defmodule Aesir.ZoneServer.Content.Npc.Quests.EyeOfHellion.Npc101190 do
  @moduledoc """
  The invisible ceiling inscription in Payon that carries the third Eye of Hellion clue.

  ## Behavior

  - On touch while `HELLIONQ` is 48, reveals the `This garment is one size fits
    all` clue and advances `HELLIONQ` to 49.
  - Does nothing at any other quest step.

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

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :HELLIONQ, 0) == 48 do
      read_inscription(ctx)
    else
      ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp read_inscription(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Well, this is where")
    |> mes("Grout'he told me to look.")
    |> mes("Ooh, there's something")
    |> mes("written on the ceiling. Um,")
    |> mes("let's see... ''This garment")
    |> mes("is one size fits all.''")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("That's it...?")
    |> mes("Hopefully this will")
    |> mes("make more sense once")
    |> mes("I find more clues. I hope.")
    |> set_char_var(:HELLIONQ, 49)
    |> close()
  end
end
