defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.RiftGuard do
  @moduledoc """
  The first rift guard at the dimensional rift entrance, who lets a proven alliance member
  pass through.

  ## Behavior

  - Past step 19 welcomes the alliance member and, on confirmation, closes the dialog and
    warps to `moc_fild22b` 38,195.
  - Below that step refuses entry and points at the guard behind him.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_fild20",
        x: 349,
        y: 179,
        dir: 3,
        sprite: 707,
        name: "Rift Guard",
        scope: :shared,
        unique_name: "Rift Guard#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :ep13_ryu, 0) > 19 do
      offer_passage(ctx)
    else
      refused(ctx)
    end
  end

  defp offer_passage(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Guard]")
      |> mes(
        "Ah, you are a member of the alliance that discovered the dimensional rift? Welcome. Everything is prepared. Just enter and find the camp when you pass through the rift."
      )
      |> next()
      |> mes("[Guard]")
      |> mes("The new head of the alliance, Munkenro, will direct all of us.")
      |> next()
      |> mes("[Guard]")
      |> mes("Then you will pass.")
      |> mes("Are you ready?")
      |> next()
      |> select(["Yes, sure.", "Please wait."])

    case choice do
      1 -> pass(ctx)
      2 -> not_ready(ctx)
      _ -> ctx
    end
  end

  defp pass(ctx) do
    ctx
    |> mes("[Guard]")
    |> mes("Good luck.")
    |> close()
    |> warp("moc_fild22b", 38, 195)
  end

  defp not_ready(ctx) do
    ctx
    |> mes("[Guard]")
    |> mes("Just tell me once you are ready. I will let you pass right away.")
    |> close()
  end

  defp refused(ctx) do
    ctx
    |> mes("[Guard]")
    |> mes("You're not allowed to enter here.")
    |> mes("If you have any business, just ask the guard behind me, or just leave.")
    |> close()
  end
end
