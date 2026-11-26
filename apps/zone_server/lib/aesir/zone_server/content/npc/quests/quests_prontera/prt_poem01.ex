defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.PrtPoem01 do
  @moduledoc """
  An invisible verse of the Geoborg Family Curse poem, shown at one quest step.

  ## Behavior

  - Touching or clicking it while `prt_curse` is 11 shows the verse; otherwise nothing happens.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Evera
    - Samuray22
    - SinSloth
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mjolnir_01",
        x: 298,
        y: 302,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#prt_poem01",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx), do: read_verse(ctx)

  @impl true
  def on_talk(ctx), do: read_verse(ctx)

  defp read_verse(ctx) do
    if get_char_var(ctx, :prt_curse, 0) == 11, do: show_verse(ctx), else: ctx
  end

  defp show_verse(ctx) do
    ctx
    |> mes("^FF0000*The great serpent*^000000")
    |> mes("^FF0000*swallowed the sea.*^000000")
    |> close()
  end
end
