defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Julian15582 do
  @moduledoc """
  Julian reacts to the excavation leaders’ dispute.

  ## Behavior

  - His dialogue changes with quest progress.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
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
        map: "hu_in01",
        x: 155,
        y: 82,
        dir: 4,
        sprite: 86,
        name: "Julian",
        scope: :shared,
        unique_name: "Julian#2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :hg_odin, 0) in [22, 23] do
      ctx
      |> mes("[Julian]")
      |> mes("I...")
      |> mes("I don't know")
      |> mes("what I should do!")
      |> close()
    else
      ctx
      |> mes("[Julian]")
      |> mes("I've stopped caring")
      |> mes("whether they fight or")
      |> mes("not... I'm so not get")
      |> mes("involved. If you want,")
      |> mes("you can try to stop them...")
      |> close()
    end
  end
end
