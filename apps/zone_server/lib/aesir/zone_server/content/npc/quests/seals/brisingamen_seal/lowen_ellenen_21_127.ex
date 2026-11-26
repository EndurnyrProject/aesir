defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.LowenEllenen21127 do
  @moduledoc """
  Lowen recalls the events following her failed mission.

  ## Behavior

  - Recounts her punishment and starts the next battle after the conversation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_god02",
        x: 21,
        y: 127,
        dir: 3,
        sprite: 745,
        name: "Lowen Ellenen",
        scope: :shared,
        unique_name: "Lowen Ellenen#2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Lowen Ellenen]")
    |> mes("I was a fool.")
    |> mes(
      "Now I remember Hermite. He must have been the one who rescued me. But when I came to my senses, no one was there."
    )
    |> next()
    |> mes("[Lowen Ellenen]")
    |> mes(
      "I blamed myself for surviving alone. I should have died there with my friends. I felt so useless."
    )
    |> next()
    |> mes("[Lowen Ellenen]")
    |> mes(
      "Now I realize that there were many people who loved me. But at the time, I felt only guilt."
    )
    |> next()
    |> mes("[Lowen Ellenen]")
    |> mes(
      "I returned 3 days later to my commander. It was stupid, but at the moment I couldn't think of anything else."
    )
    |> next()
    |> mes("[Lowen Ellenen]")
    |> mes(
      "The higher ups and the politicians were looking for a scapegoat for the failure of the mission."
    )
    |> next()
    |> mes("[Lowen Ellenen]")
    |> mes(
      "So I was the one who was blamed. Then, they took away everything I had. My status, the holy power granted to me..."
    )
    |> next()
    |> mes("[Lowen Ellenen]")
    |> mes("I thought I deserved that punishment. After all, why should")
    |> mes("I have survived when all my comrades died?")
    |> next()
    |> mes("[Lowen Ellenen]")
    |> mes("It was then that I decided to avenge my friends, and salvage")
    |> mes("what was left of my sense of honor.")
    |> next()
    |> mes("[Lowen Ellenen]")
    |> mes("I went back to that place.")
    |> mes("I fought and I fought, trying to make penance for what I had")
    |> mes("done wrong...")
    |> next()
    |> mapannounce(
      "que_god02",
      "If you wish, continue your battle. I promise you the winner will become an Einherjar...",
      0,
      7_396_243
    )
    |> mes("[Lowen Ellenen]")
    |> mes("That voice...")
    |> mes("Isn't that...?")
    |> next()
    |> mes("[Lowen Ellenen]")
    |> mes(
      "Are you giving me another chance? But I no longer have a body to fight monsters anymore..."
    )
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Don't worry,")
    |> mes("I'm with you!")
    |> mes("Let's do it!")
    |> close2()
    |> donpcevent("#brisinsummon::OnSummon")
    |> donpcevent("#brisinsummon::OnLowen2Off")
  end
end
