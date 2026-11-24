defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.GateSoldier171174 do
  @moduledoc """
  Guards the sick lord’s mother and discusses her condition.

  ## Behavior

  - Starts the Amatsu quest on the first conversation.
  - Dialogue changes with quest progression.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - MasterOfMuppets
    - L0ne_W0lf
    - Gepard
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "amatsu",
        x: 171,
        y: 174,
        dir: 4,
        sprite: 767,
        name: "Gate Soldier",
        scope: :shared,
        unique_name: "Gate Soldier#ama6"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx = mes(ctx, "[Gate Soldier]")

    ctx =
      case get_char_var(ctx, :event_amatsu, 0) do
        0 ->
          ctx
          |> mes("You can't enter here.")
          |> mes("The mother of our lord is resting in here.")
          |> mes(" ")
          |> next()
          |> setquest(8131)
          |> set_char_var(:event_amatsu, 1)
          |> mes("[Gate Soldier]")
          |> mes("She has been sick for months.")
          |> mes("That is why she is staying in here.")
          |> mes("...")

        1 ->
          ctx
          |> mes("Please, be quiet.")
          |> mes("The mother of the lord is staying in here. She needs to relax.")
          |> next()
          |> mes("[Gate Soldier]")
          |> mes("Why is this happening")
          |> mes("to my kind lord...")
          |> mes("How can it be? *Sob*...")

        5 ->
          ctx
          |> mes("Eh? Something was flying")
          |> mes("in the sky... You didn't see? Ugh.")
          |> mes("That sound suprised me.")

        6 ->
          ctx
          |> mes("Now our lord is relieved.")
          |> mes("We were so worrying about it so much.")
          |> mes("Now, it is okay... *sob*.")

        _ ->
          ctx
          |> mes("Oh...man. People from the other")
          |> mes("continents are all doctors!")
          |> mes("How many doctors have come to visit?! I can't even count anymore!")
      end

    close(ctx)
  end
end
