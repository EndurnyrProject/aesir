defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Guard130232 do
  @moduledoc """
  The Lighthalzen gate guard posted at the registration hall, who both sends a finished
  player to the dimensional rift and lets a registered one inside.

  ## Behavior

  - Past step 19 refuses the player, then offers to warp them straight to the dimensional
    rift: accepting closes the dialog and warps to `moc_fild20` 342,179, and declining points
    the way.
  - Past step 8 lets a player registering with the three kingdoms inside.
  - Refuses everyone else.

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
        map: "lhz_in01",
        x: 130,
        y: 232,
        dir: 5,
        sprite: 899,
        name: "Guard",
        scope: :shared,
        unique_name: "Guard#ep13_1-9"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ep13_ryu, 0) do
      step when step > 19 -> offer_transport(ctx)
      step when step > 8 -> admit(ctx)
      _step -> refuse(ctx)
    end
  end

  defp offer_transport(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Guard]")
      |> mes("You're not allowed to enter.")
      |> mes("All of you are instructed to go to the Time-Gap of Dimension on Rune-Midgarts!")
      |> next()
      |> mes("[Guard]")
      |> mes("Just go there.")
      |> mes("This is a restricted area.")
      |> next()
      |> mes("[Guard]")
      |> mes("Will you go to the dimensional rift right now?")
      |> next()
      |> mes("[Guard]")
      |> mes("If you want,")
      |> mes("I can send you to the Time-Gap of Dimension.")
      |> next()
      |> select(["Send me there.", "I will go there myself."])

    case choice do
      1 -> rift_transport(ctx)
      2 -> own_way(ctx)
      _ -> ctx
    end
  end

  defp rift_transport(ctx) do
    ctx
    |> mes("[Guard]")
    |> mes(
      "Ok, I will send you to the dimensional rift. Once you get there, just find the head of the alliance."
    )
    |> close()
    |> warp("moc_fild20", 342, 179)
  end

  defp own_way(ctx) do
    ctx
    |> mes("[Guard]")
    |> mes("You are something of an adventurer... Ok. I got it...")
    |> next()
    |> mes("[Guard]")
    |> mes("Once you get there, just find the head of the alliance.")
    |> close()
  end

  defp admit(ctx) do
    ctx
    |> mes("[Guard]")
    |> mes("You've come here")
    |> mes("to register as a member of the three kingdoms?")
    |> next()
    |> mes("[Guard]")
    |> mes("Enter.")
    |> close()
  end

  defp refuse(ctx) do
    ctx
    |> mes("[Guard]")
    |> mes("You are not allowed")
    |> mes("to enter.")
    |> close()
  end
end
