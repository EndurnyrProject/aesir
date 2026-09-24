defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Rogue.AntonioJunior do
  @moduledoc """
  Sends Rogue candidates assigned to Antonio Jr. into the underground tunnel test.

  ## Behavior

  - Explains the tunnel test to candidates at the Antonio step, then sends them into the tunnel
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
        x: 177,
        y: 109,
        dir: 1,
        sprite: 88,
        name: "Antonio junior",
        scope: :shared,
        unique_name: "Antonio junior#rg"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ROGUE_Q, 0) do
      10 -> offer_test(ctx)
      14 -> offer_retest(ctx)
      _ -> greet_visitor(ctx)
    end
  end

  defp offer_test(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Antonio Jr.]")
      |> mes("You're from")
      |> mes("the Rogue guild?")
      |> mes("If you wanna learn")
      |> mes("about becoming a Rogue,")
      |> mes("then shut up and stay put.")
      |> next()
      |> mes("[Antonio Jr.]")
      |> mes(
        "^0000FFAvoid the strong! Be malicious to the weak!^000000 That's our motto for battling monsters."
      )
      |> next()
      |> mes("[Antonio Jr.]")
      |> mes(
        "Show no mercy when you fight weaker monsters, and try to keep away from stronger monsters."
      )
      |> next()
      |> mes("[Antonio Jr.]")
      |> mes(
        "Now, I want you to walk all the way to the Rogue Guild through this ^0000FFUnderground Tunnel^000000."
      )
      |> next()
      |> mes("[Antonio Jr.]")
      |> mes(
        "There are monsters there, but if you avoid the strong and be malicious to the weak, you'll be fine."
      )
      |> next()
      |> select(["Let's go!", "W-wait~"])

    if choice == 1 do
      ctx
      |> mes("[Antonio Jr.]")
      |> mes("I hope you do")
      |> mes("not fail this test")
      |> mes("You can only become")
      |> mes("a Rogue if you pass...")
      |> close()
      |> warp("in_rogue", 15, 105)
      |> set_char_var(:ROGUE_Q, 14)
      |> changequest(2023, 2026)
    else
      not_ready(ctx)
    end
  end

  defp offer_retest(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Antonio Jr.]")
      |> mes("You failed...?")
      |> mes("I guess that's life.")
      |> mes("Are you gonna try")
      |> mes("again or what?")
      |> next()
      |> select(["Re-test", "Cancel"])

    if choice == 1 do
      ctx
      |> mes("[Antonio Jr.]")
      |> mes("Remember, I'm doing")
      |> mes("you a favor here...")
      |> mes("Now, don't come back")
      |> mes("until you're a Rogue.")
      |> close()
      |> warp("in_rogue", 15, 105)
    else
      not_ready(ctx)
    end
  end

  defp not_ready(ctx) do
    ctx
    |> mes("[Antonio Jr.]")
    |> mes("I don't have time")
    |> mes("to fool around with")
    |> mes("you. Hurry up, get")
    |> mes("ready, then take")
    |> mes("the test.")
    |> close()
  end

  defp greet_visitor(ctx) do
    if Rathena.job_id(base_job(ctx)) != Rathena.job_id(:rogue) do
      ctx
      |> mes("Huh...?")
      |> mes("Who are you?!")
      |> mes("You're not from")
      |> mes("the Rogue Guild!!")
      |> next()
      |> mes("[Antonio Jr.]")
      |> mes(
        "You've come here to kill me?! I won't let you!! Come on, give me your best shot! You can't fight if I rip out your eyes!"
      )
      |> close()
    else
      ctx
      |> mes("[Antonio Jr.]")
      |> mes("Hey, how's it goin'?")
      |> mes("Take it easy, and just")
      |> mes("relax before you leave.")
      |> close()
    end
  end
end
