defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.Lab01Heart do
  @moduledoc """
  Prompts the player to investigate the laboratory.

  ## Behavior

  - Shows a thought when the Heart Fragment quest reaches stage nine.

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
        x: 279,
        y: 25,
        dir: 0,
        sprite: 139,
        name: "",
        scope: :shared,
        unique_name: "#lab01_heart",
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
      |> mes("(^333333I've... I've just")
      |> mes("got to investigate")
      |> mes("that laboratory and")
      |> mes("see if anything funny")
      |> mes("is going on in there.^000000)")
      |> close()
    else
      ctx
    end
  end
end
