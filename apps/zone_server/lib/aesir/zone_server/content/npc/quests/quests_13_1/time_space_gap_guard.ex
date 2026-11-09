defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.TimeSpaceGapGuard do
  @moduledoc """
  The frightened guard at the ruins of Morocc who secretly sends a proven adventurer
  through the time-space gap.

  ## Behavior

  - At `ep13_ryu` step 100 trembles, admires the player's courage and offers to send them
    through the gap: accepting closes the dialog and warps to `moc_fild22b` 49,195, declining
    keeps the secret.
  - Below that step only confesses his fear and asks the player to keep quiet about him.

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
        map: "moc_ruins",
        x: 137,
        y: 89,
        dir: 5,
        sprite: 707,
        name: "Time-Space Gap Guard",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :ep13_ryu, 0) == 100 do
      offer_passage(ctx)
    else
      confesses_fear(ctx)
    end
  end

  defp offer_passage(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Guard]")
      |> mes("- Trembling in fear. -")
      |> next()
      |> mes("[Guard]")
      |> mes("- Trembling in fear. -")
      |> next()
      |> mes("[Guard]")
      |> mes("Honestly, I should keep")
      |> mes("to the dimensional rift,")
      |> mes("but it's quite scary.")
      |> mes("I ran away from it.")
      |> next()
      |> mes("[Guard]")
      |> mes("Ah?")
      |> mes("You're quite brave!")
      |> mes("And not scared about things around you. I envy you...")
      |> next()
      |> mes("[Guard]")
      |> mes("I am a coward but,")
      |> mes(
        "I can send you through the dimensional rift. That's the only thing I can do for you."
      )
      |> next()
      |> mes("[Guard]")
      |> mes("I send you there easily,")
      |> mes("but don't tell others about me. Ok??")
      |> next()
      |> mes("[Guard]")
      |> mes("Then, do you want to go through the Time-Space Gap now??")
      |> next()
      |> select(["Yes.", "No, thanks."])

    case choice do
      1 -> send_through(ctx)
      2 -> wait_here(ctx)
      _ -> ctx
    end
  end

  defp send_through(ctx) do
    ctx
    |> mes("[Guard]")
    |> mes(
      "Ok, then I will send you there. As I already said, don't tell anybody about me. Anyway... good luck!!"
    )
    |> close()
    |> warp("moc_fild22b", 49, 195)
  end

  defp wait_here(ctx) do
    ctx
    |> mes("[Guard]")
    |> mes("It's ok.")
    |> mes("Just don't tell anybody about me. Please.")
    |> close()
  end

  # The reference spells this page "onestly", unlike the "Honestly" of the passage dialog above.
  defp confesses_fear(ctx) do
    ctx
    |> mes("[Guard]")
    |> mes("- Trembling in fear. -")
    |> next()
    |> mes("[Guard]")
    |> mes("onestly, I should keep")
    |> mes("to the dimensional rift,")
    |> mes("but it's quite scary.")
    |> mes("I ran away from it.")
    |> next()
    |> mes("[Guard]")
    |> mes("- Trembling. -")
    |> mes("Please keep the secret")
    |> mes("about me being here.")
    |> mes("I am so scared!!")
    |> close()
  end
end
