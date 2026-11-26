defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Monologue do
  @moduledoc """
  Touch trigger that plays Hermite Charles' memory of Lowen's last stand.

  ## Behavior

  - Shows Lowen casting Grand Cross against Hermite's pleas, with map announcements.
  - Hides Hermite from the scene, then returns the player to the start of the area.

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
        x: 120,
        y: 52,
        dir: 0,
        sprite: 139,
        name: "",
        scope: :shared,
        unique_name: "#monologue",
        trigger: {0, 0}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: play_memory(ctx)

  @impl true
  def on_talk(ctx), do: play_memory(ctx)

  defp play_memory(ctx) do
    ctx
    |> player_header()
    |> mes("Where am I?")
    |> mes("Isn't that...")
    |> mes("What's Hermite")
    |> mes("doing here?!")
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("No, no, no!")
    |> mes("Lowen don't...!")
    |> mes("He's gonna kill you!")
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("Grand Cross?!")
    |> mes("Using that's")
    |> mes("committing suicide!")
    |> mes("Lowen, don't do it!")
    |> mes("Don't do that, Lowen!")
    |> next()
    |> mapannounce("que_god02", "Mwahaha! Mortals are such fools...", 0, 11_053_224)
    |> mes("[Hermite Charles]")
    |> mes("Lowen!")
    |> mes("Noooooooooo!!!")
    |> next()
    |> donpcevent("#brisinsummon::OnHermiteOff")
    |> player_header()
    |> mes("Where did he go?")
    |> mes("Was... Was that")
    |> mes("from his mind?")
    |> mapannounce("que_god02", "What happened?! L-Lowen's gone!!", 0, 11_053_224)
    |> next()
    |> mes("[Lowen Ellenen]")
    |> mes("...")
    |> mes("I see now.")
    |> mes("I know...")
    |> mes("What happened...")
    |> close2()
    |> warp("que_god02", 18, 127)
  end

  defp player_header(ctx), do: mes(ctx, "[#{char_name(ctx, 0)}]")
end
