defmodule Aesir.ZoneServer.Content.Npc.Jobs.M11e.Ninja.Akagi do
  @moduledoc """
  Offers Job Level 10 Novices passage to Amatsu to begin the Ninja job quest.

  ## Behavior

  - Sends willing Job Level 10 Novices to one of three random spots in Amatsu.
  - Turns away weaker Novices and offers other classes a friendly spar.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Legionaire
    - Kisuka
    - Lupus
    - Playtester
    - SinSloth
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "alberta", x: 30, y: 65, dir: 3, sprite: 730, name: "Akagi", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      Rathena.job_id(class(ctx)) != Rathena.job_id(:novice) ->
        ctx
        |> mes("[Akagi]")
        |> mes("Hmm...")
        |> mes("You and I...")
        |> mes("We are fairly equal in")
        |> mes("terms of combat ability.")
        |> mes("Perhaps we can spar")
        |> mes("together sometime.")
        |> close()

      job_level(ctx) == 10 ->
        offer_passage(ctx)

      true ->
        ctx
        |> mes("[Akagi]")
        |> mes("Hm? I cannot be")
        |> mes("of any service to")
        |> mes("you until you grow")
        |> mes("a little stronger...")
        |> close()
    end
  end

  defp offer_passage(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Akagi]")
      |> mes("Hmmm...")
      |> mes("You must have come,")
      |> mes("sensing that someone")
      |> mes("is waiting for you here.")
      |> mes("Tell me, do you seek")
      |> mes("the path of patience?")
      |> next()
      |> select(["No", "Yes"])

    if choice == 1 do
      ctx
      |> mes("[Akagi]")
      |> mes("I see.")
      |> mes("To each his own,")
      |> mes("I suppose. Take")
      |> mes("care of yourself.")
      |> close()
    else
      ctx =
        ctx
        |> mes("[Akagi]")
        |> mes("Very well.")
        |> mes("Then, let me")
        |> mes("set you on that")
        |> mes("path right away...")
        |> close()

      case :rand.uniform(3) - 1 do
        1 -> warp(ctx, "amatsu", 170, 229)
        2 -> warp(ctx, "amatsu", 216, 188)
        _ -> warp(ctx, "amatsu", 178, 176)
      end
    end
  end
end
