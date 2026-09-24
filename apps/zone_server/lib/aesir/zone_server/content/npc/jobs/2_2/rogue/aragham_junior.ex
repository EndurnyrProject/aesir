defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Rogue.AraghamJunior do
  @moduledoc """
  Sends Rogue candidates assigned to Aragham Jr. into the underground tunnel test.

  ## Behavior

  - Explains the tunnel test to candidates at the Aragham step, then sends them into the tunnel
    and advances their quest.
  - Lets candidates who failed the tunnel retry it.
  - Threatens non-Rogues and greets Rogues otherwise.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_rogue",
        x: 244,
        y: 39,
        dir: 1,
        sprite: 99,
        name: "Aragham Junior",
        scope: :shared,
        unique_name: "Aragham Junior#rg"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ROGUE_Q, 0) do
      9 -> offer_test(ctx)
      13 -> offer_retest(ctx)
      _ -> greet_visitor(ctx)
    end
  end

  defp offer_test(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Aragham Jr.]")
      |> mes("Oh, you must be")
      |> mes("from the Rogue Guild...")
      |> next()
      |> mes("[Aragham Jr.]")
      |> mes("My name is")
      |> mes("Aragham Junior,")
      |> mes("Rogue of the Desert.")
      |> mes("Are you ready to learn")
      |> mes("how to be a Rogue?")
      |> next()
      |> mes("[Aragham Jr.]")
      |> mes(
        "See, as a Rogue, our motto is, '^0000FFAvoid the strong! Be malicious to the weak!^000000' That rule especially goes true for monsters."
      )
      |> next()
      |> mes("[Aragham Jr.]")
      |> mes("Avoid the strong!")
      |> mes("Be malicious to the weak!")
      |> mes("It's a simple rule...")
      |> next()
      |> mes("[Aragham Jr.]")
      |> mes(
        "Now, remember it as you go through ^0000FFthe Underground Tunnel^000000. Try to walk all the way to the Rogue Guild."
      )
      |> next()
      |> mes("[Aragham Jr.]")
      |> mes(
        "There will be a few monsters, but don't worry. I know you're strong. Alright, are you ready to go or what?"
      )
      |> next()
      |> select(["Yes, let's go.", "Nah~"])

    if choice == 1 do
      ctx
      |> mes("[Aragham Jr.]")
      |> mes("Alright...")
      |> mes("Good luck, then.")
      |> close()
      |> warp("in_rogue", 15, 105)
      |> set_char_var(:ROGUE_Q, 13)
      |> changequest(2022, 2026)
    else
      not_ready(ctx)
    end
  end

  defp offer_retest(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Aragham Jr.]")
      |> mes("Oh, you're back.")
      |> mes(
        "I think you'll do well this time. Another motto Rogues have is '^0000FFFailure teaches success^000000.' Well, then again..."
      )
      |> next()
      |> select(["Re-Test", "Cancel"])

    if choice == 1 do
      ctx
      |> mes("[Aragham Jr.]")
      |> mes("Good luck.")
      |> close()
      |> warp("in_rogue", 15, 105)
    else
      not_ready(ctx)
    end
  end

  defp not_ready(ctx) do
    ctx
    |> mes("[Aragham Jr.]")
    |> mes("Fine, fine.")
    |> mes("Take your time")
    |> mes("and come back")
    |> mes("when you're ready.")
    |> close()
  end

  defp greet_visitor(ctx) do
    if Rathena.job_id(base_job(ctx)) != Rathena.job_id(:rogue) do
      ctx
      |> mes("[Aragham Jr.]")
      |> mes("Huh...?")
      |> mes("Who are you?!")
      |> mes("You're not from")
      |> mes("the Rogue Guild!!")
      |> next()
      |> mes("[Aragham Jr.]")
      |> mes(
        "You've come here to kill me, haven't you? N-no! I'm can't die yet! Get lost! Otherwise, I'll kill you first!"
      )
      |> close()
    else
      ctx
      |> mes("[Aragham Jr.]")
      |> mes("Hey...")
      |> mes("what brings")
      |> mes("you back here?")
      |> mes("Why don't you")
      |> mes("take a rest")
      |> mes("before you leave?")
      |> close()
    end
  end
end
