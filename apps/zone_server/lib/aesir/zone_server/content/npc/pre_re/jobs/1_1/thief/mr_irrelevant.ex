defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Thief.MrIrrelevant do
  @moduledoc """
  Admits Thief applicants to the Mushroom Farm.

  ## Behavior

  - Sends registered applicants to a random farm entrance and records their first visit.
  - Greets Thieves and other visitors according to their job.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - Lupus
    - massdriller
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script pre-re/jobs/1-1/thief.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "moc_ruins",
        x: 141,
        y: 125,
        dir: 3,
        sprite: 83,
        name: "Mr. Irrelevant",
        scope: :pre_renewal
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:thief) ->
        ctx
        |> mes("[Mr. Irrelevant]")
        |> mes("Ah, I see that you are now a Thief. I always knew you'd join us.")
        |> next()
        |> mes("[Mr. Irrelevant]")
        |> mes(
          "Stealing from a Mushroom farm is too easy for you now. You should build up your skills and master our craft."
        )
        |> close()

      Rathena.job_id(base_job(ctx)) != Rathena.job_id(:novice) ->
        greet_visitor(ctx)

      get_char_var(ctx, :job_thief_q, 0) == 3 ->
        ctx
        |> mes("[Mr. Irrelevant]")
        |> mes("Hahahahaha~!")
        |> mes("You haven't")
        |> mes("passed the test yet?")
        |> mes("Alright, I'll let you in...")
        |> close()
        |> enter_farm()

      get_char_var(ctx, :job_thief_q, 0) == 2 ->
        ctx
        |> mes("[Mr. Irrelevant]")
        |> mes("Hmm...")
        |> mes(
          "You've come to take the test, right? I can see in your eyes that you know something."
        )
        |> next()
        |> mes("[Mr. Irrelevant]")
        |> mes(
          "Your name is #{char_name(ctx, 0)}? Ah, it's on the list. Alright, I'll let you into the Mushroom Farm , but I can't guarantee your safety..."
        )
        |> close()
        |> set_char_var(:job_thief_q, 3)
        |> enter_farm()

      get_char_var(ctx, :job_thief_q, 0) == 1 ->
        ctx
        |> mes("[Mr. Irrelevant]")
        |> mes("There is this strange smell coming from... You. Now why would that be?")
        |> close()

      true ->
        ctx
        |> mes("[Mr. Irrelevant]")
        |> mes(
          "Hey Novice! Why don't you join the ranks of the Thief Guild? You newbies are always welcome to join us and our selfish cause."
        )
        |> next()
        |> mes("[Mr. Irrelevant]")
        |> mes("You can get more information in the Underground Room in the Pyramid 1 BF.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp greet_visitor(ctx) do
    ctx = mes(ctx, "[Mr. Irrelevant]")

    case :rand.uniform(4) - 1 do
      1 ->
        ctx |> mes("I could use a good, hard drink.") |> close()

      2 ->
        ctx
        |> mes("Gimme your money.")
        |> next()
        |> mes("[Mr. Irrelevant]")
        |> mes("Kidding, I'm off the clock.")
        |> close()

      3 ->
        ctx |> mes("WHO YOU CALLING A PSYCHO?!?!") |> close()

      4 ->
        ctx
        |> mes("I've got nothing to say to you. Would you mind leaving me alone?")
        |> close()

      _ ->
        ctx
        |> mes(
          "Today looks like a good day to go to the pyramids and hunt with some of my friends."
        )
        |> close()
    end
  end

  defp enter_farm(ctx) do
    case :rand.uniform(5) - 1 do
      1 -> warp(ctx, "job_thief1", 228, 106)
      2 -> warp(ctx, "job_thief1", 38, 50)
      3 -> warp(ctx, "job_thief1", 66, 331)
      4 -> warp(ctx, "job_thief1", 196, 331)
      _ -> warp(ctx, "job_thief1", 309, 234)
    end
  end
end
