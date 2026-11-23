defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.Lab02Heart do
  @moduledoc """
  Introduces the laboratory password checker.

  ## Behavior

  - Advances the Heart Fragment quest from stage nine to ten.

  ## Credits

  - Original from rAthena, authors and contributors:
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - brianluau
    - Joseph
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
        map: "ein_in01",
        x: 264,
        y: 17,
        dir: 0,
        sprite: 139,
        name: "",
        scope: :shared,
        unique_name: "#lab02_heart",
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)

  @impl true
  def on_talk(ctx), do: ctx

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :lhz_heart, 0) == 9 do
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("What the...")
      |> mes("It's some sort of")
      |> mes("weird device. The label")
      |> mes("here says, ''Password")
      |> mes("Checker?'' Well, this")
      |> mes("might come in handy later.")
      |> next()
      |> mes("^3355FFYou decide to bring")
      |> mes("the Password Checker")
      |> mes("device with you into")
      |> mes("the laboratory.^000000")
      |> set_char_var(:lhz_heart, 10)
      |> close()
    else
      ctx
    end
  end
end
