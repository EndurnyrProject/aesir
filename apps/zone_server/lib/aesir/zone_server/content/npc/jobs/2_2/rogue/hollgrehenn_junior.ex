defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Rogue.HollgrehennJunior do
  @moduledoc """
  Sends Rogue candidates assigned to Hollgrehenn Jr. into the underground tunnel test.

  ## Behavior

  - Explains the tunnel test to candidates at the Hollgrehenn step, then sends them into the
    tunnel and advances their quest.
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
        x: 160,
        y: 34,
        dir: 1,
        sprite: 85,
        name: "Hollgrehenn junior",
        scope: :shared,
        unique_name: "Hollgrehenn junior#rg"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ROGUE_Q, 0) do
      11 -> offer_test(ctx)
      15 -> offer_retest(ctx)
      _ -> greet_visitor(ctx)
    end
  end

  defp offer_test(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hollgrehenn Jr.]")
      |> mes("Huh...")
      |> mes("From the")
      |> mes("Rogue guild, huh?")
      |> next()
      |> mes("[Hollgrehenn Jr.]")
      |> mes(
        "I'm Hollgrehenn Junior. I tend to a lot of our underground business. So are you ready to take on my test?"
      )
      |> next()
      |> mes("[Hollgrehenn Jr.]")
      |> mes(
        "We Rogues share this motto: ^0000FFAvoid the strong! Be malicious to the weak!^000000 This rule applies to any threat, especially monsters."
      )
      |> next()
      |> mes("[Hollgrehenn Jr.]")
      |> mes("It's easy to remember.")
      |> mes("Just don't forget to put it into practice. You got it?")
      |> next()
      |> mes("[Hollgrehenn Jr.]")
      |> mes(
        "For my test, you'll go through the ^0000FFUnderground Tunnel^000000. Follow it all the way back to the Rogue Guild."
      )
      |> next()
      |> mes("[Hollgrehenn Jr.]")
      |> mes(
        "There are some monsters there, but that'll be part of your training. Now, are you ready to go or not?"
      )
      |> next()
      |> select(["Yes, I am.", "Nah~"])

    if choice == 1 do
      ctx
      |> mes("[Hollgrehenn Jr.]")
      |> mes("Good luck.")
      |> close()
      |> warp("in_rogue", 15, 105)
      |> set_char_var(:ROGUE_Q, 15)
      |> changequest(2024, 2026)
    else
      not_ready(ctx)
    end
  end

  defp offer_retest(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hollgrehenn Jr.]")
      |> mes("Huh.")
      |> mes("You failed.")
      |> mes("Gonna try again?")
      |> next()
      |> select(["Re-Test", "Cancel."])

    if choice == 1 do
      ctx
      |> mes("[Hollgrehenn Jr.]")
      |> mes("Good luck.")
      |> close()
      |> warp("in_rogue", 15, 105)
    else
      not_ready(ctx)
    end
  end

  defp not_ready(ctx) do
    ctx
    |> mes("[Hollgrehenn Jr.]")
    |> mes("Take your time.")
    |> mes("Come back here")
    |> mes("when you're ready.")
    |> close()
  end

  defp greet_visitor(ctx) do
    if Rathena.job_id(base_job(ctx)) != Rathena.job_id(:rogue) do
      ctx
      |> mes("[Hollgrehenn Jr.]")
      |> mes("Huh...?")
      |> mes("You're not from")
      |> mes("the Rogue Guild...")
      |> next()
      |> mes("[Hollgrehenn Jr.]")
      |> mes("You better get out")
      |> mes("of here right now")
      |> mes("if you know what's")
      |> mes("good for you...")
      |> next()
      |> mes("[Hollgrehenn Jr.]")
      |> mes("Now...")
      |> mes("Beat it before")
      |> mes("I change my mind")
      |> mes("about killing you.")
      |> close()
    else
      ctx
      |> mes("[Hollgrehenn Jr.]")
      |> mes("Hey...")
      |> mes("Come to visit?")
      |> mes("We Rogues gotta")
      |> mes("stick together, huh?")
      |> close()
    end
  end
end
