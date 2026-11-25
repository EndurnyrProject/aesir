defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.LiEnd do
  @moduledoc """
  Marks the scientist’s abandoned laboratory.

  ## Behavior

  - Completes the curse quest when the player returns.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_que01",
        x: 94,
        y: 24,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#li_end",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: visit_lab(ctx)

  @impl true
  def on_talk(ctx), do: visit_lab(ctx)

  defp visit_lab(ctx) do
    progress = get_char_var(ctx, :lhz_curse, 0)

    if progress > 30 do
      ctx =
        ctx
        |> mes("^3131FFThere's no trace of")
        |> mes("that mad scientist. Only")
        |> mes("his stacks of well organized")
        |> mes("files remain here in the lab.^000000")

      ctx =
        if progress == 31,
          do: ctx |> set_char_var(:lhz_curse, 32) |> completequest(2095),
          else: ctx

      close(ctx)
    else
      ctx
    end
  end
end
