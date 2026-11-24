defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.GateSoldier164174 do
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
        x: 164,
        y: 174,
        dir: 4,
        sprite: 767,
        name: "Gate Soldier",
        scope: :shared,
        unique_name: "Gate Soldier#ama5"
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
          |> mes("The mother of our lord is resting in here. She needs her rest.")
          |> next()
          |> set_char_var(:event_amatsu, 1)
          |> setquest(8131)
          |> mes("[Gate Soldier]")
          |> mes("She has been sick for months.")
          |> mes("That is why she is staying in here.")
          |> mes("It's a pretty fearsome sickness...")

        1 ->
          ctx
          |> mes("She should regain her health...")
          |> mes("But still, my lord is worrying so much.")
          |> mes(" ")

        5 ->
          ctx
          |> mes("Augh! I was suprised by that loud sound.")
          |> mes("What happened? Huh?")
          |> mes(" ")

        6 ->
          ctx
          |> mes("The mother of our lord hasn't")
          |> mes("fully recovered her health.")
          |> mes("Still, she is better than before.")
          |> mes(" ")

        _ ->
          ctx
          |> mes("If you are sent by my lord,")
          |> mes("it is okay to enter...")
          |> mes("But you wouldn't be able to cure")
          |> mes("her. Many others tried and failed.")
      end

    close(ctx)
  end
end
