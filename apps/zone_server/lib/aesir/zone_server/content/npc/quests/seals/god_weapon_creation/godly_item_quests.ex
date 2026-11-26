defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.GodWeaponCreation.GodlyItemQuests do
  @moduledoc """
  GM-only emergency console for the God Item creation laboratory.

  ## Behavior

  - Only GM level 99 characters can use it, and it asks for a numeric password first; zero
    cancels the request.
  - Turns off the laboratory warps, resets Grunburti's timer, or resets the laboratory entrance
    chat room.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_god01",
        x: 293,
        y: 3,
        dir: 0,
        sprite: 90,
        name: "Godly Item Quests",
        scope: :shared,
        unique_name: "Godly Item Quests#god"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FGmNpc

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FGmNpc.call(ctx, [])

    {ctx, password} =
      ctx
      |> mes("[Use in case of emergency]")
      |> mes("Please enter password.")
      |> mes("If you wish to cancel, please enter 0.")
      |> next()
      |> FGmNpc.call([1854, 0, 0, 4000])

    case password do
      -2 ->
        ctx |> mes("[Use in case of emergency]") |> mes("Password is incorrect.") |> close()

      -1 ->
        ctx
        |> mes("[Use in case of emergency]")
        |> mes("You have canceled your request.")
        |> close()

      0 ->
        close(ctx)

      _ ->
        {ctx, choice} =
          ctx
          |> mes("[Use in case of emergency]")
          |> mes("What services would you like to use?")
          |> next()
          |> select(["Turn off Warps.", "Reset Timer.", "Reset chat room."])

        service(ctx, choice)
    end
  end

  defp service(ctx, 1) do
    ctx
    |> mes("[Use in case of emergency]")
    |> mes("Press the 'Next' button to turn off warps.")
    |> next()
    |> donpcevent("god_wep_warpmaster::OnDisable")
    |> mes("[Use in case of emergency]")
    |> mes("You have successfully turned off warps.")
    |> close()
  end

  defp service(ctx, 2) do
    ctx
    |> mes("[Use in case of emergency]")
    |> mes("Press the 'Next' button to reset timer.")
    |> next()
    |> donpcevent("Grunburti#god::OnEnable")
    |> mes("[Use in case of emergency]")
    |> mes("You have successfully reset timer.")
    |> close()
  end

  defp service(ctx, 3) do
    ctx
    |> mes("[Use in case of emergency]")
    |> mes("Please press the 'Next' button to reset the arena chat room in que_god01.")
    |> next()
    |> donpcevent("#god_hopewarp1::OnReset")
    |> mes("[Use in case of emergency]")
    |> mes("You have successfully reset the arena chat room (Laboratory Entrance 1/2).")
    |> close()
  end

  defp service(ctx, _), do: ctx
end
