defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.SleipnirSeal.Researcher1447 do
  @moduledoc """
  Pavel, a researcher with a bad flu, gives one of the Sleipnir Seal quest's research assistant
  tasks.

  ## Behavior

  - Outside the Sleipnir seal phase, or when the player is not on one of his research steps, he
    only muses about proving that spirits exist.
  - A player fresh from Kirin is assigned to him first.
  - He sends the player to look at the engraved slab, then asks for help removing the device
    installed in it.
  - Once the device is removed he thanks the player, finishes the task and advances the player
    to the next researcher.

  ## Credits

  - Original from rAthena, authors and Contributors
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
        x: 14,
        y: 47,
        dir: 3,
        sprite: 713,
        name: "Researcher",
        scope: :shared,
        unique_name: "Researcher#G4"
      }
    ]

  @research_steps [41, 12, 23, 34]
  @next_step %{41 => 42, 12 => 13, 23 => 24, 34 => 50}

  @impl true
  def on_talk(ctx) do
    if get_server_var(ctx, "God1", 0) < get_server_temp_var(ctx, "god_check2", 0) do
      ctx = assign_from_kirin(ctx)

      if get_char_var(ctx, :god_sl_1, 0) in @research_steps do
        research_task(ctx, get_char_var(ctx, :god_sl_2, 0))
      else
        spirits(ctx)
      end
    else
      spirits(ctx)
    end
  end

  defp assign_from_kirin(ctx) do
    if get_char_var(ctx, :god_sl_1, 0) == 2, do: set_char_var(ctx, :god_sl_1, 41), else: ctx
  end

  defp research_task(ctx, 0) do
    ctx
    |> mes("[Pavel]")
    |> mes("^333333*Sniff sniff*...")
    |> mes("*Achoo!*^000000 Huh?")
    |> mes("Who are you?")
    |> next()
    |> mes("[Pavel]")
    |> mes("Oh, sorry.")
    |> mes(
      "You must be the new assistan--^333333*Aaachoo!^000000 Ehhm, ^333333*Sniff sniff*^000000 I'm sorry. As you can see, I'm feeling a little bit under the weather."
    )
    |> next()
    |> mes("[Pavel]")
    |> mes(
      "It's good to know that you're help to help me. But ^333333*Achoooo! Sniff Sniff*^000000"
    )
    |> next()
    |> mes("[Pavel]")
    |> mes(
      "Anyway, go look at --^333333*Aaachooo!*^000000 that ^333333*Achoooo!*^000000 thing... ^333333*Sniff sniff*^000000"
    )
    |> set_char_var(:god_sl_2, 1)
    |> close()
  end

  defp research_task(ctx, 1) do
    ctx
    |> mes("[Pavel]")
    |> mes(
      "I told you to go look at-- ^333333*Aaachhoooo!*^000000 that ^333333*Aaachoooo! Achoo! glhk glhk*^000000"
    )
    |> close()
  end

  defp research_task(ctx, 2) do
    ctx
    |> mes("[Pavel]")
    |> mes("^333333*Cough cough*")
    |> mes("*Sniff sniff...*^000000")
    |> mes(
      "So did you take a look at it? Yeah, I don't think you'd understand, even if you saw it. ^333333*glhk glhk*^000000"
    )
    |> next()
    |> mes("[Pavel]")
    |> mes("^333333*AAAAACHHHOOO!*^000000")
    |> mes(
      "That slab of stone, no wait, ^333333*Achoo!*^000000 the letters engraved on that thing are ancien--^333333*Achoo!*^000000 language is no longer used nowadays."
    )
    |> next()
    |> mes("[Pavel]")
    |> mes(
      "I can't ^333333*glhk glhk*^000000 tell what ancient languag-- ^333333*Achoo!*^000000 it is, so... Hmm..."
    )
    |> next()
    |> mes("[Pavel]")
    |> mes(
      "Considering ^333333*Achoo! Sniff sniff*^000000 the material used for the slab isn't ^333333*Sniff*^000000 ordinary stone, there must be some kind of device installed in it? ^333333*Cough*^000000"
    )
    |> next()
    |> mes("[Pavel]")
    |> mes(
      "Not only that ^333333*Sniff sniff* letters are not just engraved. ^333333*AAAACHOO!*^000000 Something covers the ^333333*Cough*^000000 surface."
    )
    |> next()
    |> mes("[Pavel]")
    |> mes(
      "I must ^333333*Cough cough*^000000 remove the device for so that I can ^333333*Cough cough*^000000 investigate this further ^333333*Sniff*^000000 Butjust look at me. I'm a wreck. I can't even ^333333*AAAACHOO!*^000000 ...talk."
    )
    |> next()
    |> mes("[Pavel]")
    |> mes("^333333*Sniff sniff*^000000")
    |> mes(
      "So I hope you don't mind ^333333*Achoo!*^000000 helping me remove ^333333*Cough*^000000 the device. Thank you so much. ^333333*Sniff*^000000"
    )
    |> set_char_var(:god_sl_2, 3)
    |> close()
  end

  defp research_task(ctx, 3) do
    ctx
    |> mes("[Pavel]")
    |> mes("^333333Aaaaaccccchhhhoooo...!*^000000")
    |> mes("Um, what I meant to say w--^333333AAAACHOOO!*^000000")
    |> mes("^333333*Sniff sniff...*^000000")
    |> close()
  end

  defp research_task(ctx, 4) do
    ctx
    |> mes("[Pavel]")
    |> mes("^333333*Cough*^000000")
    |> mes("Oh... ^333333*Sniff*^000000")
    |> mes("Now I see...")
    |> mes("^333333*glhk glhk*^000000")
    |> next()
    |> mes("[Pavel]")
    |> mes(
      "I was~ ^333333*Achoo!*^000000 right, ^333333*Achoo!*^000000 Something was installed in the sl-^333333*Cough*^000000 slab. I couldn't look at it myself because of this damn ^333333*Cooooough c-c-cough*^000000 flu."
    )
    |> next()
    |> mes("[Pavel]")
    |> mes("Great job~")
    |> mes(
      "You did some ^333333*Sniff*^000000 good work. Thank you so much for helping me. ^333333*Achoo! Achoo!*^000000"
    )
    |> set_char_var(:god_sl_2, 0)
    |> advance_step()
    |> close()
  end

  defp research_task(ctx, _god_sl_2), do: ctx

  defp advance_step(ctx) do
    case Map.fetch(@next_step, get_char_var(ctx, :god_sl_1, 0)) do
      {:ok, step} -> set_char_var(ctx, :god_sl_1, step)
      :error -> ctx
    end
  end

  defp spirits(ctx) do
    ctx
    |> mes("[Pavel]")
    |> mes(
      "Whether or not we can actually detect or sense spirits isn't as important as first proving their existence."
    )
    |> close2()
  end
end
