defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.RiftGuard37196 do
  @moduledoc """
  A rift guard on the far side of the dimensional rift, who offers to lead the player
  back out.

  ## Behavior

  - Points a new adventurer at the head of the alliance in the Gorge and offers to lead them
    out of the rift.
  - Escaping closes the dialog and warps to `moc_fild20` 342,179; refusing leaves the player
    to go on alone.

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
        map: "moc_fild22b",
        x: 37,
        y: 196,
        dir: 5,
        sprite: 707,
        name: "Rift Guard",
        scope: :shared,
        unique_name: "Rift Guard#2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Guard]")
      |> mes("Are you the new adventurer?")
      |> mes(
        "If you're going to the other side of the rift, the head of the alliance will guide you there."
      )
      |> next()
      |> mes("[Guard]")
      |> mes(
        "He should be near the center of the Gorge. He is stronger than the former one, so be careful with your words."
      )
      |> next()
      |> mes("[Guard]")
      |> mes("If you want to run away from here, just let me know, I will guide you.")
      |> next()
      |> select(["Escape.", "Nah."])

    case choice do
      1 -> escape(ctx)
      2 -> go_ahead(ctx)
      _ -> ctx
    end
  end

  defp escape(ctx) do
    ctx
    |> mes("[Guard]")
    |> mes("Ok.")
    |> mes("Follow me, I will let you out of here.")
    |> close()
    |> warp("moc_fild20", 342, 179)
  end

  defp go_ahead(ctx) do
    ctx
    |> mes("[Guard]")
    |> mes("Ok, just go ahead for yourself.")
    |> close()
  end
end
