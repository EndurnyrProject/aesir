defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.BarmutRoom1 do
  @moduledoc """
  A burning mansion appears in the Crow of the Fate vision.

  ## Behavior

  - At the relevant quest stage, the player witnesses the mysterious man before returning to the library.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
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
        map: "que_ba",
        x: 264,
        y: 186,
        dir: 0,
        sprite: 139,
        name: "",
        scope: :shared,
        unique_name: "#barmut_room1",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx), do: show_vision(ctx)
  @impl true
  def on_talk(ctx) do
    show_vision(ctx)
  end

  defp show_vision(ctx) do
    if get_char_var(ctx, :barmunt_crow, 0) == 11 do
      ctx
      |> mes(
        "^660000You wake up, and look around you. Somehow, you've now ended up in a huge mansion.^000000"
      )
      |> next()
      |> mes(
        "^660000You suddenly feel a sharp pain in your chest, as if someone were squeezing your heart.^000000"
      )
      |> next()
      |> mes(
        "^660000This mansion looks very elegant and expensive, but it is on fire, just like the laboratory in your first dream.^000000"
      )
      |> next()
      |> mes(
        "^660000You're having trouble thinking because of your chest pain and the fire, but you know that this mansion won't last long. You look around for an exit, and see a man standing downstairs in the center of flames.^000000"
      )
      |> next()
      |> mes(
        "^660000He didn't seem to care that he'd perish along with the mansion, and was talking slowly in a low, sad voice.^000000"
      )
      |> next()
      |> mes("[Mysterious Man]")
      |> mes(".....................")
      |> mes("After all, God has trifled with me...")
      |> mes("This was his plan all long...")
      |> mes("Even my best friends were his puppets...")
      |> next()
      |> mes("[Mysterious Man]")
      |> mes("I strongly resent my fate...")
      |> mes("But I'm ready to accept the end... Of everything...")
      |> next()
      |> mes(
        "^660000He could not finish his words before flames swallowed him up. At the same time, you were...^000000"
      )
      |> specialeffect(:meteorstorm)
      |> set_char_var(:barmunt_crow, 12)
      |> close2()
      |> warp("yuno_in04", 108, 57)
    else
      warp(ctx, "yuno_in04", 108, 57)
    end
  end
end
