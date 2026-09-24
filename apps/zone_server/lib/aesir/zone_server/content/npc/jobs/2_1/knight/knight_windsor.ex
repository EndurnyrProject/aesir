defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Knight.KnightWindsor do
  @moduledoc """
  Sir Windsor's post inside the Knight combat test arena.

  ## Behavior

  - Tersely explains the three-stage combat test and how to join it through the
    waiting room.
  - Returns candidates who want to leave to the Prontera Chivalry.

  ## Credits

  - Original from rAthena, authors and Contributors
    - PGRO TEAM (Aegis)
    - kobra_k88
    - Lupus
    - Vicious
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Vali
    - Euphy
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_knt",
        x: 89,
        y: 106,
        dir: 4,
        sprite: 733,
        name: "Knight Windsor",
        scope: :shared,
        unique_name: "Knight Windsor#knt"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sir Windsor]")
      |> mes("...")
      |> next()
      |> mes("[Sir Windsor]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("[Sir Windsor]")
      |> mes("...Question?")
      |> next()
      |> select([
        "What kind of test is this?",
        "How do I take the test?",
        "I'd like to leave.",
        "No."
      ])

    ctx = ctx |> mes("[Sir Windsor]") |> mes("...")

    if choice == 4 do
      close(ctx)
    else
      ctx
      |> next()
      |> mes("[Sir Windsor]")
      |> mes("...")
      |> mes("......")
      |> answer(choice)
    end
  end

  defp answer(ctx, 1) do
    ctx
    |> next()
    |> mes("[Sir Windsor]")
    |> mes("...You fight monsters.")
    |> next()
    |> mes("[Sir Windsor]")
    |> mes("...Kill them all.")
    |> next()
    |> mes("[Sir Windsor]")
    |> mes("...")
    |> next()
    |> mes("[Sir Windsor]")
    |> mes("...Three stages.")
    |> mes("Beat them all.")
    |> next()
    |> mes("[Sir Windsor]")
    |> mes("......3 minutes")
    |> mes("for each stage.")
    |> next()
    |> mes("[Sir Windsor]")
    |> mes("..........")
    |> close()
  end

  defp answer(ctx, 2) do
    ctx
    |> next()
    |> mes("[Sir Windsor]")
    |> mes("...Go in the")
    |> mes("waiting room.")
    |> next()
    |> mes("[Sir Windsor]")
    |> mes("...Then it")
    |> mes("will begin.")
    |> next()
    |> mes("[Sir Windsor]")
    |> mes("...")
    |> next()
    |> mes("[Sir Windsor]")
    |> mes("...You have to wait")
    |> mes("if someone is testing.")
    |> next()
    |> mes("[Sir Windsor]")
    |> mes("...You can go in")
    |> mes("after that person.")
    |> next()
    |> mes("[Sir Windsor]")
    |> mes("...")
    |> close()
  end

  defp answer(ctx, 3), do: ctx |> close() |> warp("prt_in", 80, 100)
  defp answer(ctx, _choice), do: ctx
end
