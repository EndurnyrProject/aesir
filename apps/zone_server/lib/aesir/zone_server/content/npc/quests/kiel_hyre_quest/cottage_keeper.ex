defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.CottageKeeper do
  @moduledoc """
  The cottage keeper questions visitors claiming an appointment with Kiel Hyre.

  ## Behavior

  - Confirms an appointment claim at the relevant quest stage and advances the investigation.
  - Otherwise warns visitors that the cottage is private property.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_fild02",
        x: 93,
        y: 210,
        dir: 4,
        sprite: 85,
        name: "Cottage Keeper",
        scope: :shared,
        unique_name: "Cottage Keeper#kh"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Cottage Keeper]")
      |> mes("This is private property,")
      |> mes("so please do not enter this")
      |> mes("area unless you're authorized.")

    if get_char_var(ctx, :KielHyreQuest, 0) == 12 do
      ask_appointment(ctx)
    else
      close(ctx)
    end
  end

  defp ask_appointment(ctx) do
    {ctx, choice} =
      ctx
      |> next()
      |> select(["I have an appointment with Kiel Hyre.", "Alright."])

    case choice do
      1 -> confirm_appointment(ctx)
      2 -> ctx |> mes("[Cottage Keeper]") |> mes("Goodbye.") |> close()
      _ -> ctx
    end
  end

  defp confirm_appointment(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Cottage Keeper]")
      |> mes("You have an")
      |> mes("appointment with")
      |> mes("Master Kiel Hyre?")
      |> mes("Um, are you sure?")
      |> next()
      |> select(["Yes", "No"])

    case choice do
      1 ->
        ctx
        |> mes("[Cottage Keeper]")
        |> mes("There must be some sort")
        |> mes("of mistake. Mister Hyre")
        |> mes("wouldn't have left if he")
        |> mes("was supposed to keep")
        |> mes("an appointment...")
        |> set_char_var(:KielHyreQuest, 14)
        |> close()

      2 ->
        ctx
        |> mes("[Cottage Keeper]")
        |> mes("Well unless you have")
        |> mes("an appointment, I don't")
        |> mes("think you'll be able to")
        |> mes("meet with Mister Hyre.")
        |> close()

      _ ->
        ctx
    end
  end
end
